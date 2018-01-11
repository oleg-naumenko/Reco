//
//  MelAnalyzer.h
//  Reco
//
//  Created by oleg.naumenko on 1/9/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SEPlot/PlotView.h>


@interface MelAnalyzer : NSObject

- (instancetype) initWithFFTSize:(int32_t)fftSize;

- (void) start;
- (void) stop;

@property (nonatomic, strong) PlotView * plotView;

@end
