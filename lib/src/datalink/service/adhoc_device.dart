import 'package:adhoclibrary/src/datalink/service/service.dart';
import 'package:adhoclibrary/src/datalink/utils/utils.dart';
import 'package:json_annotation/json_annotation.dart';

part 'adhoc_device.g.dart';

/// Object representing an ad hoc device in general. It can have Wifi, 
/// Bluetooth Low Energy, or both enabled.
@JsonSerializable()
class AdHocDevice {
  bool directedConnected;
  String label;
  String address;
  String _name;
  String _mac;
  int _type;

  /// Creates an [AdHocDevice] object.
  ///
  /// If [directedConnected] is false, it means that this device is not
  /// connected via Wifi P2P and Bluetooth Low Energy at the same time
  /// 
  /// If [label] is given, it is used to identify the remote device.
  /// 
  /// If [address] is given, it is either an UUID in case of Bluetooth Low 
  /// Energy, or an IPv4 address in case of Wifi P2P.
  AdHocDevice({
    this.directedConnected = false, this.label = '', String address = '', 
    String name, String mac, int type = 2,
  }) {
    this.label = checkString(label);
    this.address = checkString(address);
    this._name = checkString(name);
    this._mac = checkString(mac);
    this._type = type;
  }

  String get name => _name;

  String get mac => _mac;

  int get type => _type;

  /// Creates an [AdHocDevice] object from a JSON representation.
  factory AdHocDevice.fromJson(Map<String, dynamic> json) 
    => _$AdHocDeviceFromJson(json);

  /// Creates a JSON representation of this instance of [AdHocDevice].
  Map<String, dynamic> toJson() => _$AdHocDeviceToJson(this);

  /// Returns a [String] representation of this remote device's type
  ///
  /// The type of this instance can be Bluetooth Low Energy (BluetoothLE),
  /// Wifi P2P (Wifi), or unknown (UNKNOWN) if the type is not specified.
  String _typeAsString() {
    switch (type) {
      case Service.BLUETOOTHLE:
        return "BluetoothLE";
      case Service.WIFI:
        return "Wifi";
      default:
        return "UNKNOWN";
    }
  }

  /// Returns a string representation of this object.
  @override
  String toString() {
    return 'AdHocDevice{' +
              'label=' + label +
              ', name=' + _name +
              ', mac=' + mac +
              ', address=' + address +
              ', type=' + _typeAsString() +
              ', directedConnected=' + directedConnected.toString() +
           '}';
  }
}
