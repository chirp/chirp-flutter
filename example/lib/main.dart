import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chirpsdk/chirpsdk.dart';
import 'package:simple_permissions/simple_permissions.dart';

/// Enter Chirp application credentials below
String _appKey = '<APP_KEY>';
String _appSecret = '<APP_SECRET>';
String _appConfig = '<APP_CONFIG>';

void main() => runApp(ChirpApp());

class ChirpApp extends StatefulWidget {
  @override
  _ChirpAppState createState() => _ChirpAppState();
}

class _ChirpAppState extends State<ChirpApp> with WidgetsBindingObserver {
  final chirpYellow = const Color(0xffffd659);

  ChirpState _chirpState = ChirpState.not_created;
  String _chirpErrors = '';
  String _chirpVersion = 'Unknown';
  Uint8List _chirpData = Uint8List(0);

  Future<void> _initChirp() async {
    await ChirpSDK.init(_appKey, _appSecret);
  }

  Future<void> _configureChirp() async {
    await ChirpSDK.setConfig(_appConfig);
  }

  Future<void> _sendRandomChirp() async {
    await ChirpSDK.sendRandom();
  }

  Future<void> _startAudioProcessing() async {
    await ChirpSDK.start();
  }

  Future<void> _stopAudioProcessing() async {
    await ChirpSDK.stop();
  }

  Future<void> _getChirpVersion() async {
    final String chirpVersion = await ChirpSDK.version;
    setState(() {
      _chirpVersion = chirpVersion;
    });
  }

  Future<void> _setChirpCallbacks() async {
    ChirpSDK.onStateChanged.listen((e) {
      setState(() {
        _chirpState = e.current;
      });
    });
    ChirpSDK.onSending.listen((e) {
      setState(() {
        _chirpData = e.payload;
      });
    });
    ChirpSDK.onSent.listen((e) {
      setState(() {
        _chirpData = e.payload;
      });
    });
    ChirpSDK.onReceived.listen((e) {
      setState(() {
        _chirpData = e.payload;
      });
    });
    ChirpSDK.onError.listen((e) {
      setState(() {
        _chirpErrors = e.message;
      });
    });
  }

  Future<void> _requestPermissions() async {
    bool permission = await SimplePermissions.checkPermission(Permission.RecordAudio);
    if (!permission) {
      await SimplePermissions.requestPermission(Permission.RecordAudio);
    }
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initChirp();
    _configureChirp();
    _getChirpVersion();
    _setChirpCallbacks();
    _startAudioProcessing();
  }

  @override
  void dispose() {
    _stopAudioProcessing();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopAudioProcessing();
    } else if (state == AppLifecycleState.resumed) {
      _startAudioProcessing();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'Calibre',
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: chirpYellow,
          title: const Text(
            'Flutter - ChirpSDK Demo',
            style: TextStyle(fontFamily: 'MarkPro')
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image(
                height: 300.0,
                fit: BoxFit.cover,
                image: new AssetImage('images/chirp_logo.png')
              ),
              Text('$_chirpVersion\n', textAlign: TextAlign.center),
              Text('$_chirpState\n', textAlign: TextAlign.center),
              Text('$_chirpData\n',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold)
              ),
              RaisedButton(
                child: Text(
                  'SEND',
                  style: TextStyle(fontFamily: 'MarkPro')
                ),
                color: chirpYellow,
                onPressed: _sendRandomChirp,
              ),
              Text(
                '$_chirpErrors\n',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red)
              ),
            ],
          ),
        ),
      ),
    );
  }
}
