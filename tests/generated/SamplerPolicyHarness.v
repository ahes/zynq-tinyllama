// Generator : SpinalHDL v1.11.0    git head : 63852c61e498798f4e293594ce53fcb02c45eb6b
// Component : SamplerPolicyHarness
// Git hash  : 60e0cb867717bfa3a0e283f1669841e232f15d04

`timescale 1ns/1ps

module SamplerPolicyHarness (
  input  wire          io_valid,
  input  wire [5:0]    io_tag,
  input  wire [15:0]   io_value,
  output wire          io_resultValid,
  output wire [15:0]   io_result,
  output wire          io_legacyValid,
  output wire [15:0]   io_legacy,
  input  wire          clk,
  input  wire          reset
);

  wire                greedySampler_2_argmax_tvalid;
  wire       [15:0]   greedySampler_2_argmax_tdata;
  wire                greedySampler_2_endOfDecode;
  wire       [31:0]   greedySampler_2_diagResult;
  wire       [31:0]   greedySampler_2_diagLogits;
  wire                greedySampler_3_argmax_tvalid;
  wire       [15:0]   greedySampler_3_argmax_tdata;
  wire                greedySampler_3_endOfDecode;
  wire       [31:0]   greedySampler_3_diagResult;
  wire       [31:0]   greedySampler_3_diagLogits;

  GreedySampler greedySampler_2 (
    .logits_valid  (io_valid                          ), //i
    .logits_tdata  (io_value[15:0]                    ), //i
    .logits_tuser  (io_tag[5:0]                       ), //i
    .argmax_tvalid (greedySampler_2_argmax_tvalid     ), //o
    .argmax_tdata  (greedySampler_2_argmax_tdata[15:0]), //o
    .endOfDecode   (greedySampler_2_endOfDecode       ), //o
    .diagResult    (greedySampler_2_diagResult[31:0]  ), //o
    .diagLogits    (greedySampler_2_diagLogits[31:0]  ), //o
    .clk           (clk                               ), //i
    .reset         (reset                             )  //i
  );
  GreedySampler_1 greedySampler_3 (
    .logits_valid  (io_valid                          ), //i
    .logits_tdata  (io_value[15:0]                    ), //i
    .logits_tuser  (io_tag[5:0]                       ), //i
    .argmax_tvalid (greedySampler_3_argmax_tvalid     ), //o
    .argmax_tdata  (greedySampler_3_argmax_tdata[15:0]), //o
    .endOfDecode   (greedySampler_3_endOfDecode       ), //o
    .diagResult    (greedySampler_3_diagResult[31:0]  ), //o
    .diagLogits    (greedySampler_3_diagLogits[31:0]  ), //o
    .clk           (clk                               ), //i
    .reset         (reset                             )  //i
  );
  assign io_legacyValid = greedySampler_2_argmax_tvalid;
  assign io_legacy = greedySampler_2_argmax_tdata;
  assign io_resultValid = greedySampler_3_argmax_tvalid;
  assign io_result = greedySampler_3_argmax_tdata;

endmodule

module GreedySampler_1 (
  input  wire          logits_valid,
  input  wire [15:0]   logits_tdata,
  input  wire [5:0]    logits_tuser,
  output wire          argmax_tvalid,
  output wire [15:0]   argmax_tdata,
  output wire          endOfDecode,
  output wire [31:0]   diagResult,
  output wire [31:0]   diagLogits,
  input  wire          clk,
  input  wire          reset
);

  wire                _zz_when_GreedySampler_l66_129;
  wire                _zz_when_GreedySampler_l66_130;
  wire                _zz_when_GreedySampler_l66_131;
  wire                _zz_when_GreedySampler_l66_132;
  wire                _zz_when_GreedySampler_l66_133;
  wire                _zz_when_GreedySampler_l66_134;
  wire                _zz_when_GreedySampler_l66_135;
  wire                _zz_when_GreedySampler_l66_136;
  wire                _zz_when_GreedySampler_l66_137;
  wire                _zz_when_GreedySampler_l66_138;
  wire                _zz_when_GreedySampler_l66_139;
  wire                _zz_when_GreedySampler_l66_140;
  wire                _zz_when_GreedySampler_l66_141;
  wire                _zz_when_GreedySampler_l66_142;
  wire                _zz_when_GreedySampler_l66_143;
  wire                _zz_when_GreedySampler_l66_144;
  wire                _zz_when_GreedySampler_l66_145;
  wire                _zz_when_GreedySampler_l66_146;
  wire                _zz_when_GreedySampler_l66_147;
  wire                _zz_when_GreedySampler_l66_148;
  wire                _zz_when_GreedySampler_l66_149;
  wire                _zz_when_GreedySampler_l66_150;
  wire                _zz_when_GreedySampler_l66_151;
  wire                _zz_when_GreedySampler_l66_152;
  wire       [7:0]    _zz_when_GreedySampler_l66_153;
  wire                _zz_when_GreedySampler_l66_154;
  wire                _zz_when_GreedySampler_l66_155;
  wire                _zz_when_GreedySampler_l66_156;
  wire       [7:0]    _zz_when_GreedySampler_l66_157;
  wire                _zz_when_GreedySampler_l66_158;
  wire                _zz_when_GreedySampler_l66_159;
  wire                _zz_when_GreedySampler_l66_160;
  wire       [7:0]    _zz_when_GreedySampler_l66_161;
  wire                _zz_when_GreedySampler_l66_162;
  wire                _zz_when_GreedySampler_l66_163;
  wire                _zz_when_GreedySampler_l66_164;
  wire       [7:0]    _zz_when_GreedySampler_l66_165;
  wire                _zz_when_GreedySampler_l66_166;
  wire                _zz_when_GreedySampler_l66_167;
  wire                _zz_when_GreedySampler_l66_168;
  wire       [7:0]    _zz_when_GreedySampler_l66_169;
  wire                _zz_when_GreedySampler_l66_170;
  wire                _zz_when_GreedySampler_l66_171;
  wire                _zz_when_GreedySampler_l66_172;
  wire       [7:0]    _zz_when_GreedySampler_l66_173;
  wire                _zz_when_GreedySampler_l66_174;
  wire                _zz_when_GreedySampler_l66_175;
  wire                _zz_when_GreedySampler_l66_176;
  wire       [7:0]    _zz_when_GreedySampler_l66_177;
  wire                _zz_when_GreedySampler_l66_178;
  wire                _zz_when_GreedySampler_l66_179;
  wire                _zz_when_GreedySampler_l66_180;
  wire       [7:0]    _zz_when_GreedySampler_l66_181;
  wire                _zz_when_GreedySampler_l66_182;
  wire                _zz_when_GreedySampler_l66_183;
  wire                _zz_when_GreedySampler_l66_184;
  wire       [7:0]    _zz_when_GreedySampler_l66_185;
  wire                _zz_when_GreedySampler_l66_186;
  wire                _zz_when_GreedySampler_l66_187;
  wire                _zz_when_GreedySampler_l66_188;
  wire       [7:0]    _zz_when_GreedySampler_l66_189;
  wire                _zz_when_GreedySampler_l66_190;
  wire                _zz_when_GreedySampler_l66_191;
  wire                _zz_when_GreedySampler_l66_192;
  wire       [7:0]    _zz_when_GreedySampler_l66_193;
  wire                _zz_when_GreedySampler_l66_194;
  wire                _zz_when_GreedySampler_l66_195;
  wire                _zz_when_GreedySampler_l66_196;
  wire       [7:0]    _zz_when_GreedySampler_l66_197;
  wire                _zz_when_GreedySampler_l66_198;
  wire                _zz_when_GreedySampler_l66_199;
  wire                _zz_when_GreedySampler_l66_200;
  wire       [7:0]    _zz_when_GreedySampler_l66_201;
  wire                _zz_when_GreedySampler_l66_202;
  wire                _zz_when_GreedySampler_l66_203;
  wire                _zz_when_GreedySampler_l66_204;
  wire       [7:0]    _zz_when_GreedySampler_l66_205;
  wire                _zz_when_GreedySampler_l66_206;
  wire                _zz_when_GreedySampler_l66_207;
  wire                _zz_when_GreedySampler_l66_208;
  wire       [7:0]    _zz_when_GreedySampler_l66_209;
  wire                _zz_when_GreedySampler_l66_210;
  wire                _zz_when_GreedySampler_l66_211;
  wire                _zz_when_GreedySampler_l66_212;
  wire       [7:0]    _zz_when_GreedySampler_l66_213;
  wire                _zz_when_GreedySampler_l66_214;
  wire                _zz_when_GreedySampler_l66_215;
  wire                _zz_when_GreedySampler_l66_216;
  wire       [7:0]    _zz_when_GreedySampler_l66_217;
  wire                _zz_when_GreedySampler_l66_218;
  wire                _zz_when_GreedySampler_l66_219;
  wire                _zz_when_GreedySampler_l66_220;
  wire       [7:0]    _zz_when_GreedySampler_l66_221;
  wire                _zz_when_GreedySampler_l66_222;
  wire                _zz_when_GreedySampler_l66_223;
  wire                _zz_when_GreedySampler_l66_224;
  wire       [7:0]    _zz_when_GreedySampler_l66_225;
  wire                _zz_when_GreedySampler_l66_226;
  wire                _zz_when_GreedySampler_l66_227;
  wire                _zz_when_GreedySampler_l66_228;
  wire       [7:0]    _zz_when_GreedySampler_l66_229;
  wire                _zz_when_GreedySampler_l66_230;
  wire                _zz_when_GreedySampler_l66_231;
  wire                _zz_when_GreedySampler_l66_232;
  wire       [7:0]    _zz_when_GreedySampler_l66_233;
  wire       [14:0]   _zz__zz_when_Fp16RepetitionPenalty_l38;
  wire       [14:0]   _zz__zz_when_Fp16RepetitionPenalty_l38_1;
  wire       [14:0]   _zz__zz_when_Fp16RepetitionPenalty_l38_2;
  wire       [11:0]   _zz__zz_when_Fp16RepetitionPenalty_l40_1;
  wire       [0:0]    _zz__zz_when_Fp16RepetitionPenalty_l40_1_1;
  wire       [10:0]   _zz__zz_candidate_payload_2;
  wire       [5:0]    _zz__zz_candidate_payload_3;
  wire       [9:0]    _zz__zz_candidate_payload_1;
  wire       [4:0]    _zz__zz_candidate_payload_1_1;
  wire       [9:0]    _zz__zz_candidate_payload_1_2;
  wire       [11:0]   _zz__zz_candidate_payload_1_3;
  wire       [11:0]   _zz__zz_candidate_payload_1_4;
  wire       [0:0]    _zz__zz_candidate_payload_1_5;
  wire       [4:0]    _zz__zz_candidate_payload_1_6;
  wire       [15:0]   _zz__zz_candidate_payload_4;
  wire       [15:0]   _zz__zz_candidate_payload_4_1;
  wire       [15:0]   _zz__zz_candidate_payload_4_2;
  wire       [15:0]   _zz__zz_candidate_payload_4_3;
  wire       [15:0]   _zz__zz_when_Fp16RepetitionPenalty_l57;
  wire       [15:0]   _zz__zz_when_Fp16RepetitionPenalty_l57_1;
  wire       [15:0]   _zz__zz_when_Fp16RepetitionPenalty_l57_2;
  wire       [15:0]   _zz__zz_when_Fp16RepetitionPenalty_l57_3;
  wire       [9:0]    _zz__zz_candidate_payload_1_7;
  wire       [4:0]    _zz__zz_candidate_payload_1_8;
  wire       [9:0]    _zz__zz_candidate_payload_1_9;
  wire       [15:0]   _zz_nanNext;
  wire       [0:0]    _zz_nanNext_1;
  wire       [15:0]   _zz_indexDly;
  wire       [15:0]   _zz_historyCommit_payload;
  wire                logitsIn_valid;
  wire       [15:0]   logitsIn_payload;
  wire                maxFlow_valid;
  reg        [15:0]   maxFlow_payload;
  reg        [14:0]   cnt;
  wire                cntOvf;
  wire                logitsProbe_tvalid;
  wire                logitsProbe_tlast;
  wire       [15:0]   logitsProbe_tdata;
  wire                candidate_valid;
  reg        [15:0]   candidate_payload;
  wire                historyCommit_valid;
  wire       [14:0]   historyCommit_payload;
  reg        [14:0]   _zz_when_GreedySampler_l66;
  reg        [14:0]   _zz_when_GreedySampler_l66_1;
  reg        [14:0]   _zz_when_GreedySampler_l66_2;
  reg        [14:0]   _zz_when_GreedySampler_l66_3;
  reg        [14:0]   _zz_when_GreedySampler_l66_4;
  reg        [14:0]   _zz_when_GreedySampler_l66_5;
  reg        [14:0]   _zz_when_GreedySampler_l66_6;
  reg        [14:0]   _zz_when_GreedySampler_l66_7;
  reg        [14:0]   _zz_when_GreedySampler_l66_8;
  reg        [14:0]   _zz_when_GreedySampler_l66_9;
  reg        [14:0]   _zz_when_GreedySampler_l66_10;
  reg        [14:0]   _zz_when_GreedySampler_l66_11;
  reg        [14:0]   _zz_when_GreedySampler_l66_12;
  reg        [14:0]   _zz_when_GreedySampler_l66_13;
  reg        [14:0]   _zz_when_GreedySampler_l66_14;
  reg        [14:0]   _zz_when_GreedySampler_l66_15;
  reg        [14:0]   _zz_when_GreedySampler_l66_16;
  reg        [14:0]   _zz_when_GreedySampler_l66_17;
  reg        [14:0]   _zz_when_GreedySampler_l66_18;
  reg        [14:0]   _zz_when_GreedySampler_l66_19;
  reg        [14:0]   _zz_when_GreedySampler_l66_20;
  reg        [14:0]   _zz_when_GreedySampler_l66_21;
  reg        [14:0]   _zz_when_GreedySampler_l66_22;
  reg        [14:0]   _zz_when_GreedySampler_l66_23;
  reg        [14:0]   _zz_when_GreedySampler_l66_24;
  reg        [14:0]   _zz_when_GreedySampler_l66_25;
  reg        [14:0]   _zz_when_GreedySampler_l66_26;
  reg        [14:0]   _zz_when_GreedySampler_l66_27;
  reg        [14:0]   _zz_when_GreedySampler_l66_28;
  reg        [14:0]   _zz_when_GreedySampler_l66_29;
  reg        [14:0]   _zz_when_GreedySampler_l66_30;
  reg        [14:0]   _zz_when_GreedySampler_l66_31;
  reg        [14:0]   _zz_when_GreedySampler_l66_32;
  reg        [14:0]   _zz_when_GreedySampler_l66_33;
  reg        [14:0]   _zz_when_GreedySampler_l66_34;
  reg        [14:0]   _zz_when_GreedySampler_l66_35;
  reg        [14:0]   _zz_when_GreedySampler_l66_36;
  reg        [14:0]   _zz_when_GreedySampler_l66_37;
  reg        [14:0]   _zz_when_GreedySampler_l66_38;
  reg        [14:0]   _zz_when_GreedySampler_l66_39;
  reg        [14:0]   _zz_when_GreedySampler_l66_40;
  reg        [14:0]   _zz_when_GreedySampler_l66_41;
  reg        [14:0]   _zz_when_GreedySampler_l66_42;
  reg        [14:0]   _zz_when_GreedySampler_l66_43;
  reg        [14:0]   _zz_when_GreedySampler_l66_44;
  reg        [14:0]   _zz_when_GreedySampler_l66_45;
  reg        [14:0]   _zz_when_GreedySampler_l66_46;
  reg        [14:0]   _zz_when_GreedySampler_l66_47;
  reg        [14:0]   _zz_when_GreedySampler_l66_48;
  reg        [14:0]   _zz_when_GreedySampler_l66_49;
  reg        [14:0]   _zz_when_GreedySampler_l66_50;
  reg        [14:0]   _zz_when_GreedySampler_l66_51;
  reg        [14:0]   _zz_when_GreedySampler_l66_52;
  reg        [14:0]   _zz_when_GreedySampler_l66_53;
  reg        [14:0]   _zz_when_GreedySampler_l66_54;
  reg        [14:0]   _zz_when_GreedySampler_l66_55;
  reg        [14:0]   _zz_when_GreedySampler_l66_56;
  reg        [14:0]   _zz_when_GreedySampler_l66_57;
  reg        [14:0]   _zz_when_GreedySampler_l66_58;
  reg        [14:0]   _zz_when_GreedySampler_l66_59;
  reg        [14:0]   _zz_when_GreedySampler_l66_60;
  reg        [14:0]   _zz_when_GreedySampler_l66_61;
  reg        [14:0]   _zz_when_GreedySampler_l66_62;
  reg        [14:0]   _zz_when_GreedySampler_l66_63;
  reg        [14:0]   _zz_when_GreedySampler_l66_64;
  reg        [14:0]   _zz_when_GreedySampler_l66_65;
  reg        [14:0]   _zz_when_GreedySampler_l66_66;
  reg        [14:0]   _zz_when_GreedySampler_l66_67;
  reg        [14:0]   _zz_when_GreedySampler_l66_68;
  reg        [14:0]   _zz_when_GreedySampler_l66_69;
  reg        [14:0]   _zz_when_GreedySampler_l66_70;
  reg        [14:0]   _zz_when_GreedySampler_l66_71;
  reg        [14:0]   _zz_when_GreedySampler_l66_72;
  reg        [14:0]   _zz_when_GreedySampler_l66_73;
  reg        [14:0]   _zz_when_GreedySampler_l66_74;
  reg        [14:0]   _zz_when_GreedySampler_l66_75;
  reg        [14:0]   _zz_when_GreedySampler_l66_76;
  reg        [14:0]   _zz_when_GreedySampler_l66_77;
  reg        [14:0]   _zz_when_GreedySampler_l66_78;
  reg        [14:0]   _zz_when_GreedySampler_l66_79;
  reg        [14:0]   _zz_when_GreedySampler_l66_80;
  reg        [14:0]   _zz_when_GreedySampler_l66_81;
  reg        [14:0]   _zz_when_GreedySampler_l66_82;
  reg        [14:0]   _zz_when_GreedySampler_l66_83;
  reg        [14:0]   _zz_when_GreedySampler_l66_84;
  reg        [14:0]   _zz_when_GreedySampler_l66_85;
  reg        [14:0]   _zz_when_GreedySampler_l66_86;
  reg        [14:0]   _zz_when_GreedySampler_l66_87;
  reg        [14:0]   _zz_when_GreedySampler_l66_88;
  reg        [14:0]   _zz_when_GreedySampler_l66_89;
  reg        [14:0]   _zz_when_GreedySampler_l66_90;
  reg        [14:0]   _zz_when_GreedySampler_l66_91;
  reg        [14:0]   _zz_when_GreedySampler_l66_92;
  reg        [14:0]   _zz_when_GreedySampler_l66_93;
  reg        [14:0]   _zz_when_GreedySampler_l66_94;
  reg        [14:0]   _zz_when_GreedySampler_l66_95;
  reg        [14:0]   _zz_when_GreedySampler_l66_96;
  reg        [14:0]   _zz_when_GreedySampler_l66_97;
  reg        [14:0]   _zz_when_GreedySampler_l66_98;
  reg        [14:0]   _zz_when_GreedySampler_l66_99;
  reg        [14:0]   _zz_when_GreedySampler_l66_100;
  reg        [14:0]   _zz_when_GreedySampler_l66_101;
  reg        [14:0]   _zz_when_GreedySampler_l66_102;
  reg        [14:0]   _zz_when_GreedySampler_l66_103;
  reg        [14:0]   _zz_when_GreedySampler_l66_104;
  reg        [14:0]   _zz_when_GreedySampler_l66_105;
  reg        [14:0]   _zz_when_GreedySampler_l66_106;
  reg        [14:0]   _zz_when_GreedySampler_l66_107;
  reg        [14:0]   _zz_when_GreedySampler_l66_108;
  reg        [14:0]   _zz_when_GreedySampler_l66_109;
  reg        [14:0]   _zz_when_GreedySampler_l66_110;
  reg        [14:0]   _zz_when_GreedySampler_l66_111;
  reg        [14:0]   _zz_when_GreedySampler_l66_112;
  reg        [14:0]   _zz_when_GreedySampler_l66_113;
  reg        [14:0]   _zz_when_GreedySampler_l66_114;
  reg        [14:0]   _zz_when_GreedySampler_l66_115;
  reg        [14:0]   _zz_when_GreedySampler_l66_116;
  reg        [14:0]   _zz_when_GreedySampler_l66_117;
  reg        [14:0]   _zz_when_GreedySampler_l66_118;
  reg        [14:0]   _zz_when_GreedySampler_l66_119;
  reg        [14:0]   _zz_when_GreedySampler_l66_120;
  reg        [14:0]   _zz_when_GreedySampler_l66_121;
  reg        [14:0]   _zz_when_GreedySampler_l66_122;
  reg        [14:0]   _zz_when_GreedySampler_l66_123;
  reg        [14:0]   _zz_when_GreedySampler_l66_124;
  reg        [14:0]   _zz_when_GreedySampler_l66_125;
  reg        [14:0]   _zz_when_GreedySampler_l66_126;
  reg        [14:0]   _zz_when_GreedySampler_l66_127;
  reg        [7:0]    _zz_when_GreedySampler_l66_128;
  reg        [6:0]    _zz_1;
  wire                when_GreedySampler_l66;
  wire       [4:0]    _zz_when_Fp16RepetitionPenalty_l28;
  wire       [10:0]   _zz_when_Fp16RepetitionPenalty_l51;
  reg        [15:0]   _zz_candidate_payload;
  reg        [14:0]   _zz_candidate_payload_1;
  wire                when_Fp16RepetitionPenalty_l28;
  wire                when_Fp16RepetitionPenalty_l29;
  wire       [14:0]   _zz_when_Fp16RepetitionPenalty_l38;
  wire       [11:0]   _zz_when_Fp16RepetitionPenalty_l40;
  wire       [11:0]   _zz_when_Fp16RepetitionPenalty_l40_1;
  wire       [11:0]   _zz_candidate_payload_2;
  wire       [5:0]    _zz_candidate_payload_3;
  wire                when_Fp16RepetitionPenalty_l34;
  wire                when_Fp16RepetitionPenalty_l38;
  wire                when_Fp16RepetitionPenalty_l40;
  wire                when_Fp16RepetitionPenalty_l43;
  wire       [11:0]   _zz_candidate_payload_4;
  wire       [11:0]   _zz_when_Fp16RepetitionPenalty_l57;
  wire                when_Fp16RepetitionPenalty_l51;
  wire                when_Fp16RepetitionPenalty_l55;
  wire                when_Fp16RepetitionPenalty_l57;
  wire       [127:0]  _zz_2;
  wire                when_GreedySampler_l72;
  wire                xGreaterThanMax_valid;
  reg                 xGreaterThanMax_payload;
  wire       [14:0]   _zz_xGreaterThanMax_payload;
  wire       [14:0]   _zz_xGreaterThanMax_payload_1;
  wire                when_SamplerPolicyHarness_l24;
  wire                when_SamplerPolicyHarness_l25;
  reg        [14:0]   index;
  reg        [14:0]   indexNext;
  reg        [15:0]   maxNext;
  wire                vld;
  reg        [15:0]   nanCount;
  wire                isNan;
  wire       [15:0]   nanNext;
  reg        [15:0]   firstLogit;
  reg        [31:0]   resultProbe;
  reg        [31:0]   logitsProbeLock;
  wire                when_GreedySampler_l111;
  reg                 vldDly;
  reg        [15:0]   indexDly;
  wire                argmax_valid;
  wire       [15:0]   argmax_payload;

  assign _zz__zz_when_Fp16RepetitionPenalty_l38 = (_zz__zz_when_Fp16RepetitionPenalty_l38_1 <<< 3);
  assign _zz__zz_when_Fp16RepetitionPenalty_l38_1 = {4'd0, _zz_when_Fp16RepetitionPenalty_l51};
  assign _zz__zz_when_Fp16RepetitionPenalty_l38_2 = {4'd0, _zz_when_Fp16RepetitionPenalty_l51};
  assign _zz__zz_when_Fp16RepetitionPenalty_l40_1_1 = (_zz_when_Fp16RepetitionPenalty_l38[2] && ((|_zz_when_Fp16RepetitionPenalty_l38[1 : 0]) || _zz_when_Fp16RepetitionPenalty_l40[0]));
  assign _zz__zz_when_Fp16RepetitionPenalty_l40_1 = {11'd0, _zz__zz_when_Fp16RepetitionPenalty_l40_1_1};
  assign _zz__zz_candidate_payload_2 = (_zz_when_Fp16RepetitionPenalty_l38 >>> 3'd4);
  assign _zz__zz_candidate_payload_3 = {1'd0, _zz_when_Fp16RepetitionPenalty_l28};
  assign _zz__zz_candidate_payload_1 = _zz_when_Fp16RepetitionPenalty_l40_1[9:0];
  assign _zz__zz_candidate_payload_1_1 = _zz_candidate_payload_3[4:0];
  assign _zz__zz_candidate_payload_1_3 = (_zz_candidate_payload_2 + _zz__zz_candidate_payload_1_4);
  assign _zz__zz_candidate_payload_1_2 = _zz__zz_candidate_payload_1_3[9:0];
  assign _zz__zz_candidate_payload_1_5 = (_zz_when_Fp16RepetitionPenalty_l38[3] && ((|_zz_when_Fp16RepetitionPenalty_l38[2 : 0]) || _zz_candidate_payload_2[0]));
  assign _zz__zz_candidate_payload_1_4 = {11'd0, _zz__zz_candidate_payload_1_5};
  assign _zz__zz_candidate_payload_1_6 = _zz_candidate_payload_3[4:0];
  assign _zz__zz_candidate_payload_4 = (_zz__zz_candidate_payload_4_1 / 16'h0009);
  assign _zz__zz_candidate_payload_4_1 = (_zz__zz_candidate_payload_4_2 + 16'h0004);
  assign _zz__zz_candidate_payload_4_2 = (_zz__zz_candidate_payload_4_3 <<< 3);
  assign _zz__zz_candidate_payload_4_3 = {5'd0, _zz_when_Fp16RepetitionPenalty_l51};
  assign _zz__zz_when_Fp16RepetitionPenalty_l57 = (_zz__zz_when_Fp16RepetitionPenalty_l57_1 / 16'h0009);
  assign _zz__zz_when_Fp16RepetitionPenalty_l57_1 = (_zz__zz_when_Fp16RepetitionPenalty_l57_2 + 16'h0004);
  assign _zz__zz_when_Fp16RepetitionPenalty_l57_2 = (_zz__zz_when_Fp16RepetitionPenalty_l57_3 <<< 4);
  assign _zz__zz_when_Fp16RepetitionPenalty_l57_3 = {5'd0, _zz_when_Fp16RepetitionPenalty_l51};
  assign _zz__zz_candidate_payload_1_7 = _zz_candidate_payload_4[9:0];
  assign _zz__zz_candidate_payload_1_8 = (_zz_when_Fp16RepetitionPenalty_l28 - 5'h01);
  assign _zz__zz_candidate_payload_1_9 = _zz_when_Fp16RepetitionPenalty_l57[9:0];
  assign _zz_nanNext_1 = isNan;
  assign _zz_nanNext = {15'd0, _zz_nanNext_1};
  assign _zz_indexDly = {1'd0, indexNext};
  assign _zz_historyCommit_payload = indexDly;
  assign _zz_when_GreedySampler_l66_129 = ((((((_zz_when_GreedySampler_l66_130 || _zz_when_GreedySampler_l66_226) || (_zz_when_GreedySampler_l66_227 && _zz_when_GreedySampler_l66_228)) || ((_zz_when_GreedySampler_l66_229 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_119 == cnt))) || ((8'h78 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_120 == cnt))) || ((8'h79 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_121 == cnt))) || ((8'h7a < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_122 == cnt)));
  assign _zz_when_GreedySampler_l66_230 = ((8'h7b < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_123 == cnt));
  assign _zz_when_GreedySampler_l66_231 = (8'h7c < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_232 = (_zz_when_GreedySampler_l66_124 == cnt);
  assign _zz_when_GreedySampler_l66_233 = 8'h7d;
  assign _zz_when_GreedySampler_l66_130 = ((((((_zz_when_GreedySampler_l66_131 || _zz_when_GreedySampler_l66_222) || (_zz_when_GreedySampler_l66_223 && _zz_when_GreedySampler_l66_224)) || ((_zz_when_GreedySampler_l66_225 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_113 == cnt))) || ((8'h72 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_114 == cnt))) || ((8'h73 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_115 == cnt))) || ((8'h74 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_116 == cnt)));
  assign _zz_when_GreedySampler_l66_226 = ((8'h75 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_117 == cnt));
  assign _zz_when_GreedySampler_l66_227 = (8'h76 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_228 = (_zz_when_GreedySampler_l66_118 == cnt);
  assign _zz_when_GreedySampler_l66_229 = 8'h77;
  assign _zz_when_GreedySampler_l66_131 = ((((((_zz_when_GreedySampler_l66_132 || _zz_when_GreedySampler_l66_218) || (_zz_when_GreedySampler_l66_219 && _zz_when_GreedySampler_l66_220)) || ((_zz_when_GreedySampler_l66_221 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_107 == cnt))) || ((8'h6c < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_108 == cnt))) || ((8'h6d < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_109 == cnt))) || ((8'h6e < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_110 == cnt)));
  assign _zz_when_GreedySampler_l66_222 = ((8'h6f < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_111 == cnt));
  assign _zz_when_GreedySampler_l66_223 = (8'h70 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_224 = (_zz_when_GreedySampler_l66_112 == cnt);
  assign _zz_when_GreedySampler_l66_225 = 8'h71;
  assign _zz_when_GreedySampler_l66_132 = ((((((_zz_when_GreedySampler_l66_133 || _zz_when_GreedySampler_l66_214) || (_zz_when_GreedySampler_l66_215 && _zz_when_GreedySampler_l66_216)) || ((_zz_when_GreedySampler_l66_217 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_101 == cnt))) || ((8'h66 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_102 == cnt))) || ((8'h67 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_103 == cnt))) || ((8'h68 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_104 == cnt)));
  assign _zz_when_GreedySampler_l66_218 = ((8'h69 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_105 == cnt));
  assign _zz_when_GreedySampler_l66_219 = (8'h6a < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_220 = (_zz_when_GreedySampler_l66_106 == cnt);
  assign _zz_when_GreedySampler_l66_221 = 8'h6b;
  assign _zz_when_GreedySampler_l66_133 = ((((((_zz_when_GreedySampler_l66_134 || _zz_when_GreedySampler_l66_210) || (_zz_when_GreedySampler_l66_211 && _zz_when_GreedySampler_l66_212)) || ((_zz_when_GreedySampler_l66_213 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_95 == cnt))) || ((8'h60 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_96 == cnt))) || ((8'h61 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_97 == cnt))) || ((8'h62 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_98 == cnt)));
  assign _zz_when_GreedySampler_l66_214 = ((8'h63 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_99 == cnt));
  assign _zz_when_GreedySampler_l66_215 = (8'h64 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_216 = (_zz_when_GreedySampler_l66_100 == cnt);
  assign _zz_when_GreedySampler_l66_217 = 8'h65;
  assign _zz_when_GreedySampler_l66_134 = ((((((_zz_when_GreedySampler_l66_135 || _zz_when_GreedySampler_l66_206) || (_zz_when_GreedySampler_l66_207 && _zz_when_GreedySampler_l66_208)) || ((_zz_when_GreedySampler_l66_209 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_89 == cnt))) || ((8'h5a < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_90 == cnt))) || ((8'h5b < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_91 == cnt))) || ((8'h5c < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_92 == cnt)));
  assign _zz_when_GreedySampler_l66_210 = ((8'h5d < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_93 == cnt));
  assign _zz_when_GreedySampler_l66_211 = (8'h5e < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_212 = (_zz_when_GreedySampler_l66_94 == cnt);
  assign _zz_when_GreedySampler_l66_213 = 8'h5f;
  assign _zz_when_GreedySampler_l66_135 = ((((((_zz_when_GreedySampler_l66_136 || _zz_when_GreedySampler_l66_202) || (_zz_when_GreedySampler_l66_203 && _zz_when_GreedySampler_l66_204)) || ((_zz_when_GreedySampler_l66_205 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_83 == cnt))) || ((8'h54 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_84 == cnt))) || ((8'h55 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_85 == cnt))) || ((8'h56 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_86 == cnt)));
  assign _zz_when_GreedySampler_l66_206 = ((8'h57 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_87 == cnt));
  assign _zz_when_GreedySampler_l66_207 = (8'h58 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_208 = (_zz_when_GreedySampler_l66_88 == cnt);
  assign _zz_when_GreedySampler_l66_209 = 8'h59;
  assign _zz_when_GreedySampler_l66_136 = ((((((_zz_when_GreedySampler_l66_137 || _zz_when_GreedySampler_l66_198) || (_zz_when_GreedySampler_l66_199 && _zz_when_GreedySampler_l66_200)) || ((_zz_when_GreedySampler_l66_201 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_77 == cnt))) || ((8'h4e < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_78 == cnt))) || ((8'h4f < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_79 == cnt))) || ((8'h50 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_80 == cnt)));
  assign _zz_when_GreedySampler_l66_202 = ((8'h51 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_81 == cnt));
  assign _zz_when_GreedySampler_l66_203 = (8'h52 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_204 = (_zz_when_GreedySampler_l66_82 == cnt);
  assign _zz_when_GreedySampler_l66_205 = 8'h53;
  assign _zz_when_GreedySampler_l66_137 = ((((((_zz_when_GreedySampler_l66_138 || _zz_when_GreedySampler_l66_194) || (_zz_when_GreedySampler_l66_195 && _zz_when_GreedySampler_l66_196)) || ((_zz_when_GreedySampler_l66_197 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_71 == cnt))) || ((8'h48 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_72 == cnt))) || ((8'h49 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_73 == cnt))) || ((8'h4a < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_74 == cnt)));
  assign _zz_when_GreedySampler_l66_198 = ((8'h4b < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_75 == cnt));
  assign _zz_when_GreedySampler_l66_199 = (8'h4c < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_200 = (_zz_when_GreedySampler_l66_76 == cnt);
  assign _zz_when_GreedySampler_l66_201 = 8'h4d;
  assign _zz_when_GreedySampler_l66_138 = ((((((_zz_when_GreedySampler_l66_139 || _zz_when_GreedySampler_l66_190) || (_zz_when_GreedySampler_l66_191 && _zz_when_GreedySampler_l66_192)) || ((_zz_when_GreedySampler_l66_193 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_65 == cnt))) || ((8'h42 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_66 == cnt))) || ((8'h43 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_67 == cnt))) || ((8'h44 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_68 == cnt)));
  assign _zz_when_GreedySampler_l66_194 = ((8'h45 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_69 == cnt));
  assign _zz_when_GreedySampler_l66_195 = (8'h46 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_196 = (_zz_when_GreedySampler_l66_70 == cnt);
  assign _zz_when_GreedySampler_l66_197 = 8'h47;
  assign _zz_when_GreedySampler_l66_139 = ((((((_zz_when_GreedySampler_l66_140 || _zz_when_GreedySampler_l66_186) || (_zz_when_GreedySampler_l66_187 && _zz_when_GreedySampler_l66_188)) || ((_zz_when_GreedySampler_l66_189 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_59 == cnt))) || ((8'h3c < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_60 == cnt))) || ((8'h3d < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_61 == cnt))) || ((8'h3e < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_62 == cnt)));
  assign _zz_when_GreedySampler_l66_190 = ((8'h3f < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_63 == cnt));
  assign _zz_when_GreedySampler_l66_191 = (8'h40 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_192 = (_zz_when_GreedySampler_l66_64 == cnt);
  assign _zz_when_GreedySampler_l66_193 = 8'h41;
  assign _zz_when_GreedySampler_l66_140 = ((((((_zz_when_GreedySampler_l66_141 || _zz_when_GreedySampler_l66_182) || (_zz_when_GreedySampler_l66_183 && _zz_when_GreedySampler_l66_184)) || ((_zz_when_GreedySampler_l66_185 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_53 == cnt))) || ((8'h36 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_54 == cnt))) || ((8'h37 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_55 == cnt))) || ((8'h38 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_56 == cnt)));
  assign _zz_when_GreedySampler_l66_186 = ((8'h39 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_57 == cnt));
  assign _zz_when_GreedySampler_l66_187 = (8'h3a < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_188 = (_zz_when_GreedySampler_l66_58 == cnt);
  assign _zz_when_GreedySampler_l66_189 = 8'h3b;
  assign _zz_when_GreedySampler_l66_141 = ((((((_zz_when_GreedySampler_l66_142 || _zz_when_GreedySampler_l66_178) || (_zz_when_GreedySampler_l66_179 && _zz_when_GreedySampler_l66_180)) || ((_zz_when_GreedySampler_l66_181 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_47 == cnt))) || ((8'h30 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_48 == cnt))) || ((8'h31 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_49 == cnt))) || ((8'h32 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_50 == cnt)));
  assign _zz_when_GreedySampler_l66_182 = ((8'h33 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_51 == cnt));
  assign _zz_when_GreedySampler_l66_183 = (8'h34 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_184 = (_zz_when_GreedySampler_l66_52 == cnt);
  assign _zz_when_GreedySampler_l66_185 = 8'h35;
  assign _zz_when_GreedySampler_l66_142 = ((((((_zz_when_GreedySampler_l66_143 || _zz_when_GreedySampler_l66_174) || (_zz_when_GreedySampler_l66_175 && _zz_when_GreedySampler_l66_176)) || ((_zz_when_GreedySampler_l66_177 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_41 == cnt))) || ((8'h2a < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_42 == cnt))) || ((8'h2b < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_43 == cnt))) || ((8'h2c < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_44 == cnt)));
  assign _zz_when_GreedySampler_l66_178 = ((8'h2d < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_45 == cnt));
  assign _zz_when_GreedySampler_l66_179 = (8'h2e < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_180 = (_zz_when_GreedySampler_l66_46 == cnt);
  assign _zz_when_GreedySampler_l66_181 = 8'h2f;
  assign _zz_when_GreedySampler_l66_143 = ((((((_zz_when_GreedySampler_l66_144 || _zz_when_GreedySampler_l66_170) || (_zz_when_GreedySampler_l66_171 && _zz_when_GreedySampler_l66_172)) || ((_zz_when_GreedySampler_l66_173 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_35 == cnt))) || ((8'h24 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_36 == cnt))) || ((8'h25 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_37 == cnt))) || ((8'h26 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_38 == cnt)));
  assign _zz_when_GreedySampler_l66_174 = ((8'h27 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_39 == cnt));
  assign _zz_when_GreedySampler_l66_175 = (8'h28 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_176 = (_zz_when_GreedySampler_l66_40 == cnt);
  assign _zz_when_GreedySampler_l66_177 = 8'h29;
  assign _zz_when_GreedySampler_l66_144 = ((((((_zz_when_GreedySampler_l66_145 || _zz_when_GreedySampler_l66_166) || (_zz_when_GreedySampler_l66_167 && _zz_when_GreedySampler_l66_168)) || ((_zz_when_GreedySampler_l66_169 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_29 == cnt))) || ((8'h1e < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_30 == cnt))) || ((8'h1f < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_31 == cnt))) || ((8'h20 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_32 == cnt)));
  assign _zz_when_GreedySampler_l66_170 = ((8'h21 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_33 == cnt));
  assign _zz_when_GreedySampler_l66_171 = (8'h22 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_172 = (_zz_when_GreedySampler_l66_34 == cnt);
  assign _zz_when_GreedySampler_l66_173 = 8'h23;
  assign _zz_when_GreedySampler_l66_145 = ((((((_zz_when_GreedySampler_l66_146 || _zz_when_GreedySampler_l66_162) || (_zz_when_GreedySampler_l66_163 && _zz_when_GreedySampler_l66_164)) || ((_zz_when_GreedySampler_l66_165 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_23 == cnt))) || ((8'h18 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_24 == cnt))) || ((8'h19 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_25 == cnt))) || ((8'h1a < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_26 == cnt)));
  assign _zz_when_GreedySampler_l66_166 = ((8'h1b < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_27 == cnt));
  assign _zz_when_GreedySampler_l66_167 = (8'h1c < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_168 = (_zz_when_GreedySampler_l66_28 == cnt);
  assign _zz_when_GreedySampler_l66_169 = 8'h1d;
  assign _zz_when_GreedySampler_l66_146 = ((((((_zz_when_GreedySampler_l66_147 || _zz_when_GreedySampler_l66_158) || (_zz_when_GreedySampler_l66_159 && _zz_when_GreedySampler_l66_160)) || ((_zz_when_GreedySampler_l66_161 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_17 == cnt))) || ((8'h12 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_18 == cnt))) || ((8'h13 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_19 == cnt))) || ((8'h14 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_20 == cnt)));
  assign _zz_when_GreedySampler_l66_162 = ((8'h15 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_21 == cnt));
  assign _zz_when_GreedySampler_l66_163 = (8'h16 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_164 = (_zz_when_GreedySampler_l66_22 == cnt);
  assign _zz_when_GreedySampler_l66_165 = 8'h17;
  assign _zz_when_GreedySampler_l66_147 = ((((((_zz_when_GreedySampler_l66_148 || _zz_when_GreedySampler_l66_154) || (_zz_when_GreedySampler_l66_155 && _zz_when_GreedySampler_l66_156)) || ((_zz_when_GreedySampler_l66_157 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_11 == cnt))) || ((8'h0c < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_12 == cnt))) || ((8'h0d < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_13 == cnt))) || ((8'h0e < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_14 == cnt)));
  assign _zz_when_GreedySampler_l66_158 = ((8'h0f < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_15 == cnt));
  assign _zz_when_GreedySampler_l66_159 = (8'h10 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_160 = (_zz_when_GreedySampler_l66_16 == cnt);
  assign _zz_when_GreedySampler_l66_161 = 8'h11;
  assign _zz_when_GreedySampler_l66_148 = ((((((_zz_when_GreedySampler_l66_149 || _zz_when_GreedySampler_l66_150) || (_zz_when_GreedySampler_l66_151 && _zz_when_GreedySampler_l66_152)) || ((_zz_when_GreedySampler_l66_153 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_5 == cnt))) || ((8'h06 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_6 == cnt))) || ((8'h07 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_7 == cnt))) || ((8'h08 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_8 == cnt)));
  assign _zz_when_GreedySampler_l66_154 = ((8'h09 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_9 == cnt));
  assign _zz_when_GreedySampler_l66_155 = (8'h0a < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_156 = (_zz_when_GreedySampler_l66_10 == cnt);
  assign _zz_when_GreedySampler_l66_157 = 8'h0b;
  assign _zz_when_GreedySampler_l66_149 = ((((8'h0 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66 == cnt)) || ((8'h01 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_1 == cnt))) || ((8'h02 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_2 == cnt)));
  assign _zz_when_GreedySampler_l66_150 = ((8'h03 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_3 == cnt));
  assign _zz_when_GreedySampler_l66_151 = (8'h04 < _zz_when_GreedySampler_l66_128);
  assign _zz_when_GreedySampler_l66_152 = (_zz_when_GreedySampler_l66_4 == cnt);
  assign _zz_when_GreedySampler_l66_153 = 8'h05;
  assign logitsIn_valid = (logits_valid && (logits_tuser == 6'h2a));
  assign logitsIn_payload = logits_tdata;
  assign maxFlow_valid = logitsIn_valid;
  assign cntOvf = (cnt == 15'h7cff);
  assign logitsProbe_tvalid = logitsIn_valid;
  assign logitsProbe_tlast = cntOvf;
  assign logitsProbe_tdata = logitsIn_payload;
  assign candidate_valid = logitsIn_valid;
  always @(*) begin
    candidate_payload = logitsIn_payload;
    if(when_GreedySampler_l66) begin
      candidate_payload = _zz_candidate_payload;
    end
  end

  assign when_GreedySampler_l66 = ((((((_zz_when_GreedySampler_l66_129 || _zz_when_GreedySampler_l66_230) || (_zz_when_GreedySampler_l66_231 && _zz_when_GreedySampler_l66_232)) || ((_zz_when_GreedySampler_l66_233 < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_125 == cnt))) || ((8'h7e < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_126 == cnt))) || ((8'h7f < _zz_when_GreedySampler_l66_128) && (_zz_when_GreedySampler_l66_127 == cnt))) && (15'h0003 <= cnt));
  assign _zz_when_Fp16RepetitionPenalty_l28 = logitsIn_payload[14 : 10];
  assign _zz_when_Fp16RepetitionPenalty_l51 = {(_zz_when_Fp16RepetitionPenalty_l28 != 5'h0),logitsIn_payload[9 : 0]};
  always @(*) begin
    _zz_candidate_payload = logitsIn_payload;
    if(when_Fp16RepetitionPenalty_l28) begin
      _zz_candidate_payload = {logitsIn_payload[15],_zz_candidate_payload_1};
    end
  end

  always @(*) begin
    _zz_candidate_payload_1 = logitsIn_payload[14 : 0];
    if(when_Fp16RepetitionPenalty_l28) begin
      if(when_Fp16RepetitionPenalty_l29) begin
        if(when_Fp16RepetitionPenalty_l34) begin
          _zz_candidate_payload_1 = {3'd0, _zz_when_Fp16RepetitionPenalty_l40_1};
        end else begin
          _zz_candidate_payload_1 = {_zz_when_Fp16RepetitionPenalty_l28,_zz__zz_candidate_payload_1};
          if(when_Fp16RepetitionPenalty_l38) begin
            _zz_candidate_payload_1 = {_zz__zz_candidate_payload_1_1,_zz__zz_candidate_payload_1_2};
          end else begin
            if(when_Fp16RepetitionPenalty_l40) begin
              _zz_candidate_payload_1 = {_zz__zz_candidate_payload_1_6,10'h0};
            end
          end
          if(when_Fp16RepetitionPenalty_l43) begin
            _zz_candidate_payload_1 = 15'h7c00;
          end
        end
      end else begin
        if(when_Fp16RepetitionPenalty_l51) begin
          _zz_candidate_payload_1 = {3'd0, _zz_candidate_payload_4};
        end else begin
          _zz_candidate_payload_1 = {_zz_when_Fp16RepetitionPenalty_l28,_zz__zz_candidate_payload_1_7};
          if(when_Fp16RepetitionPenalty_l55) begin
            _zz_candidate_payload_1 = {_zz__zz_candidate_payload_1_8,_zz__zz_candidate_payload_1_9};
            if(when_Fp16RepetitionPenalty_l57) begin
              _zz_candidate_payload_1 = {_zz_when_Fp16RepetitionPenalty_l28,10'h0};
            end
          end
        end
      end
    end
  end

  assign when_Fp16RepetitionPenalty_l28 = (_zz_when_Fp16RepetitionPenalty_l28 != 5'h1f);
  assign when_Fp16RepetitionPenalty_l29 = logitsIn_payload[15];
  assign _zz_when_Fp16RepetitionPenalty_l38 = (_zz__zz_when_Fp16RepetitionPenalty_l38 + _zz__zz_when_Fp16RepetitionPenalty_l38_2);
  assign _zz_when_Fp16RepetitionPenalty_l40 = (_zz_when_Fp16RepetitionPenalty_l38 >>> 2'd3);
  assign _zz_when_Fp16RepetitionPenalty_l40_1 = (_zz_when_Fp16RepetitionPenalty_l40 + _zz__zz_when_Fp16RepetitionPenalty_l40_1);
  assign _zz_candidate_payload_2 = {1'd0, _zz__zz_candidate_payload_2};
  assign _zz_candidate_payload_3 = (_zz__zz_candidate_payload_3 + 6'h01);
  assign when_Fp16RepetitionPenalty_l34 = (_zz_when_Fp16RepetitionPenalty_l28 == 5'h0);
  assign when_Fp16RepetitionPenalty_l38 = (15'h4000 <= _zz_when_Fp16RepetitionPenalty_l38);
  assign when_Fp16RepetitionPenalty_l40 = (12'h800 <= _zz_when_Fp16RepetitionPenalty_l40_1);
  assign when_Fp16RepetitionPenalty_l43 = ((_zz_when_Fp16RepetitionPenalty_l28 == 5'h1e) && ((15'h4000 <= _zz_when_Fp16RepetitionPenalty_l38) || (12'h800 <= _zz_when_Fp16RepetitionPenalty_l40_1)));
  assign _zz_candidate_payload_4 = _zz__zz_candidate_payload_4[11:0];
  assign _zz_when_Fp16RepetitionPenalty_l57 = _zz__zz_when_Fp16RepetitionPenalty_l57[11:0];
  assign when_Fp16RepetitionPenalty_l51 = ((_zz_when_Fp16RepetitionPenalty_l28 == 5'h0) || ((_zz_when_Fp16RepetitionPenalty_l28 == 5'h01) && (_zz_when_Fp16RepetitionPenalty_l51 < 11'h480)));
  assign when_Fp16RepetitionPenalty_l55 = (_zz_when_Fp16RepetitionPenalty_l51 < 11'h480);
  assign when_Fp16RepetitionPenalty_l57 = (12'h800 <= _zz_when_Fp16RepetitionPenalty_l57);
  assign _zz_2 = ({127'd0,1'b1} <<< _zz_1);
  assign when_GreedySampler_l72 = (_zz_when_GreedySampler_l66_128 != 8'h80);
  assign xGreaterThanMax_valid = (maxFlow_valid && candidate_valid);
  assign _zz_xGreaterThanMax_payload = maxFlow_payload[14 : 0];
  assign _zz_xGreaterThanMax_payload_1 = candidate_payload[14 : 0];
  always @(*) begin
    xGreaterThanMax_payload = 1'b0;
    if(when_SamplerPolicyHarness_l24) begin
      if(when_SamplerPolicyHarness_l25) begin
        xGreaterThanMax_payload = maxFlow_payload[15];
      end else begin
        xGreaterThanMax_payload = (maxFlow_payload[15] ? (_zz_xGreaterThanMax_payload_1 < _zz_xGreaterThanMax_payload) : (_zz_xGreaterThanMax_payload < _zz_xGreaterThanMax_payload_1));
      end
    end
  end

  assign when_SamplerPolicyHarness_l24 = (((! ((&maxFlow_payload[14 : 10]) && (|maxFlow_payload[9 : 0]))) && (! ((&candidate_payload[14 : 10]) && (|candidate_payload[9 : 0])))) && ((_zz_xGreaterThanMax_payload != 15'h0) || (_zz_xGreaterThanMax_payload_1 != 15'h0)));
  assign when_SamplerPolicyHarness_l25 = (maxFlow_payload[15] != candidate_payload[15]);
  always @(*) begin
    indexNext = index;
    if(logitsIn_valid) begin
      if(xGreaterThanMax_payload) begin
        indexNext = cnt;
      end
    end
  end

  always @(*) begin
    maxNext = maxFlow_payload;
    if(logitsIn_valid) begin
      if(xGreaterThanMax_payload) begin
        maxNext = candidate_payload;
      end
    end
  end

  assign vld = (logitsIn_valid && cntOvf);
  assign isNan = ((&logitsIn_payload[14 : 10]) && (|logitsIn_payload[9 : 0]));
  assign nanNext = (nanCount + _zz_nanNext);
  assign when_GreedySampler_l111 = (cnt == 15'h0);
  assign diagResult = resultProbe;
  assign diagLogits = logitsProbeLock;
  assign historyCommit_valid = vldDly;
  assign historyCommit_payload = _zz_historyCommit_payload[14:0];
  assign argmax_valid = vldDly;
  assign argmax_payload = indexDly;
  assign argmax_tvalid = argmax_valid;
  assign argmax_tdata = argmax_payload;
  assign endOfDecode = 1'b0;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      maxFlow_payload <= 16'hfc00;
      cnt <= 15'h0;
      _zz_when_GreedySampler_l66 <= 15'h0;
      _zz_when_GreedySampler_l66_1 <= 15'h0;
      _zz_when_GreedySampler_l66_2 <= 15'h0;
      _zz_when_GreedySampler_l66_3 <= 15'h0;
      _zz_when_GreedySampler_l66_4 <= 15'h0;
      _zz_when_GreedySampler_l66_5 <= 15'h0;
      _zz_when_GreedySampler_l66_6 <= 15'h0;
      _zz_when_GreedySampler_l66_7 <= 15'h0;
      _zz_when_GreedySampler_l66_8 <= 15'h0;
      _zz_when_GreedySampler_l66_9 <= 15'h0;
      _zz_when_GreedySampler_l66_10 <= 15'h0;
      _zz_when_GreedySampler_l66_11 <= 15'h0;
      _zz_when_GreedySampler_l66_12 <= 15'h0;
      _zz_when_GreedySampler_l66_13 <= 15'h0;
      _zz_when_GreedySampler_l66_14 <= 15'h0;
      _zz_when_GreedySampler_l66_15 <= 15'h0;
      _zz_when_GreedySampler_l66_16 <= 15'h0;
      _zz_when_GreedySampler_l66_17 <= 15'h0;
      _zz_when_GreedySampler_l66_18 <= 15'h0;
      _zz_when_GreedySampler_l66_19 <= 15'h0;
      _zz_when_GreedySampler_l66_20 <= 15'h0;
      _zz_when_GreedySampler_l66_21 <= 15'h0;
      _zz_when_GreedySampler_l66_22 <= 15'h0;
      _zz_when_GreedySampler_l66_23 <= 15'h0;
      _zz_when_GreedySampler_l66_24 <= 15'h0;
      _zz_when_GreedySampler_l66_25 <= 15'h0;
      _zz_when_GreedySampler_l66_26 <= 15'h0;
      _zz_when_GreedySampler_l66_27 <= 15'h0;
      _zz_when_GreedySampler_l66_28 <= 15'h0;
      _zz_when_GreedySampler_l66_29 <= 15'h0;
      _zz_when_GreedySampler_l66_30 <= 15'h0;
      _zz_when_GreedySampler_l66_31 <= 15'h0;
      _zz_when_GreedySampler_l66_32 <= 15'h0;
      _zz_when_GreedySampler_l66_33 <= 15'h0;
      _zz_when_GreedySampler_l66_34 <= 15'h0;
      _zz_when_GreedySampler_l66_35 <= 15'h0;
      _zz_when_GreedySampler_l66_36 <= 15'h0;
      _zz_when_GreedySampler_l66_37 <= 15'h0;
      _zz_when_GreedySampler_l66_38 <= 15'h0;
      _zz_when_GreedySampler_l66_39 <= 15'h0;
      _zz_when_GreedySampler_l66_40 <= 15'h0;
      _zz_when_GreedySampler_l66_41 <= 15'h0;
      _zz_when_GreedySampler_l66_42 <= 15'h0;
      _zz_when_GreedySampler_l66_43 <= 15'h0;
      _zz_when_GreedySampler_l66_44 <= 15'h0;
      _zz_when_GreedySampler_l66_45 <= 15'h0;
      _zz_when_GreedySampler_l66_46 <= 15'h0;
      _zz_when_GreedySampler_l66_47 <= 15'h0;
      _zz_when_GreedySampler_l66_48 <= 15'h0;
      _zz_when_GreedySampler_l66_49 <= 15'h0;
      _zz_when_GreedySampler_l66_50 <= 15'h0;
      _zz_when_GreedySampler_l66_51 <= 15'h0;
      _zz_when_GreedySampler_l66_52 <= 15'h0;
      _zz_when_GreedySampler_l66_53 <= 15'h0;
      _zz_when_GreedySampler_l66_54 <= 15'h0;
      _zz_when_GreedySampler_l66_55 <= 15'h0;
      _zz_when_GreedySampler_l66_56 <= 15'h0;
      _zz_when_GreedySampler_l66_57 <= 15'h0;
      _zz_when_GreedySampler_l66_58 <= 15'h0;
      _zz_when_GreedySampler_l66_59 <= 15'h0;
      _zz_when_GreedySampler_l66_60 <= 15'h0;
      _zz_when_GreedySampler_l66_61 <= 15'h0;
      _zz_when_GreedySampler_l66_62 <= 15'h0;
      _zz_when_GreedySampler_l66_63 <= 15'h0;
      _zz_when_GreedySampler_l66_64 <= 15'h0;
      _zz_when_GreedySampler_l66_65 <= 15'h0;
      _zz_when_GreedySampler_l66_66 <= 15'h0;
      _zz_when_GreedySampler_l66_67 <= 15'h0;
      _zz_when_GreedySampler_l66_68 <= 15'h0;
      _zz_when_GreedySampler_l66_69 <= 15'h0;
      _zz_when_GreedySampler_l66_70 <= 15'h0;
      _zz_when_GreedySampler_l66_71 <= 15'h0;
      _zz_when_GreedySampler_l66_72 <= 15'h0;
      _zz_when_GreedySampler_l66_73 <= 15'h0;
      _zz_when_GreedySampler_l66_74 <= 15'h0;
      _zz_when_GreedySampler_l66_75 <= 15'h0;
      _zz_when_GreedySampler_l66_76 <= 15'h0;
      _zz_when_GreedySampler_l66_77 <= 15'h0;
      _zz_when_GreedySampler_l66_78 <= 15'h0;
      _zz_when_GreedySampler_l66_79 <= 15'h0;
      _zz_when_GreedySampler_l66_80 <= 15'h0;
      _zz_when_GreedySampler_l66_81 <= 15'h0;
      _zz_when_GreedySampler_l66_82 <= 15'h0;
      _zz_when_GreedySampler_l66_83 <= 15'h0;
      _zz_when_GreedySampler_l66_84 <= 15'h0;
      _zz_when_GreedySampler_l66_85 <= 15'h0;
      _zz_when_GreedySampler_l66_86 <= 15'h0;
      _zz_when_GreedySampler_l66_87 <= 15'h0;
      _zz_when_GreedySampler_l66_88 <= 15'h0;
      _zz_when_GreedySampler_l66_89 <= 15'h0;
      _zz_when_GreedySampler_l66_90 <= 15'h0;
      _zz_when_GreedySampler_l66_91 <= 15'h0;
      _zz_when_GreedySampler_l66_92 <= 15'h0;
      _zz_when_GreedySampler_l66_93 <= 15'h0;
      _zz_when_GreedySampler_l66_94 <= 15'h0;
      _zz_when_GreedySampler_l66_95 <= 15'h0;
      _zz_when_GreedySampler_l66_96 <= 15'h0;
      _zz_when_GreedySampler_l66_97 <= 15'h0;
      _zz_when_GreedySampler_l66_98 <= 15'h0;
      _zz_when_GreedySampler_l66_99 <= 15'h0;
      _zz_when_GreedySampler_l66_100 <= 15'h0;
      _zz_when_GreedySampler_l66_101 <= 15'h0;
      _zz_when_GreedySampler_l66_102 <= 15'h0;
      _zz_when_GreedySampler_l66_103 <= 15'h0;
      _zz_when_GreedySampler_l66_104 <= 15'h0;
      _zz_when_GreedySampler_l66_105 <= 15'h0;
      _zz_when_GreedySampler_l66_106 <= 15'h0;
      _zz_when_GreedySampler_l66_107 <= 15'h0;
      _zz_when_GreedySampler_l66_108 <= 15'h0;
      _zz_when_GreedySampler_l66_109 <= 15'h0;
      _zz_when_GreedySampler_l66_110 <= 15'h0;
      _zz_when_GreedySampler_l66_111 <= 15'h0;
      _zz_when_GreedySampler_l66_112 <= 15'h0;
      _zz_when_GreedySampler_l66_113 <= 15'h0;
      _zz_when_GreedySampler_l66_114 <= 15'h0;
      _zz_when_GreedySampler_l66_115 <= 15'h0;
      _zz_when_GreedySampler_l66_116 <= 15'h0;
      _zz_when_GreedySampler_l66_117 <= 15'h0;
      _zz_when_GreedySampler_l66_118 <= 15'h0;
      _zz_when_GreedySampler_l66_119 <= 15'h0;
      _zz_when_GreedySampler_l66_120 <= 15'h0;
      _zz_when_GreedySampler_l66_121 <= 15'h0;
      _zz_when_GreedySampler_l66_122 <= 15'h0;
      _zz_when_GreedySampler_l66_123 <= 15'h0;
      _zz_when_GreedySampler_l66_124 <= 15'h0;
      _zz_when_GreedySampler_l66_125 <= 15'h0;
      _zz_when_GreedySampler_l66_126 <= 15'h0;
      _zz_when_GreedySampler_l66_127 <= 15'h0;
      _zz_when_GreedySampler_l66_128 <= 8'h0;
      _zz_1 <= 7'h0;
      index <= 15'h0;
      nanCount <= 16'h0;
      firstLogit <= 16'h0;
      resultProbe <= 32'h0;
      logitsProbeLock <= 32'h0;
      vldDly <= 1'b0;
    end else begin
      if(logitsIn_valid) begin
        cnt <= (cnt + 15'h0001);
        if(cntOvf) begin
          cnt <= 15'h0;
        end
      end
      if(historyCommit_valid) begin
        if(_zz_2[0]) begin
          _zz_when_GreedySampler_l66 <= historyCommit_payload;
        end
        if(_zz_2[1]) begin
          _zz_when_GreedySampler_l66_1 <= historyCommit_payload;
        end
        if(_zz_2[2]) begin
          _zz_when_GreedySampler_l66_2 <= historyCommit_payload;
        end
        if(_zz_2[3]) begin
          _zz_when_GreedySampler_l66_3 <= historyCommit_payload;
        end
        if(_zz_2[4]) begin
          _zz_when_GreedySampler_l66_4 <= historyCommit_payload;
        end
        if(_zz_2[5]) begin
          _zz_when_GreedySampler_l66_5 <= historyCommit_payload;
        end
        if(_zz_2[6]) begin
          _zz_when_GreedySampler_l66_6 <= historyCommit_payload;
        end
        if(_zz_2[7]) begin
          _zz_when_GreedySampler_l66_7 <= historyCommit_payload;
        end
        if(_zz_2[8]) begin
          _zz_when_GreedySampler_l66_8 <= historyCommit_payload;
        end
        if(_zz_2[9]) begin
          _zz_when_GreedySampler_l66_9 <= historyCommit_payload;
        end
        if(_zz_2[10]) begin
          _zz_when_GreedySampler_l66_10 <= historyCommit_payload;
        end
        if(_zz_2[11]) begin
          _zz_when_GreedySampler_l66_11 <= historyCommit_payload;
        end
        if(_zz_2[12]) begin
          _zz_when_GreedySampler_l66_12 <= historyCommit_payload;
        end
        if(_zz_2[13]) begin
          _zz_when_GreedySampler_l66_13 <= historyCommit_payload;
        end
        if(_zz_2[14]) begin
          _zz_when_GreedySampler_l66_14 <= historyCommit_payload;
        end
        if(_zz_2[15]) begin
          _zz_when_GreedySampler_l66_15 <= historyCommit_payload;
        end
        if(_zz_2[16]) begin
          _zz_when_GreedySampler_l66_16 <= historyCommit_payload;
        end
        if(_zz_2[17]) begin
          _zz_when_GreedySampler_l66_17 <= historyCommit_payload;
        end
        if(_zz_2[18]) begin
          _zz_when_GreedySampler_l66_18 <= historyCommit_payload;
        end
        if(_zz_2[19]) begin
          _zz_when_GreedySampler_l66_19 <= historyCommit_payload;
        end
        if(_zz_2[20]) begin
          _zz_when_GreedySampler_l66_20 <= historyCommit_payload;
        end
        if(_zz_2[21]) begin
          _zz_when_GreedySampler_l66_21 <= historyCommit_payload;
        end
        if(_zz_2[22]) begin
          _zz_when_GreedySampler_l66_22 <= historyCommit_payload;
        end
        if(_zz_2[23]) begin
          _zz_when_GreedySampler_l66_23 <= historyCommit_payload;
        end
        if(_zz_2[24]) begin
          _zz_when_GreedySampler_l66_24 <= historyCommit_payload;
        end
        if(_zz_2[25]) begin
          _zz_when_GreedySampler_l66_25 <= historyCommit_payload;
        end
        if(_zz_2[26]) begin
          _zz_when_GreedySampler_l66_26 <= historyCommit_payload;
        end
        if(_zz_2[27]) begin
          _zz_when_GreedySampler_l66_27 <= historyCommit_payload;
        end
        if(_zz_2[28]) begin
          _zz_when_GreedySampler_l66_28 <= historyCommit_payload;
        end
        if(_zz_2[29]) begin
          _zz_when_GreedySampler_l66_29 <= historyCommit_payload;
        end
        if(_zz_2[30]) begin
          _zz_when_GreedySampler_l66_30 <= historyCommit_payload;
        end
        if(_zz_2[31]) begin
          _zz_when_GreedySampler_l66_31 <= historyCommit_payload;
        end
        if(_zz_2[32]) begin
          _zz_when_GreedySampler_l66_32 <= historyCommit_payload;
        end
        if(_zz_2[33]) begin
          _zz_when_GreedySampler_l66_33 <= historyCommit_payload;
        end
        if(_zz_2[34]) begin
          _zz_when_GreedySampler_l66_34 <= historyCommit_payload;
        end
        if(_zz_2[35]) begin
          _zz_when_GreedySampler_l66_35 <= historyCommit_payload;
        end
        if(_zz_2[36]) begin
          _zz_when_GreedySampler_l66_36 <= historyCommit_payload;
        end
        if(_zz_2[37]) begin
          _zz_when_GreedySampler_l66_37 <= historyCommit_payload;
        end
        if(_zz_2[38]) begin
          _zz_when_GreedySampler_l66_38 <= historyCommit_payload;
        end
        if(_zz_2[39]) begin
          _zz_when_GreedySampler_l66_39 <= historyCommit_payload;
        end
        if(_zz_2[40]) begin
          _zz_when_GreedySampler_l66_40 <= historyCommit_payload;
        end
        if(_zz_2[41]) begin
          _zz_when_GreedySampler_l66_41 <= historyCommit_payload;
        end
        if(_zz_2[42]) begin
          _zz_when_GreedySampler_l66_42 <= historyCommit_payload;
        end
        if(_zz_2[43]) begin
          _zz_when_GreedySampler_l66_43 <= historyCommit_payload;
        end
        if(_zz_2[44]) begin
          _zz_when_GreedySampler_l66_44 <= historyCommit_payload;
        end
        if(_zz_2[45]) begin
          _zz_when_GreedySampler_l66_45 <= historyCommit_payload;
        end
        if(_zz_2[46]) begin
          _zz_when_GreedySampler_l66_46 <= historyCommit_payload;
        end
        if(_zz_2[47]) begin
          _zz_when_GreedySampler_l66_47 <= historyCommit_payload;
        end
        if(_zz_2[48]) begin
          _zz_when_GreedySampler_l66_48 <= historyCommit_payload;
        end
        if(_zz_2[49]) begin
          _zz_when_GreedySampler_l66_49 <= historyCommit_payload;
        end
        if(_zz_2[50]) begin
          _zz_when_GreedySampler_l66_50 <= historyCommit_payload;
        end
        if(_zz_2[51]) begin
          _zz_when_GreedySampler_l66_51 <= historyCommit_payload;
        end
        if(_zz_2[52]) begin
          _zz_when_GreedySampler_l66_52 <= historyCommit_payload;
        end
        if(_zz_2[53]) begin
          _zz_when_GreedySampler_l66_53 <= historyCommit_payload;
        end
        if(_zz_2[54]) begin
          _zz_when_GreedySampler_l66_54 <= historyCommit_payload;
        end
        if(_zz_2[55]) begin
          _zz_when_GreedySampler_l66_55 <= historyCommit_payload;
        end
        if(_zz_2[56]) begin
          _zz_when_GreedySampler_l66_56 <= historyCommit_payload;
        end
        if(_zz_2[57]) begin
          _zz_when_GreedySampler_l66_57 <= historyCommit_payload;
        end
        if(_zz_2[58]) begin
          _zz_when_GreedySampler_l66_58 <= historyCommit_payload;
        end
        if(_zz_2[59]) begin
          _zz_when_GreedySampler_l66_59 <= historyCommit_payload;
        end
        if(_zz_2[60]) begin
          _zz_when_GreedySampler_l66_60 <= historyCommit_payload;
        end
        if(_zz_2[61]) begin
          _zz_when_GreedySampler_l66_61 <= historyCommit_payload;
        end
        if(_zz_2[62]) begin
          _zz_when_GreedySampler_l66_62 <= historyCommit_payload;
        end
        if(_zz_2[63]) begin
          _zz_when_GreedySampler_l66_63 <= historyCommit_payload;
        end
        if(_zz_2[64]) begin
          _zz_when_GreedySampler_l66_64 <= historyCommit_payload;
        end
        if(_zz_2[65]) begin
          _zz_when_GreedySampler_l66_65 <= historyCommit_payload;
        end
        if(_zz_2[66]) begin
          _zz_when_GreedySampler_l66_66 <= historyCommit_payload;
        end
        if(_zz_2[67]) begin
          _zz_when_GreedySampler_l66_67 <= historyCommit_payload;
        end
        if(_zz_2[68]) begin
          _zz_when_GreedySampler_l66_68 <= historyCommit_payload;
        end
        if(_zz_2[69]) begin
          _zz_when_GreedySampler_l66_69 <= historyCommit_payload;
        end
        if(_zz_2[70]) begin
          _zz_when_GreedySampler_l66_70 <= historyCommit_payload;
        end
        if(_zz_2[71]) begin
          _zz_when_GreedySampler_l66_71 <= historyCommit_payload;
        end
        if(_zz_2[72]) begin
          _zz_when_GreedySampler_l66_72 <= historyCommit_payload;
        end
        if(_zz_2[73]) begin
          _zz_when_GreedySampler_l66_73 <= historyCommit_payload;
        end
        if(_zz_2[74]) begin
          _zz_when_GreedySampler_l66_74 <= historyCommit_payload;
        end
        if(_zz_2[75]) begin
          _zz_when_GreedySampler_l66_75 <= historyCommit_payload;
        end
        if(_zz_2[76]) begin
          _zz_when_GreedySampler_l66_76 <= historyCommit_payload;
        end
        if(_zz_2[77]) begin
          _zz_when_GreedySampler_l66_77 <= historyCommit_payload;
        end
        if(_zz_2[78]) begin
          _zz_when_GreedySampler_l66_78 <= historyCommit_payload;
        end
        if(_zz_2[79]) begin
          _zz_when_GreedySampler_l66_79 <= historyCommit_payload;
        end
        if(_zz_2[80]) begin
          _zz_when_GreedySampler_l66_80 <= historyCommit_payload;
        end
        if(_zz_2[81]) begin
          _zz_when_GreedySampler_l66_81 <= historyCommit_payload;
        end
        if(_zz_2[82]) begin
          _zz_when_GreedySampler_l66_82 <= historyCommit_payload;
        end
        if(_zz_2[83]) begin
          _zz_when_GreedySampler_l66_83 <= historyCommit_payload;
        end
        if(_zz_2[84]) begin
          _zz_when_GreedySampler_l66_84 <= historyCommit_payload;
        end
        if(_zz_2[85]) begin
          _zz_when_GreedySampler_l66_85 <= historyCommit_payload;
        end
        if(_zz_2[86]) begin
          _zz_when_GreedySampler_l66_86 <= historyCommit_payload;
        end
        if(_zz_2[87]) begin
          _zz_when_GreedySampler_l66_87 <= historyCommit_payload;
        end
        if(_zz_2[88]) begin
          _zz_when_GreedySampler_l66_88 <= historyCommit_payload;
        end
        if(_zz_2[89]) begin
          _zz_when_GreedySampler_l66_89 <= historyCommit_payload;
        end
        if(_zz_2[90]) begin
          _zz_when_GreedySampler_l66_90 <= historyCommit_payload;
        end
        if(_zz_2[91]) begin
          _zz_when_GreedySampler_l66_91 <= historyCommit_payload;
        end
        if(_zz_2[92]) begin
          _zz_when_GreedySampler_l66_92 <= historyCommit_payload;
        end
        if(_zz_2[93]) begin
          _zz_when_GreedySampler_l66_93 <= historyCommit_payload;
        end
        if(_zz_2[94]) begin
          _zz_when_GreedySampler_l66_94 <= historyCommit_payload;
        end
        if(_zz_2[95]) begin
          _zz_when_GreedySampler_l66_95 <= historyCommit_payload;
        end
        if(_zz_2[96]) begin
          _zz_when_GreedySampler_l66_96 <= historyCommit_payload;
        end
        if(_zz_2[97]) begin
          _zz_when_GreedySampler_l66_97 <= historyCommit_payload;
        end
        if(_zz_2[98]) begin
          _zz_when_GreedySampler_l66_98 <= historyCommit_payload;
        end
        if(_zz_2[99]) begin
          _zz_when_GreedySampler_l66_99 <= historyCommit_payload;
        end
        if(_zz_2[100]) begin
          _zz_when_GreedySampler_l66_100 <= historyCommit_payload;
        end
        if(_zz_2[101]) begin
          _zz_when_GreedySampler_l66_101 <= historyCommit_payload;
        end
        if(_zz_2[102]) begin
          _zz_when_GreedySampler_l66_102 <= historyCommit_payload;
        end
        if(_zz_2[103]) begin
          _zz_when_GreedySampler_l66_103 <= historyCommit_payload;
        end
        if(_zz_2[104]) begin
          _zz_when_GreedySampler_l66_104 <= historyCommit_payload;
        end
        if(_zz_2[105]) begin
          _zz_when_GreedySampler_l66_105 <= historyCommit_payload;
        end
        if(_zz_2[106]) begin
          _zz_when_GreedySampler_l66_106 <= historyCommit_payload;
        end
        if(_zz_2[107]) begin
          _zz_when_GreedySampler_l66_107 <= historyCommit_payload;
        end
        if(_zz_2[108]) begin
          _zz_when_GreedySampler_l66_108 <= historyCommit_payload;
        end
        if(_zz_2[109]) begin
          _zz_when_GreedySampler_l66_109 <= historyCommit_payload;
        end
        if(_zz_2[110]) begin
          _zz_when_GreedySampler_l66_110 <= historyCommit_payload;
        end
        if(_zz_2[111]) begin
          _zz_when_GreedySampler_l66_111 <= historyCommit_payload;
        end
        if(_zz_2[112]) begin
          _zz_when_GreedySampler_l66_112 <= historyCommit_payload;
        end
        if(_zz_2[113]) begin
          _zz_when_GreedySampler_l66_113 <= historyCommit_payload;
        end
        if(_zz_2[114]) begin
          _zz_when_GreedySampler_l66_114 <= historyCommit_payload;
        end
        if(_zz_2[115]) begin
          _zz_when_GreedySampler_l66_115 <= historyCommit_payload;
        end
        if(_zz_2[116]) begin
          _zz_when_GreedySampler_l66_116 <= historyCommit_payload;
        end
        if(_zz_2[117]) begin
          _zz_when_GreedySampler_l66_117 <= historyCommit_payload;
        end
        if(_zz_2[118]) begin
          _zz_when_GreedySampler_l66_118 <= historyCommit_payload;
        end
        if(_zz_2[119]) begin
          _zz_when_GreedySampler_l66_119 <= historyCommit_payload;
        end
        if(_zz_2[120]) begin
          _zz_when_GreedySampler_l66_120 <= historyCommit_payload;
        end
        if(_zz_2[121]) begin
          _zz_when_GreedySampler_l66_121 <= historyCommit_payload;
        end
        if(_zz_2[122]) begin
          _zz_when_GreedySampler_l66_122 <= historyCommit_payload;
        end
        if(_zz_2[123]) begin
          _zz_when_GreedySampler_l66_123 <= historyCommit_payload;
        end
        if(_zz_2[124]) begin
          _zz_when_GreedySampler_l66_124 <= historyCommit_payload;
        end
        if(_zz_2[125]) begin
          _zz_when_GreedySampler_l66_125 <= historyCommit_payload;
        end
        if(_zz_2[126]) begin
          _zz_when_GreedySampler_l66_126 <= historyCommit_payload;
        end
        if(_zz_2[127]) begin
          _zz_when_GreedySampler_l66_127 <= historyCommit_payload;
        end
        _zz_1 <= (_zz_1 + 7'h01);
        if(when_GreedySampler_l72) begin
          _zz_when_GreedySampler_l66_128 <= (_zz_when_GreedySampler_l66_128 + 8'h01);
        end
      end
      if(logitsIn_valid) begin
        maxFlow_payload <= maxNext;
        index <= indexNext;
        if(cntOvf) begin
          maxFlow_payload <= 16'hfc00;
          index <= 15'h0;
        end
      end
      if(logitsIn_valid) begin
        nanCount <= nanNext;
        if(when_GreedySampler_l111) begin
          firstLogit <= logitsIn_payload;
        end
        if(cntOvf) begin
          resultProbe <= {nanNext,maxNext};
          logitsProbeLock <= {firstLogit,logitsIn_payload};
          nanCount <= 16'h0;
        end
      end
      vldDly <= vld;
    end
  end

  always @(posedge clk) begin
    indexDly <= _zz_indexDly;
  end


endmodule

module GreedySampler (
  input  wire          logits_valid,
  input  wire [15:0]   logits_tdata,
  input  wire [5:0]    logits_tuser,
  output wire          argmax_tvalid,
  output wire [15:0]   argmax_tdata,
  output wire          endOfDecode,
  output wire [31:0]   diagResult,
  output wire [31:0]   diagLogits,
  input  wire          clk,
  input  wire          reset
);

  wire       [15:0]   _zz_nanNext;
  wire       [0:0]    _zz_nanNext_1;
  wire       [15:0]   _zz_indexDly;
  wire       [15:0]   _zz_historyCommit_payload;
  wire                logitsIn_valid;
  wire       [15:0]   logitsIn_payload;
  wire                maxFlow_valid;
  reg        [15:0]   maxFlow_payload;
  reg        [14:0]   cnt;
  wire                cntOvf;
  wire                logitsProbe_tvalid;
  wire                logitsProbe_tlast;
  wire       [15:0]   logitsProbe_tdata;
  wire                candidate_valid;
  wire       [15:0]   candidate_payload;
  wire                historyCommit_valid;
  wire       [14:0]   historyCommit_payload;
  wire                xGreaterThanMax_valid;
  reg                 xGreaterThanMax_payload;
  wire       [14:0]   _zz_xGreaterThanMax_payload;
  wire       [14:0]   _zz_xGreaterThanMax_payload_1;
  wire                when_SamplerPolicyHarness_l24;
  wire                when_SamplerPolicyHarness_l25;
  reg        [14:0]   index;
  reg        [14:0]   indexNext;
  reg        [15:0]   maxNext;
  wire                vld;
  reg        [15:0]   nanCount;
  wire                isNan;
  wire       [15:0]   nanNext;
  reg        [15:0]   firstLogit;
  reg        [31:0]   resultProbe;
  reg        [31:0]   logitsProbeLock;
  wire                when_GreedySampler_l111;
  reg                 vldDly;
  reg        [15:0]   indexDly;
  wire                argmax_valid;
  wire       [15:0]   argmax_payload;

  assign _zz_nanNext_1 = isNan;
  assign _zz_nanNext = {15'd0, _zz_nanNext_1};
  assign _zz_indexDly = {1'd0, indexNext};
  assign _zz_historyCommit_payload = indexDly;
  assign logitsIn_valid = (logits_valid && (logits_tuser == 6'h2a));
  assign logitsIn_payload = logits_tdata;
  assign maxFlow_valid = logitsIn_valid;
  assign cntOvf = (cnt == 15'h7cff);
  assign logitsProbe_tvalid = logitsIn_valid;
  assign logitsProbe_tlast = cntOvf;
  assign logitsProbe_tdata = logitsIn_payload;
  assign candidate_valid = logitsIn_valid;
  assign candidate_payload = logitsIn_payload;
  assign xGreaterThanMax_valid = (maxFlow_valid && candidate_valid);
  assign _zz_xGreaterThanMax_payload = maxFlow_payload[14 : 0];
  assign _zz_xGreaterThanMax_payload_1 = candidate_payload[14 : 0];
  always @(*) begin
    xGreaterThanMax_payload = 1'b0;
    if(when_SamplerPolicyHarness_l24) begin
      if(when_SamplerPolicyHarness_l25) begin
        xGreaterThanMax_payload = maxFlow_payload[15];
      end else begin
        xGreaterThanMax_payload = (maxFlow_payload[15] ? (_zz_xGreaterThanMax_payload_1 < _zz_xGreaterThanMax_payload) : (_zz_xGreaterThanMax_payload < _zz_xGreaterThanMax_payload_1));
      end
    end
  end

  assign when_SamplerPolicyHarness_l24 = (((! ((&maxFlow_payload[14 : 10]) && (|maxFlow_payload[9 : 0]))) && (! ((&candidate_payload[14 : 10]) && (|candidate_payload[9 : 0])))) && ((_zz_xGreaterThanMax_payload != 15'h0) || (_zz_xGreaterThanMax_payload_1 != 15'h0)));
  assign when_SamplerPolicyHarness_l25 = (maxFlow_payload[15] != candidate_payload[15]);
  always @(*) begin
    indexNext = index;
    if(logitsIn_valid) begin
      if(xGreaterThanMax_payload) begin
        indexNext = cnt;
      end
    end
  end

  always @(*) begin
    maxNext = maxFlow_payload;
    if(logitsIn_valid) begin
      if(xGreaterThanMax_payload) begin
        maxNext = candidate_payload;
      end
    end
  end

  assign vld = (logitsIn_valid && cntOvf);
  assign isNan = ((&logitsIn_payload[14 : 10]) && (|logitsIn_payload[9 : 0]));
  assign nanNext = (nanCount + _zz_nanNext);
  assign when_GreedySampler_l111 = (cnt == 15'h0);
  assign diagResult = resultProbe;
  assign diagLogits = logitsProbeLock;
  assign historyCommit_valid = vldDly;
  assign historyCommit_payload = _zz_historyCommit_payload[14:0];
  assign argmax_valid = vldDly;
  assign argmax_payload = indexDly;
  assign argmax_tvalid = argmax_valid;
  assign argmax_tdata = argmax_payload;
  assign endOfDecode = 1'b0;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      maxFlow_payload <= 16'hfc00;
      cnt <= 15'h0;
      index <= 15'h0;
      nanCount <= 16'h0;
      firstLogit <= 16'h0;
      resultProbe <= 32'h0;
      logitsProbeLock <= 32'h0;
      vldDly <= 1'b0;
    end else begin
      if(logitsIn_valid) begin
        cnt <= (cnt + 15'h0001);
        if(cntOvf) begin
          cnt <= 15'h0;
        end
      end
      if(logitsIn_valid) begin
        maxFlow_payload <= maxNext;
        index <= indexNext;
        if(cntOvf) begin
          maxFlow_payload <= 16'hfc00;
          index <= 15'h0;
        end
      end
      if(logitsIn_valid) begin
        nanCount <= nanNext;
        if(when_GreedySampler_l111) begin
          firstLogit <= logitsIn_payload;
        end
        if(cntOvf) begin
          resultProbe <= {nanNext,maxNext};
          logitsProbeLock <= {firstLogit,logitsIn_payload};
          nanCount <= 16'h0;
        end
      end
      vldDly <= vld;
    end
  end

  always @(posedge clk) begin
    indexDly <= _zz_indexDly;
  end


endmodule
