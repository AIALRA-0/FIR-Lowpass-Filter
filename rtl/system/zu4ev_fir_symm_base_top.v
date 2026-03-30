`timescale 1ns/1ps

module zu4ev_fir_symm_base_top (
    input  wire         aclk,
    input  wire         aresetn,
    input  wire [5:0]   s_axi_ctrl_awaddr,
    input  wire         s_axi_ctrl_awvalid,
    output wire         s_axi_ctrl_awready,
    input  wire [31:0]  s_axi_ctrl_wdata,
    input  wire [3:0]   s_axi_ctrl_wstrb,
    input  wire         s_axi_ctrl_wvalid,
    output wire         s_axi_ctrl_wready,
    output wire [1:0]   s_axi_ctrl_bresp,
    output wire         s_axi_ctrl_bvalid,
    input  wire         s_axi_ctrl_bready,
    input  wire [5:0]   s_axi_ctrl_araddr,
    input  wire         s_axi_ctrl_arvalid,
    output wire         s_axi_ctrl_arready,
    output wire [31:0]  s_axi_ctrl_rdata,
    output wire [1:0]   s_axi_ctrl_rresp,
    output wire         s_axi_ctrl_rvalid,
    input  wire         s_axi_ctrl_rready,
    input  wire [15:0]  s_axis_in_tdata,
    input  wire         s_axis_in_tvalid,
    output wire         s_axis_in_tready,
    input  wire         s_axis_in_tlast,
    output wire [15:0]  m_axis_out_tdata,
    output wire         m_axis_out_tvalid,
    input  wire         m_axis_out_tready,
    output wire         m_axis_out_tlast,
    output wire         irq
);

fir_zu4ev_shell #(
    .ARCH_ID(0)
) u_shell (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axi_ctrl_awaddr(s_axi_ctrl_awaddr),
    .s_axi_ctrl_awvalid(s_axi_ctrl_awvalid),
    .s_axi_ctrl_awready(s_axi_ctrl_awready),
    .s_axi_ctrl_wdata(s_axi_ctrl_wdata),
    .s_axi_ctrl_wstrb(s_axi_ctrl_wstrb),
    .s_axi_ctrl_wvalid(s_axi_ctrl_wvalid),
    .s_axi_ctrl_wready(s_axi_ctrl_wready),
    .s_axi_ctrl_bresp(s_axi_ctrl_bresp),
    .s_axi_ctrl_bvalid(s_axi_ctrl_bvalid),
    .s_axi_ctrl_bready(s_axi_ctrl_bready),
    .s_axi_ctrl_araddr(s_axi_ctrl_araddr),
    .s_axi_ctrl_arvalid(s_axi_ctrl_arvalid),
    .s_axi_ctrl_arready(s_axi_ctrl_arready),
    .s_axi_ctrl_rdata(s_axi_ctrl_rdata),
    .s_axi_ctrl_rresp(s_axi_ctrl_rresp),
    .s_axi_ctrl_rvalid(s_axi_ctrl_rvalid),
    .s_axi_ctrl_rready(s_axi_ctrl_rready),
    .s_axis_in_tdata(s_axis_in_tdata),
    .s_axis_in_tvalid(s_axis_in_tvalid),
    .s_axis_in_tready(s_axis_in_tready),
    .s_axis_in_tlast(s_axis_in_tlast),
    .m_axis_out_tdata(m_axis_out_tdata),
    .m_axis_out_tvalid(m_axis_out_tvalid),
    .m_axis_out_tready(m_axis_out_tready),
    .m_axis_out_tlast(m_axis_out_tlast),
    .irq(irq)
);

endmodule
