//
//  Spectrogram.m
//  VoiceGraph
//
//  Created by oleg.naumenko on 1/12/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import "Spectrogram.h"

@implementation Spectrogram
{
    float * _buffer;
}

- (instancetype) initWithWidth:(NSUInteger)width height:(NSUInteger)height
{
    if (self = [super init]) {
        _width = width;
        _height = height;
         size_t count = width * height;
        _buffer = calloc(count, sizeof(float));
        assert(_buffer);
    }
    return self;
}

- (void)dealloc
{
    free(_buffer);
}



- (void) setSpectra:(float*)values length:(NSUInteger) length atTimeIndex:(NSUInteger)timeIdx
{
    //spectrogram consists of columns each representing spectra in frequency, distributed horisontally in time
    assert(length == self.height);
    assert(timeIdx * self.height + length <= self.width * self.height);
    
    memcpy(_buffer + timeIdx * self.height, values, length * sizeof(float));
}

- (float*) getSpectra:(float*)valuePtr ofLength:(NSUInteger)length atTimeIndex:(NSUInteger)timeIdx
{
    assert(length == self.height);
    assert(timeIdx * self.height + length <= self.width * self.height);
    
    float * ptr = _buffer + timeIdx * self.height;
    return ptr;
}


@end
