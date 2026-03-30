`timescale 1ns/1ps

module fir_control_regs #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 32,
    parameter ARCH_ID = 0
) (
    input  wire                     clk,
    input  wire                     rstn,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire                     s_axi_awvalid,
    output reg                      s_axi_awready,
    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                     s_axi_wvalid,
    output reg                      s_axi_wready,
    output reg  [1:0]               s_axi_bresp,
    output reg                      s_axi_bvalid,
    input  wire                     s_axi_bready,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire                     s_axi_arvalid,
    output reg                      s_axi_arready,
    output reg  [DATA_WIDTH-1:0]    s_axi_rdata,
    output reg  [1:0]               s_axi_rresp,
    output reg                      s_axi_rvalid,
    input  wire                     s_axi_rready,
    output reg                      start_pulse,
    output reg                      soft_reset,
    output reg  [31:0]              sample_count,
    output reg  [31:0]              mismatch_count,
    input  wire                     done,
    input  wire                     busy,
    input  wire                     error,
    input  wire [31:0]              cycle_count
);

localparam ADDR_LSB = 2;
localparam REG_CONTROL  = 0;
localparam REG_ARCH_ID  = 1;
localparam REG_SAMPLES  = 2;
localparam REG_STATUS   = 3;
localparam REG_CYCLES   = 4;
localparam REG_MISMATCH = 5;

reg [ADDR_WIDTH-1:0] awaddr_latched;
reg [ADDR_WIDTH-1:0] araddr_latched;
wire [ADDR_WIDTH-ADDR_LSB-1:0] aw_word = awaddr_latched[ADDR_WIDTH-1:ADDR_LSB];
wire [ADDR_WIDTH-ADDR_LSB-1:0] ar_word = araddr_latched[ADDR_WIDTH-1:ADDR_LSB];

integer i;

always @(posedge clk) begin
    if (!rstn) begin
        s_axi_awready <= 1'b0;
        s_axi_wready <= 1'b0;
        s_axi_bresp <= 2'b00;
        s_axi_bvalid <= 1'b0;
        s_axi_arready <= 1'b0;
        s_axi_rdata <= {DATA_WIDTH{1'b0}};
        s_axi_rresp <= 2'b00;
        s_axi_rvalid <= 1'b0;
        awaddr_latched <= {ADDR_WIDTH{1'b0}};
        araddr_latched <= {ADDR_WIDTH{1'b0}};
        start_pulse <= 1'b0;
        soft_reset <= 1'b0;
        sample_count <= 32'd0;
        mismatch_count <= 32'd0;
    end else begin
        start_pulse <= 1'b0;

        s_axi_awready <= (!s_axi_awready && s_axi_awvalid && s_axi_wvalid);
        s_axi_wready <= (!s_axi_wready && s_axi_wvalid && s_axi_awvalid);

        if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
            awaddr_latched <= s_axi_awaddr;
        end

        if (s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid && !s_axi_bvalid) begin
            case (s_axi_awaddr[ADDR_WIDTH-1:ADDR_LSB])
                REG_CONTROL: begin
                    if (s_axi_wstrb[0]) begin
                        start_pulse <= s_axi_wdata[0];
                        soft_reset <= s_axi_wdata[1];
                    end
                end
                REG_SAMPLES: begin
                    for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
                        if (s_axi_wstrb[i]) begin
                            sample_count[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                        end
                    end
                end
                REG_MISMATCH: begin
                    for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
                        if (s_axi_wstrb[i]) begin
                            mismatch_count[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                        end
                    end
                end
                default: begin
                end
            endcase
            s_axi_bvalid <= 1'b1;
            s_axi_bresp <= 2'b00;
        end else if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
        end

        s_axi_arready <= (!s_axi_arready && s_axi_arvalid && !s_axi_rvalid);
        if (!s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
            araddr_latched <= s_axi_araddr;
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
