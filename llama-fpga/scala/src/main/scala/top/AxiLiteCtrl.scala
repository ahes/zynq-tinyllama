package top

import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axilite.{AxiLite4, AxiLite4SlaveFactory, AxiLite4SpecRenamer}

import scala.language.postfixOps

class AxiLiteCtrl(resetLowPolarity: Boolean = true) extends Component {

  val io = new Bundle {
    val ctrl = slave(AxiLite4(32, 32))
    val tokenIndex = master(Flow(util.AxiFrame(Bits(16 bits), userBit = 6)))
    val cmdSel = out UInt (2 bits)
    val diagPage = out UInt (2 bits)
    val diagIndex = out UInt (13 bits)
    val presetLayer = out Bits(5 bits)
    val presetToken = out Bits(10 bits)

    //    val attnQKVSplit = out UInt (4 bits) addTag (crossClockDomain)
    //    val attnOSplit = out UInt (4 bits) addTag (crossClockDomain)
    //    val mlpDenseGSplit = out UInt (4 bits) addTag (crossClockDomain)
    //    val lgSplit = out UInt (4 bits) addTag (crossClockDomain)
  }

  val status = new Bundle {
    val tokenCnt = in Bits (16 bits) addTag (crossClockDomain)
    val layerCnt = in Bits (8 bits) addTag (crossClockDomain)
    val argMaxVld = in Bool() addTag (crossClockDomain)
    val argMaxIndex = in Bits (16 bits) addTag (crossClockDomain)
    val prefill = in Bool() addTag (crossClockDomain)
    val diagCore = in Vec(Bits(32 bits), 2) addTag (crossClockDomain)
    val diagAxi = in Vec(Bits(32 bits), 2) addTag (crossClockDomain)
    val diagC2c = in Bits (32 bits) addTag (crossClockDomain)
    val diagPipe = in Vec(Vec(Bits(32 bits), 3), 2) addTag (crossClockDomain)
  }

  val liteBus = AxiLite4(32, 32)
  liteBus << io.ctrl
  liteBus.ar.addr.removeDataAssignments()
  liteBus.ar.addr := (B(0, 22 bits) ## io.ctrl.ar.addr.take(10)).asUInt
  liteBus.aw.addr.removeDataAssignments()
  liteBus.aw.addr := (B(0, 22 bits) ## io.ctrl.aw.addr.take(10)).asUInt

  val ctrl = new AxiLite4SlaveFactory(liteBus)

  val token = Bits(16 bits).setAsReg().init(0)
  val tokenVld = Bool().setAsReg().init(False)
  val isPrefillToken = Bool().setAsReg().init(False)
  val isPrefillLastToken = Bool().setAsReg().init(False)
  val isDecodeToken = Bool().setAsReg().init(False)
  val destTokenCnt = Bits(16 bits).setAsReg().init(0)
  val cmdSel = Bits(2 bits).setAsReg().init(0)
  val softReset = Bool().setAsReg().init(False)
  val diagPage = Bits(2 bits).setAsReg().init(0)
  val diagIndex = Bits(13 bits).setAsReg().init(0)

  ctrl.write(token, 0x00, 0)
  ctrl.write(tokenVld, 0x00, 16)
  ctrl.write(isPrefillToken, 0x00, 17)
  ctrl.write(isPrefillLastToken, 0x00, 18)
  ctrl.write(isDecodeToken, 0x00, 19)
  ctrl.write(cmdSel, 0x24, 0)
  ctrl.write(softReset, 0xC0, 0)
  ctrl.write(diagPage, 0xC4, 0)
  ctrl.read(diagPage, 0xC4, 0)
  ctrl.write(diagIndex, 0xC8, 0)
  ctrl.read(diagIndex, 0xC8, 0)

  tokenVld.clear()
  softReset.clear()

  val resetCycle = 4
  val resetCnt = UInt(log2Up(resetCycle) bits).setAsReg().init(0)
  val resetCntOvf = resetCnt === resetCycle - 1
  val resetKeep = Bool().setAsReg().init(False)
  resetKeep.setWhen(softReset)
  when(resetKeep) {
    resetCnt := resetCnt + 1
    when(resetCntOvf) {
      resetCnt.clearAll()
      resetKeep.clear()
    }
  }

  val resetDly = Delay(resetKeep, 64, init = False)
  val resetOut = out Bool()
  if (resetLowPolarity) {
    resetOut := ~resetDly
  }
  else {
    resetOut := resetDly
  }

  val tokenCntDly = Delay(status.tokenCnt, init = B(0, 16 bits), cycleCount = 2)
  val argMaxVldDly = Delay(status.argMaxVld, init = False, cycleCount = 2)
  val argMaxIndexDly = Delay(status.argMaxIndex.resize(15), init = B(0, 15 bits), cycleCount = 2)
  val prefillDly = Delay(status.prefill, init = False, cycleCount = 2)
  val layerCntDly = Delay(status.layerCnt, init = B(0, 8 bits), cycleCount = 2)

  val argMaxVldClr = Bool().setAsReg().init(False)
  ctrl.write(argMaxVldClr, 0x80, 0)
  argMaxVldClr.clear()

  val argMaxVldLock = Bool().setAsReg().init(False)
  val argMaxIndexLock = Bits(15 bits).setAsReg().init(0)
  argMaxVldLock.setWhen(argMaxVldDly)
  argMaxVldLock.clearWhen(argMaxVldClr)
  when(argMaxVldDly) {
    argMaxIndexLock := argMaxIndexDly
  }
  when(argMaxVldClr) {
    argMaxIndexLock.clearAll()
  }

  val testReg = UInt(32 bits).setAsReg().init(0)
  val magicNum = UInt(32 bits)
  magicNum := 77

  ctrl.read(tokenCntDly, 0x04, 0)
  ctrl.read(argMaxIndexLock, 0x04, 16)
  ctrl.read(argMaxVldLock, 0x04, 31)

  ctrl.read(prefillDly, 0x08, 0)
  ctrl.read(layerCntDly, 0x20, 0)

  // Sticky hardware diagnostics.  The producers latch short AXI/c2c events
  // in their native clock domains, so these values remain safe to inspect
  // from software long after the first stalled transaction.
  ctrl.read(Delay(status.diagCore(0), init = B(0, 32 bits), cycleCount = 2), 0x28, 0)
  ctrl.read(Delay(status.diagCore(1), init = B(0, 32 bits), cycleCount = 2), 0x2C, 0)
  ctrl.read(Delay(status.diagAxi(0), init = B(0, 32 bits), cycleCount = 2), 0x30, 0)
  ctrl.read(Delay(status.diagAxi(1), init = B(0, 32 bits), cycleCount = 2), 0x34, 0)
  ctrl.read(Delay(status.diagC2c, init = B(0, 32 bits), cycleCount = 2), 0x38, 0)
  // Per-core second-level pipeline diagnostics.  Core 0 occupies
  // 0x48/0x4c/0x50 and core 1 occupies 0x54/0x58/0x5c.
  for (core <- 0 until 2; word <- 0 until 3) {
    ctrl.read(
      Delay(status.diagPipe(core)(word), init = B(0, 32 bits), cycleCount = 2),
      0x48 + core * 12 + word * 4,
      0
    )
  }

  ctrl.write(testReg, 0x0C, 0)
  ctrl.read(testReg, 0x0C, 0)
  ctrl.read(magicNum, 0x44, 0)

  val timer = UInt(32 bits).setAsReg().init(0)
  val flag = Bool().setAsReg().init(False)
  when(flag) {
    timer := timer + 1
  }
  flag.setWhen(tokenVld)
  flag.clearWhen(destTokenCnt === status.tokenCnt)

  ctrl.write(destTokenCnt, 0x10, 0)
  ctrl.read(timer, 0x10, 0)

  val tokenUseTag = Bits(6 bits)
  tokenUseTag.clearAll()
  when(isPrefillToken)(tokenUseTag := 0)
  when(isPrefillLastToken)(tokenUseTag := 1)
  when(isDecodeToken)(tokenUseTag := 2)

  io.tokenIndex.tdata := token
  io.tokenIndex.tuser := tokenUseTag
  io.tokenIndex.valid := tokenVld
  io.cmdSel := cmdSel.asUInt
  io.diagPage := diagPage.asUInt
  io.diagIndex := diagIndex.asUInt


  //  val attnQKVSplit = UInt(4 bits).setAsReg().init(0)
  //  val attnOSplit = UInt(4 bits).setAsReg().init(1)
  //  val mlpDenseGSplit = UInt(4 bits).setAsReg().init(2)
  //  val lgSplit = UInt(4 bits).setAsReg().init(4)
  //  ctrl.write(attnQKVSplit, 0x20, 0)
  //  ctrl.write(attnOSplit, 0x20, 4)
  //  ctrl.write(mlpDenseGSplit, 0x20, 8)
  //  ctrl.write(lgSplit, 0x20, 12)
  //  io.attnQKVSplit := attnQKVSplit
  //  io.attnOSplit := attnOSplit
  //  io.mlpDenseGSplit := mlpDenseGSplit
  //  io.lgSplit := lgSplit
}
