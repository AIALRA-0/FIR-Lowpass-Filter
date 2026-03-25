`timescale 1ns/1ps

module delay_line #(
    parameter WIDTH = 16,
    parameter DEPTH = 4
) (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    en,
    input  wire signed [WIDTH-1:0] din,
    output wire [WIDTH*DEPTH-1:0]  taps_flat
);

generate
if (DEPTH == 0) begin : g_zero
    assign taps_flat = {WIDTH{1'b0}};
end else begin : g_delay
    reg signed [WIDTH-1:0] shift [0:DEPTH-1];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                shift[i] <= {WIDTH{1'b0}};
            end
        end else if (en) begin
            shift[0] <= din;
            for (i = 1; i < DEPTH; i = i + 1) begin
                shift[i] <= shift[i-1];
            end
        end
    end

    genvar g;
    for (g = 0; g < DEPTH; g = g + 1) begin : g_assign
        assign taps_flat[(g+1)*WIDTH-1 -: WIDTH] = shift[g];
    end
end
endgenerate

endmodule
