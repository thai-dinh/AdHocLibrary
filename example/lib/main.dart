import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:adhoc_plugin/adhoc_plugin.dart';
import 'package:analyzer_plugin/utilities/pair.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'search_bar.dart';


void main() => runApp(AdHocMusicClient());

enum MenuOptions { add, search, display }

const platform = MethodChannel('adhoc.music.player/main');

class AdHocMusicClient extends StatefulWidget {
  @override
  _AdHocMusicClientState createState() => _AdHocMusicClientState();
}

class _AdHocMusicClientState extends State<AdHocMusicClient> {
  static const PLAYLIST = 0;
  static const REQUEST = 1;
  static const REPLY = 2;
  static const TRANSFER = 3;

  static const NONE = 'none';

  final TransferManager _manager = TransferManager(true);
  final List<AdHocDevice> _discovered = List.empty(growable: true);
  final List<AdHocDevice> _peers = List.empty(growable: true);
  final List<Pair<String, String>> _playlist = List.empty(growable: true);
  final HashMap<String, HashMap<String, PlatformFile?>> _globalPlaylist = HashMap();
  final HashMap<String, PlatformFile?> _localPlaylist = HashMap();
  final HashMap<String, bool> _isTransfering = HashMap();
  final Set<String> timestamps = <String>{};

  bool _requested = false;
  bool _display = false;
  String? _selected = NONE;

  @override
  void initState() {
    super.initState();
    _manager.enableBle(3600);
    _manager.eventStream.listen(_processAdHocEvent);
    _manager.open = true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: const Text('Ad Hoc Music Client'),
            actions: <Widget>[
              PopupMenuButton<MenuOptions>(
                onSelected: (result) async {
                  switch (result) {
                    case MenuOptions.add:
                      await _openFileExplorer();
                      break;

                    case MenuOptions.search:
                      var songs = List<String>.empty(growable: true);
                      _localPlaylist.entries.map((entry) => songs.add(entry.key));

                      _selected = (await showSearch(
                        context: context,
                        delegate: SearchBar(songs),
                      ))!;

                      if (_selected == null) {
                        _selected = NONE;
                      }
                      break;

                    case MenuOptions.display:
                      setState(() => _display = !_display);
                      break;
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<MenuOptions>>[
                  const PopupMenuItem<MenuOptions>(
                    value: MenuOptions.add,
                    child: ListTile(
                      leading: Icon(Icons.playlist_add),
                      title: Text('Add song to playlist'),
                    ),
                  ),
                  const PopupMenuItem<MenuOptions>(
                    value: MenuOptions.search,
                    child: ListTile(
                      leading: Icon(Icons.search),
                      title: Text('Search song'),
                    ),
                  ),
                  const PopupMenuItem<MenuOptions>(
                    value: MenuOptions.display,
                    child: ListTile(
                      leading: Icon(Icons.music_note),
                      title: Text('Switch view'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    if (!_display) ...<Widget>[
                      Card(child: ListTile(title: Center(child: Text('Ad Hoc Peers')))),

                      ElevatedButton(
                        child: Center(child: Text('Search for nearby devices')),
                        onPressed: _manager.discovery,
                      ),

                      Expanded(
                        child: ListView(
                          children: _discovered.map((device) {
                            var type = device.mac.ble == '' ? 'Wi-Fi' : 'BLE';
                            var mac = device.mac.ble == '' ? device.mac.wifi : device.mac.ble;
                            if (device.mac.ble != '' && device.mac.wifi != '') {
                              type = 'Wi-Fi/BLE';
                              mac = '${device.mac.wifi}/${device.mac.ble}';
                            }

                            return Card(
                              child: ListTile(
                                title: Center(child: Text(device.name!)),
                                subtitle: Center(child: Text('$type: $mac')),
                                onTap: () async {
                                  await _manager.connect(device);
                                  setState(() => _discovered.removeWhere((element) => (element.mac == device.mac)));
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ] else ...<Widget>[
                      Card(child: Stack(
                        children: <Widget> [
                          ListTile(
                            title: Center(child: Text('$_selected')),
                            subtitle: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                IconButton(
                                  icon: Icon(Icons.play_arrow_rounded),
                                  onPressed: _play,
                                ),
                                IconButton(
                                  icon: Icon(Icons.pause_rounded),
                                  onPressed: _pause,
                                ),
                                IconButton(
                                  icon: Icon(Icons.stop_rounded),
                                  onPressed: _stop,
                                ),
                                if (_requested)
                                  Container(child: Center(child: CircularProgressIndicator()))
                                else
                                  Container()
                              ],
                            ),
                          ),
                        ],
                      )),

                      Card(
                        color: Colors.blue,
                        child: ListTile(
                          title: Center(
                            child: const Text('Ad Hoc Playlist', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),

                      Expanded(
                        child: ListView(
                          children: _playlist.map((pair) {
                            return Card(
                              child: ListTile(
                                title: Center(child: Text(pair.last)),
                                subtitle: Center(child: Text(pair.first)),
                                onTap: () => setState(() => _selected = pair.last),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _processAdHocEvent(Event event) {
    switch (event.type) {
      case AdHocType.onDeviceDiscovered:
        break;
      case AdHocType.onDiscoveryStarted:
        break;
      case AdHocType.onDiscoveryCompleted:
        setState(() {
          for (final discovered in (event.data as Map).values) {
            _discovered.add(discovered as AdHocDevice);
          }
        });
        break;
      case AdHocType.onDataReceived:
        _processDataReceived(event);
        break;
      case AdHocType.onForwardData:
        _processDataReceived(event);
        break;
      case AdHocType.onConnection:
        _peers.add(event.device as AdHocDevice);
        break;
      case AdHocType.onConnectionClosed:
        break;
      case AdHocType.onInternalException:
        break;
      case AdHocType.onGroupInfo:
        break;
      case AdHocType.onGroupDataReceived:
        break;
      default:
    }
  }

  Future<void> _processDataReceived(Event event) async {
    var peer = event.device;
    var data = event.data as Map;

    switch (data['type'] as int) {
      case PLAYLIST:
        var peers = data['peers'] as List;
        var songs = data['songs'] as List;
        var timestamp = data['timestamp'] as String;
        if (timestamps.contains(timestamp)) {
          break;
        } else {
          timestamps.add(timestamp);
        }

        var peerName = peers.first as String;
        var entry = _globalPlaylist[peerName];
        if (entry == null) {
          entry = HashMap();
        }

        for (var i = 0; i < peers.length; i++) {
          if (peerName == peers[i]) {
            entry!.putIfAbsent(songs[i] as String, () => PlatformFile(name: songs[i] as String, size: 0));
          } else {
            _globalPlaylist[peerName] = entry!;

            peerName = peers[i] as String;
            entry = _globalPlaylist[peerName];
            if (entry == null) {
              entry = HashMap();
            }

            entry.putIfAbsent(songs[i] as String, () => PlatformFile(name: songs[i] as String, size: 0));
          }

          var pair = Pair<String, String>(peerName, songs[i] as String);
          if (!_playlist.contains(pair)) {
            _playlist.add(pair);
          }
        }

        _globalPlaylist[peerName] = entry!;

        setState(() {});

        _manager.broadcastExcept(data, peer!);
        break;

      case REQUEST:
        var name = data['name'] as String;
        var found = false;
        Uint8List? bytes;
        PlatformFile? file;

        if (_localPlaylist.containsKey(name)) {
          found = true;
          bytes = _localPlaylist[name]!.bytes!;
        } else {
          for (final entry in _globalPlaylist.entries) {
            var _playlist = entry.value;
            if (_playlist.containsKey(name)) {
              file = _playlist[name];
              if (file == null && file!.bytes == null) {
                found = false;
                break;
              } else {
                bytes = file.bytes;
                if (bytes != null) {
                  found = true;
                } else {
                  found = false;
                }
                break;
              }
            }
          }
        }

        if (found == false) {
          break;
        } else {
          var message = HashMap<String, dynamic>();
          message = HashMap<String, dynamic>();
          message.putIfAbsent('type', () => TRANSFER);
          message.putIfAbsent('name', () => name);
          _manager.sendMessageTo(message, peer!.label!);

          message.clear();

          message.putIfAbsent('type', () => REPLY);
          message.putIfAbsent('name', () => name);
          message.putIfAbsent('song', () => bytes);
          _manager.sendMessageTo(message, peer.label!);
        }

        break;

      case REPLY:
        var name = data['name'] as String;
        var song = Uint8List.fromList((data['song'] as List<dynamic>).cast<int>());

        var tempDir = await getTemporaryDirectory();
        var tempFile = File('${tempDir.path}/$name');
        await tempFile.writeAsBytes(song, flush: true);

        var entry = HashMap<String, PlatformFile>();
        entry.putIfAbsent(
          name, () => PlatformFile(
            bytes: song, name: name, path: tempFile.path, size: song.length
          )
        );

        _globalPlaylist.update(peer!.label!, (value) => entry, ifAbsent: () => entry);
        setState(() => _requested = false);
        break;

      case TRANSFER:
        var name = data['name'] as String;
        _isTransfering.update(name, (value) => true, ifAbsent: () => true);
        break;

      default:
    }
  }

  Future<void> _openFileExplorer() async {
    var result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.audio,
    );

    if(result != null) {
      for (var file in result.files) {
        var bytes = await File(file.path!).readAsBytes();
        var song = PlatformFile(
          name: file.name,
          path: file.path,
          bytes: bytes, 
          size: bytes.length,
        );

        _localPlaylist.putIfAbsent(file.name, () => song);
        var pair = Pair<String, String>(_manager.ownAddress, file.name);
        if (!_playlist.contains(pair)) {
          _playlist.add(pair);
        }
      }
    }

    _updatePlaylist();
  }

  void _updatePlaylist() async {
    var peers = List<String>.empty(growable: true);
    var songs = List<String>.empty(growable: true);

    _globalPlaylist.forEach((peer, song) {
      peers.add(peer);
      song.forEach((key, value) {
        songs.add(key);
      });
    });

    _localPlaylist.forEach((name, file) {
      peers.add(_manager.ownAddress);
      songs.add(name);
    });

    var message = HashMap<String, dynamic>();
    message.putIfAbsent('type', () => PLAYLIST);
    message.putIfAbsent('peers', () => peers);
    message.putIfAbsent('songs', () => songs);
    message.putIfAbsent('timestamp', () => DateTime.now().toIso8601String());
    _manager.broadcast(message);
  }

  void _play() {
    if (_selected!.compareTo(NONE) == 0) {
      return;
    }

    PlatformFile? file;
    if (_localPlaylist.containsKey(_selected)) {
      file = _localPlaylist[_selected];
    } else {
      _globalPlaylist.forEach((peerName, playlist) {
        if (playlist.containsKey(_selected)) {
          file = playlist[_selected];
          if (file == null || file!.size == 0) {
            var message = HashMap<String, dynamic>();
            message.putIfAbsent('type', () => REQUEST);
            message.putIfAbsent('name', () => _selected);
            _manager.broadcast(message);

            setState(() => _requested = true);
            _isTransfering.putIfAbsent(_selected!, () => false);

            Timer(Duration(seconds: 30), () {
              if (_requested == true && _isTransfering[_selected] == false) {
                _manager.sendMessageTo(message, peerName);
              }
            });
          }
        }
      });
    }

    if (_requested == false) {
      platform.invokeMethod('play', file!.path);
    }
  }

  void _pause() {
    if (_selected!.compareTo(NONE) == 0) {
      return;
    }

    platform.invokeMethod('pause');
  }

  void _stop() {
    if (_selected!.compareTo(NONE) == 0) {
      return;
    }

    _selected = NONE;
    platform.invokeMethod('stop');

    setState(() {});
  }
}
