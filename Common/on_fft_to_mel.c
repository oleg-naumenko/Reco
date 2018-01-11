//
//  on_fft_to_mel.c
//  Reco
//
//  Created by oleg.naumenko on 1/11/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#include <math.h>
#include <Accelerate/Accelerate.h>
#include <assert.h>

#include "on_fft_to_mel.h"

#if !defined(MIN)
#define MIN(A,B)((A) < (B) ? (A) : (B))
#endif

#if !defined(MAX)
#define MAX(A,B)((A) > (B) ? (A) : (B))
#endif

on_fft_to_mel_setup * on_fft_to_mel_init(int32_t fftSize)
{
    on_fft_to_mel_setup * setup = (on_fft_to_mel_setup*)malloc(sizeof(on_fft_to_mel_setup));
    
    int32_t melFiltersCount = 0;
    MelFilterBank * melFilters = (MelFilterBank*)calloc(256, sizeof(MelFilterBank));
    float expandCoef = 1.432;// 1.432;//powf(2.f, log2fCoef);
    
    int32_t index = 0;
    float bins = 1.f;
    int32_t melIndex = 0;
    
    do {
        int iBins = (ceilf(bins));
        melFilters[melIndex].centerFFTNode = index;
        melFilters[melIndex].fftNodesCount = iBins + 1;
        melFiltersCount++;
        index+= iBins;
        bins = expandCoef * bins;
        melIndex++;
    } while (index < fftSize);
    
    melFilters = (MelFilterBank*)realloc(melFilters, melFiltersCount * sizeof(MelFilterBank));
    
    for (int32_t i = 0; i < melFiltersCount; i++) {
        
        MelFilterBank * bank = melFilters + i;
        assert (bank->fftNodesCount);
        int32_t startNode = floorf(bank->centerFFTNode / expandCoef);
        int32_t endNode = MIN(fftSize, ceilf(bank->centerFFTNode * expandCoef));
        int32_t nodesCount = endNode - startNode + 1;
        
        bank->fftNodesCount = (int32_t)nodesCount;
        bank->startFFTNode  = (int32_t)startNode;
        
        
        bank->weights = (float*)calloc(nodesCount, sizeof(float));
        assert (bank->weights);
        
        if (nodesCount < 1) {
            continue;//keep zeroed weight for single-node bands, i.e. for fftIndex == 0 and 1
        }
        
        for (int32_t j = startNode; j < endNode; j ++) {
            int32_t index = j - startNode;
            int32_t offset = bank->centerFFTNode - startNode;
            bank->weights[index] = ((float)index)/((float)offset);
        }
        for (int32_t j = bank->centerFFTNode; j < endNode; j ++) {
            int32_t index = j - startNode;
            int32_t offset = bank->centerFFTNode - startNode;
            int32_t width = endNode - bank->centerFFTNode;
            float tan = 1.0f/((float)width);
            bank->weights[index] = (-(float)(index - offset) * tan) + 1;
        }
        
        float gain = 20;// * ((float)(bank->centerFFTNode - bank->startFFTNode))/((float)bank->fftNodesCount); //((i+1 == _melFiltersCount) ? 1.75f : 1.0f);
        
        for (int j = 0; j < nodesCount; j ++) {
            bank->weights[j] *= gain;
        }
    }
    setup->fftBuffer = (float*)calloc(fftSize * 2, sizeof(float));
    setup->fftSize = fftSize;
    setup->melFilters = melFilters;
    setup->melFiltersCount = melFiltersCount;
    
    setup->melOutBuffer = (float*)calloc(melFiltersCount, sizeof(float));
    
    return setup;
}

void on_fft_to_mel_free(on_fft_to_mel_setup * setup)
{
    if (setup->melFilters) {
        for (int i = 0; i < setup->melFiltersCount; i ++) {
            if (setup->melFilters[i].weights) {
                free((void*)setup->melFilters[i].weights);
                setup->melFilters[i].weights = NULL;
            }
        }
        free(setup->melFilters);
        setup->melFilters = NULL;
    }
    free(setup->melOutBuffer);
    free(setup->fftBuffer);
    setup->melOutBuffer = NULL;
    setup->fftBuffer = NULL;
    free(setup);
    setup = NULL;
}

void on_fft_to_mel_transform(on_fft_to_mel_setup * setup, float * fftBuffer, int32_t fftSize)
{
    assert(fftSize == setup->fftSize);
    
    for(int i = 0; i < setup->melFiltersCount; i++) {
        MelFilterBank bank = setup->melFilters[i];
        float bandSum = 0.0;
        for (int j = 0; j < bank.fftNodesCount; j++) {
            int indexInFFT = j + bank.startFFTNode;
            float weight = bank.weights[j];
            bandSum = bandSum + weight * fftBuffer[indexInFFT];
        }
        setup->melOutBuffer[i] = bandSum;
    }
}
