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

import io.chirp.chirpsdk.interfaces.ChirpEventListener
import io.chirp.chirpsdk.models.ChirpSDKState
import io.chirp.chirpsdk.models.ChirpError


class ChirpsdkPlugin(val activity: Activity) : MethodCallHandler {

  //TODO: Don't see the reason why we need multiple StreamHandlers for the same ChirpEventListener events.
  // I don't think that StreamHandler is limited to one single event type.
  val stateStreamHandler = StateStreamHandler()
  val sendingStreamHandler = SendingStreamHandler()
  val sentStreamHandler = SentStreamHandler()
  val receivingStreamHandler = ReceivingStreamHandler()
  val receivedStreamHandler = ReceivedStreamHandler()
  val errorStreamHandler = ErrorStreamHandler()

  companion object {
    lateinit var chirpSDK: ChirpSDK

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

    //TODO: I think a switch->case is a better option here instead of multiple if/else
    if (call.method == "init") {
      val arguments = call.arguments as java.util.HashMap<*, *>
      val appKey = arguments["key"] as String
      val appSecret = arguments["secret"] as String
      chirpSDK = ChirpSDK(activity, appKey, appSecret)
    }
    else if (call.method == "version") {
      result.success(chirpSDK.version)
    }
    else if (call.method == "setConfig") {
      val config: String = call.arguments as String
      val error: ChirpError = chirpSDK.setConfig(config)
      if (error.code > 0) {
        //TODO: How do you know that errorHandler comes from this specific method call?
        // Why not returning here instead? We are awaiting for the operation to complete anyway.
        // Same for all other interface method calls.
        errorStreamHandler.send(error.code, error.message)
      } else {
        chirpSDK.onSending { payload: ByteArray, channel: Int ->
          /**
           * onSending is called when a send event begins.
           * The data argument contains the payload being sent.
           */
          activity.runOnUiThread {
            sendingStreamHandler.send(payload, channel)
          }
        }
        chirpSDK.onSent { payload: ByteArray, channel: Int ->
          /**
           * onSent is called when a send event has completed.
           * The payload argument contains the payload data that was sent.
           */
          activity.runOnUiThread {
            sentStreamHandler.send(payload, channel)
          }
        }
        chirpSDK.onReceiving { channel: Int ->
          /**
           * onReceiving is called when a receive event begins.
           * No data has yet been received.
           */
          activity.runOnUiThread {
            receivingStreamHandler.send(channel)
          }
        }
        chirpSDK.onReceived { payload: ByteArray?, channel: Int ->
          /**
           * onReceived is called when a receive event has completed.
           * If the payload was decoded successfully, it is passed in payload.
           * Otherwise, payload is null.
           */
          activity.runOnUiThread {
            if (payload != null) {
              receivedStreamHandler.send(payload, channel)
            } else {
              //TODO: Decode failure is not an error and should not processed as an error
              errorStreamHandler.send(0, "Chirp: Decode failed.")
            }
          }
        }
        chirpSDK.onStateChanged { oldState: ChirpSDKState, newState: ChirpSDKState ->
          /**
           * onStateChanged is called when the SDK changes state.
           */
          activity.runOnUiThread {
            stateStreamHandler.send(oldState.code, newState.code)
          }
        }
        chirpSDK.onSystemVolumeChanged { oldVolume: Float, newVolume: Float ->
          /**
           * onSystemVolumeChanged is called when the system volume is changed.
           */
        }
      }
    }
    else if (call.method == "start") {
      val error: ChirpError = chirpSDK.start()
      if (error.code > 0) {
        errorStreamHandler.send(error.code, error.message)
      }
    }
    else if (call.method == "stop") {
      val error: ChirpError = chirpSDK.stop()
      if (error.code > 0) {
        errorStreamHandler.send(error.code, error.message)
      }
    }
    else if (call.method == "send") {
      val payload =  call.arguments as ByteArray
      val error: ChirpError = chirpSDK.send(payload)
      if (error.code > 0) {
        errorStreamHandler.send(error.code, error.message)
      }
    }
    else if (call.method == "sendRandom") {
      val payload = chirpSDK.randomPayload(0)
      val error: ChirpError = chirpSDK.send(payload)
      if (error.code > 0) {
        errorStreamHandler.send(error.code, error.message)
      }
    }
    else if (call.method == "isValidPayload") {
      val payload =  call.arguments as ByteArray
      result.success(payload.size <= chirpSDK.maxPayloadLength())
     }
    else if (call.method == "getState") {
      result.success(chirpSDK.getState().code)
    }
    else if (call.method == "maxPayloadLength") {
      result.success(chirpSDK.maxPayloadLength())
    }
    else if (call.method == "channelCount") {
      result.success(chirpSDK.getChannelCount())
    }
    else if (call.method == "transmissionChannel") {
      result.success(chirpSDK.getTransmissionChannel())
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
