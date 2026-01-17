unit libnfc;

{$mode Delphi}

{$PACKRECORDS 1}
{$PACKENUM 4}

interface

uses
  Classes, SysUtils, ctypes;

type
  Tnfc_dep_mode = (
    NDM_UNDEFINED = 0,
    NDM_PASSIVE,
    NDM_ACTIVE
  );

  Tnfc_dep_info = record
    (** NFCID3 *)
    abtNFCID3: array[0..9] of cuint8;
    (** DID *)
    btDID: cuint8;
    (** Supported send-bit rate *)
    btBS: cuint8;
    (** Supported receive-bit rate *)
    btBR: cuint8;
    (** Timeout value *)
    btTO: cuint8;
    (** PP Parameters *)
    btPP: cuint8;
    (** General Bytes *)
    abtGB: array[0..47] of cuint8;
    szGB: csize_t;
    (** DEP mode *)
    ndm: Tnfc_dep_mode;
  end;

  Tnfc_iso14443a_info = record
    abtAtqa: array[0..1] of cuint8;
    btSak: cuint8;
    szUidLen: csize_t;
    abtUid: array[0..9] of cuint8;
    szAtsLen: csize_t;
    abtAts: array[0..253] of cuint8; // Maximal theoretical ATS is FSD-2, FSD=256 for FSDI=8 in RATS
  end;

  Tnfc_felica_info = record
    szLen: csize_t;
    btResCode: cuint8;
    abtId: array[0..7] of cuint8;
    abtPad: array[0..7] of cuint8;
    abtSysCode: array[0..1] of cuint8;
  end;

  Tnfc_iso14443b_info = record
    (** abtPupi store PUPI contained in ATQB (Answer To reQuest of type B) (see ISO14443-3) *)
    abtPupi: array[0..3] of cuint8;
    (** abtApplicationData store Application Data contained in ATQB (see ISO14443-3) *)
    abtApplicationData: array[0..3] of cuint8;
    (** abtProtocolInfo store Protocol Info contained in ATQB (see ISO14443-3) *)
    abtProtocolInfo: array[0..2] of cuint8;
    (** ui8CardIdentifier store CID (Card Identifier) attributted by PCD to the PICC *)
    ui8CardIdentifier: cuint8;
  end;

  Tnfc_iso14443bi_info = record
    (** DIV: 4 LSBytes of tag serial number *)
    abtDIV: array[0..3] of cuint8;
    (** Software version & type of REPGEN *)
    btVerLog: cuint8;
    (** Config Byte, present if long REPGEN *)
    btConfig: cuint8;
    (** ATR, if any *)
    szAtrLen: csize_t;
    abtAtr: array[0..32] of cuint8;
  end;

  Tnfc_iso14443biclass_info = record
    abtUID: array[0..7] of cuint8;
  end;

  Tnfc_iso14443b2sr_info = record
    abtUID: array[0..7] of cuint8;
  end;

  Tnfc_iso14443b2ct_info = record
    abtUID: array[0..3] of cuint8;
    btProdCode: cuint8;
    btFabCode: cuint8;
  end;

  Tnfc_jewel_info = record
    btSensRes: array[0..1] of cuint8;
    btId: array[0..3] of cuint8;
  end;

  Tnfc_barcode_info = record
    szDataLen: csize_t;
    abtData: array[0..31] of cuint8;
  end;

  Tnfc_target_info = record
    case byte of
      0: (nai: Tnfc_iso14443a_info);
      1: (nfi: Tnfc_felica_info);
      2: (nbi: Tnfc_iso14443b_info);
      3: (nii: Tnfc_iso14443bi_info);
      4: (nsi: Tnfc_iso14443b2sr_info);
      5: (nci: Tnfc_iso14443b2ct_info);
      6: (nji: Tnfc_jewel_info);
      7: (ndi: Tnfc_dep_info);
      8: (nti: Tnfc_barcode_info); // "t" for Thinfilm, "b" already used
      9: (nhi: Tnfc_iso14443biclass_info); // hid iclass / picopass - nii already used
  end;

  Tnfc_baud_rate = (
    NBR_UNDEFINED = 0,
    NBR_106,
    NBR_212,
    NBR_424,
    NBR_847
  );

  Tnfc_modulation_type = (
    NMT_ISO14443A = 1,
    NMT_JEWEL,
    NMT_ISO14443B,
    NMT_ISO14443BI, // pre-ISO14443B aka ISO/IEC 14443 B' or Type B'
    NMT_ISO14443B2SR, // ISO14443-2B ST SRx
    NMT_ISO14443B2CT, // ISO14443-2B ASK CTx
    NMT_FELICA,
    NMT_DEP,
    NMT_BARCODE,    // Thinfilm NFC Barcode
    NMT_ISO14443BICLASS, // HID iClass 14443B mode
    NMT_END_ENUM = NMT_ISO14443BICLASS // dummy for sizing - always should alias last
  );

  Tnfc_mode = (
    N_TARGET,
    N_INITIATOR
  );

  Tnfc_modulation = record
    nmt: Tnfc_modulation_type;
    nbr: Tnfc_baud_rate;
  end;

  Tnfc_target = record
    nti: Tnfc_target_info;
    nm: Tnfc_modulation;
  end;
  Pnfc_target = ^Tnfc_target;

  Pnfc_context = Pointer;
  PPnfc_context = ^Pnfc_context;
  Pnfc_device = Pointer;

  procedure nfc_init(context: PPnfc_context); cdecl; external 'libnfc.so';
  procedure nfc_exit(context: Pnfc_context); cdecl; external 'libnfc.so';
  function nfc_version: PAnsiChar; cdecl; external 'libnfc.so';
  function nfc_open(context: Pnfc_context; connstring: PAnsiChar): Pnfc_device; cdecl; external 'libnfc.so';
  function nfc_initiator_init(pnd: Pnfc_device): cint; cdecl; external 'libnfc.so';
  function nfc_strerror(pnd: Pnfc_device): PAnsiChar; cdecl; external 'libnfc.so';
  function nfc_device_get_name(pnd: Pnfc_device): PAnsiChar; cdecl; external 'libnfc.so';
  function nfc_initiator_select_passive_target(pnd: Pnfc_device; nm: Tnfc_modulation; pbtInitData: pcuint8; szInitData: csize_t; pnt: Pnfc_target): cint; cdecl; external 'libnfc.so';
  procedure nfc_close(pnd: Pnfc_device); cdecl; external 'libnfc.so';
  function nfc_initiator_transceive_bytes(pnd: Pnfc_device; pbtTx: pcuint8; szTx: csize_t; pbtRx: pcuint8; szRx: csize_t; timeout: cint): cint; cdecl; external 'libnfc.so';
  function nfc_initiator_target_is_present(pnd: Pnfc_device; pnt: Pnfc_target): cint; cdecl; external 'libnfc.so';

implementation

end.

