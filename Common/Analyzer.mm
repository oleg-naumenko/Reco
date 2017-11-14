
//
//  Analyzer.m
//  Reco
//
//  Created by oleg.naumenko on 11/14/17.
//  Copyright © 2017 oleg.naumenko. All rights reserved.
//

#import "Analyzer.h"
#import "Recorder.h"
#import "GCDTimer.h"
#import "bass.h"

#import <Accelerate/Accelerate.h>

#define FFT_SIZE 1024

@implementation Analyzer
{
    Recorder * _recorder;
    GCDTimer * _updateTimer;
    NSUInteger _fftSize;
    float * _fftBuffer;
    float * _avgBuffer;
    float * _vertexBuffer;
    float * _vertexBufferMax;
    float * _vertexBufferMin;
    NSInteger _line;
    NSInteger _lineMax;
    NSInteger _lineMin;
    vDSP_Length _sizeLog2N;
    FFTSetup _fftSetup;
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
    if (_vertexBufferMax) {
        free(_vertexBufferMax);
    }
    if (_vertexBufferMin) {
        free(_vertexBufferMin);
    }
    if (_avgBuffer) {
        free(_avgBuffer);
    }
    vDSP_destroy_fftsetup(_fftSetup);
}

- (void)setPlotView:(PlotView *)plotView
{
    _plotView = plotView;
    
    _fftSize = FFT_SIZE;
    
    _sizeLog2N = (vDSP_Length)log2((double)_fftSize);
    
    _fftSetup = vDSP_create_fftsetup(_sizeLog2N, kFFTDirection_Forward);
    
    _fftBuffer = (float*)calloc(_fftSize * 2, sizeof(float));
    _avgBuffer = (float*)calloc(_fftSize * 2, sizeof(float));
    _vertexBuffer = (float*)calloc(_fftSize * 2, sizeof(float));
    _vertexBufferMax = (float*)calloc(_fftSize * 2, sizeof(float));
    _vertexBufferMin = (float*)calloc(_fftSize * 2, sizeof(float));
    
    for (int i = 0; i < _fftSize; i ++) {
        _vertexBuffer[i*2] = (float)i;
        _vertexBufferMax[i*2] = (float)i;
        _vertexBufferMin[i*2] = (float)i;
    }
    
    _dataFlag = [self flagForFFTSize:_fftSize*2];
    
    _recorder = [[Recorder alloc] init];
    
    PlotColor color    = (PlotColor){1.0f, 1.0f, 0.0f, 1.0f};
    PlotColor colorMax = (PlotColor){1.0f, 0.0f, 0.0f, 1.0f};
    PlotColor colorMin = (PlotColor){0.0f, 1.0f, 0.0f, 1.0f};
    
    _lineMax = [_plotView addLineChartWithName:@"line" data:_vertexBuffer length:_fftSize*2 thickness:1 color:colorMax];
    _lineMin = [_plotView addLineChartWithName:@"line" data:_vertexBuffer length:_fftSize*2 thickness:1 color:colorMin];
    _line    = [_plotView addLineChartWithName:@"line" data:_vertexBuffer length:_fftSize*2 thickness:1 color:color];
    
    float lineData[] = {-10.0f, 0.0f, (float)_fftSize + 10, 0.0f};
    
    //    PlotColor grayColor = (PlotColor){0.6f, 0.6f, 0.6f, 0.8f};
    
    //    [_plotView addLineChartWithName:@"hor" data:lineData length:4 thickness:2 color:grayColor];
    
    [_plotView setRangeMinX:0 maxX:_fftSize+64 minY:-10 maxY:100];
    [_plotView setVisibleRangeMinX:0 maxX:_fftSize/2 + 16 minY:-6 maxY:9];
    _plotView.gridStepX = 125;
    _plotView.gridStepY = 5.0;
    
    [_plotView setScaleFontSize:12];
    [_plotView setWidth:20 forSide:PlotSideCount];
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

- (void)teardown
{
    [self stop];
}

- (void) start
{
    [_recorder start];
    
    __weak typeof(self) weakSelf = self;
    _updateTimer = [GCDTimer scheduledTimerWithTimeInterval:0.016
                                                    repeats:YES block:^{
                                                        [weakSelf onTimer];
                                                    }];
    BASS_CHANNELINFO info = {0};
    NSUInteger sr = BASS_ChannelGetInfo(_recorder.recChannel, &info);
    NSLog(@"Recording with SR: %u, minFreq = %lu", info.freq, info.freq/_fftSize);
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
    
    float B = 1.0f;//0.0025f;
    vDSP_vdbcon(_fftBuffer, 1, &B, _fftBuffer, 1, _fftSize, 1);
    
    B = 0.01f;
    vDSP_vsmul(_fftBuffer, 1, &B, _avgBuffer, 1, _fftSize);
    
    //    B = 10.0f;
    //    vDSP_vsadd(_fftBuffer, 1, &B, _fftBuffer, 1, _fftSize);
    
    //    for (int i = 0; i < _fftSize; i++) {
    //        float newVal = _fftBuffer[i] * 0.1f + _avgBuffer[i] * 0.9f;
    //        _avgBuffer[i] = newVal;
    ////        _vertexBuffer[2*i+1] = newVal;
    //    }
    
    DSPSplitComplex complexIn;
    complexIn.realp = _avgBuffer;
    complexIn.imagp = _avgBuffer + _fftSize;
    
    DSPSplitComplex complexOut;
    complexOut.realp = _fftBuffer;
    complexOut.imagp = _fftBuffer + _fftSize;
    
    vDSP_fft_zop(_fftSetup, &complexIn, 1, &complexOut, 1, _sizeLog2N, kFFTDirection_Inverse);
    
    for (int i = 0; i < _fftSize; i++) {
        int j = i * 2 + 1;
        if (isnan(_fftBuffer[i])) continue;
        _vertexBuffer[j] = 0.2f * _fftBuffer[i] + 0.8f * _vertexBuffer[j];// = _fftBuffer[i]/10 + 10;
        if (_vertexBuffer[j] > _vertexBufferMax[j]) _vertexBufferMax[j] = _vertexBuffer[j];
        else _vertexBufferMax[j] = 0.001f * _vertexBuffer[j] + 0.999f * _vertexBufferMax[j];
        if (_vertexBuffer[j] < _vertexBufferMin[j]) _vertexBufferMin[j] = _vertexBuffer[j];
        else _vertexBufferMin[j] = 0.001f * _vertexBuffer[j] + 0.999f * _vertexBufferMin[j];
    }
    [_plotView setData:_vertexBuffer    offset:0 ofLength:_fftSize * 2 forChart:_line];
    [_plotView setData:_vertexBufferMax offset:0 ofLength:_fftSize * 2 forChart:_lineMax];
    [_plotView setData:_vertexBufferMin offset:0 ofLength:_fftSize * 2 forChart:_lineMin];
    [_plotView update:nil];
}
@end
