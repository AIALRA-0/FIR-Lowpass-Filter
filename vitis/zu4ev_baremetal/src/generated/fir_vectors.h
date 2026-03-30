#ifndef FIR_ZU4EV_VECTORS_H
#define FIR_ZU4EV_VECTORS_H

#include <stdint.h>

typedef struct {
    const char *name;
    uint32_t length;
    const int16_t *input;
    const int16_t *golden;
} fir_vector_case_t;

extern const int16_t fir_case_impulse_input[1024];
extern const int16_t fir_case_impulse_golden[1024];

extern const int16_t fir_case_step_input[1024];
extern const int16_t fir_case_step_golden[1024];

extern const int16_t fir_case_random_short_input[1024];
extern const int16_t fir_case_random_short_golden[1024];

extern const fir_vector_case_t g_fir_vector_cases[3];
extern const uint32_t g_fir_vector_case_count;

#endif
