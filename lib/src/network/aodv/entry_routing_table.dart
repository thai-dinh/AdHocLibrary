import 'dart:collection';


/// Class representing a routing table entry for AODV protocol.
class EntryRoutingTable {
  late String _destAddress;
  late String _next;
  late int _hop;
  late int _destSeqNum;
  late int _lifetime;
  late List<String> _precursors;
  late HashMap<String, int> _activesDataPath;

  /// Creates an [EntryRoutingTable] object.
  /// 
  /// An entry requires the following parameters:
  /// - [_destAddress]  String value representing the destination address.
  /// - [_next]         String value representing the next hop to reach the 
  ///                   destination address.
  /// - [_hop]          Integer value representing the hops number of the 
  ///                   destination.
  /// - [_destSeqNum]   Integer value representing the sequence number.
  /// - [_lifetime]     Integer value representing the lifetime of the entry.
  /// - [_precursors]   List containing the precursors of the current node.
  EntryRoutingTable(
    this._destAddress, this._next, this._hop, this._destSeqNum, this._lifetime, 
    this._precursors
  ) {
    this._activesDataPath = HashMap();
  }

/*------------------------------Getters & Setters-----------------------------*/

  /// Returns the destination address stored in this routing table entry.
  String get destAddress => _destAddress;

  /// Returns the next hop stored in this routing table entry.
  String get next => _next;

  /// Returns the hops number stored in this routing table entry.
  int get hop => _hop;

  /// Returns the sequence number stored in this routing table entry.
  int get destSeqNum => _destSeqNum;

  /// Returns the lifetime of the RREP message stored in this routing table entry.
  int get lifetime => _lifetime;

  /// Returns the list of precursors of this node stored in this routing table
  /// entry.
  List<String> get precursors => _precursors;

/*------------------------------Public methods-------------------------------*/

  /// Updates the data path (active data flow) with the address of a remote 
  /// device [address].
  void updateDataPath(String address) {
    _activesDataPath.putIfAbsent(address, () => DateTime.now().millisecond);
  }

  /// Returns the timestamp where data was forwarded for a particular [address].
  /// 
  /// Returns 0 if the [address] is not found in the active data path.
  int getActivesDataPath(String address) {
    if (_activesDataPath.containsKey(address))
      return _activesDataPath[address]!;
    return 0;
  }

  /// Updates the precursors list by adding a node's address [senderAddr] as
  /// a precursor of the current node.
  void updatePrecursors(String senderAddr) {
    if (!_precursors.contains(senderAddr))
      _precursors.add(senderAddr);
  }

  /// Displays the list of the precursors of the current node.
  String displayPrecursors() {
    StringBuffer buffer = StringBuffer();

    buffer.write('precursors: {');
    for (final String precursor in _precursors)
      buffer.write('$precursor ');
    buffer.write('}');

    return buffer.toString();
  }

/*------------------------------Override methods------------------------------*/

  @override
  String toString() {
    return 'dst: $_destAddress' +
            ' nxt: $_next' +
            ' hop: $_hop' +
            ' seq: $_destSeqNum ${displayPrecursors()}' +
            ' dataPath ${_activesDataPath[_destAddress]}';
  }
}
