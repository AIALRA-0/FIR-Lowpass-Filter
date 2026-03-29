`timescale 1ns/1ps

module fir_branch_core_symm #(
    parameter WIN   = 16,
    parameter WCOEF = 20,
    parameter WACC  = 46,
    parameter TAPS  = 131,
    parameter UNIQ  = 66
) (
    input  wire                               clk,
    input  wire                               rst,
    input  wire                               en,
    input  wire signed [WIN-1:0]              in_sample,
    input  wire signed [UNIQ*WCOEF-1:0]       coeff_bus,
    output reg  signed [WACC-1:0]             acc_out
);

localparam integer WPRE      = WIN + 1;
localparam integer WPROD     = WIN + WCOEF + 1;
localparam integer TAP_DEPTH = TAPS - 1;

wire [WIN*TAP_DEPTH-1:0] tap_bus;
wire [WIN*TAPS-1:0]      hist_bus;
wire signed [WPRE-1:0]   pre_sum [0:UNIQ-1];
wire signed [WPROD-1:0]  prod    [0:UNIQ-1];
reg  signed [WACC-1:0]   acc_comb;

delay_line #(
    .WIDTH(WIN),
    .DEPTH(TAP_DEPTH)
) u_delay_line (
    .clk(clk),
    .rst(rst),
    .en(en),
    .din(in_sample),
    .taps_flat(tap_bus)
);

assign hist_bus[WIN-1:0] = in_sample;
assign hist_bus[WIN*TAPS-1:WIN] = tap_bus;

genvar g;
generate
for (g = 0; g < UNIQ; g = g + 1) begin : g_folded_taps
    localparam integer LEFT  = g;
    localparam integer RIGHT = TAPS - 1 - g;
    wire signed [WIN-1:0]   s_left;
    wire signed [WIN-1:0]   s_right;
    wire signed [WCOEF-1:0] coeff_g;

    assign s_left  = hist_bus[(LEFT+1)*WIN-1 -: WIN];
    assign s_right = (LEFT == RIGHT) ? {WIN{1'b0}} : hist_bus[(RIGHT+1)*WIN-1 -: WIN];
    assign coeff_g = coeff_bus[(g+1)*WCOEF-1 -: WCOEF];

    preadd_mult #(
        .WIN(WIN),
        .WCOEF(WCOEF)
    ) u_preadd_mult (
        .sample_a(s_left),
        .sample_b(s_right),
        .coeff(coeff_g),
        .pre_sum(pre_sum[g]),
        .product(prod[g])
    );
end
endgenerate

integer i;
always @* begin
    acc_comb = {WACC{1'b0}};
    for (i = 0; i < UNIQ; i = i + 1) begin
        acc_comb = acc_comb + {{(WACC-WPROD){prod[i][WPROD-1]}}, prod[i]};
    end
end

always @(posedge clk) begin
    if (rst) begin
        acc_out <= {WACC{1'b0}};
    end else if (en) begin
        acc_out <= acc_comb;
    end
end

endmodule
