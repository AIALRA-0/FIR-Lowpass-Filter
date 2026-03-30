#include <stdint.h>
#include <string.h>

#include "xaxidma.h"
#include "xaxidma_hw.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_mmu.h"
#include "xil_printf.h"
#include "xtime_l.h"

#include "fir_zu4ev_hw.h"
#include "generated/fir_vectors.h"

static XAxiDma g_axi_dma;
static int16_t g_tx_buffer[FIR_MAX_VECTOR_LENGTH] __attribute__((aligned(64)));
static int16_t g_rx_buffer[FIR_MAX_VECTOR_LENGTH] __attribute__((aligned(64)));

#define FIR_DMA_TIMEOUT_TICKS  (COUNTS_PER_SECOND * 10ULL)
#define FIR_CORE_TIMEOUT_TICKS (COUNTS_PER_SECOND * 10ULL)

static inline void fir_reg_write(uint32_t offset, uint32_t value) {
    Xil_Out32(FIR_CTRL_BASEADDR + offset, value);
}

static inline uint32_t fir_reg_read(uint32_t offset) {
    return Xil_In32(FIR_CTRL_BASEADDR + offset);
}

static void fir_platform_init(void) {
    /*
     * The standalone BSP does not automatically mark our PL AXI-Lite window as
     * device memory. Without this mapping, the first control register access can
     * fault before the harness prints any per-case output.
     */
    Xil_SetTlbAttributes((UINTPTR)FIR_CTRL_BASEADDR, DEVICE_MEMORY);

    /*
     * The test harness runs from OCM, but AXI DMA reaches PS memory through the
     * FPD/HPC path. Disabling D-cache keeps the DDR-backed DMA buffers
     * coherent without requiring cache maintenance during JTAG-driven closure.
     */
    Xil_DCacheDisable();
    xil_printf("DMA buffers tx=0x%016llx rx=0x%016llx\r\n",
               (unsigned long long)(UINTPTR)g_tx_buffer,
               (unsigned long long)(UINTPTR)g_rx_buffer);
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

static void fir_dump_dma_state(const char *case_name, const char *phase) {
    uint32_t mm2s_sr = XAxiDma_ReadReg(g_axi_dma.RegBase, XAXIDMA_TX_OFFSET + XAXIDMA_SR_OFFSET);
    uint32_t s2mm_sr = XAxiDma_ReadReg(g_axi_dma.RegBase, XAXIDMA_RX_OFFSET + XAXIDMA_SR_OFFSET);
    uint32_t mm2s_cr = XAxiDma_ReadReg(g_axi_dma.RegBase, XAXIDMA_TX_OFFSET + XAXIDMA_CR_OFFSET);
    uint32_t s2mm_cr = XAxiDma_ReadReg(g_axi_dma.RegBase, XAXIDMA_RX_OFFSET + XAXIDMA_CR_OFFSET);

    xil_printf("[%s] dma_state@%s mm2s_cr=0x%08lx mm2s_sr=0x%08lx s2mm_cr=0x%08lx s2mm_sr=0x%08lx\r\n",
               case_name,
               phase,
               (unsigned long)mm2s_cr,
               (unsigned long)mm2s_sr,
               (unsigned long)s2mm_cr,
               (unsigned long)s2mm_sr);
}

static void fir_dump_shell_state(const char *case_name, const char *phase) {
    uint32_t status = fir_reg_read(FIR_REG_STATUS);
    uint32_t cycles = fir_reg_read(FIR_REG_CYCLE_COUNT);
    uint32_t seen = fir_reg_read(FIR_REG_DEBUG_SEEN);
    uint32_t emitted = fir_reg_read(FIR_REG_DEBUG_EMITTED);
    uint32_t input_valid_cycles = fir_reg_read(FIR_REG_DEBUG_SVALID);
    uint32_t input_ready_cycles = fir_reg_read(FIR_REG_DEBUG_SREADY);

    xil_printf("[%s] shell_state@%s status=0x%08lx cycles=%lu seen=%lu emitted=%lu svalid=%lu sready=%lu\r\n",
               case_name,
               phase,
               (unsigned long)status,
               (unsigned long)cycles,
               (unsigned long)seen,
               (unsigned long)emitted,
               (unsigned long)input_valid_cycles,
               (unsigned long)input_ready_cycles);
}

static void fir_dma_recover(const char *case_name) {
    XAxiDma_Reset(&g_axi_dma);
    while (!XAxiDma_ResetIsDone(&g_axi_dma)) {
    }
    fir_dump_dma_state(case_name, "after_reset");
}

static int fir_wait_dma_idle(const char *case_name) {
    XTime start = 0;
    XTime now = 0;

    XTime_GetTime(&start);
    while (XAxiDma_Busy(&g_axi_dma, XAXIDMA_DMA_TO_DEVICE) ||
           XAxiDma_Busy(&g_axi_dma, XAXIDMA_DEVICE_TO_DMA)) {
        XTime_GetTime(&now);
        if ((now - start) > FIR_DMA_TIMEOUT_TICKS) {
            xil_printf("[%s] DMA timeout\r\n", case_name);
            fir_dump_dma_state(case_name, "timeout");
            fir_dump_shell_state(case_name, "timeout");
            fir_dma_recover(case_name);
            return XST_FAILURE;
        }
    }

    return XST_SUCCESS;
}

static int fir_wait_core_done(const char *case_name) {
    XTime start = 0;
    XTime now = 0;
    uint32_t status;

    XTime_GetTime(&start);
    while (1) {
        status = fir_reg_read(FIR_REG_STATUS);
        if ((status & FIR_STATUS_DONE_MASK) != 0U) {
            if ((status & FIR_STATUS_ERROR_MASK) != 0U) {
                xil_printf("[%s] core reported error status=0x%08lx\r\n",
                           case_name,
                           (unsigned long)status);
                fir_dump_shell_state(case_name, "core_error");
                return XST_FAILURE;
            }
            return XST_SUCCESS;
        }

        XTime_GetTime(&now);
        if ((now - start) > FIR_CORE_TIMEOUT_TICKS) {
            xil_printf("[%s] core done timeout status=0x%08lx\r\n",
                       case_name,
                       (unsigned long)status);
            fir_dump_shell_state(case_name, "core_timeout");
            return XST_FAILURE;
        }
    }
}

static void fir_soft_reset(void) {
    fir_reg_write(FIR_REG_CONTROL, FIR_CTRL_SOFT_RESET_MASK);
    fir_reg_write(FIR_REG_CONTROL, 0U);
}

static int fir_run_case(const fir_vector_case_t *tc) {
    uint32_t idx;
    uint32_t mismatches = 0;
    uint32_t byte_len = tc->length * sizeof(int16_t);

    xil_printf("stage=%s:case_begin len=%lu\r\n",
               tc->name,
               (unsigned long)tc->length);

    for (idx = 0; idx < tc->length; ++idx) {
        g_tx_buffer[idx] = tc->input[idx];
        g_rx_buffer[idx] = 0;
    }
    xil_printf("stage=%s:buffers_loaded\r\n", tc->name);

    xil_printf("stage=%s:buffers_ready\r\n", tc->name);

    fir_soft_reset();
    fir_reg_write(FIR_REG_SAMPLE_COUNT, tc->length);
    fir_reg_write(FIR_REG_MISMATCH_COUNT, 0U);
    fir_reg_write(FIR_REG_CONTROL, FIR_CTRL_START_MASK);
    xil_printf("stage=%s:ctrl_written\r\n", tc->name);

    if (XAxiDma_SimpleTransfer(&g_axi_dma, (UINTPTR)g_rx_buffer, byte_len, XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) {
        xil_printf("[%s] S2MM start failed\r\n", tc->name);
        fir_dump_dma_state(tc->name, "s2mm_start_failed");
        fir_dump_shell_state(tc->name, "s2mm_start_failed");
        fir_dma_recover(tc->name);
        return XST_FAILURE;
    }
    xil_printf("stage=%s:s2mm_started\r\n", tc->name);
    if (XAxiDma_SimpleTransfer(&g_axi_dma, (UINTPTR)g_tx_buffer, byte_len, XAXIDMA_DMA_TO_DEVICE) != XST_SUCCESS) {
        xil_printf("[%s] MM2S start failed\r\n", tc->name);
        fir_dump_dma_state(tc->name, "mm2s_start_failed");
        fir_dump_shell_state(tc->name, "mm2s_start_failed");
        fir_dma_recover(tc->name);
        return XST_FAILURE;
    }
    xil_printf("stage=%s:mm2s_started\r\n", tc->name);

    if (fir_wait_dma_idle(tc->name) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    xil_printf("stage=%s:dma_idle\r\n", tc->name);
    if (fir_wait_core_done(tc->name) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    xil_printf("stage=%s:core_done\r\n", tc->name);

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
    uint32_t arch_id;

    xil_printf("ZU4EV FIR bare-metal harness\r\n");
    xil_printf("stage=platform_init_begin\r\n");
    fir_platform_init();
    xil_printf("stage=platform_init_done\r\n");
    xil_printf("stage=dma_init_begin\r\n");

    if (fir_dma_init() != XST_SUCCESS) {
        return XST_FAILURE;
    }

    xil_printf("stage=dma_init_done\r\n");
    arch_id = fir_reg_read(FIR_REG_ARCH_ID);
    xil_printf("Console=%s, arch_id=%lu\r\n", FIR_UART_CONSOLE, (unsigned long)arch_id);

    for (idx = 0; idx < g_fir_vector_case_count; ++idx) {
        if (fir_run_case(&g_fir_vector_cases[idx]) != XST_SUCCESS) {
            ++failures;
        }
    }

    xil_printf("Completed %lu cases, failures=%d\r\n", (unsigned long)g_fir_vector_case_count, failures);
    return (failures == 0) ? XST_SUCCESS : XST_FAILURE;
}
