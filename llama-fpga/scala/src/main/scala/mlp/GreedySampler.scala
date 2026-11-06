package mlp

import adapter.FlowGate
import spinal.core._
import spinal.lib._

import scala.language.postfixOps

class GreedySampler(
                     width: Int,
                     vocabSize: Int,
                     logitsTag: (Int, Int),
                     lt_func: (Flow[Bits], Flow[Bits]) => Flow[Bool],
                     repetitionWindow: Int = 0
                   ) extends Component {

  val io = new Bundle {
    val logits = slave(Flow(util.AxiFrame(Bits(width bits), userBit = 6)))
    val argmax = master(Flow(Bits(width bits)))
    val endOfDecode = out Bool()
    val diagResult = out Bits(32 bits)
    val diagLogits = out Bits(32 bits)
  }

  noIoPrefix()
  util.AxiStreamSpecRenamer(io.argmax)

  val logitsIn = FlowGate(io.logits, List(logitsTag._1))
  require(repetitionWindow == 0 || (repetitionWindow >= 2 && isPow2(repetitionWindow) && repetitionWindow <= 1024))
  val fp16negInf = 0xfc00

  val maxFlow = Flow(Bits(width bits))
  maxFlow.valid := logitsIn.valid
  maxFlow.payload.setAsReg().init(fp16negInf)

  val cnt = UInt(log2Up(vocabSize) bits).setAsReg().init(0)
  val cntOvf = cnt === vocabSize - 1
  when(logitsIn.valid) {
    cnt := cnt + 1
    when(cntOvf) {
      cnt.clearAll()
    }
  }

  val logitsProbe = Flow(Fragment(Bits(width bits)))
  logitsProbe.valid := logitsIn.valid
  logitsProbe.last := cntOvf
  logitsProbe.payload := logitsIn.payload
  util.AxiStreamSpecRenamer(logitsProbe)

  // The default remains the original greedy sampler. The optional dialogue
  // policy penalizes only previously GENERATED tokens, once per candidate,
  // with a 9/8 repetition penalty. Prompt tokens do not enter this history.
  // Compute reset clears it before each firmware run_prompt invocation.
  val candidate = Flow(Bits(width bits))
  candidate.valid := logitsIn.valid
  candidate.payload := logitsIn.payload
  val historyCommit = Flow(UInt(log2Up(vocabSize) bits))
  if (repetitionWindow > 0) {
    require(width == 16)
    val history = Vec(Reg(UInt(log2Up(vocabSize) bits)) init(0), repetitionWindow)
    val historyCount = Reg(UInt(log2Up(repetitionWindow + 1) bits)) init(0)
    val historyWrite = Reg(UInt(log2Up(repetitionWindow) bits)) init(0)
    val seen = (0 until repetitionWindow).map(i =>
      historyCount > i && history(i) === cnt).reduce(_ || _)
    when(seen && cnt >= 3) {
      candidate.payload := util.Fp16RepetitionPenalty(logitsIn.payload)
    }
    when(historyCommit.valid) {
      history(historyWrite) := historyCommit.payload
      historyWrite := historyWrite + 1
      when(historyCount =/= repetitionWindow) { historyCount := historyCount + 1 }
    }
  }
  val xGreaterThanMax = lt_func(maxFlow, candidate)

  val index = UInt(log2Up(vocabSize) bits).setAsReg().init(0)
  val indexNext = UInt(log2Up(vocabSize) bits)
  indexNext := index

  val maxNext = Bits(16 bits)
  maxNext := maxFlow.payload

  when(logitsIn.valid) {
    when(xGreaterThanMax.payload) {
      maxNext := candidate.payload
      indexNext := cnt
    }
  }

  when(logitsIn.valid) {
    maxFlow.payload := maxNext
    index := indexNext
    when(cntOvf) {
      maxFlow.payload := fp16negInf
      index := 0
    }
  }

  val vld = logitsIn.valid & cntOvf
  // Retain numerical evidence for the last complete vocabulary scan.
  val nanCount = UInt(16 bits).setAsReg().init(0)
  val isNan = logitsIn.payload(14 downto 10).andR &&
    logitsIn.payload(9 downto 0).orR
  val nanNext = nanCount + isNan.asUInt.resize(16)
  val firstLogit = Bits(16 bits).setAsReg().init(0)
  val resultProbe = Bits(32 bits).setAsReg().init(0)
  val logitsProbeLock = Bits(32 bits).setAsReg().init(0)
  when(logitsIn.valid) {
    nanCount := nanNext
    when(cnt === 0) { firstLogit := logitsIn.payload }
    when(cntOvf) {
      resultProbe := nanNext.asBits ## maxNext
      logitsProbeLock := firstLogit ## logitsIn.payload
      nanCount := 0
    }
  }
  io.diagResult := resultProbe
  io.diagLogits := logitsProbeLock
  val vldDly = RegNext(vld, False)
  val indexDly = RegNext(indexNext.resize(16).asBits)
  historyCommit.valid := vldDly
  historyCommit.payload := indexDly.asUInt.resized

  val argmax = Flow(Bits(16 bits))
  argmax.valid := vldDly
  argmax.payload := indexDly

  io.argmax << argmax
  //  io.endOfDecode := io.argmax.valid & io.argmax.payload === logitsTag._2
  io.endOfDecode.clear()
}
