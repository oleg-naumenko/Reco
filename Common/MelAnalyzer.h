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

- (void) start;
- (void) stop;
- (void) teardown;

@property (nonatomic, strong) PlotView * plotView;

@end
