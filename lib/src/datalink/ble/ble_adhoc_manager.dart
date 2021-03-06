import 'dart:async';
import 'dart:collection';

import 'package:adhoc_plugin/src/datalink/ble/ble_adhoc_device.dart';
import 'package:adhoc_plugin/src/datalink/ble/ble_services.dart';
import 'package:adhoc_plugin/src/datalink/exceptions/bad_duration.dart';
import 'package:adhoc_plugin/src/datalink/service/adhoc_event.dart';
import 'package:adhoc_plugin/src/datalink/service/constants.dart';
import 'package:adhoc_plugin/src/datalink/service/service_manager.dart';
import 'package:adhoc_plugin/src/datalink/utils/utils.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

/// Class managing the Bluetooth Low Energy discovery process of other remote
/// Ble-capable devices.
class BleAdHocManager extends ServiceManager {
  static const String TAG = '[BleAdHocManager]';

  late FlutterReactiveBle _reactiveBle;
  late HashMap<String?, BleAdHocDevice?> _mapMacDevice;

  /// Creates a [BleAdHocManager] object.
  ///
  /// The debug/verbose mode is set if [verbose] is true.
  BleAdHocManager(bool verbose) : super(verbose) {
    BleServices.verbose = verbose;

    _reactiveBle = FlutterReactiveBle();
    _mapMacDevice = HashMap();
  }

/*------------------------------Getters & Setters-----------------------------*/

  /// Bluetooth adapter name.
  Future<String> get adapterName => BleServices.bleAdapterName;

/*-------------------------------Public methods-------------------------------*/

  /// Releases the ressources used by this and others plugins.
  @override
  void release() {
    super.release();
    _reactiveBle.deinitialize();
  }

  /// Initializes the listening process of platform-side streams.
  @override
  void initialize() {
    _reactiveBle.statusStream.listen((status) async {
      if (status == BleStatus.ready) {
        // Notify upper layer of Bluetooth being enabled and ready to be used
        controller.add(AdHocEvent(BLE_READY, true));
      }
    });
  }

  /// Enables the Bluetooth adapter.
  Future<void> enable() async => BleServices.enableBleAdapter();

  /// Disables the Bluetooth adapter.
  Future<void> disable() async => BleServices.disableBleAdapter();

  /// Sets this device into a discovery mode for [duration] seconds.
  ///
  /// Throws an [BadDurationException] if the given duration exceeds 3600
  /// seconds.
  void enableDiscovery(int duration) {
    if (verbose) log(TAG, 'enableDiscovery()');

    if (duration < 0 || duration > 3600) {
      throw BadDurationException(
          'Duration must be between 0 and 3600 second(s)');
    }

    // Start discovery mode
    BleServices.startAdvertise();

    // Start timer to stop discovery mode after 'duration' seconds
    Timer(Duration(seconds: duration), BleServices.stopAdvertise);
  }

  /// Triggers the discovery of other Ble-capable devices.
  @override
  void discovery() {
    if (verbose) log(TAG, 'discovery()');

    // If a discovery process is ongoing, then cancel the process
    if (isDiscovering) {
      _stopScan();
    }

    _mapMacDevice.clear();

    // Start the discovery process
    _reactiveBle.scanForDevices(
      withServices: [Uuid.parse(SERVICE_UUID)],
      scanMode: ScanMode.balanced,
    ).listen(
      (device) {
        var bleDevice = BleAdHocDevice(device);
        // Add the discovered device to the HashMap
        _mapMacDevice.putIfAbsent(bleDevice.mac.ble, () {
          if (verbose) {
            log(TAG,
                'Device found: Name: ${device.name} - Address: ${device.id}');
          }

          // Notify upper layer of a device discovered
          controller.add(AdHocEvent(DEVICE_DISCOVERED, bleDevice));
          return bleDevice;
        });
      },
    );

    isDiscovering = true;

    // Notify upper layer of the discovery process' start
    controller.add(AdHocEvent(DISCOVERY_START, <dynamic>[]));
    // Stop the discovery process after DISCOVERY_TIME
    Timer(Duration(milliseconds: DISCOVERY_TIME), _stopScan);
  }

  /// Updates the local adapter name of the device with [name].
  ///
  /// Returns true if the name is successfully set, otherwise false.
  @override
  Future<bool> updateDeviceName(String name) async {
    return await BleServices.updateDeviceName(name);
  }

  /// Resets the local adapter name of the device.
  ///
  /// Returns true if the name is successfully reset, otherwise false.
  @override
  Future<bool> resetDeviceName() async {
    return BleServices.resetDeviceName();
  }

  /// Gets all the paired Ble-capable devices.
  ///
  /// Returns a hash map (<[String], [BleAdHocDevice]>) containing all the
  /// paired devices.
  Future<HashMap<String?, BleAdHocDevice>> getPairedDevices() async {
    if (verbose) log(TAG, 'getPairedDevices()');

    var pairedDevices = HashMap<String?, BleAdHocDevice>();
    // Request list of paired devices
    var btDevices = await BleServices.pairedDevices;

    for (final device in btDevices) {
      pairedDevices.putIfAbsent(
          device['mac'] as String, () => BleAdHocDevice.fromMap(device));
    }

    return pairedDevices;
  }

/*------------------------------Private methods-------------------------------*/

  /// Stops the discovery process.
  void _stopScan() {
    if (verbose) log(TAG, 'Discovery end');

    isDiscovering = false;
    // Notify upper layer of the discovery process completed
    controller.add(AdHocEvent(DISCOVERY_END, _mapMacDevice));
  }
}
