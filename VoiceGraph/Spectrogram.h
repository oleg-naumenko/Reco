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

@property (nonatomic) NSUInteger width;
@property (nonatomic) NSUInteger height;

@end
