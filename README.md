# ChirpSDK (Beta)

Send data with sound.

## Getting Started

Sign up at the Chirp [Developer Hub](https://developers.chirp.io/sign-up)

Copy and paste your Chirp app key, secret and chosen configuration into the
[example application](https://github.com/chirp/chirp-connect-flutter/tree/master/chirpsdk/example)

    await ChirpSDK.init(_appKey, _appSecret);
    await ChirpSDK.setConfig(_appConfig);
    await ChirpSDK.start();

## Sending

Chirp SDKs accept data as an array of bytes, creating a versatile interface for all kinds of data.
However in most cases, Chirp is used to send a short identifier. Here is an example of how to send
a short string with the Chirp SDK.

    String identifier = "hello";
    var payload = new Uint8List.fromList(identifier.codeUnits);
    await ChirpSDK.send(payload);

It is worth noting here that the send method will not block until the entire payload has been sent,
but just as long as it takes to pass the message to the SDK. Please use the onSent callback for this
purpose.

## Receiving

To receive data you can listen for received events like so

    ChirpSDK.onReceived.listen((e) {
        String identifier = new String.fromCharCodes(e.payload);
    });

A received event includes the `payload` and the `channel` for multichannel configurations.
There are several other callbacks available which are illustrated in the example.

## Contributions

This project aims to be a community driven project and is open to contributions.
Please file any issues and pull requests at [GitHub](https://github.com/chirp/chirp-connect-flutter)
Thank you!
