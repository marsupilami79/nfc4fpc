unit iksnfc;

{$mode Delphi}

interface

uses
  Classes, SysUtils, libnfc;

  type
    TNdefPayloadEvent = procedure(Sender: TObject; Payload: RawByteString) of object;

    TNdefNfcThread = class(TThread)
      protected
        FContext: Pnfc_context;
        FPnd: Pnfc_device;
        FNdefPayload: RawByteString;
        FOnNdefPayloadReceived: TNdefPayloadEvent;
        function SendApdu(const Apdu: RawByteString; out Response: RawByteString): Boolean;
        procedure SendNdefData;
      public
        procedure Execute; override;
    end;

    TIksNdefNfc = class (TComponent)
    protected
      FOnNdefPayloadReceived: TNdefPayloadEvent;
      FActive: Boolean;
      FNfcThread: TNdefNfcThread;
      procedure OnPayloadReceived(Sender: TObject; Payload: RawByteString);
      procedure SetActive(NewValue: Boolean);
      procedure StartNfc;
      procedure StopNfc;
    public
    published
      property Active: Boolean read FActive write SetActive;
      property OnNdefPayloadReceived: TNdefPayloadEvent read FOnNdefPayloadReceived write FOnNdefPayloadReceived;
    end;

implementation

procedure TNdefNfcThread.Execute;
const
  SelectNdefAppApdu = #$00#$A4#$04#$00#$07#$D2#$76#$00#$00#$85#$01#$01;
  SelectFileApdu = #$00#$A4#$00#$0C#$02#$E1#$04;
  ReadDataApdu = #$00#$B0#$00#$00#$00;
  nmMifare: Tnfc_modulation = (nmt: NMT_ISO14443A; nbr: NBR_106);
var
  nt: Tnfc_target;
  Response: RawByteString;
begin
  while not Terminated do begin
    while nfc_initiator_select_passive_target(FPnd, nmMifare, nil, 0, @nt) <= 0 do
      sleep(0);

    if SendApdu(SelectNdefAppApdu, Response) then
      if SendApdu(SelectFileApdu, Response) then
        if SendApdu(ReadDataApdu, FNdefPayload) then
          if Assigned(FOnNdefPayloadReceived) then
            Synchronize(SendNdefData);

    while (nfc_initiator_target_is_present(FPnd, nil) = 0) and not Terminated do
      sleep(0);
  end;
end;

procedure TNdefNfcThread.SendNdefData;
begin
  if Assigned(FOnNdefPayloadReceived) then
    FOnNdefPayloadReceived(nil, FNdefPayload);
end;

function TNdefNfcThread.SendApdu(const Apdu: RawByteString; out Response: RawByteString): Boolean;
const
  ResOk: RawByteString = #$90#$00;
var
  Status: RawByteString;
  res: Integer;
begin
  Response := '';
  SetLength(Response, 257);
  res := nfc_initiator_transceive_bytes(FPnd, @Apdu[1], length(Apdu), @Response[1], length(Response), 100000);

  if res < 2 then begin
    Result := False;
    exit;
  end else begin
    SetLength(Response, res);
    Status := Copy(Response, Length(Response) - 1, 2);
    if Status <> ResOk then begin
      Result := False;
      exit;
    end else begin
      Result := True;
      Delete(Response, Length(Response) - 1, 2);
    end;
  end;
end;

{------------------------------------------------------------------------------}

procedure TIksNdefNfc.OnPayloadReceived(Sender: TObject; Payload: RawByteString);
begin
  if Assigned(FOnNdefPayloadReceived) then
    FOnNdefPayloadReceived(Self, Payload);
end;

procedure TIksNdefNfc.SetActive(NewValue: Boolean);
begin
  if not FActive and NewValue then
    StartNfc;
  if FActive and not NewValue then
    StopNfc;
end;

procedure TIksNdefNfc.StartNfc;
begin
  if Assigned(FNfcThread) then begin
    if not FNfcThread.CheckTerminated then
      raise Exception.Create('Old NFC Thread is still executing.');
  end;

  FNfcThread := TNdefNfcThread.Create(true);
  try
    FNfcThread.FOnNdefPayloadReceived := OnPayloadReceived;
    nfc_init(@FNfcThread.FContext);
    if not Assigned(FNfcThread.FContext) then
      raise Exception.Create('Unable to init libnfc (malloc)');

    // Open, using the first available NFC device which can be in order of selection:
    //   - default device specified using environment variable or
    //   - first specified device in libnfc.conf (/etc/nfc) or
    //   - first specified device in device-configuration directory (/etc/nfc/devices.d) or
    //   - first auto-detected (if feature is not disabled in libnfc.conf) device
    FNfcThread.FPnd := nfc_open(FNfcThread.FContext, nil);
    if not assigned(FNfcThread.FPnd) then
      raise Exception.Create(Format('ERROR: %s', ['Unable to open NFC device.']));

    // Set opened NFC device to initiator mode
    if nfc_initiator_init(FNfcThread.FPnd) < 0 then
      raise Exception.Create(nfc_strerror(FNfcThread.FPnd));

    FNfcThread.Start;
  except
    FreeAndNil(FNfcThread);
    raise;
  end;

  FActive := true;
end;

procedure TIksNdefNfc.StopNfc;
begin
  if Assigned(FNfcThread) then begin
    FNfcThread.Terminate;
    while not FNfcThread.CheckTerminated do
      Sleep(0);
    FreeAndNil(FNfcThread);
  end;
end;

end.

