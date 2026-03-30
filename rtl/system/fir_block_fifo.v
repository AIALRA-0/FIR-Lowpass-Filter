`timescale 1ns/1ps

module fir_block_fifo #(
    parameter WIDTH = 16,
    parameter DEPTH = 2048
) (
    input  wire             clk,
    input  wire             rst,
    input  wire             clear,
    input  wire             in_valid,
    input  wire [WIDTH-1:0] in_data,
    output wire             out_valid,
    input  wire             out_ready,
    output wire [WIDTH-1:0] out_data,
    output reg              overflow
);

localparam integer PTR_WIDTH = (DEPTH <= 2) ? 1 : $clog2(DEPTH);

(* ram_style = "block" *) reg [WIDTH-1:0] mem [0:DEPTH-1];
reg [PTR_WIDTH-1:0] wr_ptr;
reg [PTR_WIDTH-1:0] rd_ptr;
reg [PTR_WIDTH:0]   count;

wire do_write = in_valid;
wire do_read = out_valid && out_ready;
wire fifo_full = (count == DEPTH);
wire fifo_empty = (count == 0);

assign out_valid = !fifo_empty;
assign out_data = mem[rd_ptr];

always @(posedge clk) begin
    if (rst || clear) begin
        wr_ptr <= {PTR_WIDTH{1'b0}};
        rd_ptr <= {PTR_WIDTH{1'b0}};
        count <= {(PTR_WIDTH + 1){1'b0}};
        overflow <= 1'b0;
    end else begin
        case ({do_write && !fifo_full, do_read})
            2'b10: count <= count + {{PTR_WIDTH{1'b0}}, 1'b1};
            2'b01: count <= count - {{PTR_WIDTH{1'b0}}, 1'b1};
            default: count <= count;
        endcase

        if (do_write) begin
            if (!fifo_full) begin
                mem[wr_ptr] <= in_data;
                wr_ptr <= (wr_ptr == DEPTH - 1) ? {PTR_WIDTH{1'b0}} : (wr_ptr + {{(PTR_WIDTH-1){1'b0}}, 1'b1});
            end else begin
                overflow <= 1'b1;
            end
        end

        if (do_read) begin
            rd_ptr <= (rd_ptr == DEPTH - 1) ? {PTR_WIDTH{1'b0}} : (rd_ptr + {{(PTR_WIDTH-1){1'b0}}, 1'b1});
        end
    end
end

endmodule
