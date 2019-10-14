import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
  String _startStopBtnText = 'START';
  Uint8List _chirpData = Uint8List(0);

  void setPayload(Uint8List payload) {
    setState(() {
      _chirpData = payload;
    });
  }

  void setErrorMessage(String error) {
    setState(() {
      _chirpErrors = error;
    });
  }

  void setErrorCode(int errorCode) async {
    var errorMessage = await ChirpSDK.errorCodeToString(errorCode);
    setErrorMessage(errorMessage);
  }

  Future<void> _initChirp() async {
    try {
      // Init ChirpSDK
      await ChirpSDK.init(_appKey, _appSecret);

      // Get and print SDK version
      final String chirpVersion = await ChirpSDK.version;
      setState(() {
        _chirpVersion = "ChirpSDK: $chirpVersion";
      });

      // Set SDK config
      await ChirpSDK.setConfig(_appConfig);
      _setChirpCallbacks();

    } catch (err) {
      setErrorMessage("ChirpError: ${err.code} - ${err.message}");
    }
  }

  void _startStopSDK() async {
    try {
      var state = await ChirpSDK.state;
      if (state == ChirpState.stopped) {
        _startSDK();
      } else {
        _stopSDK();
      }
    } catch (err) {
      setErrorMessage("ChirpError: ${err.message};");
    }
  }

  void _startSDK() async {
    try {
      await ChirpSDK.start();
      setState(() {
        _startStopBtnText = "STOP";
      });
    } catch (err) {
      setErrorMessage("Error starting the SDK: ${err.message};");
    }
  }

  void _stopSDK() async {
    try {
      await ChirpSDK.stop();
      setState(() {
        _startStopBtnText = "START";
      });
    } catch (err) {
      setErrorMessage("Error stopping the SDK: ${err.message};");
    }
  }

  void _sendRandomPayload() async {
    try {
      Uint8List payload = await ChirpSDK.randomPayload();
      setPayload(payload);
      var errorCode = await ChirpSDK.send(payload);
      if (errorCode > 0) {
        setErrorCode(errorCode);
        return;
      }
    } catch (err) {
      setErrorMessage("Error sending random payload: ${err.message};");
    }
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
    try {
      _requestPermissions();
      _initChirp();
    } catch(e) {
      _chirpErrors = e.toString();
    }
  }

  @override
  void dispose() {
    _stopSDK();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopSDK();
    } else if (state == AppLifecycleState.resumed) {
      _startSDK();
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
                onPressed: _sendRandomPayload,
              ),
              RaisedButton(
                child: Text(
                    _startStopBtnText,
                    style: TextStyle(fontFamily: 'MarkPro')
                ),
                color: chirpYellow,
                onPressed: _startStopSDK,
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
