`timescale 1ns/1ps
module repetition_penalty_tb;
  reg [15:0] value;
  wire [15:0] penalized;
  reg [15:0] expected [0:65535];
  integer i;
  RepetitionPenaltyHarness dut(.io_value(value), .io_penalized(penalized));
  initial begin
    $readmemh("penalty_expected.hex", expected);
    for (i=0; i<65536; i=i+1) begin
      value = i; #1;
      if (penalized !== expected[i])
        $fatal(1,"PENALTY_MISMATCH value=%04x actual=%04x expected=%04x",value,penalized,expected[i]);
    end
    $display("REPETITION_PENALTY_EXHAUSTIVE_PASS count=65536");
    $finish;
  end
  initial begin #70000; $fatal(1,"PENALTY_WATCHDOG"); end
endmodule
