`timescale 1ns/1ps

module fir_control_regs #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 32,
    parameter ARCH_ID = 0
) (
    input  wire                       clk,
    input  wire                       rstn,
    input  wire [ADDR_WIDTH-1:0]      s_axi_awaddr,
    input  wire                       s_axi_awvalid,
    output reg                        s_axi_awready,
    input  wire [DATA_WIDTH-1:0]      s_axi_wdata,
    input  wire [(DATA_WIDTH/8)-1:0]  s_axi_wstrb,
    input  wire                       s_axi_wvalid,
    output reg                        s_axi_wready,
    output reg  [1:0]                 s_axi_bresp,
    output reg                        s_axi_bvalid,
    input  wire                       s_axi_bready,
    input  wire [ADDR_WIDTH-1:0]      s_axi_araddr,
    input  wire                       s_axi_arvalid,
    output reg                        s_axi_arready,
    output reg  [DATA_WIDTH-1:0]      s_axi_rdata,
    output reg  [1:0]                 s_axi_rresp,
    output reg                        s_axi_rvalid,
    input  wire                       s_axi_rready,
    output reg                        start_pulse,
    output reg                        soft_reset,
    output reg  [31:0]                sample_count,
    output reg  [31:0]                mismatch_count,
    input  wire                       done,
    input  wire                       busy,
    input  wire                       error,
    input  wire [31:0]                cycle_count,
    input  wire [31:0]                dbg_samples_seen,
    input  wire [31:0]                dbg_samples_emitted,
    input  wire [31:0]                dbg_input_valid_cycles,
    input  wire [31:0]                dbg_input_ready_cycles
);

localparam ADDR_LSB = 2;
localparam REG_CONTROL  = 0;
localparam REG_ARCH_ID  = 1;
localparam REG_SAMPLES  = 2;
localparam REG_STATUS   = 3;
localparam REG_CYCLES   = 4;
localparam REG_MISMATCH = 5;
localparam REG_DBG_SEEN = 6;
localparam REG_DBG_EMIT = 7;
localparam REG_DBG_SVALID = 8;
localparam REG_DBG_SREADY = 9;

reg [ADDR_WIDTH-1:0]     awaddr_latched;
reg [DATA_WIDTH-1:0]     wdata_latched;
reg [(DATA_WIDTH/8)-1:0] wstrb_latched;
reg                      aw_pending;
reg                      w_pending;

wire [ADDR_WIDTH-1:0]     write_addr_now = aw_pending ? awaddr_latched : s_axi_awaddr;
wire [DATA_WIDTH-1:0]     write_data_now = w_pending ? wdata_latched : s_axi_wdata;
wire [(DATA_WIDTH/8)-1:0] write_strb_now = w_pending ? wstrb_latched : s_axi_wstrb;
wire                      write_fire =
    !s_axi_bvalid &&
    (aw_pending || s_axi_awvalid) &&
    (w_pending || s_axi_wvalid);

integer i;

always @(posedge clk) begin
    if (!rstn) begin
        s_axi_awready <= 1'b0;
        s_axi_wready <= 1'b0;
        s_axi_bresp <= 2'b00;
        s_axi_bvalid <= 1'b0;
        awaddr_latched <= {ADDR_WIDTH{1'b0}};
        wdata_latched <= {DATA_WIDTH{1'b0}};
        wstrb_latched <= {(DATA_WIDTH/8){1'b0}};
        aw_pending <= 1'b0;
        w_pending <= 1'b0;
        start_pulse <= 1'b0;
        soft_reset <= 1'b0;
        sample_count <= 32'd0;
        mismatch_count <= 32'd0;
    end else begin
        start_pulse <= 1'b0;
        s_axi_awready <= (!aw_pending && !s_axi_bvalid);
        s_axi_wready <= (!w_pending && !s_axi_bvalid);

        if (!aw_pending && !s_axi_bvalid && s_axi_awvalid) begin
            awaddr_latched <= s_axi_awaddr;
            aw_pending <= 1'b1;
        end

        if (!w_pending && !s_axi_bvalid && s_axi_wvalid) begin
            wdata_latched <= s_axi_wdata;
            wstrb_latched <= s_axi_wstrb;
            w_pending <= 1'b1;
        end

        if (write_fire) begin
            case (write_addr_now[ADDR_WIDTH-1:ADDR_LSB])
                REG_CONTROL: begin
                    if (write_strb_now[0]) begin
                        start_pulse <= write_data_now[0];
                        soft_reset <= write_data_now[1];
                    end
                end
                REG_SAMPLES: begin
                    for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
                        if (write_strb_now[i]) begin
                            sample_count[i*8 +: 8] <= write_data_now[i*8 +: 8];
                        end
                    end
                end
                REG_MISMATCH: begin
                    for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
                        if (write_strb_now[i]) begin
                            mismatch_count[i*8 +: 8] <= write_data_now[i*8 +: 8];
                        end
                    end
                end
                default: begin
                end
            endcase

            aw_pending <= 1'b0;
            w_pending <= 1'b0;
            s_axi_bvalid <= 1'b1;
            s_axi_bresp <= 2'b00;
        end else if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
        end
    end
end

always @(posedge clk) begin
    if (!rstn) begin
        s_axi_arready <= 1'b0;
        s_axi_rdata <= {DATA_WIDTH{1'b0}};
        s_axi_rresp <= 2'b00;
        s_axi_rvalid <= 1'b0;
    end else begin
        s_axi_arready <= !s_axi_rvalid;

        if (!s_axi_rvalid && s_axi_arvalid) begin
            s_axi_rvalid <= 1'b1;
            s_axi_rresp <= 2'b00;
            case (s_axi_araddr[ADDR_WIDTH-1:ADDR_LSB])
                REG_CONTROL: begin
                    s_axi_rdata <= {{(DATA_WIDTH-2){1'b0}}, soft_reset, 1'b0};
                end
                REG_ARCH_ID: begin
                    s_axi_rdata <= ARCH_ID;
                end
                REG_SAMPLES: begin
                    s_axi_rdata <= sample_count;
                end
                REG_STATUS: begin
                    s_axi_rdata <= {{(DATA_WIDTH-3){1'b0}}, error, busy, done};
                end
                REG_CYCLES: begin
                    s_axi_rdata <= cycle_count;
                end
                REG_MISMATCH: begin
                    s_axi_rdata <= mismatch_count;
                end
                REG_DBG_SEEN: begin
                    s_axi_rdata <= dbg_samples_seen;
                end
                REG_DBG_EMIT: begin
                    s_axi_rdata <= dbg_samples_emitted;
                end
                REG_DBG_SVALID: begin
                    s_axi_rdata <= dbg_input_valid_cycles;
                end
                REG_DBG_SREADY: begin
                    s_axi_rdata <= dbg_input_ready_cycles;
                end
                default: begin
                    s_axi_rdata <= {DATA_WIDTH{1'b0}};
                end
            endcase
        end else if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end
end

endmodule
