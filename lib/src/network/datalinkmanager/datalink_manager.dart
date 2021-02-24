import 'dart:async';
import 'dart:collection';

import 'package:adhoclibrary/src/appframework/config.dart';
import 'package:adhoclibrary/src/datalink/exceptions/device_failure.dart';
import 'package:adhoclibrary/src/datalink/service/adhoc_device.dart';
import 'package:adhoclibrary/src/datalink/service/discovery_event.dart';
import 'package:adhoclibrary/src/datalink/service/service.dart';
import 'package:adhoclibrary/src/datalink/utils/msg_adhoc.dart';
import 'package:adhoclibrary/src/datalink/utils/msg_header.dart';
import 'package:adhoclibrary/src/network/datalinkmanager/abstract_wrapper.dart';
import 'package:adhoclibrary/src/network/datalinkmanager/wrapper_bluetooth_le.dart';
import 'package:adhoclibrary/src/network/datalinkmanager/wrapper_event.dart';
import 'package:adhoclibrary/src/network/datalinkmanager/wrapper_wifi.dart';


class DataLinkManager {
  static const _POOLING_DISCOVERY = 1000;
  static const _NB_WRAPPERS = 2;

  bool _verbose;
  Config _config;
  List<AbstractWrapper> _wrappers;
  HashMap<String, AdHocDevice> _mapAddrDevice;
  StreamController<DiscoveryEvent> _discoveryCtrl;
  StreamController<WrapperEvent> _eventCtrl;

  DataLinkManager(this._verbose, this._config) {
    this._mapAddrDevice = HashMap();
    this._wrappers = List(_NB_WRAPPERS);
    this._wrappers[Service.WIFI] = WrapperWifi(_verbose, _config, _mapAddrDevice);
    this._wrappers[Service.BLUETOOTHLE] = WrapperBluetoothLE(_verbose, _config, _mapAddrDevice);
    this._discoveryCtrl = StreamController<DiscoveryEvent>();
    this._eventCtrl = StreamController<WrapperEvent>();
    this._initialize();
    this.checkState();
  }

/*------------------------------Getters & Setters-----------------------------*/

  Stream<WrapperEvent> get eventStream async* {
    await for (WrapperEvent event in _eventCtrl.stream) {
      yield event;
    }
  }

  Stream<DiscoveryEvent> get discoveryStream async* {
    await for (DiscoveryEvent event in _discoveryCtrl.stream) {
      yield event;
    }
  }

/*-------------------------------Public methods-------------------------------*/

  int checkState() {
    int enabled = 0;
    for (AbstractWrapper wrapper in _wrappers)
      if (wrapper.enabled)
        enabled++;

    return enabled;
  }

  void enable(int duration, int type, void Function(bool) onEnable) {
    if (!_wrappers[type].enabled)
      _wrappers[type].enable(duration, (bool success) => onEnable(success));
  }

  void enableAll(void Function(bool) onEnable) {
    for (AbstractWrapper wrapper in _wrappers) {
      enable(3600, wrapper.type, onEnable);
    }
  }

  void disable(int type) {
    if (_wrappers[type].enabled) {
      _wrappers[type].stopListening();
      _wrappers[type].disable();
    }
  }

  void disableAll() {
    for (AbstractWrapper wrapper in _wrappers)
      if (wrapper.enabled)
        disable(wrapper.type);
  }

  void discovery() {
    int enabled = checkState();
    if (enabled == 0)
      throw DeviceFailureException('No wifi and bluetooth connectivity');

    if (enabled == _wrappers.length) {
      _discovery();
    } else {
      for (AbstractWrapper wrapper in _wrappers) {
        if (wrapper.enabled) {
          wrapper.discovery();
        }
      }
    }
  }

  void connect(int attempts, AdHocDevice adHocDevice) {
    switch (adHocDevice.type) {
      case Service.WIFI:
        _wrappers[Service.WIFI].connect(attempts, adHocDevice);
        break;

      case Service.BLUETOOTHLE:
        _wrappers[Service.BLUETOOTHLE].connect(attempts, adHocDevice);
        break;
    }
  }

  void stopListening() {
    for (AbstractWrapper wrapper in _wrappers)
      if (wrapper.enabled)
        wrapper.stopListening();
  }

  void removeGroup() {
    WrapperWifi wrapperWifi = _wrappers[Service.WIFI];
    if (wrapperWifi.enabled) {
      wrapperWifi.removeGroup();
    } else {
      throw DeviceFailureException("Wifi is not enabled");
    }
  }

  bool isWifiGroupOwner() {
    WrapperWifi wrapperWifi = _wrappers[Service.WIFI];
    if (wrapperWifi.enabled) {
      return wrapperWifi.isWifiGroupOwner();
    } else {
      throw DeviceFailureException("Wifi is not enabled");
    }
  }

  void sendMessage(MessageAdHoc message, String address) {
    for (AbstractWrapper wrapper in _wrappers)
      if (wrapper.enabled)
        wrapper.sendMessage(message, address);
  }

  void broadcast(MessageAdHoc message) {
    for (AbstractWrapper wrapper in _wrappers)
      if (wrapper.enabled)
        wrapper.broadcast(message);
  }

  Future<bool> broadcastObject(Object object) async {
    bool sent = false;
    for (AbstractWrapper wrapper in _wrappers) {
      if (wrapper.enabled) {
        Header header = Header(
          messageType: AbstractWrapper.BROADCAST,
          label: _config.label,
          name: await wrapper.getAdapterName(),
          deviceType: wrapper.type,
        );

        if (wrapper.broadcast(MessageAdHoc(header, object)))
          sent = true;
      }
    }

    return sent;
  }

  void broadcastExcept(MessageAdHoc message, String excludedAddress) {
    for (AbstractWrapper wrapper in _wrappers)
      if (wrapper.enabled)
        wrapper.broadcastExcept(message, excludedAddress);
  }

  Future<bool> broadcastObjectExcept(Object object, String excludedAddress) async {
    bool sent = false;
    for (AbstractWrapper wrapper in _wrappers) {
      if (wrapper.enabled) {
        Header header = Header(
          messageType: AbstractWrapper.BROADCAST,
          label: _config.label,
          name: await wrapper.getAdapterName(),
          deviceType: wrapper.type,
        );

        if (wrapper.broadcastExcept(MessageAdHoc(header, object), excludedAddress))
          sent = true;
      }
    }

    return sent;
  }

  Future<HashMap<String, AdHocDevice>> getPaired() async {
    if (_wrappers[Service.BLUETOOTHLE].enabled)
      return await _wrappers[Service.BLUETOOTHLE].getPaired();
    return null;
  }

  bool isDirectNeighbors(String address) {
    for (AbstractWrapper wrapper in _wrappers)
      if (wrapper.enabled && wrapper.isDirectNeighbors(address))
        return true;
    return false;
  }

  List<AdHocDevice> getDirectNeighbors() {
    List<AdHocDevice> adHocDevices = List.empty(growable: true);

    for (AbstractWrapper wrapper in _wrappers)
      if (wrapper.enabled)
        adHocDevices.addAll(wrapper.directNeighbors);

    return adHocDevices;
  }

  bool isEnabled(int type) => _wrappers[type].enabled;

  Future<String> getAdapterName(int type) async {
    if (_wrappers[type].enabled)
      return await _wrappers[type].getAdapterName();
    return null;
  }

  Future<HashMap<int, String>> getActifAdapterNames() async {
    HashMap<int, String> adapterNames = HashMap();
    for (AbstractWrapper wrapper in _wrappers) {
      String name = await getAdapterName(wrapper.type);
      if (name != null)
        adapterNames.putIfAbsent(wrapper.type, () => name);
    }

    return adapterNames;
  }

  Future<bool> updateAdapterName(int type, String newName) async {
    if (_wrappers[type].enabled) {
      return await _wrappers[type].updateDeviceName(newName);
    } else {
      throw DeviceFailureException(
        _typeString(type) + ' adapter is not enabled'
      );
    }
  }

  void resetAdapterName(int type) {
    if (_wrappers[type].enabled) {
      _wrappers[type].resetDeviceName();
    } else {
      throw DeviceFailureException(_typeString(type) + ' adapter is not enabled');
    }
  }

  void disconnectAll() {
    for (AbstractWrapper wrapper in _wrappers)
      if (wrapper.enabled)
        wrapper.disconnectAll();
  }

  void disconnect(String remoteDest) {
    for (AbstractWrapper wrapper in _wrappers)
      if (wrapper.enabled)
        wrapper.disconnect(remoteDest);
  }

/*------------------------------Private methods-------------------------------*/

  void _initialize() {
    _wrappers[Service.WIFI].eventStream.listen((event) {
      _eventCtrl.add(event);
    });

    _wrappers[Service.BLUETOOTHLE].eventStream.listen((event) {
      _eventCtrl.add(event);
    });

    _wrappers[Service.BLUETOOTHLE].discoveryStream.listen((event) {
      _discoveryCtrl.add(event);
    });

    _wrappers[Service.WIFI].discoveryStream.listen((event) {
      _discoveryCtrl.add(event);
    });
  }

  void _discovery() {
    for (AbstractWrapper wrapper in _wrappers)
      wrapper.discovery();

    Timer.periodic(Duration(milliseconds: _POOLING_DISCOVERY), (Timer timer) {
      bool finished = true;
      for (AbstractWrapper wrapper in _wrappers) {
        if (!wrapper.discoveryCompleted) {
          finished = false;
          break;
        }
      }

      if (finished)
        timer.cancel();
    });

    for (AbstractWrapper wrapper in _wrappers)
      wrapper.discoveryCompleted = false;
  }

  String _typeString(int type) {
    switch (type) {
      case Service.BLUETOOTHLE:
        return "Bluetooth";
      case Service.WIFI:
        return "WiFi";

      default:
        return "Unknown";
    }
  }
}
