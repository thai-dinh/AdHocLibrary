import 'dart:async';
import 'dart:collection';

import 'package:adhoc_plugin/src/appframework/config.dart';
import 'package:adhoc_plugin/src/datalink/exceptions/no_connection.dart';
import 'package:adhoc_plugin/src/datalink/service/adhoc_device.dart';
import 'package:adhoc_plugin/src/datalink/service/adhoc_event.dart';
import 'package:adhoc_plugin/src/datalink/service/service_server.dart';
import 'package:adhoc_plugin/src/datalink/utils/msg_header.dart';
import 'package:adhoc_plugin/src/datalink/utils/msg_adhoc.dart';
import 'package:adhoc_plugin/src/datalink/utils/utils.dart';
import 'package:adhoc_plugin/src/network/datalinkmanager/constants.dart' as Constants;
import 'package:adhoc_plugin/src/network/datalinkmanager/flood_msg.dart';
import 'package:adhoc_plugin/src/network/datalinkmanager/neighbors.dart';
import 'package:adhoc_plugin/src/network/datalinkmanager/network_manager.dart';


abstract class WrapperNetwork {
  static const String TAG = "[WrapperNetwork]";

  final bool verbose;

  late String ownLabel;
  late String ownName;
  late String ownMac;

  late bool flood;
  late int timeOut;
  late int attempts;

  late int type;
  late bool enabled;
  late bool discoveryCompleted;
  late Neighbors neighbors;

  late ServiceServer serviceServer;

  late HashMap<String?, NetworkManager?> mapAddrNetwork;
  late HashMap<String?, AdHocDevice?> mapMacDevices;

  late StreamController<AdHocEvent> controller;

  late Set<String?> setFloodEvents;
  late HashSet<AdHocDevice?> setRemoteDevices;

  /// Creates a [WrapperNetwork] object.
  /// 
  /// The debug/verbose mode is set if [verbose] is true.
  /// 
  /// This object is configured according to [config], which contains specific 
  /// configurations.
  /// 
  /// This object maps a MAC address entry ([String]) to an [AdHocDevice] object 
  /// into [mapMacDevices].
  WrapperNetwork(
    this.verbose, Config config, HashMap<String?, AdHocDevice?> mapMacDevices,
  ) {
    this.flood = config.flood;
    this.timeOut = config.timeOut;
    this.attempts = 3;
    this.ownLabel = config.label;
    this.ownName = '';
    this.ownMac = '';
    this.type = -1;
    this.enabled = false;
    this.discoveryCompleted = false;
    this.neighbors = Neighbors();
    this.mapMacDevices = mapMacDevices;
    this.mapAddrNetwork = HashMap();
    this.controller = StreamController<AdHocEvent>();
    this.setFloodEvents = Set();
    this.setRemoteDevices = HashSet();
  }

/*------------------------------Getters & Setters-----------------------------*/

  /// Gets the direct neighbours of this node.
  /// 
  /// Returns a list of [AdHocDevice], which are direct neighbors of this node.
  List<AdHocDevice> get directNeighbors {
    List<AdHocDevice> devices = List.empty(growable: true);
    for (String? macAddress in neighbors.labelMac.values)
      devices.add(mapMacDevices[macAddress]!);

    return devices;
  }

  /// Returns a [Stream] of [AdHocEvent] events of lower layers.
  Stream<AdHocEvent> get eventStream => controller.stream;

/*------------------------------Abstract methods------------------------------*/

  void init(bool verbose, Config config);

  void enable(int duration);

  void disable();

  void discovery();

  Future<void> connect(int attempts, AdHocDevice device);

  Future<HashMap<String?, AdHocDevice>?>? getPaired();

  Future<String> getAdapterName();

  Future<bool> updateDeviceName(String name);

  Future<bool> resetDeviceName();

/*-------------------------------Public methods-------------------------------*/

  void stopListening() {
    this.controller.close();
  }

  bool checkFloodEvent(String? id) {
    if (!setFloodEvents.contains(id)) {
      setFloodEvents.add(id!);
      return true;
    }

    return false;
  }

  bool isDirectNeighbors(String? remoteLabel) {
    return neighbors.neighbors.containsKey(remoteLabel);
  }

  void sendMessage(String remoteLabel, MessageAdHoc message, ) {
    NetworkManager? network = neighbors.getNeighbor(remoteLabel);
    if (network != null)
      network.sendMessage(message);
  }

  bool broadcast(MessageAdHoc message) {
    if (neighbors.neighbors.length > 0) {
      neighbors.neighbors.values.forEach((network) async {
        if (network != null)
          await network.sendMessage(message);
      });

      return true;
    }

    return false;
  }

  bool broadcastExcept(MessageAdHoc message, String excludedLabel) {
    if (neighbors.neighbors.length > 0) {
      neighbors.neighbors.forEach((remoteLabel, network) async {
        if (excludedLabel.compareTo(remoteLabel!) != 0 && network != null) {
          await network.sendMessage(message);
        }
      });

      return true;
    }

    return false;
  }

  void receivedPeerMessage(Header header, NetworkManager? network) {
    if (verbose) log(TAG, 'receivedPeerMessage(): ${header.mac}');

    AdHocDevice device = AdHocDevice(
      label: header.label,
      address: header.address,
      name: header.name,
      mac: header.mac,
      type: header.deviceType!
    );

    mapMacDevices.putIfAbsent(header.mac!, () => device);
    if (!neighbors.neighbors.containsKey(header.label)) {
      neighbors.addNeighbors(header.label, header.mac, network);

      controller.add(AdHocEvent(Constants.CONNECTION_EVENT, device));

      setRemoteDevices.add(device);
      if (flood) {
        String id = header.label + DateTime.now().millisecond.toString();
        setFloodEvents.add(id);
        header.messageType = Constants.CONNECT_BROADCAST;
        broadcast(
          MessageAdHoc(header, FloodMsg(id, setRemoteDevices).toJson()),
        );
      }
    }
  }

  void disconnect(String? remoteLabel) {
    NetworkManager? network = neighbors.getNeighbor(remoteLabel);
    if (network != null) {
      network.disconnect();
      neighbors.remove(remoteLabel);
    }
  }

  void disconnectAll() {
    if (neighbors.neighbors.length > 0) {
      for (NetworkManager? network in neighbors.neighbors.values)
        network!.disconnect();
      neighbors.clear();
    }
  }

  void connectionClosed(String? mac) {
    if (mac == null || mac.compareTo('') == 0)
      return;

    AdHocDevice? device = mapMacDevices[mac];
    if (device != null) {
      String? label = device.label;

      neighbors.remove(label);
      mapAddrNetwork.remove(device.address);
      mapMacDevices.remove(device.mac);

      controller.add(AdHocEvent(Constants.BROKEN_LINK, device.label));
      controller.add(AdHocEvent(Constants.DISCONNECTION_EVENT, device));

      if (flood) {
        String id = label! + DateTime.now().millisecond.toString();
        setFloodEvents.add(id);

        Header header = Header(
          messageType: Constants.DISCONNECT_BROADCAST,
          label: label,
          name: device.name,
          mac: device.mac,
          address: device.address,
          deviceType: device.type
        );

        broadcastExcept(MessageAdHoc(header, id), label);

        if (setRemoteDevices.contains(device))
          setRemoteDevices.remove(device);
      }
    } else {
      throw NoConnectionException('Error while closing connection');
    }
  }
}
