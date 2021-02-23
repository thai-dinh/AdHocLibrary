import 'package:adhoclibrary/src/datalink/service/service.dart';
import 'package:adhoclibrary/src/datalink/utils/msg_adhoc.dart';


abstract class ServiceServer extends Service {
  static const String TAG = "[ServiceServer]";

  List<String> _activeConnections;

  ServiceServer(bool verbose, int state) : super(verbose, state) {
    _activeConnections = List.empty(growable: true);
  }

/*------------------------------Getters & Setters-----------------------------*/

  List<String> get activeConnections => _activeConnections;

/*-------------------------------Public methods-------------------------------*/

  void addActiveConnection(String mac) {
    _activeConnections.add(mac);
  }

  void removeInactiveConnection(String mac) {
    if (containConnection(mac))
      _activeConnections.remove(mac);
  }

  bool containConnection(String mac) {
    return _activeConnections.contains(mac);
  }

  void stopListening();

  Future<void> cancelConnection(String mac);

  Future<void> send(MessageAdHoc message, String mac);
}
