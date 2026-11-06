// Generator : SpinalHDL v1.11.0    git head : 63852c61e498798f4e293594ce53fcb02c45eb6b
// Component : RepetitionPenaltyHarness
// Git hash  : 60e0cb867717bfa3a0e283f1669841e232f15d04

`timescale 1ns/1ps

module RepetitionPenaltyHarness (
  input  wire [15:0]   io_value,
  output wire [15:0]   io_penalized
);

  wire       [14:0]   _zz__zz_when_Fp16RepetitionPenalty_l38;
  wire       [14:0]   _zz__zz_when_Fp16RepetitionPenalty_l38_1;
  wire       [14:0]   _zz__zz_when_Fp16RepetitionPenalty_l38_2;
  wire       [11:0]   _zz__zz_when_Fp16RepetitionPenalty_l40_1;
  wire       [0:0]    _zz__zz_when_Fp16RepetitionPenalty_l40_1_1;
  wire       [10:0]   _zz__zz_io_penalized_2;
  wire       [5:0]    _zz__zz_io_penalized_3;
  wire       [9:0]    _zz__zz_io_penalized_1;
  wire       [4:0]    _zz__zz_io_penalized_1_1;
  wire       [9:0]    _zz__zz_io_penalized_1_2;
  wire       [11:0]   _zz__zz_io_penalized_1_3;
  wire       [11:0]   _zz__zz_io_penalized_1_4;
  wire       [0:0]    _zz__zz_io_penalized_1_5;
  wire       [4:0]    _zz__zz_io_penalized_1_6;
  wire       [15:0]   _zz__zz_io_penalized_4;
  wire       [15:0]   _zz__zz_io_penalized_4_1;
  wire       [15:0]   _zz__zz_io_penalized_4_2;
  wire       [15:0]   _zz__zz_io_penalized_4_3;
  wire       [15:0]   _zz__zz_when_Fp16RepetitionPenalty_l57;
  wire       [15:0]   _zz__zz_when_Fp16RepetitionPenalty_l57_1;
  wire       [15:0]   _zz__zz_when_Fp16RepetitionPenalty_l57_2;
  wire       [15:0]   _zz__zz_when_Fp16RepetitionPenalty_l57_3;
  wire       [9:0]    _zz__zz_io_penalized_1_7;
  wire       [4:0]    _zz__zz_io_penalized_1_8;
  wire       [9:0]    _zz__zz_io_penalized_1_9;
  wire       [4:0]    _zz_when_Fp16RepetitionPenalty_l28;
  wire       [10:0]   _zz_when_Fp16RepetitionPenalty_l51;
  reg        [15:0]   _zz_io_penalized;
  reg        [14:0]   _zz_io_penalized_1;
  wire                when_Fp16RepetitionPenalty_l28;
  wire                when_Fp16RepetitionPenalty_l29;
  wire       [14:0]   _zz_when_Fp16RepetitionPenalty_l38;
  wire       [11:0]   _zz_when_Fp16RepetitionPenalty_l40;
  wire       [11:0]   _zz_when_Fp16RepetitionPenalty_l40_1;
  wire       [11:0]   _zz_io_penalized_2;
  wire       [5:0]    _zz_io_penalized_3;
  wire                when_Fp16RepetitionPenalty_l34;
  wire                when_Fp16RepetitionPenalty_l38;
  wire                when_Fp16RepetitionPenalty_l40;
  wire                when_Fp16RepetitionPenalty_l43;
  wire       [11:0]   _zz_io_penalized_4;
  wire       [11:0]   _zz_when_Fp16RepetitionPenalty_l57;
  wire                when_Fp16RepetitionPenalty_l51;
  wire                when_Fp16RepetitionPenalty_l55;
  wire                when_Fp16RepetitionPenalty_l57;

  assign _zz__zz_when_Fp16RepetitionPenalty_l38 = (_zz__zz_when_Fp16RepetitionPenalty_l38_1 <<< 3);
  assign _zz__zz_when_Fp16RepetitionPenalty_l38_1 = {4'd0, _zz_when_Fp16RepetitionPenalty_l51};
  assign _zz__zz_when_Fp16RepetitionPenalty_l38_2 = {4'd0, _zz_when_Fp16RepetitionPenalty_l51};
  assign _zz__zz_when_Fp16RepetitionPenalty_l40_1_1 = (_zz_when_Fp16RepetitionPenalty_l38[2] && ((|_zz_when_Fp16RepetitionPenalty_l38[1 : 0]) || _zz_when_Fp16RepetitionPenalty_l40[0]));
  assign _zz__zz_when_Fp16RepetitionPenalty_l40_1 = {11'd0, _zz__zz_when_Fp16RepetitionPenalty_l40_1_1};
  assign _zz__zz_io_penalized_2 = (_zz_when_Fp16RepetitionPenalty_l38 >>> 3'd4);
  assign _zz__zz_io_penalized_3 = {1'd0, _zz_when_Fp16RepetitionPenalty_l28};
  assign _zz__zz_io_penalized_1 = _zz_when_Fp16RepetitionPenalty_l40_1[9:0];
  assign _zz__zz_io_penalized_1_1 = _zz_io_penalized_3[4:0];
  assign _zz__zz_io_penalized_1_3 = (_zz_io_penalized_2 + _zz__zz_io_penalized_1_4);
  assign _zz__zz_io_penalized_1_2 = _zz__zz_io_penalized_1_3[9:0];
  assign _zz__zz_io_penalized_1_5 = (_zz_when_Fp16RepetitionPenalty_l38[3] && ((|_zz_when_Fp16RepetitionPenalty_l38[2 : 0]) || _zz_io_penalized_2[0]));
  assign _zz__zz_io_penalized_1_4 = {11'd0, _zz__zz_io_penalized_1_5};
  assign _zz__zz_io_penalized_1_6 = _zz_io_penalized_3[4:0];
  assign _zz__zz_io_penalized_4 = (_zz__zz_io_penalized_4_1 / 16'h0009);
  assign _zz__zz_io_penalized_4_1 = (_zz__zz_io_penalized_4_2 + 16'h0004);
  assign _zz__zz_io_penalized_4_2 = (_zz__zz_io_penalized_4_3 <<< 3);
  assign _zz__zz_io_penalized_4_3 = {5'd0, _zz_when_Fp16RepetitionPenalty_l51};
  assign _zz__zz_when_Fp16RepetitionPenalty_l57 = (_zz__zz_when_Fp16RepetitionPenalty_l57_1 / 16'h0009);
  assign _zz__zz_when_Fp16RepetitionPenalty_l57_1 = (_zz__zz_when_Fp16RepetitionPenalty_l57_2 + 16'h0004);
  assign _zz__zz_when_Fp16RepetitionPenalty_l57_2 = (_zz__zz_when_Fp16RepetitionPenalty_l57_3 <<< 4);
  assign _zz__zz_when_Fp16RepetitionPenalty_l57_3 = {5'd0, _zz_when_Fp16RepetitionPenalty_l51};
  assign _zz__zz_io_penalized_1_7 = _zz_io_penalized_4[9:0];
  assign _zz__zz_io_penalized_1_8 = (_zz_when_Fp16RepetitionPenalty_l28 - 5'h01);
  assign _zz__zz_io_penalized_1_9 = _zz_when_Fp16RepetitionPenalty_l57[9:0];
  assign _zz_when_Fp16RepetitionPenalty_l28 = io_value[14 : 10];
  assign _zz_when_Fp16RepetitionPenalty_l51 = {(_zz_when_Fp16RepetitionPenalty_l28 != 5'h0),io_value[9 : 0]};
  always @(*) begin
    _zz_io_penalized = io_value;
    if(when_Fp16RepetitionPenalty_l28) begin
      _zz_io_penalized = {io_value[15],_zz_io_penalized_1};
    end
  end

  always @(*) begin
    _zz_io_penalized_1 = io_value[14 : 0];
    if(when_Fp16RepetitionPenalty_l28) begin
      if(when_Fp16RepetitionPenalty_l29) begin
        if(when_Fp16RepetitionPenalty_l34) begin
          _zz_io_penalized_1 = {3'd0, _zz_when_Fp16RepetitionPenalty_l40_1};
        end else begin
          _zz_io_penalized_1 = {_zz_when_Fp16RepetitionPenalty_l28,_zz__zz_io_penalized_1};
          if(when_Fp16RepetitionPenalty_l38) begin
            _zz_io_penalized_1 = {_zz__zz_io_penalized_1_1,_zz__zz_io_penalized_1_2};
          end else begin
            if(when_Fp16RepetitionPenalty_l40) begin
              _zz_io_penalized_1 = {_zz__zz_io_penalized_1_6,10'h0};
            end
          end
          if(when_Fp16RepetitionPenalty_l43) begin
            _zz_io_penalized_1 = 15'h7c00;
          end
        end
      end else begin
        if(when_Fp16RepetitionPenalty_l51) begin
          _zz_io_penalized_1 = {3'd0, _zz_io_penalized_4};
        end else begin
          _zz_io_penalized_1 = {_zz_when_Fp16RepetitionPenalty_l28,_zz__zz_io_penalized_1_7};
          if(when_Fp16RepetitionPenalty_l55) begin
            _zz_io_penalized_1 = {_zz__zz_io_penalized_1_8,_zz__zz_io_penalized_1_9};
            if(when_Fp16RepetitionPenalty_l57) begin
              _zz_io_penalized_1 = {_zz_when_Fp16RepetitionPenalty_l28,10'h0};
            end
          end
        end
      end
    end
  end

  assign when_Fp16RepetitionPenalty_l28 = (_zz_when_Fp16RepetitionPenalty_l28 != 5'h1f);
  assign when_Fp16RepetitionPenalty_l29 = io_value[15];
  assign _zz_when_Fp16RepetitionPenalty_l38 = (_zz__zz_when_Fp16RepetitionPenalty_l38 + _zz__zz_when_Fp16RepetitionPenalty_l38_2);
  assign _zz_when_Fp16RepetitionPenalty_l40 = (_zz_when_Fp16RepetitionPenalty_l38 >>> 2'd3);
  assign _zz_when_Fp16RepetitionPenalty_l40_1 = (_zz_when_Fp16RepetitionPenalty_l40 + _zz__zz_when_Fp16RepetitionPenalty_l40_1);
  assign _zz_io_penalized_2 = {1'd0, _zz__zz_io_penalized_2};
  assign _zz_io_penalized_3 = (_zz__zz_io_penalized_3 + 6'h01);
  assign when_Fp16RepetitionPenalty_l34 = (_zz_when_Fp16RepetitionPenalty_l28 == 5'h0);
  assign when_Fp16RepetitionPenalty_l38 = (15'h4000 <= _zz_when_Fp16RepetitionPenalty_l38);
  assign when_Fp16RepetitionPenalty_l40 = (12'h800 <= _zz_when_Fp16RepetitionPenalty_l40_1);
  assign when_Fp16RepetitionPenalty_l43 = ((_zz_when_Fp16RepetitionPenalty_l28 == 5'h1e) && ((15'h4000 <= _zz_when_Fp16RepetitionPenalty_l38) || (12'h800 <= _zz_when_Fp16RepetitionPenalty_l40_1)));
  assign _zz_io_penalized_4 = _zz__zz_io_penalized_4[11:0];
  assign _zz_when_Fp16RepetitionPenalty_l57 = _zz__zz_when_Fp16RepetitionPenalty_l57[11:0];
  assign when_Fp16RepetitionPenalty_l51 = ((_zz_when_Fp16RepetitionPenalty_l28 == 5'h0) || ((_zz_when_Fp16RepetitionPenalty_l28 == 5'h01) && (_zz_when_Fp16RepetitionPenalty_l51 < 11'h480)));
  assign when_Fp16RepetitionPenalty_l55 = (_zz_when_Fp16RepetitionPenalty_l51 < 11'h480);
  assign when_Fp16RepetitionPenalty_l57 = (12'h800 <= _zz_when_Fp16RepetitionPenalty_l57);
  assign io_penalized = _zz_io_penalized;

endmodule
