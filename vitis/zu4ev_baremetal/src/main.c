#include <stdint.h>
#include <string.h>

#include "xaxidma.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"

#include "fir_zu4ev_hw.h"
#include "generated/fir_vectors.h"

static XAxiDma g_axi_dma;
static volatile int16_t *const g_tx_buffer = (int16_t *)FIR_TX_BUFFER_BASE;
static volatile int16_t *const g_rx_buffer = (int16_t *)FIR_RX_BUFFER_BASE;

static inline void fir_reg_write(uint32_t offset, uint32_t value) {
    Xil_Out32(FIR_CTRL_BASEADDR + offset, value);
}

static inline uint32_t fir_reg_read(uint32_t offset) {
    return Xil_In32(FIR_CTRL_BASEADDR + offset);
}

static int fir_dma_init(void) {
    XAxiDma_Config *cfg = XAxiDma_LookupConfig(FIR_DMA_DEVICE_ID);
    if (cfg == NULL) {
        xil_printf("DMA lookup failed\r\n");
        return XST_FAILURE;
    }
    if (XAxiDma_CfgInitialize(&g_axi_dma, cfg) != XST_SUCCESS) {
        xil_printf("DMA init failed\r\n");
        return XST_FAILURE;
    }
    if (XAxiDma_HasSg(&g_axi_dma)) {
        xil_printf("Scatter-gather mode is not supported in this demo\r\n");
        return XST_FAILURE;
    }
    return XST_SUCCESS;
}

static void fir_soft_reset(void) {
    fir_reg_write(FIR_REG_CONTROL, FIR_CTRL_SOFT_RESET_MASK);
    fir_reg_write(FIR_REG_CONTROL, 0U);
}

static int fir_run_case(const fir_vector_case_t *tc) {
    uint32_t idx;
    uint32_t mismatches = 0;
    uint32_t byte_len = tc->length * sizeof(int16_t);

    for (idx = 0; idx < tc->length; ++idx) {
        g_tx_buffer[idx] = tc->input[idx];
        g_rx_buffer[idx] = 0;
    }

    Xil_DCacheFlushRange((UINTPTR)g_tx_buffer, byte_len);
    Xil_DCacheFlushRange((UINTPTR)g_rx_buffer, byte_len);

    fir_soft_reset();
    fir_reg_write(FIR_REG_SAMPLE_COUNT, tc->length);
    fir_reg_write(FIR_REG_MISMATCH_COUNT, 0U);
    fir_reg_write(FIR_REG_CONTROL, FIR_CTRL_START_MASK);

    if (XAxiDma_SimpleTransfer(&g_axi_dma, (UINTPTR)g_rx_buffer, byte_len, XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) {
        xil_printf("[%s] S2MM start failed\r\n", tc->name);
        return XST_FAILURE;
    }
    if (XAxiDma_SimpleTransfer(&g_axi_dma, (UINTPTR)g_tx_buffer, byte_len, XAXIDMA_DMA_TO_DEVICE) != XST_SUCCESS) {
        xil_printf("[%s] MM2S start failed\r\n", tc->name);
        return XST_FAILURE;
    }

    while (XAxiDma_Busy(&g_axi_dma, XAXIDMA_DMA_TO_DEVICE) || XAxiDma_Busy(&g_axi_dma, XAXIDMA_DEVICE_TO_DMA)) {
    }
    while ((fir_reg_read(FIR_REG_STATUS) & FIR_STATUS_DONE_MASK) == 0U) {
    }

    Xil_DCacheInvalidateRange((UINTPTR)g_rx_buffer, byte_len);

    for (idx = 0; idx < tc->length; ++idx) {
        if (g_rx_buffer[idx] != tc->golden[idx]) {
            ++mismatches;
        }
    }

    fir_reg_write(FIR_REG_MISMATCH_COUNT, mismatches);

    xil_printf("[%s] len=%lu cycles=%lu mismatches=%lu status=0x%08lx\r\n",
               tc->name,
               (unsigned long)tc->length,
               (unsigned long)fir_reg_read(FIR_REG_CYCLE_COUNT),
               (unsigned long)mismatches,
               (unsigned long)fir_reg_read(FIR_REG_STATUS));

    return (mismatches == 0U) ? XST_SUCCESS : XST_FAILURE;
}

int main(void) {
    uint32_t idx;
    int failures = 0;

    xil_printf("ZU4EV FIR bare-metal harness\r\n");
    xil_printf("Console=%s, arch_id=%lu\r\n", FIR_UART_CONSOLE, (unsigned long)fir_reg_read(FIR_REG_ARCH_ID));

    if (fir_dma_init() != XST_SUCCESS) {
        return XST_FAILURE;
    }

    for (idx = 0; idx < g_fir_vector_case_count; ++idx) {
        if (fir_run_case(&g_fir_vector_cases[idx]) != XST_SUCCESS) {
            ++failures;
        }
    }

    xil_printf("Completed %lu cases, failures=%d\r\n", (unsigned long)g_fir_vector_case_count, failures);
    return (failures == 0) ? XST_SUCCESS : XST_FAILURE;
}
