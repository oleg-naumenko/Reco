//
//  Analyzer.h
//  Reco
//
//  Created by oleg.naumenko on 11/14/17.
//  Copyright © 2017 oleg.naumenko. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SEPlot/PlotView.h>

@interface Analyzer : NSObject

- (void) start;
- (void) stop;
- (void) teardown;

@property (nonatomic, strong) PlotView * plotView;

@end
