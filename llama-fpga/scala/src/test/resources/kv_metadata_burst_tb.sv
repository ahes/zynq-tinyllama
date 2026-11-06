`timescale 1ns/1ps
module kv_metadata_burst_tb;
  reg clk=0;
  always #5 clk=~clk;
  reg reset=1;
  reg io_bus_tvalid=0;
  wire io_bus_tready;
  reg [127:0] io_bus_tdata=0;
  reg [5:0] io_bus_tdest=0;
  reg io_bus_tlast=0;
  reg [15:0] io_bus_tkeep=16'hffff;
  reg [9:0] io_token=0;
  reg io_modeV=0;
  wire io_main_valid;
  reg io_main_ready=0;
  wire [127:0] io_main_payload;
  wire [7:0] io_zeroValue;
  wire [31:0] io_scaleValue;
  integer cycles=0, observed=0, metadata_sent=0, phase=0, selected=0;
  integer cases[0:6];
  integer n, v, i;
  localparam [127:0] DATA_BASE=128'h12340000000000000000000000000000;
  KvMetadataBurstHarness dut(
    .clk(clk), .reset(reset),
    .io_bus_valid(io_bus_tvalid), .io_bus_ready(io_bus_tready),
    .io_bus_payload_data(io_bus_tdata), .io_bus_payload_dest(io_bus_tdest),
    .io_bus_payload_last(io_bus_tlast), .io_bus_payload_keep(io_bus_tkeep),
    .io_token(io_token), .io_modeV(io_modeV),
    .io_main_valid(io_main_valid), .io_main_ready(io_main_ready),
    .io_main_payload(io_main_payload), .io_zeroValue(io_zeroValue), .io_scaleValue(io_scaleValue));
  always @(negedge clk) begin
    cycles=cycles+1;
    io_main_ready = (cycles%7 != 0 && cycles%11 != 0);
  end
  always @(posedge clk) if (!reset && io_main_valid && io_main_ready) begin
    if (io_main_payload !== DATA_BASE+observed)
      $fatal(1,"DATA_MISMATCH token=%0d V=%0d beat=%0d got=%h",io_token,io_modeV,observed,io_main_payload);
    if (io_zeroValue !== ((observed/4)%31+1))
      $fatal(1,"ZERO_MISMATCH token=%0d V=%0d beat=%0d got=%h",io_token,io_modeV,observed,io_zeroValue);
    if (io_scaleValue !== ((io_modeV ? 32'h00004000 : 32'h00003000)+observed/4))
      $fatal(1,"SCALE_MISMATCH token=%0d V=%0d beat=%0d got=%h",io_token,io_modeV,observed,io_scaleValue);
    observed=observed+1;
  end
  task beat(input [127:0] data, input bit last);
    begin
      @(negedge clk);
      io_bus_tdata=data;
      io_bus_tlast=last;
      io_bus_tvalid=1;
      @(posedge clk);
      while (!io_bus_tready) @(posedge clk);
      @(negedge clk);
      io_bus_tvalid=0;
    end
  endtask
  function automatic [127:0] metadata(input integer first_token);
    integer lane;
    begin
      metadata=0;
      for (lane=0;lane<4;lane=lane+1) begin
        metadata[lane*32+:16]=16'h3000+first_token+lane;
        metadata[lane*32+16+:8]=(first_token+lane)%31+1;
      end
    end
  endfunction
  task check_case(input integer tokens, input integer is_v);
    begin
      @(negedge clk);
      io_token=tokens;
      io_modeV=is_v;
      io_bus_tdest=is_v;
      observed=0;
      metadata_sent=0;
      phase=0;
      repeat(5) @(posedge clk);
      // The real DMA completes the metadata command before sending any
      // cached weights. Do not interleave/reorder these transfers to pass.
      for (i=0;i<tokens/4;i=i+1) begin
        beat(metadata(i*4), i==tokens/4-1);
        metadata_sent=metadata_sent+1;
      end
      phase=1;
      for (i=0;i<tokens*4;i=i+1) beat(DATA_BASE+i, i==tokens*4-1);
      while (observed < tokens*4) @(posedge clk);
      repeat(20) @(posedge clk);
      if (observed != tokens*4) $fatal(1,"COUNT_MISMATCH");
      $display("KV_METADATA_CASE_PASS tokens=%0d V=%0d metadata=%0d data=%0d",tokens,is_v,metadata_sent,observed);
    end
  endtask
  initial begin
    #3000000;
    $fatal(1,"KV_METADATA_TIMEOUT token=%0d V=%0d phase=%0d metadata_sent=%0d main_observed=%0d",io_token,io_modeV,phase,metadata_sent,observed);
  end
  initial begin
    cases[0]=4; cases[1]=252; cases[2]=256; cases[3]=260;
    cases[4]=384; cases[5]=768; cases[6]=1020;
    repeat(12) @(posedge clk);
    @(negedge clk); reset=0;
    if ($value$plusargs("TOKEN=%d",selected)) begin
      check_case(selected,0);
    end else begin
      for (n=0;n<7;n=n+1) begin
        for (v=0;v<2;v=v+1) check_case(cases[n],v);
      end
    end
    $display("KV_METADATA_BURST_PASS");
    $finish;
  end
endmodule
