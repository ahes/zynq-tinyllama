package mlp

import spinal.core._
import spinal.lib._

class RepetitionPenaltyHarness extends Component {
  val io = new Bundle {
    val value = in Bits(16 bits)
    val penalized = out Bits(16 bits)
  }
  io.penalized := util.Fp16RepetitionPenalty(io.value)
}

object RepetitionPenaltyHarness extends App {
  SpinalConfig(targetDirectory = sys.env("ROUND55_SIM_DIR")).generateVerilog(new RepetitionPenaltyHarness)
}
