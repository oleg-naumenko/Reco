//
//  on_mag_to_log.c
//  Reco
//
//  Created by oleg.naumenko on 1/11/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#include "on_mag_to_log.h"
#include <Accelerate/Accelerate.h>
#include <math.h>


on_mag_to_log_setup * on_mag_log_init(float bias)
{
    on_mag_to_log_setup * ptr = (on_mag_to_log_setup*)malloc(sizeof(on_mag_to_log_setup));
    ptr->biasLog = -log10f(bias);
    ptr->bias = bias;
    return ptr;
}

void on_mag_log_free(on_mag_to_log_setup * setup)
{
    free(setup);
}

void on_mag_log_do(on_mag_to_log_setup * setup, float * buffer, int32_t length)
{
    vDSP_vsadd(buffer, 1, &setup->bias, buffer, 1, length);
    
    vvlog10f(buffer, buffer, &length);

    vDSP_vsadd(buffer, 1, &setup->biasLog, buffer, 1, length);
    
//    for(int i = 0; i < length; i++) {
//        buffer[i] = log10f(buffer[i]) - setup->biasLog;
//    }
}
