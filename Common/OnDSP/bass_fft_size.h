//
//  bass_fft_size.h
//  Reco
//
//  Created by oleg.naumenko on 1/12/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#ifndef bass_fft_size_h
#define bass_fft_size_h

#include <stdio.h>
#include <MacTypes.h>
#include "bass.h"

#ifdef __cplusplus
extern "C" {
#endif
    
    DWORD bassFlagForFFTSize(UInt32 fftSize);
    
#ifdef __cplusplus
}
#endif

#endif /* bass_fft_size_h */
