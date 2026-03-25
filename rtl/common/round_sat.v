`timescale 1ns/1ps

module round_sat #(
    parameter IN_WIDTH  = 32,
    parameter OUT_WIDTH = 16,
    parameter SHIFT     = 0
) (
    input  wire signed [IN_WIDTH-1:0]  din,
    output reg  signed [OUT_WIDTH-1:0] dout
);

localparam signed [OUT_WIDTH-1:0] OUT_MAX = {1'b0, {(OUT_WIDTH-1){1'b1}}};
localparam signed [OUT_WIDTH-1:0] OUT_MIN = {1'b1, {(OUT_WIDTH-1){1'b0}}};

reg signed [IN_WIDTH-1:0] rounded_full;
reg signed [IN_WIDTH-1:0] shifted_full;

always @* begin
    if (SHIFT == 0) begin
        rounded_full = din;
    end else if (din >= 0) begin
        rounded_full = din + ({{(IN_WIDTH-1){1'b0}}, 1'b1} <<< (SHIFT - 1));
    end else begin
        rounded_full = din - ({{(IN_WIDTH-1){1'b0}}, 1'b1} <<< (SHIFT - 1));
    end

    shifted_full = rounded_full >>> SHIFT;

    if (shifted_full > $signed(OUT_MAX)) begin
        dout = OUT_MAX;
    end else if (shifted_full < $signed(OUT_MIN)) begin
        dout = OUT_MIN;
    end else begin
        dout = shifted_full[OUT_WIDTH-1:0];
    end
end

endmodule
