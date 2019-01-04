#import <Flutter/Flutter.h>
#import <ChirpConnect/ChirpConnect.h>

@class StateStreamHandler;
@class SendingStreamHandler;
@class SentStreamHandler;
@class ReceivingStreamHandler;
@class ReceivedStreamHandler;
@class ErrorStreamHandler;

@interface ChirpsdkPlugin : NSObject<FlutterPlugin>

@property (nonatomic, strong) ChirpConnect *connect;

@property StateStreamHandler *stateStreamHandler;
@property SendingStreamHandler *sendingStreamHandler;
@property SentStreamHandler *sentStreamHandler;
@property ReceivingStreamHandler *receivingStreamHandler;
@property ReceivedStreamHandler *receivedStreamHandler;
@property ErrorStreamHandler *errorStreamHandler;

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

@interface ErrorStreamHandler : NSObject<FlutterStreamHandler>
- (void)send:(NSNumber *)code message:(NSString *)message;
@end
