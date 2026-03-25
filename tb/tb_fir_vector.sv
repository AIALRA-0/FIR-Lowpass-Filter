`timescale 1ns/1ps

`ifndef DUT_MODULE
`define DUT_MODULE fir_l2_polyphase
`endif

`ifndef LANES
`define LANES 2
`endif

`include "fir_params.vh"

module tb_fir_vector;
  localparam int LANES_I = `LANES;
  localparam int IN_WIDTH = LANES_I * `FIR_WIN;
  localparam int OUT_WIDTH = LANES_I * `FIR_WOUT;
  localparam int MAX_FRAMES = 8192;

  logic clk = 1'b0;
  logic rst = 1'b1;
  logic in_valid = 1'b0;
  logic signed [IN_WIDTH-1:0] in_vec = '0;
  wire out_valid;
  wire signed [OUT_WIDTH-1:0] out_vec;

  logic [IN_WIDTH-1:0] input_mem [0:MAX_FRAMES-1];
  logic [OUT_WIDTH-1:0] golden_mem [0:MAX_FRAMES-1];

  string input_file;
  string golden_file;
  int input_len = 1024;
  int input_frames;
  int output_frames;
  int in_idx;
  int out_idx;
  int errors;

  `DUT_MODULE dut (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .in_vec(in_vec),
    .out_valid(out_valid),
    .out_vec(out_vec)
  );

  always #2.5 clk = ~clk;

  initial begin
    if (LANES_I == 2) begin
      input_file = "vectors/impulse/input_l2.memh";
      golden_file = "vectors/impulse/golden_l2.memh";
    end else begin
      input_file = "vectors/impulse/input_l3.memh";
      golden_file = "vectors/impulse/golden_l3.memh";
    end

    void'($value$plusargs("INPUT_FILE=%s", input_file));
    void'($value$plusargs("GOLDEN_FILE=%s", golden_file));
    void'($value$plusargs("INPUT_LEN=%d", input_len));
    $readmemh(input_file, input_mem);
    $readmemh(golden_file, golden_mem);

    repeat (5) @(posedge clk);
    rst <= 1'b0;

    input_frames = (input_len + LANES_I - 1) / LANES_I;
    output_frames = (input_len + `FIR_TAPS - 1 + LANES_I - 1) / LANES_I;

    for (in_idx = 0; in_idx < output_frames; in_idx++) begin
      @(posedge clk);
      in_valid <= 1'b1;
      if (in_idx < input_frames) begin
        in_vec <= input_mem[in_idx];
      end else begin
        in_vec <= '0;
      end
    end

    @(posedge clk);
    in_valid <= 1'b0;
    in_vec <= '0;

    wait (out_idx == output_frames);
    if (errors == 0) begin
      $display("TB PASS: vector DUT %s lanes=%0d case=%s", `"DUT_MODULE`", LANES_I, input_file);
    end else begin
      $fatal(1, "TB FAIL: %0d mismatches", errors);
    end
    #20;
    $finish;
  end

  always @(posedge clk) begin
    if (rst) begin
      out_idx <= 0;
      errors <= 0;
    end else if (out_valid) begin
      if (out_vec !== golden_mem[out_idx]) begin
        $display("Mismatch @%0d got=%h expected=%h", out_idx, out_vec, golden_mem[out_idx]);
        errors <= errors + 1;
      end
      out_idx <= out_idx + 1;
    end
  end
endmodule

