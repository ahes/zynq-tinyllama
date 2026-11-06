package core

import spinal.core._
import spinal.lib._
import util.{Fp16ScaleDown, StreamFifoVldProbe}

import scala.language.postfixOps

class MulEngine(
                 width: Int,
                 bankLen: Int,
                 maxFirstDim: Int,
                 inLineRam: Boolean,
                 mul_latency: Int,
                 mul_func_nonblock: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                 mul_func_block: (Stream[Bits], Stream[Bits]) => Stream[Bits],
                 mlpScaleShift: Int = 0,
                 mlpScaleTag: Int = 31
               ) extends Component {

  val serialBit = width
  val parallelBit = width * bankLen

  case class Config() extends Bundle {

    val data = Bits(32 bits)
    data.setPartialName("")

    def firstDim = data.drop(16).take(8).asUInt

    def secondDim = data.take(16).asUInt

    def isAxpy = data.takeHigh(8).lsb
  }

  val io = new Bundle {
    val wkvIn = slave(Stream(Bits(parallelBit bits)))
    val dotIn = slave(Stream(Bits(parallelBit bits)))
    val axpyIn = slave(Stream(Bits(serialBit bits)))
    val scale = slave(Stream(Bits(serialBit bits)))
    val output = master(Stream(Bits(parallelBit bits)))
    val cfg = slave(Stream(Config()))
    val preCfgTag = out Bits (6 bits)
    val secondDim = out Bits(16 bits)
    val diagDeep = out Bits(32 bits)
    val diagFifo = out Bits(32 bits)
  }

  noIoPrefix()
  util.AxiStreamSpecRenamer(io.wkvIn)
  util.AxiStreamSpecRenamer(io.dotIn)
  util.AxiStreamSpecRenamer(io.axpyIn)
  util.AxiStreamSpecRenamer(io.scale)
  util.AxiStreamSpecRenamer(io.output)
  util.AxiStreamSpecRenamer(io.cfg)

  val cfgDeMux = new StreamDemux(Config(), 2)
  cfgDeMux.io.input << io.cfg
  cfgDeMux.io.select := io.cfg.payload.isAxpy.asUInt
  val toDotCfg = cfgDeMux.io.outputs(0)
  val toAxpyCfg = cfgDeMux.io.outputs(1)

  val ram = new Bundle {
    val rdPort = util.MemRdPort(Bits(parallelBit bits), maxFirstDim)
    val wrPort = Flow(util.MemWrPort(Bits(parallelBit bits), maxFirstDim))
  }

  val mem = if (inLineRam) Mem(Bits(parallelBit bits), maxFirstDim) else null
  if (inLineRam) {
    mem.addAttribute("ram_style", "distributed")
    ram.rdPort.rsp := mem.readSync(enable = ram.rdPort.cmd.valid, address = ram.rdPort.cmd.payload)
    mem.write(enable = ram.wrPort.valid, address = ram.wrPort.address, data = ram.wrPort.data)
  }
  else {
    ram.rdPort.setAsMaster()
    ram.wrPort.setAsMaster()
  }

  val dotLogic = new Area {
    val cfg = toDotCfg
    val cfgPayload = cfg.payload

    val enInc = Bool()
    val (cnt, cntOvf) = util.LoopsCntGen.wireOvf(List(cfgPayload.firstDim, cfgPayload.secondDim), enInc)
    val cntOvfReduce = cntOvf.reduce(_ & _)

    val flag = Bool().setAsReg().init(False)
    val notReadyFlag =  Bool().setAsReg().init(False)
    val inCnt = UInt(log2Up(maxFirstDim) bits).setAsReg().init(0)
    val inCntOvf = inCnt === cfgPayload.firstDim
    inCnt.addAttribute("max_fanout", 100)
    cnt.head.addAttribute("max_fanout", 100)

    when(io.dotIn.fire) {
      inCnt := inCnt + 1
      when(inCntOvf) {
        inCnt := 0
        flag.set()
        notReadyFlag.set()
      }
    }

    val popPre = Event
    popPre.valid := Mux(flag, True, cnt.head < inCnt)
    ram.wrPort.valid := io.dotIn.fire
    ram.wrPort.address := inCnt
    ram.wrPort.data := io.dotIn.payload

    val dotOut = Stream(Bits(parallelBit bits))
    dotOut.arbitrationFrom(popPre.m2sPipe())
    dotOut.payload := ram.rdPort.rsp
    ram.rdPort.cmd.valid := popPre.ready
    ram.rdPort.cmd.payload := cnt.head.resized

    val enIncPipe = Bool()
    val (cntPipe, cntOvfPipe) = util.LoopsCntGen.wireOvf(List(cfgPayload.firstDim, cfgPayload.secondDim), enIncPipe)
    val cntOvfReducePipe = cntOvfPipe.reduce(_ & _)
    enIncPipe := dotOut.fire
    val clrCondPipe = enIncPipe & cntOvfReducePipe

    val incCond = popPre.fire
    val clrCond = incCond & cntOvfReduce
    flag.clearWhen(clrCond)
    notReadyFlag.clearWhen(clrCondPipe)
    cfg.ready := clrCondPipe
    enInc := incCond

    val dotInReady = Bool().setAsReg().init(False)
    dotInReady.addAttribute("keep", "true")
    dotInReady.addAttribute("max_fanout", 100)
    dotInReady.setWhen(cfg.valid & ~notReadyFlag)
    dotInReady.clearWhen(io.dotIn.fire & inCntOvf)

    io.dotIn.ready := dotInReady
  }

  val axpyLogic = new Area {
    val enInc = Bool()
    val (cnt, cntOvf) = util.LoopsCntGen.wireOvf(List(toAxpyCfg.firstDim, toAxpyCfg.secondDim), enInc)
    val cntOvfReduce = cntOvf.reduce(_ & _)

    val inpHalt = io.axpyIn.continueWhen(toAxpyCfg.valid)
    val scaleHalt = io.scale.continueWhen(toAxpyCfg.valid)
    val scaledInput = if (mlpScaleShift == 0) inpHalt else inpHalt.translateWith(
      Mux(toAxpyCfg.payload.asBits.takeHigh(6) === mlpScaleTag,
        util.Fp16Pow2(inpHalt.payload, mlpScaleShift), inpHalt.payload))
    val inpRepeat = util.StreamRepeat(scaledInput, toAxpyCfg.firstDim)
    val scaledRes =  mul_func_block(inpRepeat, scaleHalt)
    val res = scaledRes.m2sPipe()
    res.valid.addAttribute("max_fanout", 100)

    val axpyOut = Stream(Bits(parallelBit bits))
    axpyOut.arbitrationFrom(res)
    axpyOut.payload := Repeat(res.payload, bankLen)

    val incCond = res.fire
    val clrCond = incCond & cntOvfReduce
    toAxpyCfg.ready := clrCond
    enInc := incCond
  }

  val secondDim = toAxpyCfg.secondDim.asBits
  io.secondDim := secondDim
  io.preCfgTag := toAxpyCfg.payload.asBits.takeHigh(6)

  val mux = new StreamMux(Bits(parallelBit bits), 2)
  mux.io.inputs(0) << dotLogic.dotOut
  mux.io.inputs(1) << axpyLogic.axpyOut
  mux.io.select := axpyLogic.axpyOut.valid.asUInt

  val join = StreamJoin(io.wkvIn.toEvent(), mux.io.output.toEvent())

  val act = Flow(Vec(Bits(serialBit bits), bankLen))
  val wkv = Flow(Vec(Bits(serialBit bits), bankLen))
  val wkvScaleDown = io.wkvIn.payload
  act.valid := join.fire
  wkv.valid := join.fire
  act.payload := mux.io.output.payload.subdivideIn(bankLen slices)
  wkv.payload := wkvScaleDown.subdivideIn(bankLen slices)

  val mul = new core.Vec2to1(serialBit, bankLen, mul_latency, mul_func_nonblock)
  mul.io.in0 << act
  mul.io.in1 << wkv

  // Capture the first lane of the first four layer-0/token-2 attention AXPY
  // products.  With firstDim=1 these are local V pack 0/1 followed by cached
  // token-0 V pack 0/1.  Keeping the probe before AddEngine separates a bad
  // scalar/V/scale pairing from an accumulation error.
  val diagAxpyProduct = Vec(Bits(serialBit bits), 4)
  diagAxpyProduct.foreach(_.setAsReg().init(0))
  val diagAxpyProductCnt = UInt(3 bits).setAsReg().init(0)
  val diagAxpyInputCnt = UInt(3 bits).setAsReg().init(0)
  val diagAxpyLocalScalar = Bits(serialBit bits).setAsReg().init(0)
  val diagAxpyLocalValue = Bits(serialBit bits).setAsReg().init(0)
  val diagAxpyCache0Scalar = Bits(serialBit bits).setAsReg().init(0)
  val diagAxpyCache0Value = Bits(serialBit bits).setAsReg().init(0)
  val diagAxpyTarget = toAxpyCfg.valid &&
    toAxpyCfg.payload.asBits.takeHigh(6) === B(15, 6 bits) &&
    toAxpyCfg.secondDim === U(2, 16 bits)
  when(join.fire && diagAxpyTarget && diagAxpyInputCnt < 4) {
    when(diagAxpyInputCnt === 0) {
      diagAxpyLocalScalar := act.payload.head
      diagAxpyLocalValue := wkv.payload.head
    }
    when(diagAxpyInputCnt === 2) {
      diagAxpyCache0Scalar := act.payload.head
      diagAxpyCache0Value := wkv.payload.head
    }
    diagAxpyInputCnt := diagAxpyInputCnt + 1
  }
  val diagAxpyTargetDly = Delay(join.fire && diagAxpyTarget, mul_latency, init = False)
  when(mul.io.res.valid && diagAxpyTargetDly && diagAxpyProductCnt < 4) {
    diagAxpyProduct(diagAxpyProductCnt.resized) := mul.io.res.payload.head
    diagAxpyProductCnt := diagAxpyProductCnt + 1
  }

  val fifo = new StreamFifoVldProbe(Bits(parallelBit bits), 32, forFMax = true)
  val popVldNext = fifo.io.popVldNext.toIo()
  fifo.io.push.valid := mul.io.res.valid
  fifo.io.push.payload := mul.io.res.payload.asBits

  io.output << fifo.io.pop

  val ready = Bool().setAsReg().init(False)
  ready.addAttribute("max_fanout", 100)
  ready := fifo.io.availability >= 8
  join.ready := ready

  // Token-2 layer-0 probe: actual softmax scalar and the paired V lane before
  // multiplication.  word0 is local, word1 is cached token 0.
  io.diagDeep := diagAxpyLocalValue ## diagAxpyLocalScalar
  io.diagFifo := diagAxpyCache0Value ## diagAxpyCache0Scalar
}
