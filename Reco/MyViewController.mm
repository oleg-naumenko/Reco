//
//  MyViewController.m
//  Reco
//
//  Created by oleg.naumenko on 10/27/17.
//  Copyright © 2017 oleg.naumenko. All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import "GCDTimer.h"
#import "MyViewController.h"
#import "PlotView.h"
#import "Recorder.h"
#import "bass.h"

#define FFT_SIZE 1024// * 4

@interface MyViewController ()

@end

@implementation MyViewController
{
    Recorder * _recorder;
    PlotView * _plotView;
    GCDTimer * _updateTimer;
    NSUInteger _fftSize;
    float * _fftBuffer;
    float * _vertexBuffer;
    NSInteger _line;
    DWORD _dataFlag;
}

- (void)dealloc
{
    if (_fftBuffer) {
        free(_fftBuffer);
    }
    if (_vertexBuffer) {
        free(_vertexBuffer);
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _fftSize = FFT_SIZE;
    
    _fftBuffer = (float*)calloc(_fftSize, sizeof(float));
    _vertexBuffer = (float*)calloc(_fftSize*2, sizeof(float));
    
    for (int i = 0; i < _fftSize; i ++) {
        _vertexBuffer[i*2] = (float)i;
    }
    
    _dataFlag = [self flagForFFTSize:_fftSize*2];
    
    _recorder = [[Recorder alloc] init];
    
    NSRect rect = self.view.bounds;
    _plotView = [[PlotView alloc] initWithFrame:rect];
    _plotView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    [self.view addSubview:_plotView];
    
    PlotColor color = (PlotColor){1.0f, 1.0f, 0.0f, 1.0f};
    
    _line = [_plotView addLineChartWithName:@"line" data:_vertexBuffer length:_fftSize*2 thickness:2 color:color];
    
    float lineData[] = {-10.0f, 0.0f, (float)_fftSize + 10, 0.0f};
    
//    PlotColor grayColor = (PlotColor){0.6f, 0.6f, 0.6f, 0.8f};
    
//    [_plotView addLineChartWithName:@"hor" data:lineData length:4 thickness:2 color:grayColor];
    
    [_plotView setRangeMinX:0 maxX:_fftSize+64 minY:-10 maxY:10];
    [_plotView setVisibleRangeMinX:-32 maxX:_fftSize+32 minY:-1 maxY:10];
    _plotView.gridStepX = 256;
    _plotView.gridStepY = 1.0;
}

- (DWORD) flagForFFTSize:(NSUInteger)fftSize
{
    DWORD dataFlag = BASS_DATA_FLOAT;//|BASS_DATA_FFT_NOWINDOW;//BASS_DATA_FFT_COMPLEX|BASS_DATA_FFT_INDIVIDUAL|BASS_DATA_FFT_REMOVEDC|//
    switch (fftSize)
    {
        case 256:
            dataFlag |= BASS_DATA_FFT256;
            break;
        case 512:
            dataFlag |= BASS_DATA_FFT512;
            break;
        case 1024:
            dataFlag |= BASS_DATA_FFT1024;
            break;
        case 2048:
            dataFlag |= BASS_DATA_FFT2048;
            break;
        case 4096:
            dataFlag |= BASS_DATA_FFT4096;
            break;
        case 8192:
            dataFlag |= BASS_DATA_FFT8192;
            break;
        case 16384:
            dataFlag |= BASS_DATA_FFT16384;
            break;
        case 32768:
            dataFlag |= BASS_DATA_FFT32768;
            break;
        default:
            assert(0);// @"wrong fft size"
            break;
    }
    return dataFlag;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    [self start];
}

- (void) start
{
    [_recorder start];
    
    _updateTimer = [GCDTimer scheduledTimerWithTimeInterval:0.016 repeats:YES block:^{
        [self onTimer];
    }];
    
    
    BASS_CHANNELINFO info = {0};
    NSUInteger sr = BASS_ChannelGetInfo(_recorder.recChannel, &info);
    NSLog(@"Recording with SR: %lu, minFreq = %lu", info.freq, info.freq/_fftSize);
    
}

- (void) stop
{
    [_updateTimer invalidate];
    _updateTimer = nil;
}

- (void)onTimer
{
    HRECORD recChannel = _recorder.recChannel;
    DWORD recieved = BASS_ChannelGetData(recChannel, _fftBuffer, _dataFlag);
//    NSLog(@"Received: %u", recieved/sizeof(float));
    
    float B = 0.0025f;
    vDSP_vdbcon(_fftBuffer, 1, &B, _fftBuffer, 1, _fftSize, 1);
    
    for (int i = 0; i < _fftSize; i++) {
        _vertexBuffer[i*2+1] = _fftBuffer[i]/10 + 10;
    }
    [_plotView setData:_vertexBuffer offset:0 ofLength:_fftSize*2 forChart:_line];
    [_plotView update:nil];
}

@end
