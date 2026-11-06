package top

import spinal.core._

import scala.language.postfixOps

object EdgeLLMInst extends App {

  import cfgGen.LLaMA2_7B._
  private val targetModelCfg = cfgGen.Zynq7100_1B.modelCfg

  //  val DMA_SPLIT = List(4)
  //  val baseAddr = List(0)
  //  val cmdAddrWidth = List(40)
  //  val splitBaseAddr = List((BigInt(0x800000000L), BigInt(0x36000)))
  //  val numOfCore = 1
  //  val sync = true
  //  val resetLowPolarity = true

  //  val DMA_SPLIT = List(1)
  //  val baseAddr = List(0)
  //  val cmdAddrWidth = List(32)
  //  val splitBaseAddr = List((BigInt(0), BigInt(0)))
  //  val numOfCore = 1
  //  val sync = true
  //  val resetLowPolarity = false

  //  val DMA_SPLIT = List(4, 1)
  //  val baseAddr = List(0x36000, 0)
  //  val cmdAddrWidth = List(32, 32)
  //  val splitBaseAddr = List((BigInt(0), BigInt(0)), (BigInt(0), BigInt(0)))
  //  val numOfCore = 2
  //  val sync = true
  //  val resetLowPolarity = false

  //  val DMA_SPLIT = List(1, 1, 1, 1)
  //  val baseAddr = List(0, 0, 0, 0)
  //  val cmdAddrWidth = List(32, 32, 32, 32)
  //  val splitBaseAddr = List((BigInt(0), BigInt(0)), (BigInt(0), BigInt(0)), (BigInt(0), BigInt(0)), (BigInt(0), BigInt(0)))
  //  val numOfCore = 4
  //  val sync = false
  //  val resetLowPolarity = false
  // remember to change the mlpDim configuration

  private val target = sys.env.getOrElse("EDGELLM_TARGET", "zynq7100")
  private val isZynq7035 = target == "zynq7035"
  require(target == "zynq7100" || isZynq7035,
    s"Unsupported EDGELLM_TARGET=$target (expected zynq7100 or zynq7035)")

  // Core 0 stripes its 512-bit stream over the four 128-bit HP-facing
  // masters; core 1 uses the 512-bit PL-DDR master.  Leave 16 MiB at the
  // bottom of PS DDR for FSBL, the application, stacks and heaps.
  val DMA_SPLIT = if (isZynq7035) List(1) else List(4, 1)
  val baseAddr = if (isZynq7035) List(BigInt(0x01000000)) else
    List(BigInt(0x01000000), BigInt("80000000", 16))
  val cmdAddrWidth = if (isZynq7035) List(32) else List(32, 32)
  val splitBaseAddr = if (isZynq7035) List((BigInt(0), BigInt(0))) else
    List((BigInt(0), BigInt(0)), (BigInt(0), BigInt(0)))
  val numOfCore = if (isZynq7035) 1 else 2
  val sync = isZynq7035
  val resetLowPolarity = false

  val busWidth = if (isZynq7035) 128 else 512
  val sgSplit = 4
  val bankLen = busWidth / 4
  val clock = new ClockDomainConfig(resetActiveLevel = LOW)
  val cfg = SpinalConfig(
    targetDirectory = if (isZynq7035) "../../zynq7035_port/rtl" else ".",
    defaultConfigForClockDomains = clock,
    inlineRom = true,
    nameWhenByFile = false,
    anonymSignalPrefix = "t"
  )
  cfg.generateVerilog(
    new DataPath_xN(
      sync = sync,
      numOfCore = numOfCore,
      DMA_SPLIT = DMA_SPLIT,
      baseAddr = baseAddr,
      cmdAddrWidth = cmdAddrWidth,
      splitBaseAddr = splitBaseAddr,
      busWidth = busWidth,
      sgSplit = sgSplit,

      dim = targetModelCfg.dim,
      head = targetModelCfg.head,
      headDim = targetModelCfg.headDim,
      predDim = targetModelCfg.predDim,
      mlpDim = targetModelCfg.mlpDim,
      layer = targetModelCfg.layer,
      maxToken = 1024,
      ropePoint = 1 << 14,
      sqrtHeadDim = targetModelCfg.sqrtHeadDim,
      vocabSize = targetModelCfg.vocabSize,

      ropeTagMap = tagMap.ropeTagMap,
      quantTagMap = tagMap.quantTagMap,
      softmaxTag = tagMap.softmaxTag,
      lnInTagMap = tagMap.lnInTagMap,
      zeroFilterTagMap = tagMap.zeroFilterTagMap,

      logitsTag = tag.logitsTag,
      resAddTag = tag.resAddTag,
      normFilterTag = tag.normFilterTag,
      resOut2NodeTag = tag.resOut2NodeTag,
      p2sOut2NodeTag = tag.p2sOut2NodeTag,
      index2NodeTag = tag.index2NodeTag,
      index2UgTag = tag.index2UgTag,

      attnLnTag = tensor.ATTN_LN_OUT,
      logitsLnTag = tensor.LOGITS_LN_OUT,
      lmHeadParamTag = param.LM_HEAD_W,
      attnVParamTag = param.ATTN_W_V,
      mlpDParamTag = param.MLP_W_D,
      kvInTag = tag.kvInTag,

      lnScaleBusTag = tag.axiLnBusTag,
      denseBusTag = tag.axiDenseBusTag,
      kvCacheBusTag = tag.axiKvBusTag,
      sparseDotTagMap = tag.axiSparseDotBusTagMap(busWidth, numOfCore, targetModelCfg.dim),
      sparseAxpyTagMap = tag.axiSparseAxpyBusTagMap(busWidth, numOfCore, targetModelCfg.dim, targetModelCfg.mlpDim),
      denseCfgTag = tag.axiDenseCfgTag,
      sparseCfgTag = tag.axiSparseCfgTag,
      lnSqrCfgTag = tag.axiLnCfgTag,
      kvCfgTag = tag.axiKvCfgTag,

      qkMulTag = tag.qkMulTag,
      ugMulTag = tag.ugMulTag,
      axpyTensorInTag = tag.axpyTensorInTag,
      axpyParamInTag = tag.axpyParamInTag,
      tokenTag = tag.extTokenTag,
      vTensorTag = tag.vTag,

      zeroFilterTag2SeqLen = List(
        (tensor.MLP_PRED_U_FILTER, targetModelCfg.predDim),
        (tensor.MLP_PRED_D_FILTER, targetModelCfg.mlpDim / numOfCore),
        (tensor.MLP_G_FILTER, targetModelCfg.mlpDim)
      ),

      vecIn2ResTag = tag.vecIn2ResTag,
      vecIn2ScalarTag = tag.vecIn2ScalarTag,
      vLocalTag = tag.vLocalTag,
      serial2VecOutTag = tag.serial2VecOutTag,
      busIn2VecOutTag = tag.busIn2VecOutTag,
      engine2VecOutTag = tag.engine2VecOutTag,
      lnOut2VecTag = tag.lnOut2VecTag,
      dotOut2VecTag = tag.dotOut2VecTag,
      rope2VecTag = tag.rope2VecTag,
      dotOut2NodeTag = tag.dotOut2NodeTag,
      cfgInsertTag = tag.cfgInsertTag,
      mlpGTag = tag.axiMlpGTag,

      mul_func = util.fp16mul6.mul,
      add_func = util.fp16add6.add,
      sub_func = util.fp16sub8.sub,
      div_func = util.fp16div12.div,
      acc_func = util.fp16acc16.acc,
      act_func = x => x,
      mul_func_block = util.fp16mul7s.mul,

      rope_highPcs_mul_func = util.fp32mul8.mul,
      rope_toInt_func = util.fp32toint32d6.to,
      rope_fromInt_func = util.fp32int16d4.from,
      quant_conv_func = util.fp16toint9d4.to,
      deQuant_int4_conv_func = util.fp16int5d4.from,
      deQuant_int8_conv_func = util.fp16int9d4.from,

      add_latency = util.fp16add6.latency,
      deQuant_latency = 4 + 1,
      mul_latency = util.fp16mul6.latency,
      acc_latency = util.fp16acc16.latency,
      exp_latency = util.fp16ex12.latency,
      div_latency = util.fp16div12.latency,

      expo_func = util.fp16ex12.exp,
      rsqrt_func = util.fp16rsqrt4.rsqrt,
      lt_func = util.fp16lt0.lt_async,

      fp16toFp32_func = util.fp16toFp32.to,
      fp16toFp32_func_block = util.fp16toFp32s.to,
      fp32toFp16_func = util.fp32toFp16.to,
      fp32mul_func = util.fp32mul8.mul,
      fp32mul_func_block = util.fp32mul8s.mul,
      fp32acc_func = util.fp32acc22.acc,
      fp32rsqrt_func = util.fp32rsqrt32.rsqrt,
      fp32add_func = util.fp32add11.add,
      fp32exp_func = util.fp32exp20.exp,
      fp32div_func = util.fp32div28.div,
      fp32lt_func = util.fp32lt0.lt_async,
      fp32sub_func = util.fp32sub11.sub,
      mix_mul_func = util.fp16mulFp32.apply,
      add_conv_func = util.fp32add2Fp16.apply,

      toFp32_latency = util.fp16toFp32.latency,
      toFp16_latency = util.fp32toFp16.latency,
      fp32Mul_latency = util.fp32mul8.latency,
      fp32Add_latency = util.fp32add11.latency,
      fp32Acc_latency = util.fp32acc22.latency,
      fp32Exp_latency = util.fp32exp20.latency,
      fp32Div_latency = util.fp32div28.latency,

      // These depths also determine the address/counter widths inside the
      // engines.  With bankLen=32 the largest dot firstDim is 2048/32=64,
      // while the MLP AXPY path reaches 5632/32=176 entries.
      dotMaxFirstDim = if (isZynq7035) 64 else 32,
      axpyMaxFirstDim = if (isZynq7035) 256 else 32,
      wkvOutFifoDepth = 32,
      // BusIn receives a full token vector as a Flow and therefore cannot
      // backpressure it when the P2S FIFO fills.  On the 128-bit target one
      // 2048-element vector occupies 2048 / bankLen = 64 FIFO entries; the
      // old depth of 32 silently dropped the tail and RMSNorm never saw last.
      vecP2sFifoDepth = if (isZynq7035) 64 else 32,
      // A 128-bit bus has bankLen=32, so a full 2048-element vector occupies
      // 64 beats. VecOutBuf uses one half of its ping-pong RAM per vector and
      // also needs a non-zero start slot for QKV output; 128 total entries
      // cannot represent the inclusive end pointer. Keep 256 entries here.
      vecOutFifoDepth = if (isZynq7035) 256 else scala.math.max(64, 128 / numOfCore),
      resetLowPolarity = resetLowPolarity
    )
  )
}
