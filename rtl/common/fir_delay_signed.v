`timescale 1ns/1ps

module fir_delay_signed #(
    parameter WIDTH = 16,
    parameter DEPTH = 1
) (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    en,
    input  wire signed [WIDTH-1:0] din,
    output wire signed [WIDTH-1:0] dout
);

generate
if (DEPTH == 0) begin : g_zero
    assign dout = din;
end else begin : g_pipe
    reg signed [WIDTH-1:0] pipe [0:DEPTH-1];
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                pipe[i] <= {WIDTH{1'b0}};
            end
        end else if (en) begin
            pipe[0] <= din;
            for (i = 1; i < DEPTH; i = i + 1) begin
                pipe[i] <= pipe[i-1];
            end
        end
    end
    assign dout = pipe[DEPTH-1];
end
endgenerate

endmodule
