`timescale 1ns/1ps

module valid_pipe #(
    parameter LATENCY = 1
) (
    input  wire clk,
    input  wire rst,
    input  wire in_valid,
    output wire out_valid
);

generate
if (LATENCY == 0) begin : g_passthrough
    assign out_valid = in_valid;
end else begin : g_pipe
    reg [LATENCY-1:0] pipe;
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            pipe <= {LATENCY{1'b0}};
        end else begin
            pipe[0] <= in_valid;
            for (i = 1; i < LATENCY; i = i + 1) begin
                pipe[i] <= pipe[i-1];
            end
        end
    end
    assign out_valid = pipe[LATENCY-1];
end
endgenerate

endmodule
