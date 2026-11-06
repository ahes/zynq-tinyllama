package busdemux

import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axis._
import util.{LargeBankFifo, StreamAxiFrameFifo}

import scala.language.postfixOps

class AxiBusDistributor(
                         busWidth: Int,
                         dim: Int,
                         headDim: Int,
                         numOfCore: Int,
                         scaleBanks: Int,
                         maxToken: Int,
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
                         fp16ToFp32: Stream[Bits] => Stream[Bits] = x => x
                       ) extends Component {

  val cfg = Axi4StreamConfig(
    dataWidth = busWidth / 8,
    destWidth = 6,
    useDest = true,
    useLast = true,
    useKeep = true
  )

  val sparseBusTagMap = sparseDotTagMap ++ sparseAxpyTagMap

  val io = new Bundle {
    val bus = slave(Axi4Stream(cfg))
    val token = in UInt (log2Up(maxToken) bits)
    val preCfgTag = in Bits (6 bits)
    val postCfgTag = in Bits (6 bits)
    val enPredictor = in Bool()
    val kSzOut = slave(Stream(Bits(32 bits)))
    val vSzOut = slave(Stream(Bits(32 bits)))

    //    val busDeMuxSel = in UInt (3 bits)
    //    val busMuxSel = in UInt (2 bits)
    //    val miscInMuxSel = in UInt (2 bits)
  }

  val int = new Bundle {
    val bus = master(Stream(Fragment(util.AxiFrame(Bits(busWidth bits), userBit = 6))))
    val lnScale = master(Stream(Bits(16 bits)))
    val zeroInt4 = master(Stream(Bits(8 bits)))
    val zeroInt8 = master(Stream(Bits(8 bits)))
    val preScale = master(Stream(Bits(16 bits)))
    val postScale = master(Stream(Bits(32 bits)))
    val diag = out Bits(16 bits)
    val diagDeep = out Vec(Bits(32 bits), 2)
  }

  //  val busFire = io.bus.fire
  //  busFire.addAttribute("mark_debug", "true")

  //  val startInfer = Bool().setAsReg().init(False)
  //  startInfer.setWhen(busFire)
  //  val haltDetected = Bool().setAsReg().init(False)
  //  val haltCnt = UInt(16 bits).setAsReg().init(0)
  //  val haltCntEn = Bool()
  //  val haltCntClr = Bool()
  //  when(haltCntEn) {
  //    haltCnt := haltCnt + 1
  //    when(haltCnt >= 6500) {
  //      haltDetected.set()
  //    }
  //  }
  //  when(haltCntClr) {
  //    haltCnt.clearAll()
  //  }
  //  haltCntEn := startInfer & ~busFire
  //  haltCntClr := busFire
  //  haltDetected.addAttribute("mark_debug", "true")
  //  io.bus.valid.addAttribute("mark_debug", "true")
  //  io.bus.ready.addAttribute("mark_debug", "true")
  //  io.bus.last.addAttribute("mark_debug", "true")

  val busDeMux = new StreamDemux(NoData(), 5)
  val busMux = new StreamMux(NoData(), 4)
  val miscInMux = new StreamMux(NoData(), 3)
  busDeMux.io.input.arbitrationFrom(io.bus)

  val busTag = UInt(6 bits)
  busTag := io.bus.dest
  //  busTag.addAttribute("mark_debug", "true")
  val mlpGBusHitNotSparse = busTag === mlpGTag._1 & ~io.enPredictor
  val lnScaleHit = lnScaleBusTag.map(_ === busTag).reduce(_ || _)
  val denseHit = denseBusTag.map(_ === busTag).reduce(_ || _) || mlpGBusHitNotSparse
  val sparseHit = sparseBusTagMap.map(_._1 === busTag).reduce(_ || _) & ~mlpGBusHitNotSparse
  val kvHit = kvCacheBusTag.map(_ === busTag).reduce(_ || _)

  val busDeMuxSel = UInt(3 bits)
  busDeMuxSel := 0
  when(denseHit) {
    busDeMuxSel := 1
  }.elsewhen(sparseHit) {
    busDeMuxSel := 2
  }.elsewhen(kvHit) {
    busDeMuxSel := 3
  }.elsewhen(lnScaleHit) {
    busDeMuxSel := 4
  }

  val busMuxSel = UInt(2 bits)
  busMuxSel := 0
  when(denseHit) {
    busMuxSel := 1
  }.elsewhen(sparseHit) {
    busMuxSel := 2
  }.elsewhen(kvHit) {
    busMuxSel := 3
  }

  val miscInMuxSel = UInt(2 bits)
  miscInMuxSel := 0
  when(sparseHit) {
    miscInMuxSel := 1
  }.elsewhen(kvHit) {
    miscInMuxSel := 2
  }

  // Data, tag and TLAST are one transaction.  Keeping them in independent
  // FIFOs is not atomic: one queue can accept/pop while the other cannot,
  // shifting every following tag by one beat.  That only surfaced after a
  // long dense transfer on the 128-bit target.  Store the complete frame in
  // one FIFO so a single ready/valid handshake advances all fields.
  val busFifo = new StreamFifo(
    Fragment(util.AxiFrame(Bits(busWidth bits), userBit = 6)),
    depth = 32,
    forFMax = true
  )
  busFifo.io.push.arbitrationFrom(busMux.io.output)
  busFifo.io.push.tdata := io.bus.data
  busFifo.io.push.tuser := io.bus.dest.asBits
  busFifo.io.push.last := io.bus.last
  busFifo.io.pop >> int.bus

  val isVOut = io.bus.dest === kvCacheBusTag(1)
  val axpyHit = sparseAxpyTagMap.map(_._1 === io.bus.dest).reduce(_ || _)

  // LargeBankFifo's split distributed implementation never asserted push
  // ready on the 128-bit single-core target. Use the existing monolithic FIFO
  // fallback for this low-bandwidth scale/zero side channel.
  // The misc payload and its routing metadata have the same atomicity
  // requirement.  The old two-FIFO implementation drove tag.valid from
  // data.fire without including tag.ready in upstream ready, so a full tag
  // queue could silently discard metadata while retaining the data beat.
  // A cached K/V transfer sends its entire metadata burst before any data.
  // Zero-point consumption waits for that data, so the misc FIFO must hold
  // the whole burst. At 128 bits, token260 needs 65 metadata beats and the
  // old 64-entry FIFO deadlocks before the data command can start.
  val maxKvMetadataBeats = (maxToken + busWidth / 32 - 1) / (busWidth / 32)
  val miscFifoDepth = scala.math.max(64, 1 << log2Up(maxKvMetadataBeats))
  val miscFifo = new StreamFifo(Bits((busWidth + 10) bits), depth = miscFifoDepth, forFMax = true)
  miscFifo.io.push.arbitrationFrom(miscInMux.io.output)
  miscFifo.io.push.payload := axpyHit ## isVOut ## miscInMux.io.select.asBits ##
    io.bus.dest.asBits ## io.bus.data

  busDeMux.io.select := busDeMuxSel
  busMux.io.select := busMuxSel
  miscInMux.io.select := miscInMuxSel

  val miscData = miscFifo.io.pop.payload.take(busWidth)
  val miscTag = miscFifo.io.pop.payload.drop(busWidth)

  val tagFifoDest = Bits(6 bits)
  tagFifoDest := miscTag.take(6)
  val tagFifoSel = Bits(2 bits)
  tagFifoSel := miscTag.drop(6).take(2)

  //  tagFifoDest.addAttribute("mark_debug", "true")
  //  tagFifo.io.pop.valid.addAttribute("mark_debug", "true")
  //  tagFifo.io.pop.ready.addAttribute("mark_debug", "true")

  val miscOutDeMux = new StreamDemux(NoData(), 3)
  miscOutDeMux.io.select := tagFifoSel.asUInt
  miscOutDeMux.io.input.arbitrationFrom(miscFifo.io.pop)

  val ln = new Area {
    //    val buf = new StreamFifo(Bits(busWidth bits), depth = scaleBanks, forFMax = true)
    //    val scaleOut = Stream(Bits(16 bits))
    //    StreamWidthAdapter(buf.io.pop, scaleOut)
    //    buf.io.push.arbitrationFrom(busDeMux.io.outputs(4))
    //    buf.io.push.payload := io.bus.data
    //    int.lnScale << scaleOut

    val bufWidth = scala.math.max(16, 16 * dim / 512)
    val buf = new StreamFifo(Bits(bufWidth bits), 512, forFMax = true)
    val bufIn = Stream(Bits(busWidth bits))
    bufIn.arbitrationFrom(busDeMux.io.outputs(4))
    bufIn.payload := io.bus.data
    StreamWidthAdapter(bufIn, buf.io.push)
    val scaleOut = Stream(Bits(16 bits))
    StreamWidthAdapter(buf.io.pop, scaleOut)
    int.lnScale << scaleOut.queue(32, latency = 2, forFMax = true)
  }

  val dense = new Area {
    val gen = new DenseCase(busWidth)
    val bus = Stream(Bits(busWidth bits))
    bus.arbitrationFrom(miscOutDeMux.io.outputs(0))
    bus.payload := miscData

    val cnt = UInt(3 bits).setAsReg().init(0)
    val cntIsZero = Bool().setAsReg().init(True)
    val cntOvf = cnt === 4
    when(bus.fire) {
      cnt := cnt + 1
      cntIsZero.clear()
      when(cntOvf) {
        cnt := 0
        cntIsZero.set()
      }
    }

    val deMux = new StreamDemux(NoData(), 2)
    deMux.io.input.arbitrationFrom(bus)
    deMux.io.select := cntIsZero.asUInt

    val toScale = Stream(Bits(busWidth bits))
    toScale.arbitrationFrom(deMux.io.outputs(0))
    toScale.payload := bus.payload

    val toZero = Stream(Bits(busWidth bits))
    toZero.arbitrationFrom(deMux.io.outputs(1))
    toZero.payload := bus.payload

    // Scale and zero decoding must remain phase-locked across layer
    // boundaries.  Avoid the non-atomic split FIFO here for the same reason
    // as the main return-data FIFO above.
    val scaleFifo = new StreamFifo(Bits(busWidth bits), 8, forFMax = true)
    scaleFifo.io.push << toScale
    val scale = Stream(Bits(16 bits))
    StreamWidthAdapter(scaleFifo.io.pop, scale)

    val zero = Stream(Bits(4 bits))
    val zeroPipe = zero.m2sPipe()
    val zeroAlign = Stream(Bits(8 bits))
    StreamWidthAdapter(toZero.m2sPipe(), zero)
    zeroAlign.arbitrationFrom(zeroPipe)
    zeroAlign.payload := zeroPipe.payload.resized
  }

  val sparse = new Area {
    val scaleZeroPackWidth = 20
    val scaleZeroPerPack = busWidth / scaleZeroPackWidth
    val truncWidth = scaleZeroPerPack * scaleZeroPackWidth

    val gen = new SparseCase(sparseBusTagMap)
    gen.io.tag := io.bus.dest.asBits

    val bus = Stream(util.AxiFrame(Bits(truncWidth bits), userBit = 6))
    bus.arbitrationFrom(miscOutDeMux.io.outputs(1))
    bus.tdata := miscData.take(truncWidth)
    bus.tuser := tagFifoDest

    val tagHit = sparseBusTagMap.map(_._1 === bus.tuser).asBits()
    val packVec = sparseBusTagMap.map(x => U(x._3, 8 bits))
    val packCnt = MuxOH(tagHit, packVec)

    val packOut = Stream(Bits(scaleZeroPackWidth bits))

    val cntLv1 = UInt(8 bits).setAsReg().init(0)
    val cntLv2 = UInt(8 bits).setAsReg().init(0)
    val cntLv1Ovf = cntLv1 === scaleZeroPerPack - 1
    val cntLv2Ovf = cntLv2 === packCnt - 1
    bus.ready.clear()
    when(packOut.fire) {
      cntLv1 := cntLv1 + 1
      cntLv2 := cntLv2 + 1
      when(cntLv1Ovf) {
        cntLv1.clearAll()
        bus.ready.set()
      }
      when(cntLv2Ovf) {
        cntLv1.clearAll()
        cntLv2.clearAll()
        bus.ready.set()
      }
    }
    cntLv1.addAttribute("max_fanout", 100)

    val busPayloadSubDiv = bus.tdata.subdivideIn(scaleZeroPackWidth bits)
    packOut.valid := bus.valid
    packOut.payload := busPayloadSubDiv(cntLv1.resize(log2Up(scaleZeroPerPack) bits))

    val preScaleFifo = StreamFifo(Bits(16 bits), 32, latency = 2, forFMax = true)
    val postScaleFifo = StreamFifo(Bits(16 bits), 32, latency = 2, forFMax = true)
    val zeroFifo = StreamFifo(Bits(4 bits), 64, latency = 1, forFMax = true)

    preScaleFifo.io.push.payload := packOut.payload.drop(4)
    postScaleFifo.io.push.payload := packOut.payload.drop(4)
    zeroFifo.io.push.payload := packOut.payload.take(4)

    val selAxpy = miscTag.msb
    // Scale and zero are two halves of the same 20-bit sideband entry.  The
    // old freeRun connection advanced packOut even while either destination
    // FIFO was full, silently dropping entries during deep MLP prefetch.  The
    // loss surfaced later as a deterministic preScale underflow at layer 7.
    // Make the two writes atomic and only advance the unpack counters when
    // both selected destinations accept the entry.
    val scalePushReady = Mux(
      selAxpy,
      preScaleFifo.io.push.ready,
      postScaleFifo.io.push.ready
    )
    packOut.ready := scalePushReady & zeroFifo.io.push.ready
    preScaleFifo.io.push.valid := packOut.valid & selAxpy & zeroFifo.io.push.ready
    postScaleFifo.io.push.valid := packOut.valid & ~selAxpy & zeroFifo.io.push.ready
    zeroFifo.io.push.valid := packOut.valid & scalePushReady

    val preScale = preScaleFifo.io.pop
    val postScale = postScaleFifo.io.pop
    val zeroQueue = Stream(Bits(8 bits))
    zeroQueue.arbitrationFrom(zeroFifo.io.pop)
    zeroQueue.payload := B"0000" ## zeroFifo.io.pop.payload

    //    val fork = new StreamFork(NoData(), 2, synchronous = true)
    //    fork.io.input.arbitrationFrom(packOut)
    //
    //    val scale = Stream(Bits(16 bits))
    //    scale.arbitrationFrom(fork.io.outputs(0))
    //    scale.payload := packOut.payload.drop(4)
    //
    //    //    val dotHit = sparseDotTagMap.map(_._1 === bus.tuser).reduce(_ || _)
    //    //    val axpyHit = sparseAxpyTagMap.map(_._1 === bus.tuser).reduce(_ || _)
    //    //    val scaleDeMux = StreamDemuxOh(scale, Seq(axpyHit, dotHit))
    //
    //    val scaleDeMux = new StreamDemux(Bits(16 bits), 2)
    //    scaleDeMux.io.input << scale
    //    val preScale = scaleDeMux.io.outputs(1)
    //    val postScale = scaleDeMux.io.outputs(0)
    //    val selAxpy = tagFifo.io.pop.payload.msb
    //    scaleDeMux.io.select := selAxpy.asUInt
    //
    //    val zeroAlign = Stream(Bits(8 bits))
    //    zeroAlign.arbitrationFrom(fork.io.outputs(1))
    //    zeroAlign.payload := B"0000" ## packOut.payload.take(4)
    //
    //    val zeroQueue = zeroAlign.queue(32, latency = 1, forFMax = true)
  }

  val kv = new Area {
    val scaleZeroPackWidth = 32
    val scaleZeroPerPack = busWidth / scaleZeroPackWidth

    val gen = new KvCacheCase(busWidth, headDim, maxToken)
    gen.io.token := io.token
    val bus = Stream(Bits(busWidth bits))
    bus.arbitrationFrom(miscOutDeMux.io.outputs(2))
    bus.payload := miscData

    val extPack = Stream(Bits(scaleZeroPackWidth bits))
    StreamWidthAdapter(bus, extPack)

    val kPack = Stream(Bits(scaleZeroPackWidth bits))
    val vPack = Stream(Bits(scaleZeroPackWidth bits))
    val isVOut = miscTag.dropHigh(1).msb

    val kCnt = UInt(log2Up(maxToken) bits).setAsReg().init(0)
    val kCntOvf = kCnt === io.token - 1

    val vCnt = UInt(log2Up(maxToken) bits).setAsReg().init(0)
    val vCntOvf = vCnt === io.token - 1

    val tokenHigh = io.token.drop(log2Up(scaleZeroPerPack)).asUInt
    val kCntHigh = kCnt.drop(log2Up(scaleZeroPerPack)).asUInt
    val vCntHigh = vCnt.drop(log2Up(scaleZeroPerPack)).asUInt
    val kCntLow = kCnt.take(log2Up(scaleZeroPerPack)).asUInt
    val vCntLow = vCnt.take(log2Up(scaleZeroPerPack)).asUInt
    val tokenHighZeroDly = RegNext(tokenHigh === 0, init = True)

    val kCntHighMatch = Bool().setAsReg().init(False)
    when(kPack.fire) {
      kCnt := kCnt + 1
      when(kCntLow.andR & kCntHigh === tokenHigh - 1) {
        kCntHighMatch.set()
      }
      when(kCntOvf) {
        kCnt := 0
        kCntHighMatch.clear()
      }
    }

    val vCntHighMatch = Bool().setAsReg().init(False)
    when(vPack.fire) {
      vCnt := vCnt + 1
      when(vCntLow.andR & vCntHigh === tokenHigh - 1) {
        vCntHighMatch.set()
      }
      when(vCntOvf) {
        vCnt := 0
        vCntHighMatch.clear()
      }
    }

    //    val kSelLocal = tokenHighZeroDly || kCntHigh === tokenHigh
    //    val vSelLocal = tokenHighZeroDly || vCntHigh === tokenHigh
    val kSelLocal = tokenHighZeroDly || kCntHighMatch
    val vSelLocal = tokenHighZeroDly || vCntHighMatch

    //    val kLocalCnt = UInt(16 bits).setAsReg().init(0)
    //    val kLocalErrDetect = Bool().setAsReg().init(False)
    //    when(kSelLocal & io.token > 17){
    //      kLocalCnt := kLocalCnt + 1
    //      when(kLocalCnt > 1024){
    //        kLocalErrDetect.set()
    //      }
    //    }.otherwise{
    //      kLocalCnt.clearAll()
    //      kLocalErrDetect.clear()
    //    }
    //    kLocalCnt.addAttribute("mark_debug", "true")
    //    kLocalErrDetect.addAttribute("mark_debug", "true")

    val extPackDeMux = new StreamDemux(Bits(scaleZeroPackWidth bits), 2)
    extPackDeMux.io.input << extPack.m2sPipe()
    extPackDeMux.io.select := isVOut.asUInt

    val kMux = new StreamMux(Bits(scaleZeroPackWidth bits), 2)
    kMux.io.inputs(0) << extPackDeMux.io.outputs(0)
    kMux.io.inputs(1) << io.kSzOut
    kMux.io.select := kSelLocal.asUInt
    kMux.io.output >> kPack

    val vMux = new StreamMux(Bits(scaleZeroPackWidth bits), 2)
    vMux.io.inputs(0) << extPackDeMux.io.outputs(1)
    vMux.io.inputs(1) << io.vSzOut
    vMux.io.select := vSelLocal.asUInt
    vMux.io.output >> vPack

    val kFork = new StreamFork(NoData(), 2)
    kFork.io.input.arbitrationFrom(kPack)

    val kScale = Stream(Bits(16 bits))
    kScale.arbitrationFrom(kFork.io.outputs(0))
    kScale.payload := kPack.payload.take(16)
    val kZero = Stream(Bits(8 bits))
    kZero.arbitrationFrom(kFork.io.outputs(1))
    kZero.payload := kPack.payload.drop(16).take(8)

    val vFork = new StreamFork(NoData(), 2)
    vFork.io.input.arbitrationFrom(vPack)

    val vScalePreInsert = Stream(Bits(16 bits))
    vScalePreInsert.arbitrationFrom(vFork.io.outputs(0))
    // Cached V values are divided by another 2^4 in BusInSubModNew.  Move the
    // inverse factor into their metadata scale so probability * scale remains
    // a normal FP16 value.  The inserted local-V unity scale bypasses this.
    vScalePreInsert.payload := util.Fp16ScaleUp(vPack.payload.take(16), 4)
    val vZero = Stream(Bits(8 bits))
    vZero.arbitrationFrom(vFork.io.outputs(1))
    vZero.payload := vPack.payload.drop(16).take(8)

    val vScale = Stream(Bits(16 bits))
    val vScaleOne = Stream(Bits(16 bits))
    val vScaleCnt = UInt(log2Up(maxToken) bits).setAsReg().init(0)
    val vScaleCntIsZero = Bool().setAsReg().init(True)
    when(vScale.fire) {
      vScaleCnt := vScaleCnt + 1
      vScaleCntIsZero.clear()
      when(vScaleCnt === io.token) {
        vScaleCnt := 0
        vScaleCntIsZero.set()
      }
    }

    vScaleOne.valid := vScalePreInsert.valid & vScaleCntIsZero
    vScaleOne.payload := 0x3c00

    val vScaleMux = new StreamMux(Bits(16 bits), 2)
    vScaleMux.io.inputs(0) << vScalePreInsert
    vScaleMux.io.inputs(1) << vScaleOne
    vScaleMux.io.select := vScaleCntIsZero.asUInt
    vScaleMux.io.output >> vScale

//    kScale.payload.removeDataAssignments()
//    kZero.payload.removeDataAssignments()
//    kScale.payload := 0x3c00
//    kZero.payload := 1
//    vScale.payload.removeDataAssignments()
//    vZero.payload.removeDataAssignments()
//    vScale.payload := 0x3c00
//    vZero.payload := 1
  }

  dense.gen.io.bus.arbitrationFrom(busDeMux.io.outputs(1))
  sparse.gen.io.bus.arbitrationFrom(busDeMux.io.outputs(2))
  kv.gen.io.bus.arbitrationFrom(busDeMux.io.outputs(3))

  busMux.io.inputs(0).arbitrationFrom(busDeMux.io.outputs(0))
  busMux.io.inputs(1).arbitrationFrom(dense.gen.io.main)
  busMux.io.inputs(2).arbitrationFrom(sparse.gen.io.main)
  busMux.io.inputs(3).arbitrationFrom(kv.gen.io.main)

  miscInMux.io.inputs(0).arbitrationFrom(dense.gen.io.misc)
  miscInMux.io.inputs(1).arbitrationFrom(sparse.gen.io.misc)
  miscInMux.io.inputs(2).arbitrationFrom(kv.gen.io.misc)

  // A Stream payload is don't-care while valid is low.  Preserve the tag of
  // the last real main beat so a queued zero/scale tail is still routed to
  // the matrix that produced it instead of following the stale payload of
  // the next (back-pressured) DMA transfer.
  val postBusTag = Bits(6 bits).setAsReg().init(0)
  when(int.bus.fire) {
    postBusTag := int.bus.tuser
  }
  val activePostBusTag = Bits(6 bits)
  activePostBusTag := postBusTag
  when(int.bus.valid) {
    activePostBusTag := int.bus.tuser
  }
  val postMlpGBusHitNotSparse = activePostBusTag === mlpGTag._1 & ~io.enPredictor
  val postSparseHit = sparseBusTagMap.map(_._1 === activePostBusTag).reduce(_ || _) & ~postMlpGBusHitNotSparse
  val postKHit = activePostBusTag === kvCacheBusTag.head
  val postVHit = activePostBusTag === kvCacheBusTag.last

  val zeroInt4Mux = new StreamMux(Bits(8 bits), 2)
  // A dense zero word unpacks to 32 zero entries, matching the following 32
  // packed-weight beats one-for-one.  Repeating entries here overfills the
  // metadata FIFO and deadlocks before the next zero word can be accepted.
  zeroInt4Mux.io.inputs(0) << dense.zeroAlign
  zeroInt4Mux.io.inputs(1) << sparse.zeroQueue
  zeroInt4Mux.io.select := postSparseHit.asUInt
  int.zeroInt4 << zeroInt4Mux.io.output

  // Each K/V zero point belongs to a logical head, while the int8 converter
  // consumes one zero per physical FP16 pack.  Repeat both zero streams on a
  // narrow datapath. Both V-cache AXPY and K-cache dot products consume one
  // scale per physical pack: Fp32AccEngine multiplies each pack reduction
  // before accumulating the complete logical head.
  val headPackLen = KvCacheCase.fp16PacksPerHead(busWidth, headDim)
  val kZeroExpanded = if (headPackLen == 1) {
    kv.kZero
  } else {
    util.StreamRepeat(kv.kZero, U(headPackLen - 1))
  }
  val vZeroExpanded = if (headPackLen == 1) {
    kv.vZero
  } else {
    util.StreamRepeat(kv.vZero, U(headPackLen - 1))
  }
  val vZeroFifo = new StreamFifo(Bits(8 bits), 512, forFMax = true)
  vZeroFifo.io.push << vZeroExpanded
  val vScaleFifo = new StreamFifo(Bits(16 bits), 512, forFMax = true)
  val vScaleExpanded = if (headPackLen == 1) {
    kv.vScale
  } else {
    util.StreamRepeat(kv.vScale, U(headPackLen - 1))
  }
  vScaleFifo.io.push << vScaleExpanded

  val zeroInt8Mux = new StreamMux(Bits(8 bits), 3)
  zeroInt8Mux.io.inputs(0).valid.clear()
  zeroInt8Mux.io.inputs(0).payload.clearAll()
  zeroInt8Mux.io.inputs(1) << kZeroExpanded
  zeroInt8Mux.io.inputs(2) << vZeroFifo.io.pop
  zeroInt8Mux.io.select := 0
  when(postKHit)(zeroInt8Mux.io.select := 1)
  when(postVHit)(zeroInt8Mux.io.select := 2)
  int.zeroInt8 << zeroInt8Mux.io.output

  //  val sqrFactor = Stream(Bits(16 bits))
  //  sqrFactor.payload := 0x3c00
  //
  //  val postScaleMux = new StreamMux(Bits(16 bits), 5)
  //  postScaleMux.io.inputs(0) << dense.scale.queue(512, forFMax = true)
  //  postScaleMux.io.inputs(1) << sparse.postScale.queue(512, forFMax = true)
  //  postScaleMux.io.inputs(2) << kv.kScale.queue(512, forFMax = true)
  //  postScaleMux.io.inputs(3) << sqrFactor
  //  postScaleMux.io.inputs(4).valid.clear()
  //  postScaleMux.io.inputs(4).payload.clearAll()
  //  postScaleMux.io.output >> int.postScale

  //  val sqrFactor = Stream(Bits(32 bits))
  //  sqrFactor.payload := 0x3f800000
  val denseScaleFifo = new StreamFifo(Bits(32 bits), 512, forFMax = true)
  val sparseScaleFifo = new StreamFifo(Bits(32 bits), 512, forFMax = true)
  val kScaleFifo = new StreamFifo(Bits(32 bits), 512, forFMax = true)
  denseScaleFifo.io.push << fp16ToFp32(dense.scale)
  sparseScaleFifo.io.push << fp16ToFp32(sparse.postScale)
  // Match every per-pack reduction entering Fp32AccEngine. Without expansion
  // the second pack consumes the next cached token's scale, then subsequent
  // reductions see an empty scale FIFO and silently reuse its stale payload.
  val kScaleExpanded = if (headPackLen == 1) {
    kv.kScale
  } else {
    util.StreamRepeat(kv.kScale, U(headPackLen - 1))
  }
  kScaleFifo.io.push << fp16ToFp32(kScaleExpanded)
  val denseScale = denseScaleFifo.io.pop
  val sparseScale = sparseScaleFifo.io.pop
  val kScale = kScaleFifo.io.pop
  val postScaleMux = new StreamMux(Bits(32 bits), 4)
  postScaleMux.io.inputs(0) << denseScale
  postScaleMux.io.inputs(1) << sparseScale
  postScaleMux.io.inputs(2) << kScale
  postScaleMux.io.inputs(3).valid.clear()
  postScaleMux.io.inputs(3).payload.clearAll()
  postScaleMux.io.output >> int.postScale

  val postMlpCfgHitNotSparse = io.postCfgTag === mlpGTag._2 & ~io.enPredictor
  val postCfgDenseHit = denseCfgTag.map(_ === io.postCfgTag).reduce(_ || _) || postMlpCfgHitNotSparse
  val postCfgSparseHit = sparseCfgTag.map(_ === io.postCfgTag).reduce(_ || _) & ~postMlpCfgHitNotSparse
  val postCfgKvHit = io.postCfgTag === kvCfgTag._1
  //  val postCfgLnHit = lnSqrCfgTag.map(_ === io.postCfgTag).reduce(_ || _)

  //  sqrFactor.valid.setAsReg().init(False)
  //  sqrFactor.valid.setWhen(postCfgLnHit.rise())
  //  val sqrCnt = UInt(log2Up(scaleBanks / 4) bits).setAsReg().init(0)
  //  when(sqrFactor.fire) {
  //    sqrCnt := sqrCnt + 1
  //    when(sqrCnt === scaleBanks / 4 - 1) {
  //      sqrCnt := 0
  //      sqrFactor.valid.clear()
  //    }
  //  }

  val postSel = UInt(2 bits)
  postSel := 3
  when(postCfgDenseHit)(postSel := 0)
  when(postCfgSparseHit)(postSel := 1)
  when(postCfgKvHit)(postSel := 2)
  //  when(postCfgLnHit)(postSel := 3)
  postScaleMux.io.select := postSel

  val sparsePreScaleFifo = new StreamFifo(Bits(16 bits), 512, forFMax = true)
  sparsePreScaleFifo.io.push << sparse.preScale
  //  sparsePreScaleFifo.io.availability.addAttribute("mark_debug", "true")

  val preScaleMux = new StreamMux(Bits(16 bits), 3)
  preScaleMux.io.inputs(0) << sparsePreScaleFifo.io.pop
  preScaleMux.io.inputs(1) << vScaleFifo.io.pop
  preScaleMux.io.inputs(2).valid.clear()
  preScaleMux.io.inputs(2).payload.clearAll()
  preScaleMux.io.output >> int.preScale

  val preCfgSparseHit = sparseCfgTag.map(_ === io.preCfgTag).reduce(_ || _)
  val preCfgKvHit = io.preCfgTag === kvCfgTag._2

  val preSel = UInt(2 bits)
  preSel := 2
  when(preCfgSparseHit)(preSel := 0)
  when(preCfgKvHit)(preSel := 1)
  preScaleMux.io.select := preSel

  // Live pre-scale probe, exported in diagPipe(2)[15:0].  Layout:
  // [15:6] sparsePreScale occupancy, [5:4] mux select,
  // [3:2] sparse producer valid/ready, [1:0] output valid/ready.
  int.diag := sparsePreScaleFifo.io.occupancy.asBits.resize(10) ##
    preSel.asBits ##
    sparse.preScale.valid.asBits ## sparse.preScale.ready.asBits ##
    preScaleMux.io.output.valid.asBits ## preScaleMux.io.output.ready.asBits

  // Deep return-path probe, consumed by the Zynq-7035 loader.
  int.diagDeep(0) := io.bus.dest.asBits ##
    io.bus.valid.asBits ## io.bus.ready.asBits ## io.bus.last.asBits ##
    busFifo.io.occupancy.asBits.resize(6) ##
    busFifo.io.pop.valid.asBits ## busFifo.io.pop.ready.asBits ##
    busFifo.io.pop.last.asBits ## busFifo.io.pop.tuser ##
    miscFifo.io.occupancy.asBits.resize(7) ## miscFifo.io.pop.valid.asBits
  int.diagDeep(1) := dense.gen.io.diagSel ## dense.cnt.asBits ##
    dense.scaleFifo.io.occupancy.asBits.resize(4) ##
    dense.bus.valid.asBits ## dense.bus.ready.asBits ##
    dense.zeroAlign.valid.asBits ## dense.zeroAlign.ready.asBits ##
    dense.scale.valid.asBits ## dense.scale.ready.asBits ##
    busFifo.io.pop.valid.asBits ## B(0, 16 bits)

  //  val scaleCnt = UInt(16 bits).setAsReg().init(0)
  //  scaleCnt.addAttribute("mark_debug", "true")
  //  when(preScaleMux.io.output.fire & preSel === 0)(scaleCnt := scaleCnt + 1)
  //  when(preSel =/= 0)(scaleCnt.clearAll())
}
