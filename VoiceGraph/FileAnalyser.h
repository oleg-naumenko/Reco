//
//  FileAnalyser.h
//  VoiceGraph
//
//  Created by oleg.naumenko on 1/12/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "Spectrogram.h"

typedef void(^AnalyserCallback)(id result, NSError * error);

@interface FileAnalyser : NSObject

- (void) openFileFromPath:(NSString*)path completion:(AnalyserCallback)callback;

@property (nonatomic, readonly) Spectrogram * spectrogram;
@property (nonatomic, readonly) UInt64 streamByteLength;
@property (nonatomic, readonly) UInt64 sampleRate;
@property (nonatomic, readonly) NSTimeInterval duration;

@property (nonatomic, readonly) NSString * filePath;

@end
