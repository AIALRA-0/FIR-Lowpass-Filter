`timescale 1ns/1ps

`include "fir_params.vh"

module fir_l3_pipe (
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          in_valid,
    input  wire signed [3*`FIR_WIN-1:0]  in_vec,
    output wire                          out_valid,
    output wire signed [3*`FIR_WOUT-1:0] out_vec
);

localparam integer WCORE = `FIR_WACC + 4;

reg                         in_valid_s0;
reg signed [`FIR_WIN-1:0]   lane0_s0;
reg signed [`FIR_WIN-1:0]   lane1_s0;
reg signed [`FIR_WIN-1:0]   lane2_s0;

wire                        core_valid;
wire signed [WCORE-1:0]     y0_core;
wire signed [WCORE-1:0]     y1_core;
wire signed [WCORE-1:0]     y2_core;

reg                         out_valid_s2;
reg signed [WCORE-1:0]      y0_s2;
reg signed [WCORE-1:0]      y1_s2;
reg signed [WCORE-1:0]      y2_s2;

wire signed [`FIR_WOUT-1:0] out_lane0;
wire signed [`FIR_WOUT-1:0] out_lane1;
wire signed [`FIR_WOUT-1:0] out_lane2;

always @(posedge clk) begin
    if (rst) begin
        in_valid_s0 <= 1'b0;
        lane0_s0 <= {`FIR_WIN{1'b0}};
        lane1_s0 <= {`FIR_WIN{1'b0}};
        lane2_s0 <= {`FIR_WIN{1'b0}};
        out_valid_s2 <= 1'b0;
        y0_s2 <= {WCORE{1'b0}};
        y1_s2 <= {WCORE{1'b0}};
        y2_s2 <= {WCORE{1'b0}};
    end else begin
        in_valid_s0 <= in_valid;
        lane0_s0 <= in_valid ? in_vec[`FIR_WIN-1:0] : {`FIR_WIN{1'b0}};
        lane1_s0 <= in_valid ? in_vec[2*`FIR_WIN-1:`FIR_WIN] : {`FIR_WIN{1'b0}};
        lane2_s0 <= in_valid ? in_vec[3*`FIR_WIN-1:2*`FIR_WIN] : {`FIR_WIN{1'b0}};

        out_valid_s2 <= core_valid;
        if (core_valid) begin
            y0_s2 <= y0_core;
            y1_s2 <= y1_core;
            y2_s2 <= y2_core;
        end else begin
            y0_s2 <= {WCORE{1'b0}};
            y1_s2 <= {WCORE{1'b0}};
            y2_s2 <= {WCORE{1'b0}};
        end
    end
end

fir_l3_ffa_core u_l3_ffa_core (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid_s0),
    .lane0_in(lane0_s0),
    .lane1_in(lane1_s0),
    .lane2_in(lane2_s0),
    .out_valid(core_valid),
    .y0_sum(y0_core),
    .y1_sum(y1_core),
    .y2_sum(y2_core)
);

round_sat #(
    .IN_WIDTH(WCORE),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_0 (
    .din(y0_s2),
    .dout(out_lane0)
);

round_sat #(
    .IN_WIDTH(WCORE),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_1 (
    .din(y1_s2),
    .dout(out_lane1)
);

round_sat #(
    .IN_WIDTH(WCORE),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round_sat_2 (
    .din(y2_s2),
    .dout(out_lane2)
);

assign out_valid = out_valid_s2;
assign out_vec = {out_lane2, out_lane1, out_lane0};

endmodule
