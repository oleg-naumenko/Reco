//
//  MelAnalyzer.m
//  Reco
//
//  Created by oleg.naumenko on 1/9/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import "MelAnalyzer.h"

#import "Recorder.h"
#import "GCDTimer.h"
#import "bass.h"

#import <Accelerate/Accelerate.h>

#define FFT_SIZE 512

struct MelFilterBank {
    int32_t centerFFTNode;
    int32_t fftNodesCount;
    float * weights;
};


@implementation MelAnalyzer
{
    Recorder * _recorder;
    GCDTimer * _updateTimer;
    NSUInteger _fftSize;
    float * _fftBuffer;
    float * _avgBuffer;
    float * _melBuffer;
    float * _vertexBuffer;
    float * _vertexBufferMax;
    float * _vertexBufferMin;
    
    MelFilterBank * _melFilters;
    NSInteger _melFiltersCount;
    
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
    if (_melBuffer) {
        free(_melBuffer);
    }
    if (_melFilters) {
        for (int i = 0; i < _melFiltersCount; i ++) {
            if (_melFilters[i].weights) {
                free(_melFilters[i].weights);
                _melFilters[i].weights = NULL;
            }
        }
        free(_melFilters);
    }
    
    vDSP_destroy_fftsetup(_fftSetup);
}

- (void)setPlotView:(PlotView *)plotView
{
    _plotView = plotView;
    
    _fftSize = FFT_SIZE;
    
    _melFiltersCount = 16;
    _melFilters = (MelFilterBank*)calloc(_melFiltersCount, sizeof(MelFilterBank));
    
    float fsz = _fftSize;
    float neededBins = 16.0f;
    float log2fCoef = (log2f(fsz))/(neededBins-1);
    float expandCoef = 1.432;//powf(2.f, log2fCoef);
    
    NSMutableArray * marr = @[].mutableCopy;
    int32_t index = 0;
    float bins = 1.f;
    int32_t melIndex = 0;
    
    do {
        int iBins = (ceilf(bins));
        [marr addObject:[NSString stringWithFormat:@"%@ - %@", @(iBins + 1), @(index)]];
        _melFilters[melIndex].centerFFTNode = index;
        _melFilters[melIndex].fftNodesCount = iBins + 1;
        //        for (int i = 0; i < iBins; i++) {
        index+= iBins;
        //        }
        bins = expandCoef * bins;
        melIndex++;
        //        bins = 2 * bins;
    } while (index < _fftSize && melIndex < _melFiltersCount);
    

    for (int i = 0; i < _melFiltersCount; i++) {
        
        MelFilterBank * bank = _melFilters + i;
        assert (bank->fftNodesCount);
        NSInteger startNode = floorf(bank->centerFFTNode / 1.432);
        NSInteger endNode = ceilf(bank->centerFFTNode * 1.432);
        NSInteger nodesCount = endNode - startNode + 1;
        
        bank->weights = (float*)calloc(nodesCount, sizeof(float));
        assert (bank->weights);
        
        if (nodesCount < 4) {
            continue;//keep zeroed weight for single-node bands, i.e. for fftIndex == 0 and 1
        }
        
        for (NSInteger j = startNode; j < endNode; j ++) {
            NSInteger index = j - startNode;
            NSInteger offset = bank->centerFFTNode - startNode;
            bank->weights[index] = ((float)index)/((float)offset);
        }
        for (NSInteger j = bank->centerFFTNode; j < endNode; j ++) {
            NSInteger index = j - startNode;
            NSInteger offset = bank->centerFFTNode - startNode;
            NSInteger width = endNode - bank->centerFFTNode;
            float tan = 1.0f/((float)width);
            bank->weights[index] = (-(float)(index - offset) * tan) + 1;
        }
        
        for (int i = 0; i < nodesCount; i ++) {
            bank->weights[i] *= 20.0f;
        }
        
//        if (i == 15/* || i == 14*/)  {
        PlotColor color = (PlotColor){1.0f, 1.0f, 1.0f, 1.0f};

        float * buffer = (float*)calloc(nodesCount*2, sizeof(float));
        for (int i = 0; i < nodesCount; i++) {
            int index = i;
            if (index < _fftSize) {
                buffer[2*index] = (float)index + startNode;
                buffer[2*index+1] = bank->weights[i];
            }
        }
        
        NSInteger line = [_plotView addLineChartWithName:@"weight" data:buffer length:nodesCount * 2 thickness:1 color:color];
        [_plotView setData:buffer offset:0 ofLength:nodesCount * 2 forChart:line];
//        }
    }
    
    
    NSLog(@"%@", marr);// N(2) = log2(fftSize) + 1
    NSLog(@"count = %lu", (unsigned long)marr.count);
    
    
    _sizeLog2N = (vDSP_Length)log2((double)_fftSize);
    
    _fftSetup = vDSP_create_fftsetup(_sizeLog2N, kFFTDirection_Forward);
    
    _fftBuffer = (float*)calloc(_fftSize * 2, sizeof(float));
    _avgBuffer = (float*)calloc(_fftSize * 2, sizeof(float));
    _vertexBuffer = (float*)calloc(_fftSize * 2, sizeof(float));
    _vertexBufferMax = (float*)calloc(_fftSize * 2, sizeof(float));
    _vertexBufferMin = (float*)calloc(_fftSize * 2, sizeof(float));
    
    _melBuffer = (float*)calloc(16 * 2, sizeof(float));
    
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
    
    _lineMax = [_plotView addLineChartWithName:@"max" data:_vertexBuffer length:_melFiltersCount*2 thickness:1 color:colorMax];
    _lineMin = [_plotView addLineChartWithName:@"min" data:_vertexBuffer length:_melFiltersCount*2 thickness:1 color:colorMin];
    _line    = [_plotView addLineChartWithName:@"line" data:_vertexBuffer length:_melFiltersCount*2 thickness:2 color:color];
    //    _line    = [_plotView addBarChartWithName:@"live" data:_vertexBuffer length:_fftSize*2 color1:color color2:color];
    
    PlotColor backColor = (PlotColor){0.0f, 0.0f, 0.0f, 1.0f};
    _plotView.chartsBackgroundColor = backColor;
    
    float lineData[] = {-10.0f, 0.0f, (float)_fftSize + 10, 0.0f};
    
    //    PlotColor grayColor = (PlotColor){0.6f, 0.6f, 0.6f, 0.8f};
    
    //    [_plotView addLineChartWithName:@"hor" data:lineData length:4 thickness:2 color:grayColor];
    
    [_plotView setRangeMinX:-25 maxX:_fftSize+64 minY:-100 maxY:500];
    [_plotView setVisibleRangeMinX:0 maxX:_melFiltersCount minY:-6 maxY:10];
    _plotView.gridStepX = 25;
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
    _updateTimer = [GCDTimer scheduledTimerWithTimeInterval:0.010
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
    
    for(int i = 0; i < _melFiltersCount; i++) {
        MelFilterBank bank = _melFilters[i];
        assert(bank.weights);
        float bandSum = 0.0;
        for (int j = 0; j < bank.fftNodesCount; j++) {
            int indexInFFT = j + bank.centerFFTNode;
            float weight = bank.weights[j];
            bandSum = bandSum + weight * _fftBuffer[indexInFFT];
        }
        _melBuffer[i] = bandSum;
    }
    
    float B = 1.0f;//0.0025f;
    vDSP_vdbcon(_melBuffer, 1, &B, _melBuffer, 1, _melFiltersCount, 1);
    
//    B = 0.001f;
//    vDSP_vsmul(_melBuffer, 1, &B, _melBuffer, 1, _melFiltersCount);
    
//    NSInteger index = 0;
//    NSInteger bins = 1;
//    while (index < _fftSize) {
//
//        for (int i = 0; i < bins; i++) {
//            index++;
//        }
//        bins = 2 * bins;
//    }
    
//    float mean = 0.0;
//    vDSP_meanv(_avgBuffer, 1, &mean, _fftSize);
//    mean = -mean;
    
//    vDSP_vsadd(_avgBuffer, 1, &mean, _avgBuffer, 1, _fftSize);
    
    //    B = 10.0f;
    //    vDSP_vsadd(_fftBuffer, 1, &B, _fftBuffer, 1, _fftSize);
    
    //    for (int i = 0; i < _fftSize; i++) {
    //        float newVal = _fftBuffer[i] * 0.1f + _avgBuffer[i] * 0.9f;
    //        _avgBuffer[i] = newVal;
    ////        _vertexBuffer[2*i+1] = newVal;
    //    }
    
//    DSPSplitComplex complexIn;
//    complexIn.realp = _avgBuffer;
//    complexIn.imagp = _avgBuffer + _fftSize;
//
//    DSPSplitComplex complexOut;
//    complexOut.realp = _fftBuffer;
//    complexOut.imagp = _fftBuffer + _fftSize;
//
//    vDSP_fft_zop(_fftSetup, &complexIn, 1, &complexOut, 1, _sizeLog2N, kFFTDirection_Forward);
    
    //    vDSP_zvmags(&complexOut, 1, _fftBuffer, 1, _fftSize);
    
    for (int i = 0; i < _melFiltersCount; i++) {
        int j = i * 2 + 1;
        if (isnan(_melBuffer[i])) {
            continue;
        }
        _vertexBuffer[j] = 0.08f * _melBuffer[i] + 0.92f * _vertexBuffer[j];// = _fftBuffer[i]/10 + 10;
        if (_vertexBuffer[j] > _vertexBufferMax[j]) _vertexBufferMax[j] = _vertexBuffer[j];
        else _vertexBufferMax[j] = 0.01f * _vertexBuffer[j] + 0.99f * _vertexBufferMax[j];
        if (_vertexBuffer[j] < _vertexBufferMin[j]) _vertexBufferMin[j] = _vertexBuffer[j];
        else _vertexBufferMin[j] = 0.01f * _vertexBuffer[j] + 0.99f * _vertexBufferMin[j];
        //        _vertexBufferMin[j] = 0.2f * _fftBuffer[_fftSize+i] + 0.8f * _vertexBuffer[j];
    }
    [_plotView setData:_vertexBuffer    offset:0 ofLength:_melFiltersCount * 2 forChart:_line];
    [_plotView setData:_vertexBufferMax offset:0 ofLength:_melFiltersCount * 2 forChart:_lineMax];
    [_plotView setData:_vertexBufferMin offset:0 ofLength:_melFiltersCount * 2 forChart:_lineMin];
    [_plotView update:nil];
}

@end
