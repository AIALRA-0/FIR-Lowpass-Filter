#ifndef FIR_ZU4EV_VECTORS_H
#define FIR_ZU4EV_VECTORS_H

#include <stdint.h>

#define FIR_MAX_VECTOR_LENGTH 2048U

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

extern const int16_t fir_case_passband_edge_sine_input[1024];
extern const int16_t fir_case_passband_edge_sine_golden[1024];

extern const int16_t fir_case_transition_sine_input[1024];
extern const int16_t fir_case_transition_sine_golden[1024];

extern const int16_t fir_case_multitone_input[2048];
extern const int16_t fir_case_multitone_golden[2048];

extern const int16_t fir_case_stopband_sine_input[1024];
extern const int16_t fir_case_stopband_sine_golden[1024];

extern const int16_t fir_case_large_random_buffer_input[2048];
extern const int16_t fir_case_large_random_buffer_golden[2048];

extern const fir_vector_case_t g_fir_vector_cases[8];
extern const uint32_t g_fir_vector_case_count;

#endif
