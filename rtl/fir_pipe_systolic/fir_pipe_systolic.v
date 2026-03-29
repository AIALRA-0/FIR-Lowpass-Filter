`timescale 1ns/1ps

`include "fir_params.vh"

module fir_pipe_systolic (
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

wire signed [`FIR_WIN-1:0]        in_sample_eff;
wire [`FIR_WIN*(`FIR_TAPS-1)-1:0] tap_bus;
wire [`FIR_WIN*`FIR_TAPS-1:0]     hist_bus;
wire signed [WPRE-1:0]            pre_sum      [0:`FIR_UNIQ-1];
wire signed [WPROD-1:0]           prod_raw     [0:`FIR_UNIQ-1];
wire signed [WPROD-1:0]           prod_delayed [0:`FIR_UNIQ-1];
reg  signed [`FIR_WACC-1:0]       acc_pipe     [0:`FIR_UNIQ-1];

assign in_sample_eff = in_valid ? in_sample : {`FIR_WIN{1'b0}};

delay_line #(
    .WIDTH(`FIR_WIN),
    .DEPTH(`FIR_TAPS-1)
) u_delay_line (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .din(in_sample_eff),
    .taps_flat(tap_bus)
);

assign hist_bus[`FIR_WIN-1:0] = in_sample_eff;
assign hist_bus[`FIR_WIN*`FIR_TAPS-1:`FIR_WIN] = tap_bus;

genvar g;
generate
for (g = 0; g < `FIR_UNIQ; g = g + 1) begin : g_systolic_taps
    localparam integer LEFT  = g;
    localparam integer RIGHT = `FIR_TAPS - 1 - g;
    wire signed [`FIR_WIN-1:0] s_left;
    wire signed [`FIR_WIN-1:0] s_right;

    assign s_left  = hist_bus[(LEFT+1)*`FIR_WIN-1 -: `FIR_WIN];
    assign s_right = (LEFT == RIGHT) ? {`FIR_WIN{1'b0}} : hist_bus[(RIGHT+1)*`FIR_WIN-1 -: `FIR_WIN];

    preadd_mult #(
        .WIN(`FIR_WIN),
        .WCOEF(`FIR_WCOEF)
    ) u_preadd_mult (
        .sample_a(s_left),
        .sample_b(s_right),
        .coeff(fir_coeff_at(g)),
        .pre_sum(pre_sum[g]),
        .product(prod_raw[g])
    );

    fir_delay_signed #(
        .WIDTH(WPROD),
        .DEPTH(g)
    ) u_prod_delay (
        .clk(clk),
        .rst(rst),
        .en(1'b1),
        .din(prod_raw[g]),
        .dout(prod_delayed[g])
    );
end
endgenerate

integer i;
always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < `FIR_UNIQ; i = i + 1) begin
            acc_pipe[i] <= {`FIR_WACC{1'b0}};
        end
    end else begin
        acc_pipe[0] <= {{(`FIR_WACC-WPROD){prod_delayed[0][WPROD-1]}}, prod_delayed[0]};
        for (i = 1; i < `FIR_UNIQ; i = i + 1) begin
            acc_pipe[i] <= acc_pipe[i-1] + {{(`FIR_WACC-WPROD){prod_delayed[i][WPROD-1]}}, prod_delayed[i]};
        end
    end
end

valid_pipe #(
    .LATENCY(`FIR_UNIQ)
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
    .din(acc_pipe[`FIR_UNIQ-1]),
    .dout(out_sample)
);

endmodule
