`timescale 1ns/1ps

module fir_branch_core_mirror_pair #(
    parameter WIN      = 16,
    parameter WCOEF    = 20,
    parameter WACC     = 48,
    parameter TAPS     = 87,
    parameter NEGATE_B = 1,
    parameter USE_DSP  = 1
) (
    input  wire                               clk,
    input  wire                               rst,
    input  wire                               en,
    input  wire signed [WIN-1:0]              in_sample_a,
    input  wire signed [WIN-1:0]              in_sample_b,
    input  wire signed [TAPS*WCOEF-1:0]       coeff_bus,
    output reg  signed [WACC-1:0]             acc_out
);

localparam integer WPAIR     = WIN + 1;
localparam integer WPROD     = WIN + WCOEF + 1;
localparam integer TAP_DEPTH = TAPS - 1;

wire [WIN*TAP_DEPTH-1:0] tap_bus_a;
wire [WIN*TAP_DEPTH-1:0] tap_bus_b;
wire [WIN*TAPS-1:0]      hist_bus_a;
wire [WIN*TAPS-1:0]      hist_bus_b;
wire signed [WPROD-1:0]  prod [0:TAPS-1];
reg  signed [WACC-1:0]   acc_comb;

delay_line #(
    .WIDTH(WIN),
    .DEPTH(TAP_DEPTH)
) u_delay_line_a (
    .clk(clk),
    .rst(rst),
    .en(en),
    .din(in_sample_a),
    .taps_flat(tap_bus_a)
);

delay_line #(
    .WIDTH(WIN),
    .DEPTH(TAP_DEPTH)
) u_delay_line_b (
    .clk(clk),
    .rst(rst),
    .en(en),
    .din(in_sample_b),
    .taps_flat(tap_bus_b)
);

assign hist_bus_a[WIN-1:0] = in_sample_a;
assign hist_bus_a[WIN*TAPS-1:WIN] = tap_bus_a;
assign hist_bus_b[WIN-1:0] = in_sample_b;
assign hist_bus_b[WIN*TAPS-1:WIN] = tap_bus_b;

genvar g;
generate
for (g = 0; g < TAPS; g = g + 1) begin : g_pair_taps
    localparam integer RIGHT = TAPS - 1 - g;
    wire signed [WIN-1:0]   sample_a_g;
    wire signed [WIN-1:0]   sample_b_g;
    wire signed [WCOEF-1:0] coeff_g;
    wire signed [WPAIR-1:0] pair_g;
    wire signed [WPROD-1:0] prod_g;

    assign sample_a_g = hist_bus_a[(g+1)*WIN-1 -: WIN];
    assign sample_b_g = hist_bus_b[(RIGHT+1)*WIN-1 -: WIN];
    assign coeff_g  = coeff_bus[(g+1)*WCOEF-1 -: WCOEF];
    assign pair_g = NEGATE_B ? ($signed(sample_a_g) - $signed(sample_b_g))
                             : ($signed(sample_a_g) + $signed(sample_b_g));

    if (USE_DSP != 0) begin : g_pair_prod_dsp
        assign prod_g = $signed(pair_g) * $signed(coeff_g);
    end else begin : g_pair_prod_lut
        (* use_dsp = "no" *) wire signed [WPROD-1:0] prod_lut;
        assign prod_lut = $signed(pair_g) * $signed(coeff_g);
        assign prod_g = prod_lut;
    end

    assign prod[g] = prod_g;
end
endgenerate

integer i;
always @* begin
    acc_comb = {WACC{1'b0}};
    for (i = 0; i < TAPS; i = i + 1) begin
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
