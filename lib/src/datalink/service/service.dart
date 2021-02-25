import 'package:adhoclibrary/src/datalink/service/connect_status.dart';
import 'package:adhoclibrary/src/datalink/utils/msg_adhoc.dart';
import 'package:adhoclibrary/src/datalink/utils/utils.dart';


abstract class Service {
  static const String TAG = "[Service]";

  static const WIFI = 0;
  static const BLUETOOTHLE = 1;

  static const STATE_NONE = 0;
  static const STATE_CONNECTED = 1;
  static const STATE_CONNECTING = 2;
  static const STATE_LISTENING = 3;

  static const MESSAGE_RECEIVED = 4;
  static const DEVICE_DISCOVERED = 5;
  static const DISCOVERY_STARTED = 6;
  static const DISCOVERY_END = 7;
  static const CONNECTION_PERFORMED = 8;
  static const CONNECTION_CLOSED = 9;
  static const CONNECTION_EXCEPTION = 10;

  int _state;

  bool verbose;
  Stream<ConnectStatus> connStatusStream;
  Stream<MessageAdHoc> messageStream;

  Service(this.verbose, this._state);

/*------------------------------Getters & Setters-----------------------------*/

  set state(int state) {
    if (verbose)
      log(TAG, 'state: ${_stateAsString(_state)}  -> ${_stateAsString(state)}');
    _state = state;
  }

  int get state => _state;

/*-----------------------------Private methods-------------------------------*/

  String _stateAsString(int state) {
    switch (state) {
      case STATE_CONNECTED:
        return 'Connected';
      case STATE_CONNECTING:
        return 'Connecting';
      case STATE_LISTENING:
        return 'Listening';
      default:
        return 'None';
    }
  }
}
