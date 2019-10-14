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
import io.chirp.chirpsdk.models.ChirpErrorCode


class ChirpsdkPlugin(private val activity: Activity) : MethodCallHandler {

  val stateStreamHandler = StateStreamHandler()
  val sendingStreamHandler = SendingStreamHandler()
  val sentStreamHandler = SentStreamHandler()
  val receivingStreamHandler = ReceivingStreamHandler()
  val receivedStreamHandler = ReceivedStreamHandler()

  lateinit var chirpSDK: ChirpSDK

  companion object {

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
    }
  }

  private fun isInitialised(call: MethodCall, result: Result): Boolean {
    if (!::chirpSDK.isInitialized) {
      val errorCode = ChirpErrorCode.CHIRP_SDK_NOT_INITIALISED.code.toString()
      result.error(errorCode, "ChirpSDK not initialised", null)
      return false
    }
    return true
  }

  private fun init(call: MethodCall, result: Result) {
    val arguments = call.arguments as java.util.HashMap<*, *>
    val appKey = arguments["key"] as String
    val appSecret = arguments["secret"] as String
    chirpSDK = ChirpSDK(activity, appKey, appSecret)
    if (chirpSDK) {
      result.success(ChirpErrorCode.CHIRP_SDK_OK.code)
    } else {
      result.error(-1, "Failed to initialise ChirpSDK", null)
    }
  }

  private fun version(call: MethodCall, result: Result) {
    if (!isInitialised(call, result)) return;
    result.success(chirpSDK.version)
  }

  private fun setCallbacks() {
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
        receivedStreamHandler.send(payload, channel)
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

  private fun setConfig(call: MethodCall, result: Result) {
    if (!isInitialised(call, result)) return
    val config: String = call.arguments as String
    val error: ChirpError = chirpSDK.setConfig(config)
    if (error.code > 0) {
      result.error(error.code.toString(), error.message, null)
      return
    }
    setCallbacks()
    result.success(error.code)
  }

  private fun start(call: MethodCall, result: Result) {
    if (!isInitialised(call, result)) return
    val error: ChirpError = chirpSDK.start()
    if (error.code > 0) {
      result.error(error.code.toString(), error.message, null)
      return
    }
    result.success(error.code)
  }

  private fun stop(call: MethodCall, result: Result) {
    if (!isInitialised(call, result)) return
    val error: ChirpError = chirpSDK.stop()
    if (error.code > 0) {
      result.error(error.code.toString(), error.message, null)
      return
    }
    result.success(error.code)
  }

  private fun send(call: MethodCall, result: Result) {
    if (!isInitialised(call, result)) return
    val payload =  call.arguments as ByteArray
    val error: ChirpError = chirpSDK.send(payload)
    if (error.code > 0) {
      result.error(error.code.toString(), error.message, null)
      return
    }
    result.success(error.code)
  }

  private fun randomPayload(call: MethodCall, result: Result) {
    if (!isInitialised(call, result)) return
    result.success(chirpSDK.randomPayload(0))
  }

  private fun isValidPayload(call: MethodCall, result: Result) {
    if (!isInitialised(call, result)) return
    val payload =  call.arguments as ByteArray
    result.success(payload.size <= chirpSDK.maxPayloadLength())
  }

  private fun getState(call: MethodCall, result: Result) {
    if (!isInitialised(call, result)) return
    result.success(chirpSDK.getState().code)
  }

  private fun maxPayloadLength(call: MethodCall, result: Result) {
    if (!isInitialised(call, result)) return
    result.success(chirpSDK.maxPayloadLength())
  }

  private fun channelCount(call: MethodCall, result: Result) {
    if (!isInitialised(call, result)) return
    result.success(chirpSDK.getChannelCount())
  }

  private fun transmissionChannel(call: MethodCall, result: Result) {
    if (!isInitialised(call, result)) return
    result.success(chirpSDK.getTransmissionChannel())
  }

  private fun errorCodeToString(call: MethodCall, result: Result) {
    if (!isInitialised(call, result)) return
    val code =  call.arguments as Int
    result.success(ChirpError(code).message)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {

    when (call.method) {
      "init" -> init(call, result)
      "version" -> version(call, result)
      "setConfig" -> setConfig(call, result)
      "start" -> start(call, result)
      "stop" -> stop(call, result)
      "send" -> send(call, result)
      "randomPayload" -> randomPayload(call, result)
      "isValidPayload" -> isValidPayload(call, result)
      "getState" -> getState(call, result)
      "maxPayloadLength" -> maxPayloadLength(call, result)
      "channelCount" -> channelCount(call, result)
      "transmissionChannel" -> transmissionChannel(call, result)
      "errorCodeToString" -> errorCodeToString(call, result)
      else -> {
        result.notImplemented()
      }
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

  fun send(data: ByteArray?, channel: Int) {
    eventSink?.success(mapOf("data" to data,
                             "channel" to channel))
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}
