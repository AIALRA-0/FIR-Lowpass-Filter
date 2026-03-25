`timescale 1ns/1ps

`include "fir_params.vh"

module fir_symm_base (
    input  wire                        clk,
    input  wire                        rst,
    input  wire                        in_valid,
    input  wire signed [`FIR_WIN-1:0]  in_sample,
    output wire                        out_valid,
    output wire signed [`FIR_WOUT-1:0] out_sample
);

localparam WPRE  = `FIR_WIN + 1;
localparam WPROD = `FIR_WIN + `FIR_WCOEF + 1;

`include "fir_coeffs.vh"

wire [`FIR_WIN*(`FIR_TAPS-1)-1:0] tap_bus;
wire signed [WPRE-1:0]            pre_sum [0:`FIR_UNIQ-1];
wire signed [WPROD-1:0]           prod    [0:`FIR_UNIQ-1];
reg  signed [`FIR_WACC-1:0]       acc_comb;
reg  signed [`FIR_WACC-1:0]       acc_reg;

delay_line #(
    .WIDTH(`FIR_WIN),
    .DEPTH(`FIR_TAPS-1)
) u_delay_line (
    .clk(clk),
    .rst(rst),
    .en(in_valid),
    .din(in_sample),
    .taps_flat(tap_bus)
);

function signed [`FIR_WIN-1:0] sample_at;
    input integer pos;
    begin
        if (pos == 0) begin
            sample_at = in_sample;
        end else begin
            sample_at = tap_bus[pos*`FIR_WIN-1 -: `FIR_WIN];
        end
    end
endfunction

genvar g;
generate
for (g = 0; g < `FIR_UNIQ; g = g + 1) begin : g_folded_taps
    localparam integer LEFT  = g;
    localparam integer RIGHT = `FIR_TAPS - 1 - g;
    wire signed [`FIR_WIN-1:0] s_left;
    wire signed [`FIR_WIN-1:0] s_right;

    assign s_left  = sample_at(LEFT);
    assign s_right = (LEFT == RIGHT) ? {`FIR_WIN{1'b0}} : sample_at(RIGHT);

    preadd_mult #(
        .WIN(`FIR_WIN),
        .WCOEF(`FIR_WCOEF)
    ) u_preadd_mult (
        .sample_a(s_left),
        .sample_b(s_right),
        .coeff(fir_coeff_at(g)),
        .pre_sum(pre_sum[g]),
        .product(prod[g])
    );
end
endgenerate

integer i;
always @* begin
    acc_comb = {`FIR_WACC{1'b0}};
    for (i = 0; i < `FIR_UNIQ; i = i + 1) begin
        acc_comb = acc_comb + {{(`FIR_WACC-WPROD){prod[i][WPROD-1]}}, prod[i]};
    end
end

always @(posedge clk) begin
    if (rst) begin
        acc_reg <= {`FIR_WACC{1'b0}};
    end else if (in_valid) begin
        acc_reg <= acc_comb;
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
) u_round_sat (
    .din(acc_reg),
    .dout(out_sample)
);

endmodule
