import 'dart:convert';
import 'dart:typed_data';

import 'package:adhoclibrary/src/datalink/ble/ble_manager.dart';
import 'package:adhoclibrary/src/datalink/message/msg_adhoc.dart';
import 'package:adhoclibrary/src/datalink/message/msg_manager.dart';

class BleMessageManager implements MessageManager {
  BleManager _bleManager;

  BleMessageManager(this._bleManager);

  void sendMessage(MessageAdHoc message) {
    List<Uint8List> data = List.empty(growable: true);
    Utf8Encoder encoder = Utf8Encoder();
    Uint8List msg = encoder.convert(message.toString());
    int length = msg.length, start = 0, end = _bleManager.mtu, count = 0;

    while (length > _bleManager.mtu) {
      data.add(msg.sublist(start, end));
      start += _bleManager.mtu;
      end += _bleManager.mtu;
      length -= _bleManager.mtu;
    }

    data.add(msg.sublist(start, start += length));

    while (count < data.length)
      _bleManager.writeValue(data.removeAt(0));
  }

  MessageAdHoc receiveMessage() {
    return null;
  }
}