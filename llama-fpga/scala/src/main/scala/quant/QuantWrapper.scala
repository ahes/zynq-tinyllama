package quant

import adapter.{FlowGate, FlowMux, TagMap}
import spinal.core._
import spinal.lib._
import util._

import scala.language.postfixOps

class QuantWrapper(
                    busWidth: Int,
                    quantWidth: Int,
                    headDim: Int,
                    maxIntFP16Init: Int,
                    numOfPort: Int,
                    tagMap: List[(Int, Int)],
                    lt_func: (Flow[Bits], Flow[Bits]) => Flow[Bool],
                    sub_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                    div_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                    convert_func: Flow[Bits] => Flow[Bits]
                  ) extends Component {

  val io = new Bundle {
    val toBeQuant = Vec(slave(Flow(util.AxiFrame(Bits(16 bits), userBit = 6))), numOfPort)
    val quantZero = master(Flow(Bits(quantWidth bits)))
    val quantScale = master(Flow(Bits(16 bits)))
    val afterQuant = master(Flow(Fragment(Bits(quantWidth bits))))
    val diag = out Bits(16 bits)
  }

  //  val (toBeQuantTgM, toBeQuantErr) = TagMap(io.toBeQuant, tagMap)
  //  val toBeQuant = toBeQuantTgM.m2sPipe()

  val kToBeQuant = TagMap.gate(io.toBeQuant(0), tagMap.take(2)).m2sPipe
  val vToBeQuant = TagMap.gate(io.toBeQuant(1), tagMap.drop(2)).m2sPipe
  val (toBeQuant, _) = FlowMux(Vec(kToBeQuant, vToBeQuant))

  util.AxiStreamSpecRenamer(toBeQuant)

  val find = new FindRange(lt_func)
  val getCfg = new GetScaleZero(quantWidth, maxIntFP16Init, sub_func, div_func, convert_func)
  val quant = new LinearQuant(quantWidth, div_func, convert_func)

  find.cfg.length := U(headDim - 1, 16 bits)

  find.io.x << toBeQuant.translateWith(toBeQuant.tdata)
  find.io.min >> getCfg.io.min
  find.io.max >> getCfg.io.max

  // The 128-bit single-core target can queue several head vectors while the
  // scale/zero pipeline replays earlier vectors.  The old 1024-entry FIFO
  // silently dropped Flow samples once eight 128-element vectors accumulated.
  val quantFifoDepth = if (busWidth == 128) 4096 else 1024
  val cfgFifoDepth = if (busWidth == 128) 64 else 32
  val xFifo = new StreamFifo(Bits(16 bits), quantFifoDepth, forFMax = true)
  xFifo.io.push.valid := find.io.x.valid
  xFifo.io.push.payload := find.io.x.payload

  val scaleFifo = new StreamFifo(Bits(16 bits), cfgFifoDepth, forFMax = true)
  val scaleRep = scaleFifo.io.pop.repeat(headDim)._1.m2sPipe()
  scaleFifo.io.push.valid := getCfg.io.scale.valid
  scaleFifo.io.push.payload := getCfg.io.scale.payload

  val zeroFifo = new StreamFifo(Bits(quantWidth bits), cfgFifoDepth, forFMax = true)
  val zeroRep = zeroFifo.io.pop.repeat(headDim)._1.m2sPipe()
  zeroFifo.io.push.valid := getCfg.io.zero.valid
  zeroFifo.io.push.payload := getCfg.io.zero.payload

  val joinEvent = StreamJoin(xFifo.io.pop.toEvent(), scaleRep.toEvent())
  val joinEventFire = joinEvent.fire
  joinEvent.freeRun()

  quant.io.x.valid := joinEventFire
  quant.io.x.payload := xFifo.io.pop.payload
  quant.io.scale.valid := joinEventFire
  quant.io.scale.payload := scaleRep.payload
  quant.io.zero << zeroRep
  //  io.afterQuant << quant.io.q

  val afterQuant = Flow(Fragment(Bits(quantWidth bits)))

  val cnt = UInt(log2Up(headDim) bits).setAsReg().init(0)
  val cntOvf = cnt === headDim - 1
  when(afterQuant.valid) {
    cnt := cnt + 1
    when(cntOvf) {
      cnt := 0
    }
  }

  afterQuant.valid := quant.io.q.valid
  afterQuant.payload := quant.io.q.payload
  afterQuant.last := cntOvf & quant.io.q.valid

  io.afterQuant << afterQuant.m2sPipe
  io.quantScale << getCfg.io.scale.m2sPipe
  io.quantZero << getCfg.io.zero.m2sPipe

  io.diag(0) := kToBeQuant.valid
  io.diag(1) := vToBeQuant.valid
  io.diag(2) := toBeQuant.valid
  io.diag(3) := find.io.min.valid
  io.diag(4) := find.io.max.valid
  io.diag(5) := getCfg.io.scale.valid
  io.diag(6) := getCfg.io.zero.valid
  io.diag(7) := xFifo.io.push.ready
  io.diag(8) := toBeQuant.valid && !xFifo.io.push.ready
  io.diag(9) := xFifo.io.pop.valid
  io.diag(10) := quant.io.q.valid
  io.diag(11) := afterQuant.valid && afterQuant.last
  io.diag(12) := scaleFifo.io.push.ready
  io.diag(13) := zeroFifo.io.push.ready
  io.diag(14) := scaleRep.valid
  io.diag(15) := zeroRep.valid
}
