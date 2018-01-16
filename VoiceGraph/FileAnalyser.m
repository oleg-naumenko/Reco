//
//  FileAnalyser.m
//  VoiceGraph
//
//  Created by oleg.naumenko on 1/12/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import "FileAnalyser.h"
#import "bass.h"
#import "on_fft_to_mel.h"
#import "on_mag_to_log.h"
#import "bass_fft_size.h"

#import <Accelerate/Accelerate.h>


#define MAX_DURATION 30.0

@implementation FileAnalyser
{
    DWORD _bassChannel;
    on_fft_to_mel_setup * _melTransformer;
    on_mag_to_log_setup * _logTransformer;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        BOOL init = BASS_Init(-1, 0, 0, NULL, NULL);
        if (!init) {
            NSLog(@"Could not init bass: %d", BASS_ErrorGetCode());
        }
        _melTransformer = NULL;
        _logTransformer = NULL;
    }
    return self;
}

- (void)dealloc
{
    BASS_StreamFree(_bassChannel);
    if (_logTransformer) {
        on_mag_log_free(_logTransformer);
    }
    if (_melTransformer) {
        on_fft_to_mel_free(_melTransformer);
    }
}

- (void) openFileFromPath:(NSString*)path completion:(AnalyserCallback)fileOpenedCallback
{
    _filePath = path;
    _bassChannel = [self bassChannelFromFile:path];
    if (!_bassChannel) {
        NSError * error = [NSError errorWithDomain:@"naumenko.com" code:100 userInfo:@{NSLocalizedDescriptionKey:@"Could not load audio file", NSURLErrorKey:[NSURL fileURLWithPath:path]}];
        if (fileOpenedCallback) fileOpenedCallback(nil, error);
        return;
    }
    
    [self startAnalyzeStream];
    
    if (fileOpenedCallback) fileOpenedCallback(self, nil);
}

- (void) startAnalyzeStream
{
    DWORD fftSize = 512;//is't actually an fft halph size, named here like this for convenience
    
    float hopInterval = 0.04;
    float hopHalfSpanFFT = BASS_ChannelBytes2Seconds(_bassChannel, fftSize * sizeof(float));
    
    float duration = MIN(MAX_DURATION, self.duration);
    
    NSUInteger timeHopsNum = (duration - hopHalfSpanFFT) / hopInterval;
    
    _melTransformer = on_fft_to_mel_init(fftSize);
    _logTransformer = on_mag_log_init(0.000000001);
    
    NSUInteger spectraSize = _melTransformer->melFiltersCount;
    
    _spectrogram = [[Spectrogram alloc] initWithWidth:timeHopsNum height:spectraSize - 1];
    
    DWORD dataFlag = bassFlagForFFTSize(2 * fftSize);//we need to tell bass full fft size we need
    
    QWORD positionBytes = 0;
    float position = 0.0f;
    float oldPos = 0.0f;
    for(NSUInteger i = 0; i < timeHopsNum; i++) {
        
        positionBytes = BASS_ChannelSeconds2Bytes(_bassChannel, position);
        BOOL jumped = BASS_ChannelSetPosition(_bassChannel, positionBytes, BASS_POS_BYTE);
        
        if (!jumped) {
            NSLog(@"Could not set stream position: %d", BASS_ErrorGetCode());
        }
        
        float pos = BASS_ChannelBytes2Seconds(_bassChannel, BASS_ChannelGetPosition(_bassChannel, BASS_POS_BYTE));
        assert(!i || ABS(pos - oldPos - hopInterval) < 0.001);
        
        oldPos = pos;
        
        DWORD read = BASS_ChannelGetData(_bassChannel, _melTransformer->fftBuffer, dataFlag);
        
//        NSLog(@"Read: %lu  :  %2.3f - %lu", i, pos, read/sizeof(float));
        
        on_fft_to_mel_transform(_melTransformer, _melTransformer->fftBuffer, _melTransformer->fftSize);
        on_mag_log_do(_logTransformer, _melTransformer->melOutBuffer, _melTransformer->melFiltersCount);
        
        [_spectrogram setSpectra:_melTransformer->melOutBuffer + 1 length:_melTransformer->melFiltersCount - 1 atTimeIndex:i];
        
        position += hopInterval;
    }
    
//    float filter [9] = {.0f, .0f, 0.3f, .0f, .0f, 0.3f, .0f, .0f, 0.3f};
//    float filter [9] = {.0f, 0.33f, .0f, .0f, 0.33f, .0f, .0f, 0.33f, .0f};
//    float filter [9] = {0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f};
    
    CFAbsoluteTime tm = CFAbsoluteTimeGetCurrent();
    
    float averagedForwadSum[_spectrogram.width];
    float averagedBackwardSum[_spectrogram.width];
    
    
    //populate averaged forward/backward:
    for (int i = 0; i < _spectrogram.width; i++) {
        float sum = 0.0f;
        float * spectra = [_spectrogram getSpectra:NULL ofLength:_spectrogram.height atTimeIndex:i];
        for (int j = 0; j < _spectrogram.height; j++) {
            sum += (spectra[j]);
        }
//        sum/= _spectrogram.height;
//        if (i) {
//            float * spectra1 = [_spectrogram getSpectra:NULL ofLength:_spectrogram.height atTimeIndex:i-1];
//            sum = sum * 0.01f + averagedForwadSum[i] * 0.99f;
//        }
//        if (sum > maxSum) maxSum = sum;
//        if (sum < minSum) minSum = sum;
        
        averagedForwadSum[i] = sum;
        averagedBackwardSum[i] = sum;
    }
    
    float maxSum = FLT_MIN;
    float minSum = FLT_MAX;
    
    //average forward:
    for (int i = 1; i < _spectrogram.width; i++) {
        float sum = averagedForwadSum[i];
        if (i) {
            sum = sum * 0.05f + averagedForwadSum[i-1] * 0.95f;
        }
        if (sum > maxSum) maxSum = sum;
        if (sum < minSum) minSum = sum;
        averagedForwadSum[i] = sum;
    }
    
    //scale fwd averaged sums:
    
    for (int i = 0; i < _spectrogram.width; i++) {
        averagedForwadSum[i] -= minSum;
        averagedForwadSum[i] /= (maxSum - minSum);
    }
    
    maxSum = FLT_MIN;
    minSum = FLT_MAX;
    
    //average backward:
    for (int i = (int)_spectrogram.width - 2; i >= 0; i--) {
        float sum = averagedBackwardSum[i];
        
        if (i) {
            sum = sum * 0.1f + averagedBackwardSum[i+1] * 0.9f;
        }
        if (sum > maxSum) maxSum = sum;
        if (sum < minSum) minSum = sum;
        averagedBackwardSum[i] = sum;
    }
    
    //scale bwd averaged sums:
    
    for (int i = 0; i < _spectrogram.width; i++) {

        averagedBackwardSum[i] -= minSum;
        averagedBackwardSum[i] /= (maxSum - minSum);
    }
    
    
//    float filter [5] = {0.0f, 0.05f, 0.9f, 0.05f, 0.0f};
//    float filter [5] = {0.33f, 0.33f, 0.33f};//, 0.2f, 0.2f};
//    float filter [9] = {0.11f, 0.11f, 0.11f, 0.11f, 0.12f, 0.11f, 0.11f, 0.11f, 0.11f};//, 0.2f, 0.2f};
    
//    vDSP_conv(_spectrogram.buffer, _spectrogram.height, filter, 1, _spectrogram.buffer, _spectrogram.height, _spectrogram.width, 9);
//    for (int i = 0; i < _spectrogram.width; i++) {
//        float sum = 0.0f;
//        float * spectra = [_spectrogram getSpectra:NULL ofLength:_spectrogram.height atTimeIndex:i];
//    }
    
    
    //put data into plot:
    for (int i = 0; i < _spectrogram.width; i++) {
        float * spectra = [_spectrogram getSpectra:NULL ofLength:_spectrogram.height atTimeIndex:i];
        
//        spectra[0] = (i < _spectrogram.width/2 ? averagedForwadSum[i] : averagedBackwardSum[i]);
        spectra[0] = averagedForwadSum[i];
//        spectra[0] = averagedBackwardSum[i];
        
    }
    
    NSLog(@"Total Hops: %lu", timeHopsNum);
    
    NSMutableArray * maxima = @[].mutableCopy;
    NSMutableArray * minima = @[].mutableCopy;
    
    
    //find first onset for "start" marker:
    
    for (int i = 0; i < _spectrogram.width - 2; i++) {
        
        float curValue = averagedForwadSum[i];
        int riseSize = 5;
        BOOL isRise = YES;
        BOOL isAccel = NO;
        float delta = 0.0f;
        
        for (int j = 1; j < riseSize; j++) {
            int index = i + j;
            if (index > _spectrogram.width -1) break;
            float nextValue = averagedForwadSum[index];
            isRise = isRise && (nextValue > curValue);
            if (!isRise) {
                break;
            } else {
                float newDelta = nextValue - curValue;
                isAccel = (isAccel || newDelta > delta);
                curValue = nextValue;
            }
        }
        if (isRise && isAccel && curValue < 0.6f && curValue > 0.1f) {
            _spectrogram.startIndex = i;
            break;
        }
    }
    
    //find last dropoff for "end" marker:
    
    for (int i = (int)_spectrogram.width - 1; i > 2; i--) {
        
        float curValue = averagedBackwardSum[i];
        
        int riseSize = 5;
        BOOL isRise = YES;
        for (int j = 1; j < riseSize; j++) {
            int index = i - j;
            if (index < 0) break;
            float nextValue = averagedBackwardSum[index];
            isRise = isRise && (nextValue > curValue);
            if (!isRise) {
                break;
            } else {
//                NSLog(@"ISRISE: %2.2f %2.2f - %d", nextValue, curValue, i);
                curValue = nextValue;
            }
        }
        if (isRise && i > _spectrogram.startIndex && curValue < 0.6f && curValue > 0.05) {
            _spectrogram.endIndex = i;
            break;
        }
    }
    if(!_spectrogram.endIndex) {
        _spectrogram.endIndex = _spectrogram.width - 1;
    }
    _spectrogram.maximas = maxima.copy;
    _spectrogram.minimas = minima.copy;
    
    NSLog(@"CONV: %2.5f", CFAbsoluteTimeGetCurrent() - tm);
}



//        BOOL isLocalMax = ( *spectra > *spectraMinus1 && *spectra > *spectraPlus1 && *spectra > *spectraMinus2 && *spectra > *spectraPlus2 && *spectra > 0.3);
//
//        if (isLocalMax && !wasMaxima && wasStart) {
//            wasMaxima = YES;
//            [maxima addObject:@(i)];
//            maxCount ++;
//        } else {
//            BOOL isLocalMin = (*spectra < *spectraMinus1 && *spectra < *spectraPlus1 && *spectra < *spectraMinus2 && *spectra < *spectraPlus2);
//            if (isLocalMin && wasMaxima && wasStart) {
//                wasMaxima = NO;
//                [minima addObject:@(i)];
//            }
//        }

- (DWORD)bassChannelFromFile:(NSString*)filePath
{
    DWORD channel = BASS_StreamCreateFile(NO, filePath.UTF8String, 0, 0, BASS_SAMPLE_FLOAT|BASS_STREAM_DECODE);
    if (!channel) {
        NSLog(@"Could not create bass channel: %d", BASS_ErrorGetCode());
    }
    return channel;
}

- (UInt64)streamByteLength
{
    return BASS_ChannelGetLength(_bassChannel, BASS_POS_BYTE);
}

- (NSTimeInterval)duration
{
    return (NSTimeInterval)BASS_ChannelBytes2Seconds(_bassChannel, self.streamByteLength);
}

- (UInt64)sampleRate
{
    BASS_CHANNELINFO info = {0};
    BASS_ChannelGetInfo(_bassChannel, &info);
    return info.freq;
}


@end
