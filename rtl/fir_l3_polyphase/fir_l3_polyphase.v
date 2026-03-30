`timescale 1ns/1ps

`include "fir_params.vh"

module fir_l3_polyphase (
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          in_valid,
    input  wire signed [3*`FIR_WIN-1:0]  in_vec,
    output wire                          out_valid,
    output wire signed [3*`FIR_WOUT-1:0] out_vec
);

localparam integer WCORE = `FIR_WACC + 4;

wire signed [`FIR_WIN-1:0] lane0_in = in_vec[`FIR_WIN-1:0];
wire signed [`FIR_WIN-1:0] lane1_in = in_vec[2*`FIR_WIN-1:`FIR_WIN];
wire signed [`FIR_WIN-1:0] lane2_in = in_vec[3*`FIR_WIN-1:2*`FIR_WIN];

wire signed [WCORE-1:0] y0_sum;
wire signed [WCORE-1:0] y1_sum;
wire signed [WCORE-1:0] y2_sum;
wire signed [`FIR_WOUT-1:0] out_lane0;
wire signed [`FIR_WOUT-1:0] out_lane1;
wire signed [`FIR_WOUT-1:0] out_lane2;

fir_l3_ffa_core u_l3_ffa_core (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .lane0_in(lane0_in),
    .lane1_in(lane1_in),
    .lane2_in(lane2_in),
    .out_valid(out_valid),
    .y0_sum(y0_sum),
    .y1_sum(y1_sum),
    .y2_sum(y2_sum)
);

round_sat #(
    .IN_WIDTH(WCORE),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_0 (
    .din(y0_sum),
    .dout(out_lane0)
);

round_sat #(
    .IN_WIDTH(WCORE),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_1 (
    .din(y1_sum),
    .dout(out_lane1)
);

round_sat #(
    .IN_WIDTH(WCORE),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_2 (
    .din(y2_sum),
    .dout(out_lane2)
);

assign out_vec = {out_lane2, out_lane1, out_lane0};

endmodule
