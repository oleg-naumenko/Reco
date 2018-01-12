//
//  RecorderViewController.m
//  VoiceGraph
//
//  Created by oleg.naumenko on 1/12/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import "RecorderViewController.h"
#import "bassenc.h"
#import "bass.h"

@implementation RecorderViewController
{
    IBOutlet NSTextField * _counterTextField;
    IBOutlet NSButton * recordButton;
    
    NSString * _filePath;
    HRECORD _recChannel;
    HENCODE _encoder;
    BOOL _deploying;
    
    NSTimer * _timer;
    NSTimeInterval _startTime;
}

- (void)updateControls
{
    [recordButton setTitle:(self.recording ? @"Stop" : @"Record")];
    [recordButton setState:(self.recording ? NSControlStateValueOn : NSControlStateValueOff)];
    
    [self updateCounter];
}

- (void) updateCounter
{
//    int seconds = floorf(_recTime);
//    int miliseconds = (_recTime - seconds) * 1000.0f;
//    _counterTextField.stringValue = [NSString stringWithFormat:@"%2.2d:%.2d", seconds, miliseconds];
    float recTime = CFAbsoluteTimeGetCurrent() - _startTime;
    if (recTime < 0) recTime = 0.0f;
    _counterTextField.stringValue = [NSString stringWithFormat:@"%2.2f", recTime];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    BASS_Init(-1, 0, BASS_DEVICE_MONO, NULL, NULL);
}

- (void) viewWillAppear
{
    [super viewWillAppear];
    _startTime = CFAbsoluteTimeGetCurrent();
    [self updateControls];
}

- (void) viewDidAppear
{
    [super viewDidAppear];
    
}

- (void) viewWillDisappear
{
    [self stopRecording];
}


- (IBAction)onRecButton:(id)sender
{
    if (!self.recording) {
        [self startRecording];
    } else {
        [self stopRecording];
        [self deployFile];
    }
}

- (void) startRecording
{
    BOOL cool = BASS_RecordInit(-1);
    if (!cool) {
        NSLog(@"Could not init bass recording: %d", BASS_ErrorGetCode());
        return;
    }
    
    NSString * name = [NSUUID UUID].UUIDString;
    
    NSString * filePath = [self.storagePath stringByAppendingPathComponent:name];
    filePath = [filePath stringByAppendingPathExtension:@"wav"];

    _recChannel = BASS_RecordStart(16000, 1, BASS_SAMPLE_FLOAT, NULL, NULL);
    if (!_recChannel) {
        NSLog(@"Error starting recording: %d", BASS_ErrorGetCode());
    }
    _encoder = BASS_Encode_Start(_recChannel, filePath.UTF8String, BASS_ENCODE_PCM, NULL, NULL);
    if (!_encoder) {
        NSLog(@"Error starting encoder: %d", BASS_ErrorGetCode());
    }
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        
        BYTE buf[2048 * 8];
        while (BASS_Encode_IsActive(_encoder)) {
            int r = BASS_ChannelGetData(_recChannel, buf, sizeof(buf));
            if (r == -1) {
                DWORD err = BASS_ErrorGetCode();
                if (err == BASS_ERROR_ENDED) {
                    NSLog(@"ENCODER ENDED");
                    BASS_Encode_Stop(_encoder);
                    break;
                }
            }
        }
    });
    
    
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.01 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self updateCounter];
    }];
    
    _filePath = filePath;
    _recording = YES;
    _startTime = CFAbsoluteTimeGetCurrent();
    [self updateControls];
}

- (void) stopRecording
{
    [_timer invalidate];
    BASS_Encode_Stop(_encoder);
    BASS_ChannelStop(_recChannel);
    _recording = NO;
    [self updateControls];
}

- (void) deployFile
{
    _deploying = YES;
    if (self.completion) {
        self.completion(_filePath, nil);
    }
}

- (float) recPosition
{
    return BASS_ChannelBytes2Seconds(_recChannel, BASS_ChannelGetPosition(_recChannel, BASS_POS_BYTE));
}

- (NSString*) storagePath
{
    NSArray<NSString*> * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * path = [paths.firstObject stringByAppendingPathComponent:@"VoiceGraph"];
    
    NSError * error;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (!exists) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error];
    }
    return path;
}


@end
