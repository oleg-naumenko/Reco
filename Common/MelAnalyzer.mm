//
//  MelAnalyzer.m
//  Reco
//
//  Created by oleg.naumenko on 1/9/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import <Accelerate/Accelerate.h>

#import "MelAnalyzer.h"

#import "Recorder.h"
#import "GCDTimer.h"
#import "bass.h"
#import "on_fft_to_mel.h"
#import "on_mag_to_log.h"

#define DEFAULT_FFT_SIZE 512

@implementation MelAnalyzer
{
    //transform in/out:
    on_fft_to_mel_setup * _melSetup;
    on_mag_to_log_setup * _logTransform;
    GCDTimer * _updateTimer;
    
    //display:
    NSInteger _line;
    NSInteger _lineMax;
    NSInteger _lineMin;
    float * _vertexBuffer;
    float * _vertexBufferMax;
    float * _vertexBufferMin;
    
    //record audio:
    Recorder * _recorder;
    DWORD _bassDataFlag;
}

- (instancetype) initWithFFTSize:(int32_t)fftSize
{
    if (self = [super init]) {
        
        [self setupWithFFTSize:fftSize];
        _recorder = [[Recorder alloc] init];
    }
    return self;
}

- (instancetype) init
{
    if (self = [super init]) {
        [self setupWithFFTSize:DEFAULT_FFT_SIZE];
        _recorder = [[Recorder alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_recorder stop];
    
    if (_melSetup) {
        on_fft_to_mel_free(_melSetup);
    }
    if(_logTransform) {
        on_mag_log_free(_logTransform);
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
}

- (void) setupWithFFTSize:(int32_t)fftSize
{
    _bassDataFlag = [self flagForFFTSize:fftSize * 2];
    
    _melSetup = on_fft_to_mel_init(fftSize);
    _logTransform = on_mag_log_init(.000000001f);
    
    //log filter bank fft nodes:
    
    NSMutableArray * marr = @[].mutableCopy;
    for (int i = 0; i < _melSetup->melFiltersCount; i++) {
        MelFilterBank bank = _melSetup->melFilters[i];
        
        float sumWeight = 0.0;
        for (int j = 0; j < bank.fftNodesCount; j++) {
            sumWeight += bank.weights[j];
        }
        sumWeight /= bank.fftNodesCount;
        
        [marr addObject:[NSString stringWithFormat:@"%@ - %@ - %@ - %2.2f", @(bank.startFFTNode), @(bank.centerFFTNode), @(bank.startFFTNode + bank.fftNodesCount), sumWeight]];
    }
    NSLog(@"%@", marr);// N(2) = log2(fftSize) + 1
    NSLog(@"mel count = %lu", (unsigned long)_melSetup->melFiltersCount);
}

- (void)setPlotView:(PlotView *)plotView
{
    _plotView = plotView;
    
    int32_t melFiltersCount = _melSetup->melFiltersCount;
    int32_t fftSize = _melSetup->fftSize;
    
    //display mel filter responces:
    
//    for (int i = 0; i < melFiltersCount; i++) {
//        PlotColor color = (PlotColor){1.0f, 1.0f, 1.0f, 1.0f};
//        MelFilterBank bank = _melSetup->melFilters[i];
//        float * buffer = (float*)calloc(bank.fftNodesCount * 2, sizeof(float));
//        for (int i = 0; i < bank.fftNodesCount; i++) {
//            int index = i;
//            if (index < _melSetup->fftSize) {
//                buffer[2*index] = (float)index + bank.startFFTNode;
//                buffer[2*index+1] = bank.weights[i];
//            }
//        }
//        NSInteger line = [_plotView addLineChartWithName:@"weight" data:buffer length:bank.fftNodesCount * 2 thickness:1 color:color];
//        [_plotView setData:buffer offset:0 ofLength:bank.fftNodesCount * 2 forChart:line];
//        free(buffer);
//    }
    
    //preps for live curves display:
    
    _vertexBuffer =    (float*)calloc(fftSize * 2, sizeof(float));
    _vertexBufferMax = (float*)calloc(fftSize * 2, sizeof(float));
    _vertexBufferMin = (float*)calloc(fftSize * 2, sizeof(float));
    
    for (int i = 0; i < fftSize; i ++) {
        _vertexBuffer[i*2] = (float)i;
        _vertexBufferMax[i*2] = (float)i;
        _vertexBufferMin[i*2] = (float)i;
    }
    
    PlotColor color    = (PlotColor){1.0f, 1.0f, 0.0f, 1.0f};
    PlotColor colorMax = (PlotColor){1.0f, 0.0f, 0.0f, 1.0f};
    PlotColor colorMin = (PlotColor){0.0f, 1.0f, 0.0f, 1.0f};
    
    _lineMax = [_plotView addLineChartWithName:@"max" data:_vertexBuffer length:melFiltersCount * 2 thickness:1 color:colorMax];
    _lineMin = [_plotView addLineChartWithName:@"min" data:_vertexBuffer length:melFiltersCount * 2 thickness:1 color:colorMin];
    _line    = [_plotView addLineChartWithName:@"line" data:_vertexBuffer length:melFiltersCount * 2 thickness:2 color:color];
    
    PlotColor backColor = (PlotColor){0.0f, 0.0f, 0.0f, 1.0f};
    _plotView.chartsBackgroundColor = backColor;
    
    [_plotView setRangeMinX:0 maxX:fftSize+64 minY:-100 maxY:500];
    [_plotView setVisibleRangeMinX:0 maxX:melFiltersCount minY:5 maxY:10];
    _plotView.gridStepX = 2.0f;
    _plotView.gridStepY = 1.0f;
    
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

- (void) start
{
    [_recorder start];
//    __block NSUInteger counter = 0;
//    __block NSTimeInterval initTime = CFAbsoluteTimeGetCurrent();
    
    __weak typeof(self) weakSelf = self;
    _updateTimer = [GCDTimer scheduledTimerWithTimeInterval:0.010
                                                    repeats:YES
                                                      block:^{
//                                                          counter++;
//                                                          NSTimeInterval curTime = CFAbsoluteTimeGetCurrent();
//                                                          NSTimeInterval workTime = curTime - initTime;
                                                          
                                                          [weakSelf onTimer];
//                                                          NSTimeInterval newTime = CFAbsoluteTimeGetCurrent();
//                                                          NSLog(@"anim: %2.4f", 1000 * (newTime - curTime));
                                                    }];
    BASS_CHANNELINFO info = {0};
    BASS_ChannelGetInfo(_recorder.recChannel, &info);
    NSLog(@"Recording with SR: %u, minFreq = %u", info.freq, info.freq/_melSetup->fftSize);
}

- (void) stop
{
    [_updateTimer invalidate];
    _updateTimer = nil;
}

- (void)onTimer
{
    BASS_ChannelGetData(_recorder.recChannel, _melSetup->fftBuffer, _bassDataFlag);

    on_fft_to_mel_transform(_melSetup, _melSetup->fftBuffer, _melSetup->fftSize);
    on_mag_log_do(_logTransform, _melSetup->melOutBuffer, _melSetup->melFiltersCount);
    
    int omit_bands = 2;
    int omit_poles = omit_bands * 2;
    
    for (int i = 0; i < _melSetup->melFiltersCount; i++) {
        int j = i * 2 + 1;
        if (isnan(_melSetup->melOutBuffer[i])) {
            continue;
        }
        if (isinf(_melSetup->melOutBuffer[i])) {
            continue;
        }
        _vertexBuffer[j] = 0.5f * _melSetup->melOutBuffer[i] + 0.5f * _vertexBuffer[j];// = _fftBuffer[i]/10 + 10;
        if (_vertexBuffer[j] > _vertexBufferMax[j]) _vertexBufferMax[j] = _vertexBuffer[j];
        else _vertexBufferMax[j] = 0.01f * _vertexBuffer[j] + 0.99f * _vertexBufferMax[j];
        if (_vertexBuffer[j] < _vertexBufferMin[j]) _vertexBufferMin[j] = _vertexBuffer[j];
        else _vertexBufferMin[j] = 0.01f * _vertexBuffer[j] + 0.99f * _vertexBufferMin[j];
    }
    
    NSUInteger lengthToDraw = _melSetup->melFiltersCount * 2 - omit_poles;
    
    [_plotView setData:_vertexBuffer + omit_poles    offset:0 ofLength:lengthToDraw forChart:_line];
    [_plotView setData:_vertexBufferMax + omit_poles offset:0 ofLength:lengthToDraw forChart:_lineMax];
    [_plotView setData:_vertexBufferMin + omit_poles offset:0 ofLength:lengthToDraw forChart:_lineMin];
    [_plotView update:nil];
}



//void fftToMel(MelFilterBank * filters, float * outMelBuffer, long melBufferSize, float * inputFFTBuffer, long fftBufferSize)
//{
//    for(int i = 0; i < melBufferSize; i++) {
//        MelFilterBank bank = filters[i];
//        assert(bank.weights);
//        float bandSum = 0.0;
//        for (int j = 0; j < bank.fftNodesCount; j++) {
//            int indexInFFT = j + bank.startFFTNode;
//            float weight = bank.weights[j];
//            bandSum = bandSum + weight * inputFFTBuffer[indexInFFT];
//        }
//        outMelBuffer[i] = bandSum;
//    }
//
//    float B = 1.0f;//0.0025f;
//    vDSP_vdbcon(outMelBuffer, 1, &B, outMelBuffer, 1, melBufferSize, 1);
//}

//
//- (void)onTimer2
//{
//    HRECORD recChannel = _recorder.recChannel;
//    DWORD recieved = BASS_ChannelGetData(recChannel, _fftBuffer, _dataFlag);
//
//    fftToMel(_melFilters, _melBuffer, _melFiltersCount, _fftBuffer, _fftSize);
//
////    B = 0.001f;
////    vDSP_vsmul(_melBuffer, 1, &B, _melBuffer, 1, _melFiltersCount);
//
////    NSInteger index = 0;
////    NSInteger bins = 1;
////    while (index < _fftSize) {
////
////        for (int i = 0; i < bins; i++) {
////            index++;
////        }
////        bins = 2 * bins;
////    }
//
////    float mean = 0.0;
////    vDSP_meanv(_avgBuffer, 1, &mean, _fftSize);
////    mean = -mean;
//
////    vDSP_vsadd(_avgBuffer, 1, &mean, _avgBuffer, 1, _fftSize);
//
//    //    B = 10.0f;
//    //    vDSP_vsadd(_fftBuffer, 1, &B, _fftBuffer, 1, _fftSize);
//
//    //    for (int i = 0; i < _fftSize; i++) {
//    //        float newVal = _fftBuffer[i] * 0.1f + _avgBuffer[i] * 0.9f;
//    //        _avgBuffer[i] = newVal;
//    ////        _vertexBuffer[2*i+1] = newVal;
//    //    }
//
////    DSPSplitComplex complexIn;
////    complexIn.realp = _avgBuffer;
////    complexIn.imagp = _avgBuffer + _fftSize;
////
////    DSPSplitComplex complexOut;
////    complexOut.realp = _fftBuffer;
////    complexOut.imagp = _fftBuffer + _fftSize;
////
////    vDSP_fft_zop(_fftSetup, &complexIn, 1, &complexOut, 1, _sizeLog2N, kFFTDirection_Forward);
//
//    //    vDSP_zvmags(&complexOut, 1, _fftBuffer, 1, _fftSize);
//
//    for (int i = 0; i < _melFiltersCount; i++) {
//        int j = i * 2 + 1;
//        if (isnan(_melBuffer[i])) {//} || isinf(_melBuffer[i])) {
//            continue;
//        }
//        _vertexBuffer[j] = _melBuffer[i];//0.08f * _melBuffer[i] + 0.92f * _vertexBuffer[j];// = _fftBuffer[i]/10 + 10;
//        if (_vertexBuffer[j] > _vertexBufferMax[j]) _vertexBufferMax[j] = _vertexBuffer[j];
//        else _vertexBufferMax[j] = 0.01f * _vertexBuffer[j] + 0.99f * _vertexBufferMax[j];
//        if (_vertexBuffer[j] < _vertexBufferMin[j]) _vertexBufferMin[j] = _vertexBuffer[j];
//        else _vertexBufferMin[j] = 0.01f * _vertexBuffer[j] + 0.99f * _vertexBufferMin[j];
//        //        _vertexBufferMin[j] = 0.2f * _fftBuffer[_fftSize+i] + 0.8f * _vertexBuffer[j];
//    }
//    [_plotView setData:_vertexBuffer    offset:0 ofLength:_melFiltersCount * 2 forChart:_line];
//    [_plotView setData:_vertexBufferMax offset:0 ofLength:_melFiltersCount * 2 forChart:_lineMax];
//    [_plotView setData:_vertexBufferMin offset:0 ofLength:_melFiltersCount * 2 forChart:_lineMin];
//    [_plotView update:nil];
//}

@end
