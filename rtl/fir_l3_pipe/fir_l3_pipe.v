`timescale 1ns/1ps

`include "fir_params.vh"
`include "fir_polyphase_params.vh"

module fir_l3_pipe (
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              in_valid,
    input  wire signed [3*`FIR_WIN-1:0]      in_vec,
    output wire                              out_valid,
    output wire signed [3*`FIR_WOUT-1:0]     out_vec
);

localparam integer WPAIR = `FIR_WACC + 1;
localparam integer WMAT  = `FIR_WACC + 2;

`include "fir_polyphase_coeffs.vh"

reg                               stage0_valid;
reg signed [`FIR_WIN-1:0]         lane0_s0;
reg signed [`FIR_WIN-1:0]         lane1_s0;
reg signed [`FIR_WIN-1:0]         lane2_s0;
wire                              stage1_valid;
reg                               stage2_valid;

wire signed [`FIR_L3_E0_TAPS*`FIR_WCOEF-1:0] coeff_l3_e0_bus;
wire signed [`FIR_L3_E1_UNIQ*`FIR_WCOEF-1:0] coeff_l3_e1_bus;
wire signed [`FIR_L3_E2_TAPS*`FIR_WCOEF-1:0] coeff_l3_e2_bus;

wire signed [`FIR_WACC-1:0] a0_acc;
wire signed [`FIR_WACC-1:0] a1_acc;
wire signed [`FIR_WACC-1:0] a2_acc;
wire signed [`FIR_WACC-1:0] b0_acc;
wire signed [`FIR_WACC-1:0] b1_acc;
wire signed [`FIR_WACC-1:0] b2_acc;
wire signed [`FIR_WACC-1:0] c0_acc;
wire signed [`FIR_WACC-1:0] c1_acc;
wire signed [`FIR_WACC-1:0] c2_acc;

wire signed [WPAIR-1:0] y0_delay_pair_s1 = {{1{b2_acc[`FIR_WACC-1]}}, b2_acc} + {{1{c1_acc[`FIR_WACC-1]}}, c1_acc};
wire signed [WPAIR-1:0] y0_delay_pair_d1;
wire signed [`FIR_WACC-1:0] c2_acc_d1;

reg signed [WMAT-1:0] y0_sum_s2;
reg signed [WMAT-1:0] y1_sum_s2;
reg signed [WMAT-1:0] y2_sum_s2;

wire signed [`FIR_WOUT-1:0] out_lane0;
wire signed [`FIR_WOUT-1:0] out_lane1;
wire signed [`FIR_WOUT-1:0] out_lane2;

genvar g;
generate
for (g = 0; g < `FIR_L3_E0_TAPS; g = g + 1) begin : g_l3_e0_coeff
    assign coeff_l3_e0_bus[(g+1)*`FIR_WCOEF-1 -: `FIR_WCOEF] = fir_l3_e0_coeff_at(g);
end
for (g = 0; g < `FIR_L3_E1_UNIQ; g = g + 1) begin : g_l3_e1_coeff
    assign coeff_l3_e1_bus[(g+1)*`FIR_WCOEF-1 -: `FIR_WCOEF] = fir_l3_e1_coeff_at(g);
end
for (g = 0; g < `FIR_L3_E2_TAPS; g = g + 1) begin : g_l3_e2_coeff
    assign coeff_l3_e2_bus[(g+1)*`FIR_WCOEF-1 -: `FIR_WCOEF] = fir_l3_e2_coeff_at(g);
end
endgenerate

always @(posedge clk) begin
    if (rst) begin
        stage0_valid <= 1'b0;
        lane0_s0 <= {`FIR_WIN{1'b0}};
        lane1_s0 <= {`FIR_WIN{1'b0}};
        lane2_s0 <= {`FIR_WIN{1'b0}};
    end else begin
        stage0_valid <= in_valid;
        lane0_s0 <= in_valid ? in_vec[`FIR_WIN-1:0] : {`FIR_WIN{1'b0}};
        lane1_s0 <= in_valid ? in_vec[2*`FIR_WIN-1:`FIR_WIN] : {`FIR_WIN{1'b0}};
        lane2_s0 <= in_valid ? in_vec[3*`FIR_WIN-1:2*`FIR_WIN] : {`FIR_WIN{1'b0}};
    end
end

fir_branch_core_full #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L3_E0_TAPS),
    .USE_DSP(0)
) u_e0_x0 (
    .clk(clk),
    .rst(rst),
    .en(stage0_valid),
    .in_sample(lane0_s0),
    .coeff_bus(coeff_l3_e0_bus),
    .acc_out(a0_acc)
);

fir_branch_core_full #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L3_E0_TAPS),
    .USE_DSP(0)
) u_e0_x1 (
    .clk(clk),
    .rst(rst),
    .en(stage0_valid),
    .in_sample(lane1_s0),
    .coeff_bus(coeff_l3_e0_bus),
    .acc_out(a1_acc)
);

fir_branch_core_full #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L3_E0_TAPS),
    .USE_DSP(0)
) u_e0_x2 (
    .clk(clk),
    .rst(rst),
    .en(stage0_valid),
    .in_sample(lane2_s0),
    .coeff_bus(coeff_l3_e0_bus),
    .acc_out(a2_acc)
);

fir_branch_core_symm #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L3_E1_TAPS),
    .UNIQ(`FIR_L3_E1_UNIQ)
) u_e1_x0 (
    .clk(clk),
    .rst(rst),
    .en(stage0_valid),
    .in_sample(lane0_s0),
    .coeff_bus(coeff_l3_e1_bus),
    .acc_out(b0_acc)
);

fir_branch_core_symm #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L3_E1_TAPS),
    .UNIQ(`FIR_L3_E1_UNIQ)
) u_e1_x1 (
    .clk(clk),
    .rst(rst),
    .en(stage0_valid),
    .in_sample(lane1_s0),
    .coeff_bus(coeff_l3_e1_bus),
    .acc_out(b1_acc)
);

fir_branch_core_symm #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L3_E1_TAPS),
    .UNIQ(`FIR_L3_E1_UNIQ)
) u_e1_x2 (
    .clk(clk),
    .rst(rst),
    .en(stage0_valid),
    .in_sample(lane2_s0),
    .coeff_bus(coeff_l3_e1_bus),
    .acc_out(b2_acc)
);

fir_branch_core_full #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L3_E2_TAPS),
    .USE_DSP(0)
) u_e2_x0 (
    .clk(clk),
    .rst(rst),
    .en(stage0_valid),
    .in_sample(lane0_s0),
    .coeff_bus(coeff_l3_e2_bus),
    .acc_out(c0_acc)
);

fir_branch_core_full #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L3_E2_TAPS),
    .USE_DSP(0)
) u_e2_x1 (
    .clk(clk),
    .rst(rst),
    .en(stage0_valid),
    .in_sample(lane1_s0),
    .coeff_bus(coeff_l3_e2_bus),
    .acc_out(c1_acc)
);

fir_branch_core_full #(
    .WIN(`FIR_WIN),
    .WCOEF(`FIR_WCOEF),
    .WACC(`FIR_WACC),
    .TAPS(`FIR_L3_E2_TAPS),
    .USE_DSP(0)
) u_e2_x2 (
    .clk(clk),
    .rst(rst),
    .en(stage0_valid),
    .in_sample(lane2_s0),
    .coeff_bus(coeff_l3_e2_bus),
    .acc_out(c2_acc)
);

valid_pipe #(
    .LATENCY(1)
) u_stage1_valid (
    .clk(clk),
    .rst(rst),
    .in_valid(stage0_valid),
    .out_valid(stage1_valid)
);

fir_delay_signed #(
    .WIDTH(WPAIR),
    .DEPTH(1)
) u_y0_delay (
    .clk(clk),
    .rst(rst),
    .en(stage1_valid),
    .din(y0_delay_pair_s1),
    .dout(y0_delay_pair_d1)
);

fir_delay_signed #(
    .WIDTH(`FIR_WACC),
    .DEPTH(1)
) u_y1_delay (
    .clk(clk),
    .rst(rst),
    .en(stage1_valid),
    .din(c2_acc),
    .dout(c2_acc_d1)
);

always @(posedge clk) begin
    if (rst) begin
        stage2_valid <= 1'b0;
        y0_sum_s2 <= {WMAT{1'b0}};
        y1_sum_s2 <= {WMAT{1'b0}};
        y2_sum_s2 <= {WMAT{1'b0}};
    end else begin
        stage2_valid <= stage1_valid;
        if (stage1_valid) begin
            y0_sum_s2 <= {{2{a0_acc[`FIR_WACC-1]}}, a0_acc} + {{1{y0_delay_pair_d1[WPAIR-1]}}, y0_delay_pair_d1};
            y1_sum_s2 <= {{2{a1_acc[`FIR_WACC-1]}}, a1_acc}
                       + {{2{b0_acc[`FIR_WACC-1]}}, b0_acc}
                       + {{2{c2_acc_d1[`FIR_WACC-1]}}, c2_acc_d1};
            y2_sum_s2 <= {{2{a2_acc[`FIR_WACC-1]}}, a2_acc}
                       + {{2{b1_acc[`FIR_WACC-1]}}, b1_acc}
                       + {{2{c0_acc[`FIR_WACC-1]}}, c0_acc};
        end
    end
end

round_sat #(
    .IN_WIDTH(WMAT),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_0 (
    .din(y0_sum_s2),
    .dout(out_lane0)
);

round_sat #(
    .IN_WIDTH(WMAT),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_1 (
    .din(y1_sum_s2),
    .dout(out_lane1)
);

round_sat #(
    .IN_WIDTH(WMAT),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_2 (
    .din(y2_sum_s2),
    .dout(out_lane2)
);

assign out_valid = stage2_valid;
assign out_vec = {out_lane2, out_lane1, out_lane0};

endmodule
