//
//  Spectrogram.h
//  VoiceGraph
//
//  Created by oleg.naumenko on 1/12/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Spectrogram : NSObject

- (instancetype) initWithWidth:(NSUInteger)width height:(NSUInteger)height;
- (void) setSpectra:(float*)values length:(NSUInteger) length atTimeIndex:(NSUInteger)timeIdx;
- (float*) getSpectra:(float*)valuePtr ofLength:(NSUInteger)length atTimeIndex:(NSUInteger)timeIdx;

@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;

@property (nonatomic, readonly) float * buffer;

@property (nonatomic, assign) NSUInteger startIndex;
@property (nonatomic, assign) NSUInteger endIndex;

@property (nonatomic, strong) NSArray <NSNumber*> * maximas;
@property (nonatomic, strong) NSArray <NSNumber*> * minimas;

@end
