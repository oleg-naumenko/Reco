//
//  on_mag_to_log.h
//  Reco
//
//  Created by oleg.naumenko on 1/11/18.
//  Copyright © 2018 oleg.naumenko. All rights reserved.
//

#ifndef on_mag_to_log_h
#define on_mag_to_log_h

#include <stdio.h>
#include <MacTypes.h>

#ifdef __cplusplus
extern "C" {
#endif
    
    struct on_mag_to_log_setup {
        Float32 biasLog;
        Float32 bias;
    };
    
    typedef struct on_mag_to_log_setup on_mag_to_log_setup;
    
    on_mag_to_log_setup * on_mag_log_init(float bias);
    void on_mag_log_free(on_mag_to_log_setup * setup);
    void on_mag_log_do(on_mag_to_log_setup * setup, float * buffer, int32_t length);
    
#ifdef __cplusplus
}
#endif


#endif /* on_mag_to_log_h */
