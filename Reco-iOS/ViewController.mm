//
//  ViewController.m
//  Reco-iOS
//
//  Created by oleg.naumenko on 11/14/17.
//  Copyright © 2017 oleg.naumenko. All rights reserved.
//

#import "ViewController.h"
#import <SEPlot/PlotView.h>
#import "Analyzer.h"

#import <AVFoundation/AVFoundation.h>

@interface ViewController ()
{
    Analyzer * _analyzer;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    CGRect rect = self.view.bounds;
    
    rect.origin.y += 20;
    rect.size.height -= 20;
    
    PlotView * plotView = [[PlotView alloc] initWithFrame:rect];
    plotView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    plotView.scalesOverlaid = YES;
    plotView.oneTouchMovesPlot = YES;
    [plotView setWidth:30 forSide:PlotSideCount];
    [self.view addSubview:plotView];
    
    _analyzer = [Analyzer new];
    _analyzer.plotView = plotView;
    
    [_analyzer start];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_analyzer teardown];
}


@end
