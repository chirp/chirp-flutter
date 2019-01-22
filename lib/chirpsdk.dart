import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

enum ChirpState {
  not_created,
  stopped,
  paused,
  running,
  sending,
  receiving,
}

class ChirpSDK {
  static const MethodChannel _methods = const MethodChannel('chirp.io/methods');
  static const EventChannel _stateEvents =
      const EventChannel('chirp.io/events/state');
  static const EventChannel _sendingEvents =
      const EventChannel('chirp.io/events/sending');
  static const EventChannel _sentEvents =
      const EventChannel('chirp.io/events/sent');
  static const EventChannel _receivingEvents =
      const EventChannel('chirp.io/events/receiving');
  static const EventChannel _receivedEvents =
      const EventChannel('chirp.io/events/received');
  static const EventChannel _errorEvents =
      const EventChannel('chirp.io/events/errors');

  /// Initialise the ChirpSDK
  ///
  /// An application key and secret can be retrieved by signing
  /// up for Chirp at the Developer Hub[1].
  ///
  /// [1]: https://developers.chirp.io
  static Future<void> init(String key, String secret) async {
    var parameters = {'key': key, 'secret': secret};
    await _methods.invokeMethod('init', new Map.from(parameters));
  }

  /// Get the Chirp SDK version info as a string
  static Future<String> get version async {
    final String version = await _methods.invokeMethod('version');
    return version;
  }

  /// Configure the SDK's audio properties
  ///
  /// A config string can be retrieved from the Developer Hub[1].
  ///
  /// [1]: https://developers.chirp.io
  static Future<void> setConfig(String config) async {
    await _methods.invokeMethod('setConfig', config);
  }

  /// Start audio processing
  ///
  /// This should be called after `setConfig`, and when
  /// resuming the app from the background. See example.
  static Future<void> start() async {
    await _methods.invokeMethod('start');
  }

  /// Stop audio processing
  ///
  /// This should be called when the app enters the background
  /// or when shutting down the app for exit. See example.
  static Future<void> stop() async {
    await _methods.invokeMethod('stop');
  }

  /// Send a payload to the speakers
  ///
  /// A payload should be constructed as an array of bytes.
  /// In Dart this is a Uint8List type from dart:typed_data.
  ///
  /// var data = new Uint8List(4);
  /// data[0] = 1;
  /// data[1] = 2;
  /// data[2] = 3;
  /// data[3] = 4;
  /// sdk.send(data);
  static Future<void> send(Uint8List payload) async {
    await _methods.invokeMethod('send', payload);
  }

  /// Send a random payload to the speakers
  static Future<void> sendRandom() async {
    await _methods.invokeMethod('sendRandom');
  }

  // Check if payload is valid for the current configuration
  // static Future<bool> isValidPayload(Uint8List payload) async {
  //   final bool valid = await _methods.invokeMethod('isValidPayload', payload);
  //   return valid;
  // }

  /// Get the SDKs current state
  static Future<ChirpState> get state async {
    final int state = await _methods.invokeMethod('getState');
    return ChirpState.values[state];
  }

  /// Get the max payload length for the current configuration
  static Future<int> get maxPayloadLength async {
    final int maxLength = await _methods.invokeMethod('maxPayloadLength');
    return maxLength;
  }

  /// Get the number of channels available in the current configuration
  static Future<int> get channelCount async {
    final int count = await _methods.invokeMethod('channelCount');
    return count;
  }

  /// Returns stream of events for state changes
  static Stream<ChirpStateEvent> get onStateChanged {
    return _stateEvents.receiveBroadcastStream().map(_stateEvent);
  }

  /// Returns stream of events when data is sent
  static Stream<ChirpDataEvent> get onSent {
    return _sentEvents.receiveBroadcastStream().map(_dataEvent);
  }

  /// Returns stream of events when data has started to be sent
  static Stream<ChirpDataEvent> get onSending {
    return _sendingEvents.receiveBroadcastStream().map(_dataEvent);
  }

  /// Returns stream of events when data has started to be received
  static Stream<ChirpDataEvent> get onReceiving {
    return _receivingEvents.receiveBroadcastStream().map(_dataEvent);
  }

  /// Returns stream of events when data is received
  static Stream<ChirpDataEvent> get onReceived {
    return _receivedEvents.receiveBroadcastStream().map(_dataEvent);
  }

  /// Returns stream of events when an error has occurred
  static Stream<ChirpErrorEvent> get onError {
    return _errorEvents.receiveBroadcastStream().map(_errorEvent);
  }

  static ChirpStateEvent _stateEvent(dynamic map) {
    if (map is Map) {
      return new ChirpStateEvent(ChirpState.values[map['previous']],
          ChirpState.values[map['current']]);
    }
    return null;
  }

  static ChirpDataEvent _dataEvent(dynamic map) {
    if (map is Map) {
      return new ChirpDataEvent(map['data'], map['channel']);
    }
    return null;
  }

  static ChirpErrorEvent _errorEvent(dynamic map) {
    if (map is Map) {
      return new ChirpErrorEvent(map['code'], map['message']);
    }
    return null;
  }
}

class ChirpStateEvent {
  final ChirpState previous;
  final ChirpState current;

  ChirpStateEvent(this.previous, this.current);
}

class ChirpDataEvent {
  final Uint8List payload;
  final int channel;

  ChirpDataEvent(this.payload, this.channel);
}

class ChirpErrorEvent {
  final int code;
  final String message;

  ChirpErrorEvent(this.code, this.message);
}
