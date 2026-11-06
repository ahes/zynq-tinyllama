package mlp

import spinal.core._
import spinal.lib._

class SamplerPolicyHarness(vocab: Int = 32000) extends Component {
  val io = new Bundle {
    val valid = in Bool()
    val tag = in Bits(6 bits)
    val value = in Bits(16 bits)
    val resultValid = out Bool()
    val result = out Bits(16 bits)
    val legacyValid = out Bool()
    val legacy = out Bits(16 bits)
  }
  def less(a: Flow[Bits], b: Flow[Bits]): Flow[Bool] = {
    val ret = Flow(Bool())
    ret.valid := a.valid && b.valid
    val am = a.payload(14 downto 0).asUInt
    val bm = b.payload(14 downto 0).asUInt
    val an = a.payload(14 downto 10).andR && a.payload(9 downto 0).orR
    val bn = b.payload(14 downto 10).andR && b.payload(9 downto 0).orR
    ret.payload := False
    when(!an && !bn && (am =/= 0 || bm =/= 0)) {
      when(a.payload.msb =/= b.payload.msb) { ret.payload := a.payload.msb }
      .otherwise { ret.payload := Mux(a.payload.msb, am > bm, am < bm) }
    }
    ret
  }
  for (window <- List(0, 128)) {
    val sampler = new GreedySampler(16, vocab, (42, 2), less, window)
    sampler.io.logits.valid := io.valid
    sampler.io.logits.tdata := io.value
    sampler.io.logits.tuser := io.tag
    if (window == 0) {
      io.legacyValid := sampler.io.argmax.valid
      io.legacy := sampler.io.argmax.payload
    } else {
      io.resultValid := sampler.io.argmax.valid
      io.result := sampler.io.argmax.payload
    }
  }
}

object SamplerPolicyHarness extends App {
  SpinalConfig(targetDirectory = sys.env("ROUND55_SIM_DIR")).generateVerilog(new SamplerPolicyHarness)
}

class SamplerPolicySmallHarness extends SamplerPolicyHarness(64)
object SamplerPolicySmallHarness extends App {
  SpinalConfig(targetDirectory = sys.env("ROUND55_SIM_DIR")).generateVerilog(new SamplerPolicySmallHarness)
}
