import 'dart:collection';

import 'package:adhoc_plugin/src/datalink/utils/utils.dart';
import 'package:adhoc_plugin/src/network/aodv/entry_routing_table.dart';
import 'package:adhoc_plugin/src/network/aodv/routing_table.dart';


class AodvHelper {
  static const String TAG = '[AodvHelper]';

  final bool _verbose;

  int? _rreqId;
  late RoutingTable _routingTable;
  late HashSet<String> _entryBroadcast;

  AodvHelper(this._verbose) {
    this._routingTable = RoutingTable(_verbose);
    this._entryBroadcast = HashSet();
    this._rreqId = 1;
  }

  EntryRoutingTable? addEntryRoutingTable(
    String? destAddress, String? next, int? hop, int? seq, int? lifetime, 
    List<String?>? precursors
  ) {
    EntryRoutingTable entry = EntryRoutingTable(
      destAddress, next, hop, seq, lifetime, precursors
    );

    return _routingTable.addEntry(entry) ? entry : null;
  }

  bool addBroadcastId(String sourceAddress, int? rreqId) {
    String entry = sourceAddress + rreqId.toString();
    if (!_entryBroadcast.contains(entry)) {
      _entryBroadcast.add(entry);
      if (_verbose) log(TAG, 'Add $entry into broadcast set');
      return true;
    } else {
      return false;
    }
  }

  EntryRoutingTable? getNextfromDest(String? destAddress) {
    return _routingTable.getNextFromDest(destAddress);
  }

  bool containsDest(String? destAddress) {
    return _routingTable.containsDest(destAddress);
  }

  int? getIncrementRreqId() {
    return _rreqId = _rreqId! + 1;
  }

  EntryRoutingTable? getDestination(String? destAddress) {
    return _routingTable.getDestination(destAddress);
  }

  void removeEntry(String? destAddress) {
    _routingTable.removeEntry(destAddress);
  }

  int sizeRoutingTable() {
    return _routingTable.getRoutingTable()!.length;
  }

  bool containsNext(String? nextAddress) {
    return _routingTable.containsNext(nextAddress);
  }

  String? getDestFromNext(String? nextAddress) {
    return _routingTable.getDestFromNext(nextAddress);
  }

  Set<MapEntry<String?, EntryRoutingTable>> getEntrySet() {
    return _routingTable.getRoutingTable()!.entries.toSet();
  }

  List<String?>? getPrecursorsFromDest(String? destAddress) {
    return _routingTable.getPrecursorsFromDest(destAddress);
  }

  int? getDataPathFromAddress(String? address) {
    return _routingTable.getDataPathFromAddress(address);
  }
}
