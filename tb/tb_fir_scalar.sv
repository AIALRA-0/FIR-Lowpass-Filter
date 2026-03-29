`timescale 1ns/1ps

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
  int feed_cycles = 0;
  int in_idx = 0;
  int out_idx = 0;
  int errors = 0;
  int arg_ok = 0;
  integer file_handle;

`ifdef DUT_PIPE
  fir_pipe_systolic dut (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .in_sample(in_sample),
    .out_valid(out_valid),
    .out_sample(out_sample)
  );
`else
  fir_symm_base dut (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .in_sample(in_sample),
    .out_valid(out_valid),
    .out_sample(out_sample)
  );
`endif

  always #2.5 clk = ~clk;

  task automatic require_memh_file(input string path);
    begin
      file_handle = $fopen(path, "r");
      if (file_handle == 0) begin
        $fatal(1, "TB FAIL: cannot open memory file %s", path);
      end
      $fclose(file_handle);
    end
  endtask

  function automatic bit file_exists(input string path);
    begin
      file_handle = $fopen(path, "r");
      if (file_handle != 0) begin
        $fclose(file_handle);
        file_exists = 1'b1;
      end else begin
        file_exists = 1'b0;
      end
    end
  endfunction

  initial begin
    arg_ok = $value$plusargs("INPUT_FILE=%s", input_file);
    if (!arg_ok && !file_exists(input_file)) begin
      input_file = "../../../vectors/impulse/input_scalar.memh";
    end

    arg_ok = $value$plusargs("GOLDEN_FILE=%s", golden_file);
    if (!arg_ok && !file_exists(golden_file)) begin
      golden_file = "../../../vectors/impulse/golden_scalar.memh";
    end

    arg_ok = $value$plusargs("INPUT_LEN=%d", input_len);
    require_memh_file(input_file);
    require_memh_file(golden_file);
    $readmemh(input_file, input_mem);
    $readmemh(golden_file, golden_mem);

    repeat (5) @(posedge clk);
    @(negedge clk);
    rst <= 1'b0;

    feed_cycles = input_len + `FIR_TAPS - 1;
    for (in_idx = 0; in_idx < feed_cycles; in_idx++) begin
      @(negedge clk);
      in_valid <= 1'b1;
      if (in_idx < input_len) begin
        in_sample <= input_mem[in_idx];
      end else begin
        in_sample <= '0;
      end
    end

    @(negedge clk);
    in_valid <= 1'b0;
    in_sample <= '0;

    wait (out_idx == feed_cycles);
    if (errors == 0) begin
`ifdef DUT_PIPE
      $display("TB PASS: scalar DUT fir_pipe_systolic case=%s", input_file);
`else
      $display("TB PASS: scalar DUT fir_symm_base case=%s", input_file);
`endif
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

`ifdef TB_DEBUG
  int dbg_cycle = 0;
  always @(posedge clk) begin
    if (!rst && dbg_cycle < 12) begin
      $display(
        "DBG cyc=%0d in_valid=%b in_sample=%h out_valid=%b out_sample=%h acc_comb=%h acc_reg=%h s0=%h sN=%h p0=%h",
        dbg_cycle,
        in_valid,
        in_sample,
        out_valid,
        out_sample,
        dut.acc_comb,
        dut.acc_reg,
        dut.g_folded_taps[0].s_left,
        dut.g_folded_taps[0].s_right,
        dut.prod[0]
      );
      dbg_cycle <= dbg_cycle + 1;
    end
  end
`endif
endmodule
