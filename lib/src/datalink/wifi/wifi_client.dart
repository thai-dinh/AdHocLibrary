import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:adhoclibrary/src/datalink/exceptions/no_connection.dart';
import 'package:adhoclibrary/src/datalink/service/connect_status.dart';
import 'package:adhoclibrary/src/datalink/utils/msg_adhoc.dart';
import 'package:adhoclibrary/src/datalink/service/service.dart';
import 'package:adhoclibrary/src/datalink/service/service_client.dart';
import 'package:adhoclibrary/src/datalink/utils/utils.dart';
import 'package:flutter_wifi_p2p/flutter_wifi_p2p.dart';


class WifiClient extends ServiceClient {
  StreamController<ConnectStatus> _controller;
  Socket _socket;
  String _serverIp;
  int _port;

  void Function(String) _connectListener;

  WifiClient(
    bool verbose, this._port, this._serverIp, int attempts, int timeOut,
  ) : super(
    verbose, Service.STATE_NONE, attempts, timeOut
  ) {
    this._controller = StreamController<ConnectStatus>();
  }

/*------------------------------Getters & Setters-----------------------------*/

  set connectListener(void Function(String) connectListener) {
    this._connectListener = connectListener;
  }

  Stream<ConnectStatus> get connStatusStream async* {
    await for (ConnectStatus status in _controller.stream) {
      yield status;
    }
  }

  Stream<MessageAdHoc> get messageStream async* {
    await for (Uint8List data in _socket.asBroadcastStream()) {
      String strMessage = Utf8Decoder().convert(data);
      yield MessageAdHoc.fromJson(json.decode(strMessage));
    }
  }

/*-------------------------------Public methods-------------------------------*/

  Future<void> connect() async {
    await _connect(attempts, Duration(milliseconds: backOffTime));
  }

  Future<void> disconnect() async {
    await FlutterWifiP2p().removeGroup();

    _controller.add(ConnectStatus(Service.STATE_NONE, address: _serverIp));
  }

  void send(MessageAdHoc message) {
    if (verbose) log(ServiceClient.TAG, 'Client: send() - $_serverIp');

    _socket.write(json.encode(message.toJson()));
  }

/*------------------------------Private methods-------------------------------*/

  Future<void> _connect(int attempts, Duration delay) async {
    try {
      await _connectionAttempt();
    } on NoConnectionException {
      if (attempts > 0) {
        if (verbose)
          log(ServiceClient.TAG, 'Connection attempt $attempts failed');

        await Future.delayed(delay);
        return _connect(attempts - 1, delay * 2);
      }

      rethrow;
    }
  }

  Future<void> _connectionAttempt() async {
    if (verbose) log(ServiceClient.TAG, 'Connect to $_serverIp : $_port');

    if (state == Service.STATE_NONE || state == Service.STATE_CONNECTING) {
      state = Service.STATE_CONNECTING;

      _socket = await Socket.connect(
        _serverIp, _port, timeout: Duration(milliseconds: timeOut)
      );

      _controller.add(ConnectStatus(Service.STATE_CONNECTED, address: _serverIp));

      if (_connectListener != null)
        _connectListener(_serverIp);

      if (verbose) log(ServiceClient.TAG, 'Connected to $_serverIp');

      state = Service.STATE_CONNECTED;
    }
  }
}
