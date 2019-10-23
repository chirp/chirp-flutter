#import "ChirpFlutterPlugin.h"

@implementation ChirpFlutterPlugin {
  FlutterEventSink _eventSink;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* methodChannel = [FlutterMethodChannel
                                         methodChannelWithName:@"chirp.io/methods"
                                         binaryMessenger:[registrar messenger]];
  ChirpFlutterPlugin* instance = [[ChirpFlutterPlugin alloc] init];
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
}

- (BOOL)isInitialised:(FlutterMethodCall*)call result:(FlutterResult)result {
  if (self.chirp) {
    return YES;
  } else {
    result([FlutterError errorWithCode:@"-1"
                               message:@"ChirpSDK not initialised"
                               details:nil]);
    return NO;
  }
}

- (void)handleError:(FlutterMethodCall*)call result:(FlutterResult)result withError:(NSError *)error {
  if (error) {
    result([FlutterError errorWithCode:[NSString stringWithFormat:@"%ld", (long)error.code]
                               message:error.localizedDescription
                               details:nil]);
  } else {
    result(nil);
  }
}

- (void)setCallbacks {
  __weak typeof(self) weakSelf = self;
  [weakSelf.chirp setStateUpdatedBlock:^(CHIRP_SDK_STATE oldState,
                                         CHIRP_SDK_STATE newState)
  {
    /*------------------------------------------------------------------------------
     * stateChangedBlock is called when the SDK changes state.
     *----------------------------------------------------------------------------*/
    [weakSelf.stateStreamHandler send:[NSNumber numberWithInteger:oldState]
                              current:[NSNumber numberWithInteger:newState]];
  }];

  [weakSelf.chirp setSendingBlock:^(NSData * _Nonnull data, NSUInteger channel) {
    /*------------------------------------------------------------------------------
     * sendingBlock is called when a send event begins.
     * The data argument contains the payload being sent.
     *----------------------------------------------------------------------------*/
    [weakSelf.sendingStreamHandler send:[FlutterStandardTypedData typedDataWithBytes:data]
                                channel:[NSNumber numberWithInteger:channel]];
  }];

  [weakSelf.chirp setSentBlock:^(NSData * _Nonnull data, NSUInteger channel)
  {
    /*------------------------------------------------------------------------------
     * sentBlock is called when a send event has completed.
     * The data argument contains the payload that was sent.
     *----------------------------------------------------------------------------*/
    [weakSelf.sentStreamHandler send:[FlutterStandardTypedData typedDataWithBytes:data]
                             channel:[NSNumber numberWithInteger:channel]];
  }];

  [weakSelf.chirp setReceivingBlock:^(NSUInteger channel)
  {
    /*------------------------------------------------------------------------------
     * receivingBlock is called when a receive event begins.
     * No data has yet been received.
     *----------------------------------------------------------------------------*/
    [weakSelf.receivingStreamHandler send:[NSNumber numberWithInteger:channel]];
  }];

  [weakSelf.chirp setReceivedBlock:^(NSData * _Nullable data, NSUInteger channel)
   {
     /*------------------------------------------------------------------------------
      * receivedBlock is called when a receive event has completed.
      * If the payload was decoded successfully, it is passed in data.
      * Otherwise, data is null.
      *----------------------------------------------------------------------------*/
    [weakSelf.receivedStreamHandler send:[FlutterStandardTypedData typedDataWithBytes:data]
                                 channel:[NSNumber numberWithInteger:channel]];
   }];
}

- (void)init:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSString *key = call.arguments[@"key"];
  NSString *secret = call.arguments[@"secret"];
  self.chirp = [[ChirpSDK alloc] initWithAppKey:key
                                      andSecret:secret];
  if (self.chirp) {
    result(nil);
  } else {
    result([FlutterError errorWithCode:@"-1"
                               message:@"Failed to initialise ChirpSDK"
                               details:nil]);
  }
}

- (void)version:(FlutterMethodCall*)call result:(FlutterResult)result {
  if (![self isInitialised:call result:result]) return;
  result([self.chirp version]);
}

- (void)setConfig:(FlutterMethodCall*)call result:(FlutterResult)result {
  if (![self isInitialised:call result:result]) return;
  NSString *config = call.arguments;
  NSError *error = [self.chirp setConfig:config];
  if (error) {
    result([FlutterError errorWithCode:[NSString stringWithFormat:@"%ld", (long)error.code]
                               message:error.localizedDescription
                               details:nil]);
  } else {
    [self setCallbacks];
    result(nil);
  }
}

- (void)start:(FlutterMethodCall*)call result:(FlutterResult)result {
  if (![self isInitialised:call result:result]) return;
  NSError *error = [self.chirp start];
  [self handleError:call result:result withError:error];
}

- (void)stop:(FlutterMethodCall*)call result:(FlutterResult)result {
  if (![self isInitialised:call result:result]) return;
  NSError *error = [self.chirp stop];
  [self handleError:call result:result withError:error];
}

- (void)send:(FlutterMethodCall*)call result:(FlutterResult)result {
  if (![self isInitialised:call result:result]) return;
  NSData *payload = [(FlutterStandardTypedData *)call.arguments data];
  NSError *error = [self.chirp send:payload];
  [self handleError:call result:result withError:error];
}

- (void)randomPayload:(FlutterMethodCall*)call result:(FlutterResult)result {
  if (![self isInitialised:call result:result]) return;
  NSData *payload = [self.chirp randomPayloadWithRandomLength];
  result([FlutterStandardTypedData typedDataWithBytes:payload]);
}

- (void)getState:(FlutterMethodCall*)call result:(FlutterResult)result {
  if (![self isInitialised:call result:result]) return;
  result([NSNumber numberWithInt:[self.chirp state]]);
}

- (void)maxPayloadLength:(FlutterMethodCall*)call result:(FlutterResult)result {
  if (![self isInitialised:call result:result]) return;
  result(@([self.chirp maxPayloadLength]));
}

- (void)channelCount:(FlutterMethodCall*)call result:(FlutterResult)result {
  if (![self isInitialised:call result:result]) return;
  result(@([self.chirp channelCount]));
}

- (void)isValidPayload:(FlutterMethodCall*)call result:(FlutterResult)result {
  if (![self isInitialised:call result:result]) return;
  NSData *payload = [(FlutterStandardTypedData *)call.arguments data];
  result([NSNumber numberWithBool:[self.chirp isValidPayload:payload]]);
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"init" isEqualToString:call.method]) {
    [self init:call result:result];
  }
  else if ([@"version" isEqualToString:call.method]) {
    [self version:call result:result];
  }
  else if ([@"setConfig" isEqualToString:call.method]) {
    [self setConfig:call result:result];
  }
  else if ([@"start" isEqualToString:call.method]) {
    [self start:call result:result];
  }
  else if ([@"stop" isEqualToString:call.method]) {
    [self stop:call result:result];
  }
  else if ([@"send" isEqualToString:call.method]) {
    [self send:call result:result];
  }
  else if ([@"randomPayload" isEqualToString:call.method]) {
    [self randomPayload:call result:result];
  }
  else if ([@"getState" isEqualToString:call.method]) {
    [self getState:call result:result];
  }
  else if ([@"maxPayloadLength" isEqualToString:call.method]) {
    [self maxPayloadLength:call result:result];
  }
  else if ([@"channelCount" isEqualToString:call.method]) {
    [self channelCount:call result:result];
  }
  else if ([@"isValidPayload" isEqualToString:call.method]) {
    [self isValidPayload:call result:result];
  }
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
