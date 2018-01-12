//
//  on_fft_to_mel.h
//  Reco
//
//  Created by oleg.naumenko on 1/11/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#ifndef on_fft_to_mel_h
#define on_fft_to_mel_h

#include <stdio.h>
#include <MacTypes.h>

#ifdef __cplusplus
extern "C" {
#endif

    
struct MelFilterBank {
    int32_t centerFFTNode;
    int32_t startFFTNode;
    int32_t fftNodesCount;
    Float32 * weights;
};

typedef struct MelFilterBank MelFilterBank;

struct on_fft_to_mel_setup {
    int32_t fftSize;
    int32_t melFiltersCount;
    Float32 * fftBuffer;
    Float32 * melOutBuffer;
    MelFilterBank * melFilters;
};

typedef struct on_fft_to_mel_setup on_fft_to_mel_setup;

on_fft_to_mel_setup * on_fft_to_mel_init(int32_t fftSize);
void on_fft_to_mel_free(on_fft_to_mel_setup * setup);
void on_fft_to_mel_transform(on_fft_to_mel_setup * setup, float * fftBuffer, int32_t fftSize);
    
#ifdef __cplusplus
}
#endif
        
#endif /* on_fft_to_mel_h */
