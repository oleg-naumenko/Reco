//
//  Player.m
//  Reco
//
//  Created by oleg.naumenko on 1/15/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import "Player.h"
#import "bass.h"


void CALLBACK _end_proc(HSYNC handle, DWORD channel, DWORD data, void *user)
{
    Player * player = (__bridge Player*)user;
    [player stop];
}

@implementation Player
{
    DWORD _channel;
    HSYNC _endsync;
}

- (instancetype) initWithFilePath:(NSString*)filepath
{
    if (self = [super init]) {
        _filePath = filepath;
        BASS_Init(-1, 0, 0, NULL, NULL);
        _channel = BASS_StreamCreateFile(NO, _filePath.UTF8String, 0, 0, 0);
        _endsync = BASS_ChannelSetSync(_channel, BASS_SYNC_END, 0, _end_proc, (__bridge void*)self);
        if (!_channel || !_endsync) {
            NSLog(@"AAAAAA! %d", BASS_ErrorGetCode());
        }
    }
    return self;
}

- (void) dealloc
{
    BASS_StreamFree(_channel);
}

- (void)play
{
    BASS_ChannelPlay(_channel, NO);
    if (self.stateCallback) {
        self.stateCallback(self);
    }
}

- (void) stop
{
    BASS_ChannelStop(_channel);
    if (self.stateCallback) {
        self.stateCallback(self);
    }
}

- (BOOL)isPlaying
{
    DWORD active = BASS_ChannelIsActive(_channel);
    return (active == BASS_ACTIVE_PLAYING);
}

- (float)position
{
    return BASS_ChannelBytes2Seconds(_channel, BASS_ChannelGetPosition(_channel, BASS_POS_BYTE));
}

@end
