`timescale 1ns/1ps

`include "fir_params.vh"

module tb_fir_vector;
`ifdef DUT_L3_PIPE
  localparam int LANES_I = 3;
`elsif DUT_L3
  localparam int LANES_I = 3;
`else
  localparam int LANES_I = 2;
`endif
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
  int input_frames = 0;
  int output_frames = 0;
  int in_idx = 0;
  int out_idx = 0;
  int errors = 0;
  int arg_ok = 0;
  integer file_handle;

`ifdef DUT_L3_PIPE
  fir_l3_pipe dut (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .in_vec(in_vec),
    .out_valid(out_valid),
    .out_vec(out_vec)
  );
`elsif DUT_L3
  fir_l3_polyphase dut (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .in_vec(in_vec),
    .out_valid(out_valid),
    .out_vec(out_vec)
  );
`else
  fir_l2_polyphase dut (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .in_vec(in_vec),
    .out_valid(out_valid),
    .out_vec(out_vec)
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

  function automatic bit input_frame_known(input logic [IN_WIDTH-1:0] value);
    begin
      input_frame_known = (^value !== 1'bx);
    end
  endfunction

  function automatic bit output_frame_known(input logic [OUT_WIDTH-1:0] value);
    begin
      output_frame_known = (^value !== 1'bx);
    end
  endfunction

  initial begin
    if (LANES_I == 2) begin
      input_file = "vectors/impulse/input_l2.memh";
      golden_file = "vectors/impulse/golden_l2.memh";
    end else begin
      input_file = "vectors/impulse/input_l3.memh";
      golden_file = "vectors/impulse/golden_l3.memh";
    end

    arg_ok = $value$plusargs("INPUT_FILE=%s", input_file);
    if (!arg_ok) begin
      if (!file_exists(input_file)) begin
        if (LANES_I == 2) begin
          input_file = "../../../vectors/impulse/input_l2.memh";
        end else begin
          input_file = "../../../vectors/impulse/input_l3.memh";
        end
      end
    end

    arg_ok = $value$plusargs("GOLDEN_FILE=%s", golden_file);
    if (!arg_ok) begin
      if (!file_exists(golden_file)) begin
        if (LANES_I == 2) begin
          golden_file = "../../../vectors/impulse/golden_l2.memh";
        end else begin
          golden_file = "../../../vectors/impulse/golden_l3.memh";
        end
      end
    end

    require_memh_file(input_file);
    require_memh_file(golden_file);
    $readmemh(input_file, input_mem);
    $readmemh(golden_file, golden_mem);

    input_frames = 0;
    while ((input_frames < MAX_FRAMES) && input_frame_known(input_mem[input_frames])) begin
      input_frames = input_frames + 1;
    end

    output_frames = 0;
    while ((output_frames < MAX_FRAMES) && output_frame_known(golden_mem[output_frames])) begin
      output_frames = output_frames + 1;
    end

    repeat (5) @(posedge clk);
    @(negedge clk);
    rst <= 1'b0;

    for (in_idx = 0; in_idx < output_frames; in_idx++) begin
      @(negedge clk);
      in_valid <= 1'b1;
      if (in_idx < input_frames) begin
        in_vec <= input_mem[in_idx];
      end else begin
        in_vec <= '0;
      end
    end

    @(negedge clk);
    in_valid <= 1'b0;
    in_vec <= '0;

    wait (out_idx == output_frames);
    if (errors == 0) begin
`ifdef DUT_L3_PIPE
      $display("TB PASS: vector DUT fir_l3_pipe lanes=%0d case=%s", LANES_I, input_file);
`elsif DUT_L3
      $display("TB PASS: vector DUT fir_l3_polyphase lanes=%0d case=%s", LANES_I, input_file);
`else
      $display("TB PASS: vector DUT fir_l2_polyphase lanes=%0d case=%s", LANES_I, input_file);
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
      if (out_vec !== golden_mem[out_idx]) begin
        $display("Mismatch @%0d got=%h expected=%h", out_idx, out_vec, golden_mem[out_idx]);
        errors <= errors + 1;
      end
      out_idx <= out_idx + 1;
    end
  end
endmodule
