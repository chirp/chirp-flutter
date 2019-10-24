#import <Flutter/Flutter.h>
#import <ChirpSDK/ChirpSDK.h>

@class StateStreamHandler;
@class SendingStreamHandler;
@class SentStreamHandler;
@class ReceivingStreamHandler;
@class ReceivedStreamHandler;

@interface ChirpFlutterPlugin : NSObject<FlutterPlugin>

@property (nonatomic, strong) ChirpSDK *chirp;

@property StateStreamHandler *stateStreamHandler;
@property SendingStreamHandler *sendingStreamHandler;
@property SentStreamHandler *sentStreamHandler;
@property ReceivingStreamHandler *receivingStreamHandler;
@property ReceivedStreamHandler *receivedStreamHandler;

@end

@interface StateStreamHandler : NSObject<FlutterStreamHandler>
- (void)send:(NSNumber *)previous current:(NSNumber *)current;
@end

@interface SendingStreamHandler : NSObject<FlutterStreamHandler>
- (void)send:(FlutterStandardTypedData *)data channel:(NSNumber *)channel;
@end

@interface SentStreamHandler : NSObject<FlutterStreamHandler>
- (void)send:(FlutterStandardTypedData *)data channel:(NSNumber *)channel;
@end

@interface ReceivingStreamHandler : NSObject<FlutterStreamHandler>
- (void)send:(NSNumber *)channel;
@end

@interface ReceivedStreamHandler : NSObject<FlutterStreamHandler>
- (void)send:(FlutterStandardTypedData *)data channel:(NSNumber *)channel;
@end

