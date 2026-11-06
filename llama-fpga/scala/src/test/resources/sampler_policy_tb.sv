`timescale 1ns/1ps
module sampler_policy_tb;
`ifdef SMALL_VOCAB
  localparam VOCAB=64, ROWS=140;
`else
  localparam VOCAB=32000, ROWS=12;
`endif
  reg clk=0, reset=1;
  always #5 clk=~clk;
  reg valid=0;
  reg [5:0] tag=42;
  reg [15:0] value=0;
  wire result_valid,legacy_valid;
  wire [15:0] result,legacy;
`ifdef SMALL_VOCAB
  SamplerPolicySmallHarness dut(
`else
  SamplerPolicyHarness dut(
`endif
    .clk(clk),.reset(reset),.io_valid(valid),.io_tag(tag),.io_value(value),
    .io_resultValid(result_valid),.io_result(result),.io_legacyValid(legacy_valid),.io_legacy(legacy));
  reg [15:0] logits [0:ROWS*VOCAB-1];
  reg [31:0] expected [0:ROWS-1];
  integer row,i,result_count=0;
  always @(posedge clk) begin
    #1;
    if (!reset) begin
      if (result_valid !== legacy_valid) $fatal(1,"VALID_MISMATCH row=%0d",row);
      if(result_valid) begin
        if({legacy,result} !== expected[row])
          $fatal(1,"SAMPLER_MISMATCH row=%0d actual=%08x expected=%08x",row,{legacy,result},expected[row]);
        result_count=result_count+1;
      end
    end
  end
  task drive(input reg v,input reg[5:0] t,input reg[15:0] x);
    begin @(negedge clk); valid=v;tag=t;value=x; end
  endtask
  initial begin
    $readmemh("sampler_logits.hex",logits);
    $readmemh("sampler_expected.hex",expected);
    repeat(4) @(negedge clk);reset=0;
    // An interrupted scan must be discarded by reset.
    repeat(7) drive(1,42,16'h4900);
    @(negedge clk); reset=1; valid=0;
    repeat(3) @(negedge clk);reset=0;
    for(row=0;row<ROWS;row=row+1) begin
      if(row==5) begin
        @(negedge clk);reset=1;valid=0;
        repeat(3) @(negedge clk);reset=0;
      end
      for(i=0;i<VOCAB;i=i+1) begin
        if(i%101==0) drive(0,42,16'h7bff);
        if(i%2007==0) drive(1,41,16'h7bff);
        drive(1,42,logits[row*VOCAB+i]);
      end
      drive(0,42,0);
      repeat(5) @(negedge clk);
      if(result_count!=row+1) $fatal(1,"RESULT_COUNT row=%0d count=%0d",row,result_count);
      $display("SAMPLER_POLICY_CASE_PASS vocab=%0d row=%0d result=%0d legacy=%0d",VOCAB,row,expected[row][15:0],expected[row][31:16]);
    end
    $display("SAMPLER_POLICY_PASS vocab=%0d rows=%0d",VOCAB,ROWS);
    $finish;
  end
  initial begin #5000000; $fatal(1,"SAMPLER_WATCHDOG row=%0d i=%0d",row,i); end
endmodule
