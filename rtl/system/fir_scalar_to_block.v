`timescale 1ns/1ps

module fir_scalar_to_block #(
    parameter WIDTH = 16,
    parameter LANES = 3,
    parameter COUNT_WIDTH = 32
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         clear,
    input  wire                         run_enable,
    input  wire [COUNT_WIDTH-1:0]       sample_count,
    input  wire                         s_tvalid,
    output wire                         s_tready,
    input  wire signed [WIDTH-1:0]      s_tdata,
    output reg                          block_valid,
    output reg  signed [LANES*WIDTH-1:0] block_data,
    output reg                          protocol_error,
    output reg  [COUNT_WIDTH-1:0]       samples_seen
);

reg signed [LANES*WIDTH-1:0] block_accum;
reg [31:0]                   lane_index;

assign s_tready = run_enable && (samples_seen < sample_count);

integer i;
reg signed [LANES*WIDTH-1:0] next_block;
reg [COUNT_WIDTH-1:0]        next_seen;
reg                          emit_now;

always @* begin
    next_block = block_accum;
    for (i = 0; i < LANES; i = i + 1) begin
        if (i > lane_index) begin
            next_block[(i+1)*WIDTH-1 -: WIDTH] = {WIDTH{1'b0}};
        end
    end
    next_block[(lane_index+1)*WIDTH-1 -: WIDTH] = s_tdata;
    next_seen = samples_seen + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
    emit_now = (lane_index == LANES-1) || (next_seen == sample_count);
end

always @(posedge clk) begin
    if (rst || clear) begin
        block_valid <= 1'b0;
        block_data <= {LANES*WIDTH{1'b0}};
        protocol_error <= 1'b0;
        block_accum <= {LANES*WIDTH{1'b0}};
        lane_index <= 0;
        samples_seen <= {COUNT_WIDTH{1'b0}};
    end else begin
        block_valid <= 1'b0;
        if (s_tvalid && s_tready) begin
            if (emit_now) begin
                block_valid <= 1'b1;
                block_data <= next_block;
                block_accum <= {LANES*WIDTH{1'b0}};
                lane_index <= 0;
            end else begin
                block_accum[(lane_index+1)*WIDTH-1 -: WIDTH] <= s_tdata;
                lane_index <= lane_index + 1;
            end
            samples_seen <= next_seen;
        end else if (s_tvalid && !s_tready) begin
            protocol_error <= 1'b1;
        end
    end
end

endmodule
