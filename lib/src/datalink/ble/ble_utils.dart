class BleUtils {
  static const SERVICE_UUID = '00000001-0000-1000-8000-00805f9b34fb';
  static const CHARACTERISTIC_UUID = '00000002-0000-1000-8000-00805f9b34fb';
  static const IDENTIFIER_UUID = "00000003-0000-1000-8000-00805f9b34fb";

  static const ULID_IDENTIFIER = 0;
  static const CONNECTION_STATUS = 1;

  static const BLE_STATE_DISCONNECTED = 0;

  static const MIN_MTU = 20;
  static const MAX_MTU = 512;

  static const MESSAGE_END = 0;
  static const MESSAGE_BEGIN = 1;

  static const UINT8_SIZE = 256;
}
