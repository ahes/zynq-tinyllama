package busdemux

import spinal.core._
import spinal.lib._

import scala.language.postfixOps

class KvCacheCase(
                   busWidth: Int,
                   headDim: Int,
                   maxToken: Int
                 ) extends Component {

  val scaleZeroPackWidth = 32
  val scaleZeroPerPack = busWidth / scaleZeroPackWidth

  val io = new Bundle {
    val token = in UInt (log2Up(maxToken) bits)
    val bus = slave(Event)
    val main = master(Event)
    val misc = master(Event)
  }

  // Commands alternate metadata and data separately for K and V:
  // K metadata, K data, V metadata, V data. Return to metadata after
  // ONE cache tensor, not after K+V combined. The latter misroutes the
  // first V metadata beat once token reaches busWidth/32 (four on 7035).
  val cacheBeatsPerHead = KvCacheCase.cacheBeatsPerHead(busWidth, headDim)
  val kvCnt = io.token * cacheBeatsPerHead
  val kvSzCnt = io.token.drop(log2Up(scaleZeroPerPack)).asUInt

  val deMux = new StreamDemux(NoData, 2)
  deMux.io.input << io.bus
  deMux.io.outputs(1) >> io.main
  deMux.io.outputs(0) >> io.misc

  val cntLv1 = UInt(16 bits).setAsReg().init(0)
  val cntLv2 = UInt(16 bits).setAsReg().init(0)
  val cntLv1Ovf = cntLv1 === kvSzCnt - 1
  val cntLv2Ovf = cntLv2 === kvCnt - 1

  val sel = UInt(1 bits).setAsReg().init(0)

  when(io.misc.fire) {
    cntLv1 := cntLv1 + 1
    when(cntLv1Ovf) {
      cntLv1 := 0
      sel := 1
    }
  }

  when(io.main.fire) {
    cntLv2 := cntLv2 + 1
    when(cntLv2Ovf) {
      cntLv2 := 0
      sel := 0
    }
  }

  val kvSzCntZeroDly = RegNext(kvSzCnt === 0, init = True)

  deMux.io.select := sel
  when(kvSzCntZeroDly) {
    deMux.io.select := 1
  }
}

object KvCacheCase {
  def cacheBeatsPerHead(busWidth: Int, headDim: Int): Int = {
    require(busWidth > 0 && headDim > 0)
    (headDim * 8 + busWidth - 1) / busWidth
  }

  def fp16PacksPerHead(busWidth: Int, headDim: Int): Int = {
    require(busWidth > 0 && headDim > 0 && busWidth % 4 == 0)
    val valuesPerPack = busWidth / 4
    (headDim + valuesPerPack - 1) / valuesPerPack
  }
}
