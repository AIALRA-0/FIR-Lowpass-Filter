`timescale 1ns/1ps

`include "fir_params.vh"

module fir_vendor_ip_core (
    input  wire                        clk,
    input  wire                        rst,
    input  wire                        in_valid,
    input  wire signed [`FIR_WIN-1:0]  in_sample,
    output wire                        out_valid,
    output wire signed [`FIR_WOUT-1:0] out_sample
);

wire                  s_axis_data_tready;
wire                  m_axis_data_tvalid;
wire [39:0]           m_axis_data_tdata;
wire signed [36:0]    vendor_full_precision = m_axis_data_tdata[36:0];

fir_vendor_ip_0 u_vendor_ip (
    .aresetn(~rst),
    .aclk(clk),
    .s_axis_data_tvalid(in_valid),
    .s_axis_data_tready(s_axis_data_tready),
    .s_axis_data_tdata(in_sample),
    .m_axis_data_tvalid(m_axis_data_tvalid),
    .m_axis_data_tdata(m_axis_data_tdata)
);

round_sat #(
    .IN_WIDTH(37),
    .OUT_WIDTH(`FIR_WOUT),
    .SHIFT(`FIR_SHIFT)
) u_round (
    .din(vendor_full_precision),
    .dout(out_sample)
);

assign out_valid = m_axis_data_tvalid;

endmodule
