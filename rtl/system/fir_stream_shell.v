`timescale 1ns/1ps

`include "fir_params.vh"

module fir_stream_shell #(
    parameter ARCH_ID = 0,
    parameter COUNT_WIDTH = 32
) (
    input  wire                        clk,
    input  wire                        rst,
    input  wire                        start_pulse,
    input  wire                        soft_reset,
    input  wire [COUNT_WIDTH-1:0]      sample_count,
    input  wire                        s_axis_tvalid,
    output wire                        s_axis_tready,
    input  wire signed [`FIR_WIN-1:0]  s_axis_tdata,
    output wire                        m_axis_tvalid,
    input  wire                        m_axis_tready,
    output wire signed [`FIR_WOUT-1:0] m_axis_tdata,
    output wire                        m_axis_tlast,
    output reg                         done,
    output reg                         busy,
    output reg                         error,
    output reg  [31:0]                 cycle_count
);

localparam integer LANES =
    (ARCH_ID == 2) ? 2 :
    ((ARCH_ID == 3 || ARCH_ID == 4) ? 3 : 1);

wire                           pack_valid;
wire signed [LANES*`FIR_WIN-1:0] pack_data;
wire                           pack_error;
wire [COUNT_WIDTH-1:0]         pack_seen;
wire                           unpack_done;
wire                           unpack_error;
wire [COUNT_WIDTH-1:0]         unpack_emitted;
wire                           core_out_valid;
wire signed [LANES*`FIR_WOUT-1:0] core_out_data;

wire signed [`FIR_WOUT-1:0] out_sample_base;
wire signed [`FIR_WOUT-1:0] out_sample_pipe;
wire signed [2*`FIR_WOUT-1:0] out_vec_l2;
wire signed [3*`FIR_WOUT-1:0] out_vec_l3;
wire signed [3*`FIR_WOUT-1:0] out_vec_l3_pipe;

wire run_clear = rst || soft_reset || start_pulse;

fir_scalar_to_block #(
    .WIDTH(`FIR_WIN),
    .LANES(LANES),
    .COUNT_WIDTH(COUNT_WIDTH)
) u_packer (
    .clk(clk),
    .rst(rst),
    .clear(run_clear),
    .run_enable(busy),
    .sample_count(sample_count),
    .s_tvalid(s_axis_tvalid),
    .s_tready(s_axis_tready),
    .s_tdata(s_axis_tdata),
    .block_valid(pack_valid),
    .block_data(pack_data),
    .protocol_error(pack_error),
    .samples_seen(pack_seen)
);

generate
if (ARCH_ID == 0) begin : g_base
    fir_symm_base u_core (
        .clk(clk),
        .rst(run_clear),
        .in_valid(pack_valid),
        .in_sample(pack_data[`FIR_WIN-1:0]),
        .out_valid(core_out_valid),
        .out_sample(out_sample_base)
    );
    assign core_out_data = out_sample_base;
end else if (ARCH_ID == 1) begin : g_pipe
    fir_pipe_systolic u_core (
        .clk(clk),
        .rst(run_clear),
        .in_valid(pack_valid),
        .in_sample(pack_data[`FIR_WIN-1:0]),
        .out_valid(core_out_valid),
        .out_sample(out_sample_pipe)
    );
    assign core_out_data = out_sample_pipe;
end else if (ARCH_ID == 2) begin : g_l2
    fir_l2_polyphase u_core (
        .clk(clk),
        .rst(run_clear),
        .in_valid(pack_valid),
        .in_vec(pack_data),
        .out_valid(core_out_valid),
        .out_vec(out_vec_l2)
    );
    assign core_out_data = out_vec_l2;
end else if (ARCH_ID == 3) begin : g_l3
    fir_l3_polyphase u_core (
        .clk(clk),
        .rst(run_clear),
        .in_valid(pack_valid),
        .in_vec(pack_data),
        .out_valid(core_out_valid),
        .out_vec(out_vec_l3)
    );
    assign core_out_data = out_vec_l3;
end else begin : g_l3_pipe
    fir_l3_pipe u_core (
        .clk(clk),
        .rst(run_clear),
        .in_valid(pack_valid),
        .in_vec(pack_data),
        .out_valid(core_out_valid),
        .out_vec(out_vec_l3_pipe)
    );
    assign core_out_data = out_vec_l3_pipe;
end
endgenerate

fir_block_to_scalar #(
    .WIDTH(`FIR_WOUT),
    .LANES(LANES),
    .COUNT_WIDTH(COUNT_WIDTH)
) u_unpacker (
    .clk(clk),
    .rst(rst),
    .clear(run_clear),
    .run_enable(busy),
    .sample_count(sample_count),
    .block_valid(core_out_valid),
    .block_data(core_out_data),
    .m_tvalid(m_axis_tvalid),
    .m_tready(m_axis_tready),
    .m_tdata(m_axis_tdata),
    .m_tlast(m_axis_tlast),
    .done_pulse(unpack_done),
    .protocol_error(unpack_error),
    .samples_emitted(unpack_emitted)
);

always @(posedge clk) begin
    if (rst || soft_reset) begin
        done <= 1'b0;
        busy <= 1'b0;
        error <= 1'b0;
        cycle_count <= 32'd0;
    end else begin
        if (start_pulse) begin
            done <= 1'b0;
            busy <= (sample_count != 0);
            error <= 1'b0;
            cycle_count <= 32'd0;
        end else begin
            if (busy) begin
                cycle_count <= cycle_count + 1;
            end
            if (pack_error || unpack_error) begin
                error <= 1'b1;
            end
            if (unpack_done) begin
                done <= 1'b1;
                busy <= 1'b0;
            end
        end
    end
end

endmodule
