package busdemux

import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axis._

// Production distributor; a pack consumer accepts no zero/scale until the
// corresponding weight data arrives. This preserves the metadata-before-data
// dependency which a free-running metadata sink would hide.
class KvMetadataBurstHarness extends Component {
  val io = new Bundle {
    val bus = slave(Axi4Stream(Axi4StreamConfig(dataWidth = 16, destWidth = 6,
      useDest = true, useLast = true, useKeep = true)))
    val token = in UInt(10 bits)
    val modeV = in Bool()
    val main = master(Stream(Bits(128 bits)))
    val zeroValue = out Bits(8 bits)
    val scaleValue = out Bits(32 bits)
  }
  def widen(x: Stream[Bits]): Stream[Bits] = {
    val y = Stream(Bits(32 bits))
    y.arbitrationFrom(x)
    y.payload := x.payload.resize(32)
    y
  }
  val dut = new AxiBusDistributor(
    busWidth = 128, dim = 2048, headDim = 64, numOfCore = 1,
    scaleBanks = 256, maxToken = 1024, lnScaleBusTag = List(2), denseBusTag = List(3),
    kvCacheBusTag = List(0, 1), sparseDotTagMap = List((4, 1, 1)),
    sparseAxpyTagMap = List((5, 1, 1)), denseCfgTag = List(3), sparseCfgTag = List(4),
    lnSqrCfgTag = List(2), kvCfgTag = (13, 15), mlpGTag = (6, 24), fp16ToFp32 = widen)
  dut.io.bus << io.bus
  dut.io.token := io.token
  dut.io.preCfgTag := Mux(io.modeV, B(15, 6 bits), B(13, 6 bits))
  dut.io.postCfgTag := Mux(io.modeV, B(15, 6 bits), B(13, 6 bits))
  dut.io.enPredictor := False
  dut.io.kSzOut.valid := False
  dut.io.kSzOut.payload := 0
  dut.io.vSzOut.valid := False
  dut.io.vSzOut.payload := 0
  dut.int.lnScale.ready := True
  dut.int.zeroInt4.ready := True
  // One 32-value int8->FP16 pack spans two 128-bit input beats. A complete
  // logical 64-value head consumes two repeated zero/scale entries.
  val secondBeat = Reg(Bool()) init(False)
  val localVScales = Reg(UInt(2 bits)) init(2)
  when(!io.modeV) { localVScales := 2 }
  val localV = io.modeV && localVScales =/= 0
  when(localV && dut.int.preScale.fire) { localVScales := localVScales - 1 }
  val scaleValid = Mux(io.modeV, dut.int.preScale.valid, dut.int.postScale.valid)
  val sideValid = dut.int.zeroInt8.valid && scaleValid && !localV
  io.main.valid := dut.int.bus.valid && sideValid
  io.main.payload := dut.int.bus.tdata
  dut.int.bus.ready := io.main.ready && sideValid
  when(io.main.fire) { secondBeat := !secondBeat }
  dut.int.zeroInt8.ready := io.main.fire && secondBeat
  dut.int.postScale.ready := io.main.fire && secondBeat && !io.modeV
  dut.int.preScale.ready := localV || (io.main.fire && secondBeat && io.modeV)
  io.zeroValue := dut.int.zeroInt8.payload
  io.scaleValue := Mux(io.modeV, dut.int.preScale.payload.resize(32), dut.int.postScale.payload)
}

object KvMetadataBurstHarness extends App {
  val target = sys.env.getOrElse("KV_METADATA_SIM_DIR", "../../zynq7035_port/build/round54_kv_metadata_20261101/sim_baseline")
  SpinalConfig(targetDirectory = target).generateVerilog(new KvMetadataBurstHarness)
}
