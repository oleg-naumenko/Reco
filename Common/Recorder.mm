//
//  Recorder.m
//  Reco
//
//  Created by oleg.naumenko on 10/27/17.
//  Copyright © 2017 oleg.naumenko. All rights reserved.
//

#import "Recorder.h"
#import "bass.h"

@implementation Recorder

BOOL _RecordProc (HRECORD handle, const void *buffer, DWORD length, void *user)
{
//    NSLog(@"data: %u", length);
    return YES;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _recState = RecStateStopped;
    }
    return self;
}

- (UInt32) start
{
    BASS_RecordInit(-1);
    _recChannel = BASS_RecordStart(16000, 1, 0, _RecordProc, (__bridge void*)self);
    if (_recChannel) {
        _recState = RecStateRecording;
    } else {
        NSLog(@"Error Starting Recorder: %d", BASS_ErrorGetCode());
    }
    return _recChannel;
}

- (void) pause
{
    if (BASS_ChannelPause(_recChannel)) {
        _recState = RecStatePaused;
    }
}

- (void) stop
{
    if (BASS_ChannelStop(_recChannel)) {
        _recState = RecStateStopped;
        _recChannel = 0;
    }
}

@end
