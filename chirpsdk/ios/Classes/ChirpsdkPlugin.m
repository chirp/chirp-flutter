#import "ChirpsdkPlugin.h"

@implementation ChirpsdkPlugin {
  FlutterEventSink _eventSink;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* methodChannel = [FlutterMethodChannel
                                         methodChannelWithName:@"chirp.io/methods"
                                         binaryMessenger:[registrar messenger]];
  ChirpsdkPlugin* instance = [[ChirpsdkPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:methodChannel];

  FlutterEventChannel* stateChannel = [FlutterEventChannel
                                         eventChannelWithName:@"chirp.io/events/state"
                                         binaryMessenger:[registrar messenger]];
  instance.stateStreamHandler = [[StateStreamHandler alloc] init];
  [stateChannel setStreamHandler:instance.stateStreamHandler];

  FlutterEventChannel* sendingChannel = [FlutterEventChannel
                                         eventChannelWithName:@"chirp.io/events/sending"
                                         binaryMessenger:[registrar messenger]];
  instance.sendingStreamHandler = [[SendingStreamHandler alloc] init];
  [sendingChannel setStreamHandler:instance.sendingStreamHandler];

  FlutterEventChannel* sentChannel = [FlutterEventChannel
                                      eventChannelWithName:@"chirp.io/events/sent"
                                      binaryMessenger:[registrar messenger]];
  instance.sentStreamHandler = [[SentStreamHandler alloc] init];
  [sentChannel setStreamHandler:instance.sentStreamHandler];

  FlutterEventChannel* receivingChannel = [FlutterEventChannel
                                           eventChannelWithName:@"chirp.io/events/receiving"
                                           binaryMessenger:[registrar messenger]];
  instance.receivingStreamHandler = [[ReceivingStreamHandler alloc] init];
  [receivingChannel setStreamHandler:instance.receivingStreamHandler];

  FlutterEventChannel* receivedChannel = [FlutterEventChannel
                                          eventChannelWithName:@"chirp.io/events/received"
                                          binaryMessenger:[registrar messenger]];
  instance.receivedStreamHandler = [[ReceivedStreamHandler alloc] init];
  [receivedChannel setStreamHandler:instance.receivedStreamHandler];

  FlutterEventChannel* errorChannel = [FlutterEventChannel
                                       eventChannelWithName:@"chirp.io/events/errors"
                                       binaryMessenger:[registrar messenger]];
  instance.errorStreamHandler = [[ErrorStreamHandler alloc] init];
  [errorChannel setStreamHandler:instance.errorStreamHandler];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"init" isEqualToString:call.method]) {
    NSString *key = call.arguments[@"key"];
    NSString *secret = call.arguments[@"secret"];
    self.connect = [[ChirpConnect alloc] initWithAppKey:key
                                              andSecret:secret];
  }
  else if ([@"version" isEqualToString:call.method]) {
    result([self.connect version]);
  }
  else if ([@"setConfig" isEqualToString:call.method]) {
    NSString *config = call.arguments;
    NSError *error = [self.connect setConfig:config];
    if (error) {
      [self.errorStreamHandler send:[NSNumber numberWithInteger:error.code]
                            message:error.description];
    }

    __weak typeof(self) weakSelf = self;
    [weakSelf.connect setStateUpdatedBlock:^(CHIRP_CONNECT_STATE oldState,
                                             CHIRP_CONNECT_STATE newState)
    {
      /*------------------------------------------------------------------------------
       * stateChangedBlock is called when the SDK changes state.
       *----------------------------------------------------------------------------*/
      [weakSelf.stateStreamHandler send:[NSNumber numberWithInteger:oldState]
                                current:[NSNumber numberWithInteger:newState]];
    }];

    [weakSelf.connect setSendingBlock:^(NSData * _Nonnull data, NSUInteger channel) {
      /*------------------------------------------------------------------------------
       * sendingBlock is called when a send event begins.
       * The data argument contains the payload being sent.
       *----------------------------------------------------------------------------*/
      [weakSelf.sendingStreamHandler send:[FlutterStandardTypedData typedDataWithBytes:data]
                                  channel:[NSNumber numberWithInteger:channel]];
    }];

    [weakSelf.connect setSentBlock:^(NSData * _Nonnull data, NSUInteger channel)
    {
      /*------------------------------------------------------------------------------
       * sentBlock is called when a send event has completed.
       * The data argument contains the payload that was sent.
       *----------------------------------------------------------------------------*/
      [weakSelf.sentStreamHandler send:[FlutterStandardTypedData typedDataWithBytes:data]
                               channel:[NSNumber numberWithInteger:channel]];
    }];

    [weakSelf.connect setReceivingBlock:^(NSUInteger channel)
    {
      /*------------------------------------------------------------------------------
       * receivingBlock is called when a receive event begins.
       * No data has yet been received.
       *----------------------------------------------------------------------------*/
      [weakSelf.receivingStreamHandler send:[NSNumber numberWithInteger:channel]];
    }];

    [weakSelf.connect setReceivedBlock:^(NSData * _Nonnull data, NSUInteger channel)
     {
       /*------------------------------------------------------------------------------
        * receivedBlock is called when a receive event has completed.
        * If the payload was decoded successfully, it is passed in data.
        * Otherwise, data is null.
        *----------------------------------------------------------------------------*/
      if (data) {
        [weakSelf.receivedStreamHandler send:[FlutterStandardTypedData typedDataWithBytes:data]
                                     channel:[NSNumber numberWithInteger:channel]];
      } else {
        [self.errorStreamHandler send:[NSNumber numberWithInteger:0]
                            message:@"Chirp: Decode failed."];
      }
     }];
  }
  else if ([@"start" isEqualToString:call.method]) {
    NSError *error = [self.connect start];
    if (error) {
      [self.errorStreamHandler send:[NSNumber numberWithInteger:error.code]
                            message:error.description];
    }
  }
  else if ([@"stop" isEqualToString:call.method]) {
    NSError *error = [self.connect stop];
    if (error) {
      [self.errorStreamHandler send:[NSNumber numberWithInteger:error.code]
                            message:error.description];
    }
  }
  else if ([@"send" isEqualToString:call.method]) {
    NSData *payload = [(FlutterStandardTypedData *)call.arguments data];
    NSError *error = [self.connect send:payload];
    if (error) {
      [self.errorStreamHandler send:[NSNumber numberWithInteger:error.code]
                            message:error.description];
    }
  }
  else if ([@"sendRandom" isEqualToString:call.method]) {
    NSData *payload = [self.connect randomPayloadWithRandomLength];
    NSError *error = [self.connect send:payload];
    if (error) {
      [self.errorStreamHandler send:[NSNumber numberWithInteger:error.code]
                            message:error.description];
    }
  }
  else if ([@"getState" isEqualToString:call.method]) {
    result([NSNumber numberWithInt:[self.connect state]]);
  }
  else if ([@"maxPayloadLength" isEqualToString:call.method]) {
    result([NSNumber numberWithInt:[self.connect maxPayloadLength]]);
  }
  else if ([@"channelCount" isEqualToString:call.method]) {
    result([NSNumber numberWithInt:[self.connect channelCount]]);
  }
  // else if ([@"isValidPayload" isEqualToString:call.method]) {
  //   NSData *payload = [(FlutterStandardTypedData *)call.arguments data];
  //   result([NSNumber numberWithBool:[self.connect isValidPayload:payload]]);
  // }
  else {
    result(FlutterMethodNotImplemented);
  }
}

- (FlutterError * _Nullable)onListenWithArguments:(id _Nullable)arguments
                                        eventSink:(nonnull FlutterEventSink)eventSink {
  _eventSink = eventSink;
  return nil;
}

- (FlutterError * _Nullable)onCancelWithArguments:(id _Nullable)arguments {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  _eventSink = nil;
  return nil;
}

@end

@implementation StateStreamHandler {
  FlutterEventSink _eventSink;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments eventSink:(FlutterEventSink)events {
  _eventSink = events;
  return nil;
}

- (void)send:(NSNumber *)previous current:(NSNumber *)current {
  if (_eventSink) {
    NSDictionary *dictionary = @{ @"previous": previous, @"current": current };
    _eventSink(dictionary);
  }
}

- (FlutterError * _Nullable)onCancelWithArguments:(id _Nullable)arguments {
  _eventSink = nil;
  return nil;
}

@end

@implementation SendingStreamHandler {
  FlutterEventSink _eventSink;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments eventSink:(FlutterEventSink)events {
  _eventSink = events;
  return nil;
}

- (void)send:(FlutterStandardTypedData *)data channel:(NSNumber *)channel {
  if (_eventSink) {
    NSDictionary *dictionary = @{ @"data": data, @"channel": channel };
    _eventSink(dictionary);
  }
}

- (FlutterError * _Nullable)onCancelWithArguments:(id _Nullable)arguments {
  _eventSink = nil;
  return nil;
}

@end


@implementation SentStreamHandler {
  FlutterEventSink _eventSink;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments eventSink:(FlutterEventSink)events {
  _eventSink = events;
  return nil;
}

- (void)send:(FlutterStandardTypedData *)data channel:(NSNumber *)channel {
  if (_eventSink) {
    NSDictionary *dictionary = @{ @"data": data, @"channel": channel };
    _eventSink(dictionary);
  }
}

- (FlutterError * _Nullable)onCancelWithArguments:(id _Nullable)arguments {
  _eventSink = nil;
  return nil;
}

@end


@implementation ReceivingStreamHandler {
  FlutterEventSink _eventSink;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments eventSink:(FlutterEventSink)events {
  _eventSink = events;
  return nil;
}

- (void)send:(NSNumber *)channel {
  if (_eventSink) {
    NSDictionary *dictionary = @{ @"channel": channel };
    _eventSink(dictionary);
  }
}

- (FlutterError * _Nullable)onCancelWithArguments:(id _Nullable)arguments {
  _eventSink = nil;
  return nil;
}

@end


@implementation ReceivedStreamHandler {
  FlutterEventSink _eventSink;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments eventSink:(FlutterEventSink)events {
  _eventSink = events;
  return nil;
}

- (void)send:(FlutterStandardTypedData *)data channel:(NSNumber *)channel {
  if (_eventSink) {
    NSDictionary *dictionary = @{ @"data": data, @"channel": channel };
    _eventSink(dictionary);
  }
}

- (FlutterError * _Nullable)onCancelWithArguments:(id _Nullable)arguments {
  _eventSink = nil;
  return nil;
}

@end


@implementation ErrorStreamHandler {
  FlutterEventSink _eventSink;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments eventSink:(FlutterEventSink)events {
  _eventSink = events;
  return nil;
}

- (void)send:(NSNumber *)code message:(NSString *)message {
  if (_eventSink) {
    NSDictionary *dictionary = @{ @"code": code, @"message": message };
    _eventSink(dictionary);
  }
}

- (FlutterError * _Nullable)onCancelWithArguments:(id _Nullable)arguments {
  _eventSink = nil;
  return nil;
}

@end
