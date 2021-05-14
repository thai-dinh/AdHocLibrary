import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:adhoc_plugin/src/appframework/config.dart';
import 'package:adhoc_plugin/src/datalink/service/adhoc_device.dart';
import 'package:adhoc_plugin/src/datalink/service/adhoc_event.dart';
import 'package:adhoc_plugin/src/network/aodv/aodv_manager.dart';
import 'package:adhoc_plugin/src/network/datalinkmanager/constants.dart';
import 'package:adhoc_plugin/src/network/datalinkmanager/datalink_manager.dart';
import 'package:adhoc_plugin/src/secure_data/constants.dart';
import 'package:adhoc_plugin/src/secure_data/secure_data.dart';
import 'package:cryptography/cryptography.dart';
import 'package:ninja_prime/ninja_prime.dart';


class SecureGroupController {
  AodvManager? _aodvManager;
  DataLinkManager? _datalinkManager;
  Stream<AdHocEvent> _eventStream;
  String? _ownLabel;

  int? _expiryTime;
  /// Order of the finite cyclic group
  int? _p;
  /// Generator of the finite cyclic group of order [_p]
  int? _g;
  /// Group member's CRT share received
  int? _received;
  /// Secret group key
  SecretKey? _groupKey;
  /// Map containing the Diffie-Hellman share of each member
  late HashMap<String?, int> _DHShares;
  /// Map containing the Chinese Remainder Theorem solution of each member
  late HashMap<String?, int> _CRTShares;

  /// Default constructor
  SecureGroupController(this._aodvManager, this._datalinkManager, this._eventStream, Config config) {
    this._ownLabel = _aodvManager!.label;
    this._expiryTime = config.expiryTime;
    this._received = 0;
    this._DHShares = HashMap();
    this._CRTShares = HashMap();
    this._initialize();
  }

/*-------------------------------Public methods-------------------------------*/

  /// Initiates a secure group creation process
  void createSecureGroup() {
    SecureData message = SecureData(
      GROUP_REQUEST, [_p = 7, _g = 3] // TODO: generate primes (BigInt)
    );

    _datalinkManager!.broadcastObject(message);

    Timer(Duration(seconds: _expiryTime!), _createSecureGroupExpired);
  }

  /// Join an existing secure group
  void joinSecureGroup() {
    
  }

  void leaveSecureGroup() {
    
  }

/*------------------------------Private methods-------------------------------*/

  void _initialize() {
    _eventStream.listen((event) {
      if (event.type == DATA_RECEIVED) {
        _processDataReceived(event);
      }
    });
  }

  void _createSecureGroupExpired() {
    print('_createGroupExpired');

    List<String?> membersLabel = List.empty(growable: true);
    for (final String? label in _DHShares.keys)
      membersLabel.add(label);
    membersLabel.add(_ownLabel);

    _DHShares.putIfAbsent(_ownLabel, () => _computeDHShare());
    SecureData message = SecureData(GROUP_FORMATION_REQ, [LEADER, membersLabel, _DHShares[_ownLabel]]);

    for (final String? label in membersLabel)
      if (label != _ownLabel)
        _aodvManager!.sendMessageTo(message, label);
  }

  int _computeDHShare() {
    return pow(_g!, Random().nextInt(512)).toInt() % _p!;
  }

  int _computeCRTShare(int yj) {
    int? pj, k, d;

    /* Step 3 */
    int mj = (pow(yj, _DHShares[_ownLabel]!) as int) % _p!;
    mj = mj > _p!/2 ? mj : _p! - mj;

    /* Step 4 */
    while (true) {
      if (mj.gcd(pj = Random().nextInt(2048)) == 1)
        break;
    }

    /* Step 5 */
    d = k = Random().nextInt(MAX_SINT_VAL);
    while (k == d)
      d = Random().nextInt(MAX_SINT_VAL);

    List<int?> coefficients = _solveBezoutIdentity(mj, pj);
    int CRTSharej = (k * coefficients[1]! * pj) + (d! * coefficients[0]! * mj);
    while (CRTSharej < 0)
      CRTSharej += (mj * pj);

    return CRTSharej;
  }

  void _computeGroupKey() {
    print('_computeGroupKey');
    /* Step 6 */
    int gk = 0;
    for (final int share in _CRTShares.values)
      gk = gk ^ share;
    _groupKey = SecretKey([gk]);
  }

  List<int?> _solveBezoutIdentity(int? a, int? b) {
    print('_solveBezoutIdentity');
    int? R = a, _R = b, U = 1, _U = 0, V = 0, _V = 1;

    while (_R != 0) {
      int Q = R!~/_R!;
      int? RS = R, US = U, VS = V;
      R = _R; U = _U; V = _V;
      _R = RS - Q*_R;
      _U = US! - Q*_U!;
      _V = VS! - Q*_V!;
    }

    return List.empty(growable: true)..add(U)..add(V);
  }

  void _processDataReceived(AdHocEvent event) {
    print('_processDataReceived');
    AdHocDevice sender = (event.payload as List<dynamic>)[0] as AdHocDevice;
    print(event.payload);
    SecureData pdu = SecureData.fromJson((event.payload as List<dynamic>)[1] as Map<String, dynamic>);

    switch (pdu.type) {
      case GROUP_REQUEST:
        _datalinkManager!.broadcastObjectExcept(pdu, sender.label);

        _p = (pdu.payload as List<dynamic>)[0] as int;
        _g = (pdu.payload as List<dynamic>)[1] as int;

        SecureData reply = SecureData(GROUP_REPLY, []);
        _aodvManager!.sendMessageTo(reply, sender.label);
        break;

      case GROUP_REPLY:
        _DHShares.putIfAbsent(sender.label, () => 0);
        _CRTShares.putIfAbsent(sender.label, () => 0);
        break;

      case GROUP_FORMATION_REQ:
        List<dynamic> data = pdu.payload as List<dynamic>;
        /* Step 1. */
        _DHShares.putIfAbsent(_ownLabel, () => _computeDHShare());
        if (data[0] == LEADER) {
          for (final String? label in data[1]) {
            if (label != _ownLabel) {
              /* Step 2. */
              _DHShares.putIfAbsent(_ownLabel, () => _computeDHShare());
              SecureData reply = SecureData(GROUP_FORMATION_REQ, [MEMBER, _DHShares[_ownLabel]]);
              _aodvManager!.sendMessageTo(reply, label);
            }
          }
        } else {
          _DHShares.putIfAbsent(sender.label, () => data[1] as int);
          _CRTShares.putIfAbsent(sender.label, () => _computeCRTShare(data[1]));
          SecureData reply = SecureData(GROUP_FORMATION_REP, _CRTShares[sender.label]);
          _aodvManager!.sendMessageTo(reply, sender.label);
        }
        break;

      case GROUP_FORMATION_REP:
        _CRTShares.putIfAbsent(sender.label, () => pdu.payload as int);
        _received = _received! + 1;
        print('${_CRTShares.length} : $_received');
        if (_received == _CRTShares.length)
          _computeGroupKey();
        break;

      case GROUP_JOIN:
        break;

      case GROUP_LEAVE:
        break;

      default:
    }
  }
}
