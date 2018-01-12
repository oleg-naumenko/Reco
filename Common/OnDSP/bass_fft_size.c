//
//  bass_fft_size.c
//  Reco
//
//  Created by oleg.naumenko on 1/12/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#include "bass_fft_size.h"
#include <stdlib.h>

DWORD bassFlagForFFTSize(UInt32 fftSize)
{
    DWORD dataFlag = BASS_DATA_FLOAT;
    switch (fftSize)
    {
        case 256:
            dataFlag |= BASS_DATA_FFT256;
            break;
        case 512:
            dataFlag |= BASS_DATA_FFT512;
            break;
        case 1024:
            dataFlag |= BASS_DATA_FFT1024;
            break;
        case 2048:
            dataFlag |= BASS_DATA_FFT2048;
            break;
        case 4096:
            dataFlag |= BASS_DATA_FFT4096;
            break;
        case 8192:
            dataFlag |= BASS_DATA_FFT8192;
            break;
        case 16384:
            dataFlag |= BASS_DATA_FFT16384;
            break;
        case 32768:
            dataFlag |= BASS_DATA_FFT32768;
            break;
        default:
            
            // @"wrong fft size"
            break;
    }
    return dataFlag;
}
