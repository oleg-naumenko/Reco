//
//  Recorder.h
//  Reco
//
//  Created by oleg.naumenko on 10/27/17.
//  Copyright © 2017 oleg.naumenko. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, RecState) {
    RecStateStopped,
    RecStatePaused,
    RecStateRecording
};


@interface Recorder : NSObject

- (UInt32) start;
- (void) pause;
- (void) stop;

@property (nonatomic, readonly) UInt32 recChannel;
@property (nonatomic, readonly) RecState recState;

@end
