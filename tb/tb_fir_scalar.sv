`timescale 1ns/1ps

`ifndef DUT_MODULE
`define DUT_MODULE fir_symm_base
`endif

`include "fir_params.vh"

module tb_fir_scalar;
  localparam int MAX_SAMPLES = 8192;

  logic clk = 1'b0;
  logic rst = 1'b1;
  logic in_valid = 1'b0;
  logic signed [`FIR_WIN-1:0] in_sample = '0;
  wire out_valid;
  wire signed [`FIR_WOUT-1:0] out_sample;

  logic [`FIR_WIN-1:0] input_mem [0:MAX_SAMPLES-1];
  logic [`FIR_WOUT-1:0] golden_mem [0:MAX_SAMPLES-1];

  string input_file = "vectors/impulse/input_scalar.memh";
  string golden_file = "vectors/impulse/golden_scalar.memh";
  int input_len = 1024;
  int feed_cycles;
  int in_idx;
  int out_idx;
  int errors;

  `DUT_MODULE dut (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .in_sample(in_sample),
    .out_valid(out_valid),
    .out_sample(out_sample)
  );

  always #2.5 clk = ~clk;

  initial begin
    void'($value$plusargs("INPUT_FILE=%s", input_file));
    void'($value$plusargs("GOLDEN_FILE=%s", golden_file));
    void'($value$plusargs("INPUT_LEN=%d", input_len));
    $readmemh(input_file, input_mem);
    $readmemh(golden_file, golden_mem);

    repeat (5) @(posedge clk);
    rst <= 1'b0;

    feed_cycles = input_len + `FIR_TAPS - 1;
    for (in_idx = 0; in_idx < feed_cycles; in_idx++) begin
      @(posedge clk);
      in_valid <= 1'b1;
      if (in_idx < input_len) begin
        in_sample <= input_mem[in_idx];
      end else begin
        in_sample <= '0;
      end
    end

    @(posedge clk);
    in_valid <= 1'b0;
    in_sample <= '0;

    wait (out_idx == feed_cycles);
    if (errors == 0) begin
      $display("TB PASS: scalar DUT %s case=%s", `"DUT_MODULE`", input_file);
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
      if (out_sample !== golden_mem[out_idx]) begin
        $display("Mismatch @%0d got=%h expected=%h", out_idx, out_sample, golden_mem[out_idx]);
        errors <= errors + 1;
      end
      out_idx <= out_idx + 1;
    end
  end
endmodule

