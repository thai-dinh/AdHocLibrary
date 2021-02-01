import 'dart:collection';

import 'package:adhoclibrary/src/appframework/config/config.dart';
import 'package:adhoclibrary/src/datalink/service/adhoc_device.dart';
import 'package:adhoclibrary/src/datalink/service/discovery_listener.dart';
import 'package:adhoclibrary/src/datalink/utils/msg_adhoc.dart';


abstract class AbstractWrapper {
  static const CONNECT_SERVER = 10;
  static const CONNECT_CLIENT = 11;
  static const CONNECT_BROADCAST = 12;
  static const DISCONNECT_BROADCAST = 13;
  static const BROADCAST = 14;

  final bool v;
  final HashMap<String, AdHocDevice> mapMacDevices;

  bool enabled;
  bool discoveryCompleted;
  String label;
  String ownName;
  String ownMac;
  int timeOut;
  int type;
  
  AbstractWrapper(this.v, Config config, this.mapMacDevices) {
    this.enabled = true;
    this.discoveryCompleted = false;
    this.label = config.label;
    this.timeOut = config.timeOut;
  }

  void enable(int duration);

  void disable();

  void discovery(DiscoveryListener discoveryListener);

  void connect(int attempts, AdHocDevice adHocDevice);

  void stopListening();

  Future<HashMap<String, AdHocDevice>> getPaired();

  Future<String> getAdapterName();

  Future<bool> updateDeviceName(String name);

  Future<bool> resetDeviceName();

  void sendMessage(MessageAdHoc message, String address);

  bool broadcast(MessageAdHoc message);

  bool broadcastExcept(MessageAdHoc message, String excludedAddress);

  bool isDirectNeighbors(String address);

  void disconnect(String remoteDest);

  void disconnectAll();
}