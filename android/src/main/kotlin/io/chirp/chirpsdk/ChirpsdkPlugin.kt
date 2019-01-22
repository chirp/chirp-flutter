package io.chirp.chirpsdk

import android.app.Activity

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

import io.chirp.connect.ChirpConnect;
import io.chirp.connect.interfaces.ConnectEventListener;
import io.chirp.connect.models.ChirpConnectState;
import io.chirp.connect.models.ChirpError


class ChirpsdkPlugin(val activity: Activity) : MethodCallHandler {

  val stateStreamHandler = StateStreamHandler()
  val sendingStreamHandler = SendingStreamHandler()
  val sentStreamHandler = SentStreamHandler()
  val receivingStreamHandler = ReceivingStreamHandler()
  val receivedStreamHandler = ReceivedStreamHandler()
  val errorStreamHandler = ErrorStreamHandler()

  companion object {
    lateinit var chirpConnect: ChirpConnect

    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val instance = ChirpsdkPlugin(registrar.activity())
      val methodChannel = MethodChannel(registrar.messenger(), "chirp.io/methods")
      methodChannel.setMethodCallHandler(instance)
      val stateChannel = EventChannel(registrar.messenger(), "chirp.io/events/state")
      stateChannel.setStreamHandler(instance.stateStreamHandler)
      val sendingChannel = EventChannel(registrar.messenger(), "chirp.io/events/sending")
      sendingChannel.setStreamHandler(instance.sendingStreamHandler)
      val sentChannel = EventChannel(registrar.messenger(), "chirp.io/events/sent")
      sentChannel.setStreamHandler(instance.sentStreamHandler)
      val receivingChannel = EventChannel(registrar.messenger(), "chirp.io/events/receiving")
      receivingChannel.setStreamHandler(instance.receivingStreamHandler)
      val receivedChannel = EventChannel(registrar.messenger(), "chirp.io/events/received")
      receivedChannel.setStreamHandler(instance.receivedStreamHandler)
      val errorsChannel = EventChannel(registrar.messenger(), "chirp.io/events/errors")
      errorsChannel.setStreamHandler(instance.errorStreamHandler)
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {

    if (call.method == "init") {
      val arguments = call.arguments as java.util.HashMap<String, String>
      val appKey = arguments["key"] as String
      val appSecret = arguments["secret"] as String
      chirpConnect = ChirpConnect(activity, appKey, appSecret)
    }
    else if (call.method == "version") {
      result.success(chirpConnect.version)
    }
    else if (call.method == "setConfig") {
      var config: String = call.arguments as String
      val error: ChirpError = chirpConnect.setConfig(config)
      if (error.code > 0) {
        errorStreamHandler.send(error.code, error.message)
      } else {
        chirpConnect.onSending { payload: ByteArray, channel: Int ->
          /**
           * onSending is called when a send event begins.
           * The data argument contains the payload being sent.
           */
          sendingStreamHandler.send(payload, channel)
        }
        chirpConnect.onSent { payload: ByteArray, channel: Int ->
          /**
           * onSent is called when a send event has completed.
           * The payload argument contains the payload data that was sent.
           */
          sentStreamHandler.send(payload, channel)
        }
        chirpConnect.onReceiving { channel: Int ->
          /**
           * onReceiving is called when a receive event begins.
           * No data has yet been received.
           */
          receivingStreamHandler.send(channel)
        }
        chirpConnect.onReceived { payload: ByteArray?, channel: Int ->
          /**
           * onReceived is called when a receive event has completed.
           * If the payload was decoded successfully, it is passed in payload.
           * Otherwise, payload is null.
           */
          if (payload != null) {
            receivedStreamHandler.send(payload, channel)
          } else {
            errorStreamHandler.send(0, "Chirp: Decode failed.")
          }
        }
        chirpConnect.onStateChanged { oldState: ChirpConnectState, newState: ChirpConnectState ->
          /**
           * onStateChanged is called when the SDK changes state.
           */
          stateStreamHandler.send(oldState.code, newState.code)
        }
        chirpConnect.onSystemVolumeChanged { oldVolume: Int, newVolume: Int ->
          /**
           * onSystemVolumeChanged is called when the system volume is changed.
           */
        }
      }
    }
    else if (call.method == "start") {
      val error: ChirpError = chirpConnect.start();
      if (error.code > 0) {
        errorStreamHandler.send(error.code, error.message)
      }
    }
    else if (call.method == "stop") {
      val error: ChirpError = chirpConnect.stop()
      if (error.code > 0) {
        errorStreamHandler.send(error.code, error.message)
      }
    }
    else if (call.method == "send") {
      val payload: ByteArray =  call.arguments as ByteArray
      val error: ChirpError = chirpConnect.send(payload)
      if (error.code > 0) {
        errorStreamHandler.send(error.code, error.message)
      }
    }
    else if (call.method == "sendRandom") {
      val payload: ByteArray = chirpConnect.randomPayload(0)
      val error: ChirpError = chirpConnect.send(payload)
      if (error.code > 0) {
        errorStreamHandler.send(error.code, error.message)
      }
    }
    // else if (call.method == "isValidPayload") {
    //   val payload: ByteArray =  call.arguments as ByteArray
    //   val error: ChirpError = chirpConnect.send(payload)
    //   if (error.code > 0) {
    //     errorStreamHandler.send(error.code, error.message)
    //   }
    // }
    else if (call.method == "getState") {
      result.success(chirpConnect.getState().code)
    }
    else if (call.method == "maxPayloadLength") {
      result.success(chirpConnect.maxPayloadLength())
    }
    else if (call.method == "channelCount") {
      result.success(chirpConnect.getChannelCount())
    }
    else if (call.method == "transmissionChannel") {
      result.success(chirpConnect.getTransmissionChannel())
    }
    else {
      result.notImplemented()
    }
  }
}

class StateStreamHandler : StreamHandler {
  private var eventSink: EventSink? = null

  override fun onListen(arguments: Any?, sink: EventSink) {
    eventSink = sink
  }

  fun send(previous: Int, current: Int) {
    eventSink?.success(mapOf("previous" to previous,
                             "current" to current))
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}

class SendingStreamHandler : StreamHandler {
  private var eventSink: EventSink? = null

  override fun onListen(arguments: Any?, sink: EventSink) {
    eventSink = sink
  }

  fun send(data: ByteArray, channel: Int) {
    eventSink?.success(mapOf("data" to data,
                             "channel" to channel))
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}

class SentStreamHandler : StreamHandler {
  private var eventSink: EventSink? = null

  override fun onListen(arguments: Any?, sink: EventSink) {
    eventSink = sink
  }

  fun send(data: ByteArray, channel: Int) {
    eventSink?.success(mapOf("data" to data,
                             "channel" to channel))
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}

class ReceivingStreamHandler : StreamHandler {
  private var eventSink: EventSink? = null

  override fun onListen(arguments: Any?, sink: EventSink) {
    eventSink = sink
  }

  fun send(channel: Int) {
    eventSink?.success(mapOf("channel" to channel))
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}

class ReceivedStreamHandler : StreamHandler {
  private var eventSink: EventSink? = null

  override fun onListen(arguments: Any?, sink: EventSink) {
    eventSink = sink
  }

  fun send(data: ByteArray, channel: Int) {
    eventSink?.success(mapOf("data" to data,
                             "channel" to channel))
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}

class ErrorStreamHandler : StreamHandler {
  private var eventSink: EventSink? = null

  override fun onListen(arguments: Any?, sink: EventSink) {
    eventSink = sink
  }

  fun send(code: Int, message: String) {
    eventSink?.success(mapOf("code" to code,
                             "message" to message))
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}
