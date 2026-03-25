`timescale 1ns/1ps

`include "fir_params.vh"

module fir_l2_polyphase (
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              in_valid,
    input  wire signed [2*`FIR_WIN-1:0]      in_vec,
    output wire                              out_valid,
    output wire signed [2*`FIR_WOUT-1:0]     out_vec
);

localparam HIST_WIDTH = `FIR_WIN * (`FIR_TAPS - 1);
reg [HIST_WIDTH-1:0] hist_bus;

`include "fir_coeffs.vh"

wire signed [`FIR_WIN-1:0] lane0_in = in_vec[`FIR_WIN-1:0];
wire signed [`FIR_WIN-1:0] lane1_in = in_vec[2*`FIR_WIN-1:`FIR_WIN];

reg [HIST_WIDTH-1:0] state_1;
reg [HIST_WIDTH-1:0] state_2;
reg signed [`FIR_WACC-1:0] acc_lane0;
reg signed [`FIR_WACC-1:0] acc_lane1;
wire signed [`FIR_WOUT-1:0] out_lane0;
wire signed [`FIR_WOUT-1:0] out_lane1;

function signed [`FIR_WIN-1:0] sample_from_state;
    input signed [`FIR_WIN-1:0] head_sample;
    input [HIST_WIDTH-1:0] state;
    input integer pos;
    begin
        if (pos == 0) begin
            sample_from_state = head_sample;
        end else begin
            sample_from_state = state[pos*`FIR_WIN-1 -: `FIR_WIN];
        end
    end
endfunction

function [HIST_WIDTH-1:0] push_state;
    input signed [`FIR_WIN-1:0] head_sample;
    input [HIST_WIDTH-1:0] state;
    integer idx;
    begin
        push_state[`FIR_WIN-1:0] = head_sample;
        for (idx = 1; idx < `FIR_TAPS - 1; idx = idx + 1) begin
            push_state[(idx+1)*`FIR_WIN-1 -: `FIR_WIN] = state[idx*`FIR_WIN-1 -: `FIR_WIN];
        end
    end
endfunction

function signed [`FIR_WACC-1:0] fir_eval;
    input signed [`FIR_WIN-1:0] head_sample;
    input [HIST_WIDTH-1:0] state;
    integer idx;
    integer left;
    integer right;
    reg signed [`FIR_WIN-1:0] s_left;
    reg signed [`FIR_WIN-1:0] s_right;
    reg signed [`FIR_WIN:0] pre_sum;
    reg signed [`FIR_WACC-1:0] acc;
    begin
        acc = {`FIR_WACC{1'b0}};
        for (idx = 0; idx < `FIR_UNIQ; idx = idx + 1) begin
            left = idx;
            right = `FIR_TAPS - 1 - idx;
            s_left = sample_from_state(head_sample, state, left);
            s_right = (left == right) ? {`FIR_WIN{1'b0}} : sample_from_state(head_sample, state, right);
            pre_sum = $signed(s_left) + $signed(s_right);
            acc = acc + ($signed(pre_sum) * $signed(fir_coeff_at(idx)));
        end
        fir_eval = acc;
    end
endfunction

always @* begin
    acc_lane0 = fir_eval(lane0_in, hist_bus);
    state_1 = push_state(lane0_in, hist_bus);
    acc_lane1 = fir_eval(lane1_in, state_1);
    state_2 = push_state(lane1_in, state_1);
end

always @(posedge clk) begin
    if (rst) begin
        hist_bus <= {HIST_WIDTH{1'b0}};
    end else if (in_valid) begin
        hist_bus <= state_2;
    end
end

valid_pipe #(
    .LATENCY(1)
) u_valid_pipe (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .out_valid(out_valid)
);

round_sat #(
    .IN_WIDTH(`FIR_WACC),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_0 (
    .din(acc_lane0),
    .dout(out_lane0)
);

round_sat #(
    .IN_WIDTH(`FIR_WACC),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_1 (
    .din(acc_lane1),
    .dout(out_lane1)
);

assign out_vec = {out_lane1, out_lane0};

endmodule
