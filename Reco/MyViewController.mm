//
//  MyViewController.m
//  Reco
//
//  Created by oleg.naumenko on 10/27/17.
//  Copyright © 2017 oleg.naumenko. All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import <SEPlot/PlotView.h>

#import "MyViewController.h"
#import "MelAnalyzer.h"
#import "Analyzer.h"


@interface MyViewController ()

@end

@implementation MyViewController
{
    MelAnalyzer * _analyzer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSRect rect = self.view.bounds;
    PlotView * plotView = [[PlotView alloc] initWithFrame:rect];
    plotView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    [self.view addSubview:plotView];
    
    _analyzer = [MelAnalyzer new];
    _analyzer.plotView = plotView;
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];
    [_analyzer stop];
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    [_analyzer start];
}

@end
