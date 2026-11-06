package top

import spinal.core.{ResetKind, _}
import spinal.lib._
import spinal.lib.bus.amba4.axi.Axi4SpecRenamer
import spinal.lib.bus.amba4.axilite.{AxiLite4, AxiLite4SpecRenamer}

import scala.language.postfixOps

class DataPath_xN(
                   sync: Boolean,
                   numOfCore: Int,
                   DMA_SPLIT: List[Int],
                   baseAddr: List[BigInt],
                   cmdAddrWidth: List[Int],
                   splitBaseAddr: List[(BigInt, BigInt)],

                   busWidth: Int,
                   sgSplit: Int,

                   dim: Int,
                   head: Int,
                   headDim: Int,
                   predDim: Int,
                   mlpDim: Int,
                   maxToken: Int,
                   layer: Int,
                   ropePoint: Int,
                   sqrtHeadDim: Int,
                   vocabSize: Int,

                   ropeTagMap: List[(Int, Int)],
                   quantTagMap: List[(Int, Int)],
                   softmaxTag: (Int, Int, Int),
                   lnInTagMap: List[(Int, Int)],
                   zeroFilterTagMap: List[(Int, Int)],

                   logitsTag: (Int, Int),
                   resAddTag: Int,
                   vLocalTag: Int,
                   normFilterTag: Int,
                   resOut2NodeTag: Int,
                   p2sOut2NodeTag: List[Int],
                   index2NodeTag: Int,
                   index2UgTag: (Int, Int, Int),

                   attnLnTag: Int,
                   logitsLnTag: Int,
                   lmHeadParamTag: Int,
                   attnVParamTag: Int,
                   mlpDParamTag: Int,
                   kvInTag: List[Int],

                   lnScaleBusTag: List[Int],
                   denseBusTag: List[Int],
                   kvCacheBusTag: List[Int],
                   sparseDotTagMap: List[(Int, Int, Int)],
                   sparseAxpyTagMap: List[(Int, Int, Int)],
                   denseCfgTag: List[Int],
                   sparseCfgTag: List[Int],
                   lnSqrCfgTag: List[Int],
                   kvCfgTag: (Int, Int),
                   mlpGTag: (Int, Int),

                   qkMulTag: (Int, Int, Int),
                   ugMulTag: (Int, Int, Int),
                   axpyTensorInTag: (Int, Int, Int),
                   axpyParamInTag: List[Int],
                   tokenTag: (Int, Int, Int),
                   vTensorTag: (Int, Int),

                   zeroFilterTag2SeqLen: List[(Int, Int)],

                   vecIn2ResTag: List[Int],
                   vecIn2ScalarTag: List[Int],
                   serial2VecOutTag: List[Int],
                   busIn2VecOutTag: List[Int],
                   engine2VecOutTag: List[Int],
                   lnOut2VecTag: List[Int],
                   dotOut2VecTag: List[Int],
                   rope2VecTag: Int,
                   dotOut2NodeTag: List[Int],
                   cfgInsertTag: (Int, Int, Int, Int),

                   mul_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                   add_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                   sub_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                   div_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                   acc_func: Flow[Fragment[Bits]] => Flow[Fragment[Bits]],
                   act_func: Flow[Bits] => Flow[Bits],
                   mul_func_block: (Stream[Bits], Stream[Bits]) => Stream[Bits],

                   rope_highPcs_mul_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                   rope_toInt_func: Flow[Bits] => Flow[Bits],
                   rope_fromInt_func: Flow[Bits] => Flow[Bits],

                   quant_conv_func: Flow[Bits] => Flow[Bits],
                   deQuant_int4_conv_func: Flow[Bits] => Flow[Bits],
                   deQuant_int8_conv_func: Flow[Bits] => Flow[Bits],

                   add_latency: Int,
                   mul_latency: Int,
                   acc_latency: Int,
                   exp_latency: Int,
                   div_latency: Int,
                   deQuant_latency: Int,

                   expo_func: Flow[Bits] => Flow[Bits],
                   rsqrt_func: Flow[Bits] => Flow[Bits],
                   lt_func: (Flow[Bits], Flow[Bits]) => Flow[Bool],

                   fp16toFp32_func: Flow[Bits] => Flow[Bits],
                   fp16toFp32_func_block: Stream[Bits] => Stream[Bits],
                   fp32toFp16_func: Flow[Bits] => Flow[Bits],
                   fp32mul_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                   fp32mul_func_block: (Stream[Bits], Stream[Bits]) => Stream[Bits],
                   fp32acc_func: Flow[Fragment[Bits]] => Flow[Fragment[Bits]],
                   fp32rsqrt_func: Flow[Bits] => Flow[Bits],
                   fp32add_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                   fp32exp_func: Flow[Bits] => Flow[Bits],
                   fp32div_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                   fp32lt_func: (Flow[Bits], Flow[Bits]) => Flow[Bool],
                   fp32sub_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                   mix_mul_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                   add_conv_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],

                   toFp32_latency: Int,
                   toFp16_latency: Int,
                   fp32Mul_latency: Int,
                   fp32Add_latency: Int,
                   fp32Acc_latency: Int,
                   fp32Exp_latency: Int,
                   fp32Div_latency: Int,

                   dotMaxFirstDim: Int,
                   axpyMaxFirstDim: Int,
                   wkvOutFifoDepth: Int,
                   vecP2sFifoDepth: Int,
                   vecOutFifoDepth: Int,
                   resetLowPolarity: Boolean = true
                 ) extends Component {

  val ctrl = slave(AxiLite4(32, 32))
  val cfg = new AxiLiteCtrl(resetLowPolarity)
  cfg.io.ctrl << ctrl
  ctrl.setName("S00_AXIL")
  AxiLite4SpecRenamer(ctrl)

  val softReset = out Bool()
  softReset := cfg.resetOut

  clockDomain.clock.setName("S00_ACLK")
  clockDomain.reset.setName("S00_ARESETN")

  val core_clk = if (!sync) in Vec(Bool(), numOfCore) else null
  val core_rstn = if (!sync) in Vec(Bool(), numOfCore) else null
  val internalClock = Range(0, numOfCore).map(i => ClockDomain.internal("clk_" + i.toString, config = ClockDomainConfig(resetActiveLevel = LOW)))
  for (i <- 0 until numOfCore) {
    if (sync) {
      internalClock(i).clock := clockDomain.readClockWire
      internalClock(i).reset := CoreSoftReset.synchronousResetN(
        clockDomain.readResetWire, cfg.resetOut, resetLowPolarity
      )
    } else {
      internalClock(i).clock := core_clk(i)
      internalClock(i).reset := core_rstn(i)
    }
  }

  val coreArea = for (i <- 0 until numOfCore) yield new ClockingArea(internalClock(i)) {
    val core = new DataPath(baseAddr(i), cmdAddrWidth(i), splitBaseAddr(i), i, numOfCore, busWidth, sgSplit, dim, head, headDim, predDim, mlpDim, maxToken, layer, ropePoint, sqrtHeadDim, vocabSize,
      ropeTagMap, quantTagMap, softmaxTag, lnInTagMap, zeroFilterTagMap,
      logitsTag, resAddTag, vLocalTag, normFilterTag, resOut2NodeTag, p2sOut2NodeTag, index2NodeTag, index2UgTag, attnLnTag, logitsLnTag, lmHeadParamTag, attnVParamTag, mlpDParamTag, kvInTag,
      lnScaleBusTag, denseBusTag, kvCacheBusTag, sparseDotTagMap, sparseAxpyTagMap, denseCfgTag, sparseCfgTag, lnSqrCfgTag, kvCfgTag, mlpGTag,
      qkMulTag, ugMulTag, axpyTensorInTag, axpyParamInTag, tokenTag, vTensorTag,
      zeroFilterTag2SeqLen, vecIn2ResTag, vecIn2ScalarTag, serial2VecOutTag, busIn2VecOutTag, engine2VecOutTag, lnOut2VecTag, dotOut2VecTag, rope2VecTag, dotOut2NodeTag, cfgInsertTag,
      mul_func, add_func, sub_func, div_func, acc_func, act_func, mul_func_block,
      rope_highPcs_mul_func, rope_toInt_func, rope_fromInt_func, quant_conv_func, deQuant_int4_conv_func, deQuant_int8_conv_func, add_latency, mul_latency, acc_latency, exp_latency, div_latency, deQuant_latency,
      expo_func, rsqrt_func, lt_func,
      fp16toFp32_func, fp16toFp32_func_block, fp32toFp16_func, fp32mul_func, fp32mul_func_block, fp32acc_func, fp32rsqrt_func, fp32add_func, fp32exp_func, fp32div_func, fp32lt_func, fp32sub_func, mix_mul_func, add_conv_func,
      toFp32_latency, toFp16_latency, fp32Mul_latency, fp32Add_latency, fp32Acc_latency, fp32Exp_latency, fp32Div_latency,
      dotMaxFirstDim, axpyMaxFirstDim, wkvOutFifoDepth, vecP2sFifoDepth, vecOutFifoDepth, DMA_SPLIT(i)
    )

    val axiArValidSeen = Bits(DMA_SPLIT(i) bits).setAsReg().init(0)
    val axiArFireSeen = Bits(DMA_SPLIT(i) bits).setAsReg().init(0)
    val axiRValidSeen = Bits(DMA_SPLIT(i) bits).setAsReg().init(0)
    val axiRLastSeen = Bits(DMA_SPLIT(i) bits).setAsReg().init(0)
    val axiRRespErrSeen = Bits(DMA_SPLIT(i) bits).setAsReg().init(0)
    val c2cToValidSeen = Bool().setAsReg().init(False)
    val c2cFromValidSeen = Bool().setAsReg().init(False)
    val c2cFromFireSeen = Bool().setAsReg().init(False)
    val softResetSync = BufferCC(cfg.resetOut, init = False)

    for (j <- 0 until DMA_SPLIT(i)) {
      val axi = if (DMA_SPLIT(i) == 1) core.m_axi else core.m_axi_hp(j)
      axiArValidSeen(j).setWhen(axi.ar.valid)
      axiArFireSeen(j).setWhen(axi.ar.valid && axi.ar.ready)
      axiRValidSeen(j).setWhen(axi.r.valid)
      axiRLastSeen(j).setWhen(axi.r.valid && axi.r.last)
      axiRRespErrSeen(j).setWhen(axi.r.valid && axi.r.resp =/= 0)
    }
    if (numOfCore != 1) {
      c2cToValidSeen.setWhen(core.c2c.to.valid)
      c2cFromValidSeen.setWhen(core.c2c.from.valid)
      c2cFromFireSeen.setWhen(core.c2c.from.valid && core.c2c.from.ready)
    }
    when(softResetSync) {
      axiArValidSeen.clearAll()
      axiArFireSeen.clearAll()
      axiRValidSeen.clearAll()
      axiRLastSeen.clearAll()
      axiRRespErrSeen.clearAll()
      c2cToValidSeen.clear()
      c2cFromValidSeen.clear()
      c2cFromFireSeen.clear()
    }
  }

  val m_axi = for (i <- 0 until numOfCore) yield {
    if (DMA_SPLIT(i) == 1) coreArea(i).core.m_axi.toIo() else null
  }

  for (i <- 0 until numOfCore) {
    if (DMA_SPLIT(i) == 1) m_axi(i).setName("M0" + i.toString + "_AXI")
    if (!sync) {
      core_clk(i).setName("M0" + i.toString + "_ACLK")
      core_rstn(i).setName("M0" + i.toString + "_ARESETN")
    }
  }

  val m_axi_hp = for (i <- 0 until numOfCore) yield {
    if (DMA_SPLIT(i) != 1) coreArea(i).core.m_axi_hp.map(_.toIo()) else null
  }

  for (i <- 0 until numOfCore) {
    if (sync) {
      coreArea(i).core.tokenIndex << cfg.io.tokenIndex.m2sPipe.m2sPipe.toStream
      coreArea(i).core.tokenIndex.addTag(crossClockDomain)
    }
    else {
      coreArea(i).core.tokenIndex << cfg.io.tokenIndex.toStream.queue(size = 32, pushClock = clockDomain, popClock = coreArea(i).clockDomain)
    }

    if (sync) {
      coreArea(i).core.aresetn := internalClock(i).readResetWire
      // This reset originates in AXI-Lite's domain but both domains use the
      // same physical clock on the synchronous target. It also feeds explicit
      // diagnostic clears; identify that intentional reset-domain crossing.
      coreArea(i).core.aresetn.addTag(crossClockDomain)
    } else
      // AxiLiteCtrl emits an active-high soft-reset request for this target.
      // It used to be exported only as an unconnected top-level pin, making
      // the loader's write to 0xC0 ineffective.  Synchronize it into each
      // core domain and combine it with the external active-low reset.
      coreArea(i).core.aresetn := core_rstn(i) && !coreArea(i).softResetSync
  }

  for (i <- 0 until numOfCore) {
    coreArea(i).core.diagPage := Delay(cfg.io.diagPage, 2, init = U(0, 2 bits))
    coreArea(i).core.diagIndex := Delay(cfg.io.diagIndex, 2, init = U(0, 13 bits))
  }
  if (numOfCore == 1 && DMA_SPLIT.head == 1 || numOfCore == 4) {
    for (i <- 0 until numOfCore) {
      coreArea(i).core.cmdSel := Delay(cfg.io.cmdSel, 2, init = U(0, 2 bits))
    }
  }

  cfg.status.tokenCnt := coreArea(if (numOfCore == 4) 1 else 0).core.toAxiLite.tokenCnt
  cfg.status.argMaxVld := coreArea(if (numOfCore == 4) 1 else 0).core.toAxiLite.argMaxVld
  cfg.status.argMaxIndex := coreArea(if (numOfCore == 4) 1 else 0).core.toAxiLite.argMaxIndex
  cfg.status.prefill := coreArea(if (numOfCore == 4) 1 else 0).core.toAxiLite.prefill
  cfg.status.layerCnt := coreArea(if (numOfCore == 4) 1 else 0).core.toAxiLite.layerCnt

  for (i <- 0 until 2) {
    if (i < numOfCore) {
      cfg.status.diagCore(i) := (
        B(0, 7 bits) ##
        coreArea(i).core.toAxiLite.layerCnt ##
        coreArea(i).core.toAxiLite.tokenCnt ##
        coreArea(i).core.toAxiLite.prefill
      )
      cfg.status.diagAxi(i) := (
        B(0, 12 bits) ##
        coreArea(i).axiRRespErrSeen.resize(4) ##
        coreArea(i).axiRLastSeen.resize(4) ##
        coreArea(i).axiRValidSeen.resize(4) ##
        coreArea(i).axiArFireSeen.resize(4) ##
        coreArea(i).axiArValidSeen.resize(4)
      )
      for (word <- 0 until 3) {
        cfg.status.diagPipe(i)(word) := coreArea(i).core.toAxiLite.diagPipe(word)
      }
    } else {
      if (numOfCore == 1 && i == 1) {
        cfg.status.diagCore(i) := coreArea(0).core.toAxiLite.diagSampler(0)
        cfg.status.diagAxi(i) := coreArea(0).core.toAxiLite.diagSampler(1)
      } else {
        cfg.status.diagCore(i) := 0
        cfg.status.diagAxi(i) := 0
      }
      for (word <- 0 until 3) {
        if (numOfCore == 1 && i == 1) {
          cfg.status.diagPipe(i)(word) := coreArea(0).core.toAxiLite.diagVecOut(word)
        } else {
          cfg.status.diagPipe(i)(word) := 0
        }
      }
    }
  }
  if (numOfCore >= 2) {
    cfg.status.diagC2c := (
      B(0, 26 bits) ##
      coreArea(1).c2cFromFireSeen ## coreArea(1).c2cFromValidSeen ## coreArea(1).c2cToValidSeen ##
      coreArea(0).c2cFromFireSeen ## coreArea(0).c2cFromValidSeen ## coreArea(0).c2cToValidSeen
    )
  } else {
    cfg.status.diagC2c := 0
  }

  for (i <- 0 until numOfCore) {
    if (m_axi(i) != null) Axi4SpecRenamer(m_axi(i))
    if (m_axi_hp(i) != null) {
      for (j <- 0 until DMA_SPLIT(i)) {
        Axi4SpecRenamer(m_axi_hp(i)(j))
      }
    }
  }

  if (numOfCore != 1) {
    if (sync) {
      (coreArea, coreArea.drop(1) ++ List(coreArea.head)).zipped.foreach { (a, b) =>
        b.core.c2c.to.toStream >> a.core.c2c.from
      }
    }
    else {
      (coreArea, coreArea.drop(1) ++ List(coreArea.head)).zipped.foreach { (a, b) =>
        b.core.c2c.to.toStream.queue(size = 32, pushClock = b.clockDomain, popClock = a.clockDomain) >> a.core.c2c.from
      }
    }
  }
}
