package util

import spinal.core._
import spinal.lib._

/** Observe one complete FP16 vector without adding backpressure to its producer.
  * The high index bit reads the captured value count; lower bits select pairs.
  * Defaults retain the original 2048-value/index1024 readout protocol.
  */
class VectorSnapshot(lanes: Int, values: Int = 2048, indexWidth: Int = 11) extends Component {
  require(lanes == 1 || (isPow2(lanes) && lanes >= 2))
  require(values >= 2 && values % 2 == 0 && values % lanes == 0)
  require(indexWidth >= log2Up(values / 2) + 1)
  val io = new Bundle {
    val input = slave(Flow(Bits(lanes * 16 bits)))
    val index = in UInt(indexWidth bits)
    val word = out Bits(32 bits)
  }
  val count = Reg(UInt(log2Up(values + 1) bits)) init(0)
  val accept = io.input.valid && count < values
  when(accept) { count := count + lanes }
  val data = Bits(32 bits)
  if (lanes == 1) {
    val low = Reg(Bits(16 bits))
    val memory = Mem(Bits(32 bits), values / 2)
    memory.addAttribute("ram_style", "block")
    when(accept && !count(0)) { low := io.input.payload }
    memory.write((count >> 1).resize(log2Up(values / 2)), io.input.payload ## low,
      enable = accept && count(0))
    data := memory.readSync(io.index.takeLow(log2Up(values / 2)).asUInt)
  } else {
    val packs = values / lanes
    val pairsPerPack = lanes / 2
    val memory = Mem(Bits(lanes * 16 bits), packs)
    memory.addAttribute("ram_style", "block")
    memory.write((count >> log2Up(lanes)).resize(log2Up(packs)), io.input.payload,
      enable = accept)
    val packed = memory.readSync((io.index >> log2Up(pairsPerPack)).resize(log2Up(packs)))
    if (pairsPerPack == 1) data := packed
    else {
      val lane = RegNext(io.index.takeLow(log2Up(pairsPerPack)).asUInt) init(0)
      data := packed.subdivideIn(32 bits)(lane)
    }
  }
  io.word := data
  // Pad shorter vectors with zeros when sharing a read index with a longer one.
  if ((1 << (indexWidth - 1)) > values / 2) {
    when(RegNext(io.index.takeLow(indexWidth - 1).asUInt >= values / 2) init(False)) {
      io.word.clearAll()
    }
  }
  when(RegNext(io.index.msb) init(False)) { io.word := count.asBits.resize(32) }
}
