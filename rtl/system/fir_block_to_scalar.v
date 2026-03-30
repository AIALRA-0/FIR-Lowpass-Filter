`timescale 1ns/1ps

module fir_block_to_scalar #(
    parameter WIDTH = 16,
    parameter LANES = 3,
    parameter COUNT_WIDTH = 32
) (
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          clear,
    input  wire                          run_enable,
    input  wire [COUNT_WIDTH-1:0]        sample_count,
    input  wire                          block_valid,
    input  wire signed [LANES*WIDTH-1:0] block_data,
    output wire                          block_ready,
    output wire                          m_tvalid,
    input  wire                          m_tready,
    output wire signed [WIDTH-1:0]       m_tdata,
    output wire                          m_tlast,
    output reg                           done_pulse,
    output reg                           protocol_error,
    output reg  [COUNT_WIDTH-1:0]        samples_emitted
);

reg signed [LANES*WIDTH-1:0] hold_block;
reg [31:0]                   hold_index;
reg [31:0]                   hold_valid_lanes;
reg [COUNT_WIDTH-1:0]        samples_assigned;
reg                          holding;

wire out_fire;
wire finishing_current;
wire can_accept_block;
wire [COUNT_WIDTH-1:0] remaining_for_new_block;
wire [31:0] next_valid_lanes;

assign m_tvalid = holding && run_enable;
assign m_tdata = hold_block[(hold_index+1)*WIDTH-1 -: WIDTH];
assign out_fire = m_tvalid && m_tready;
assign m_tlast = holding && ((samples_emitted + {{(COUNT_WIDTH-1){1'b0}}, 1'b1}) == sample_count);
assign finishing_current = out_fire && (hold_index + 1 == hold_valid_lanes);
assign can_accept_block = !holding || finishing_current;
assign block_ready = can_accept_block;
assign remaining_for_new_block = sample_count - samples_assigned;
assign next_valid_lanes = (remaining_for_new_block > LANES) ? LANES : remaining_for_new_block[31:0];

always @(posedge clk) begin
    if (rst || clear) begin
        hold_block <= {LANES*WIDTH{1'b0}};
        hold_index <= 0;
        hold_valid_lanes <= 0;
        samples_assigned <= {COUNT_WIDTH{1'b0}};
        samples_emitted <= {COUNT_WIDTH{1'b0}};
        holding <= 1'b0;
        done_pulse <= 1'b0;
        protocol_error <= 1'b0;
    end else begin
        done_pulse <= 1'b0;

        if (out_fire) begin
            samples_emitted <= samples_emitted + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
            if ((samples_emitted + {{(COUNT_WIDTH-1){1'b0}}, 1'b1}) == sample_count) begin
                done_pulse <= 1'b1;
            end
        end

        if (holding && out_fire) begin
            if (hold_index + 1 == hold_valid_lanes) begin
                holding <= 1'b0;
                hold_index <= 0;
            end else begin
                hold_index <= hold_index + 1;
            end
        end

        if (block_valid) begin
            if (can_accept_block) begin
                hold_block <= block_data;
                hold_index <= 0;
                hold_valid_lanes <= next_valid_lanes;
                holding <= (next_valid_lanes != 0);
                samples_assigned <= samples_assigned + next_valid_lanes;
            end else begin
                protocol_error <= 1'b1;
            end
        end
    end
end

endmodule
