//
//  Matcher.m
//  Reco
//
//  Created by oleg.naumenko on 1/15/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#import "Matcher.h"
#import "RNN.h"

@implementation Matcher
{
    RNN * _rnn;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self createRNN];
    }
    return self;
}

- (void) createRNN
{
    _rnn = [[RNN alloc] init];
    _rnn.maxIteration     = 500;
    _rnn.convergenceError = 0.001f;
    _rnn.learningRate     = 0.5f;
    _rnn.timestepSize     = kRNNFullBPTT;
    
    _rnn.randomMax        = 0.25f;
    _rnn.randomMin        = -0.25f;
    
    //        [_rnn addPatternsFromArray:patterns];
    
    [_rnn createHiddenLayerNetsForCount:18];
    [_rnn createOutputLayerNetsForCount:10];
    
    [_rnn randomizeWeights];
    [_rnn uniformActiviation:RNNNetActivationSigmoid];
    
    RNNOptimization *optimization = [[RNNOptimization alloc] init];
    optimization.method           = RNNOptimizationStandardSGD;
    [_rnn uniformOptimization:optimization];
}

@end
