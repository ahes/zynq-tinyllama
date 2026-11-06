package top

import adapter.FlowMux
import attn.KvScaleZeroPacker
import busdemux.AxiBusDistributor
import cfgGen._
import mlp._
import residual._
import spinal.core.Component.push
import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axis._
import util._
import spinal.lib.bus.amba4.axi._
import spinal.lib.bus.amba4.axis._

import scala.language.postfixOps

class DataPath(
                baseAddr: BigInt,
                cmdAddrWidth: Int,
                splitBaseAddr: (BigInt, BigInt),
                id: Int,
                numOfCore: Int,

                busWidth: Int,
                sgSplit: Int,

                dim: Int,
                head: Int,
                headDim: Int,
                predDim: Int,
                mlpDim: Int,
                maxToken: Int,
                layer: Int,
                ropePoint: Int,
                sqrtHeadDim: Int,
                vocabSize: Int,

                ropeTagMap: List[(Int, Int)],
                quantTagMap: List[(Int, Int)],
                softmaxTag: (Int, Int, Int),
                lnInTagMap: List[(Int, Int)],
                zeroFilterTagMap: List[(Int, Int)],

                logitsTag: (Int, Int),
                resAddTag: Int,
                vLocalTag: Int,
                normFilterTag: Int,
                resOut2NodeTag: Int,
                p2sOut2NodeTag: List[Int],
                index2NodeTag: Int,
                index2UgTag: (Int, Int, Int),

                attnLnTag: Int,
                logitsLnTag: Int,
                lmHeadParamTag: Int,
                attnVParamTag: Int,
                mlpDParamTag: Int,
                kvInTag: List[Int],

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

                qkMulTag: (Int, Int, Int),
                ugMulTag: (Int, Int, Int),
                axpyTensorInTag: (Int, Int, Int),
                axpyParamInTag: List[Int],
                tokenTag: (Int, Int, Int),
                vTensorTag: (Int, Int),

                zeroFilterTag2SeqLen: List[(Int, Int)],

                vecIn2ResTag: List[Int],
                vecIn2ScalarTag: List[Int],
                serial2VecOutTag: List[Int],
                busIn2VecOutTag: List[Int],
                engine2VecOutTag: List[Int],
                lnOut2VecTag: List[Int],
                dotOut2VecTag: List[Int],
                rope2VecTag: Int,
                dotOut2NodeTag: List[Int],
                cfgInsertTag: (Int, Int, Int, Int),

                mul_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                add_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                sub_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                div_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                acc_func: Flow[Fragment[Bits]] => Flow[Fragment[Bits]],
                act_func: Flow[Bits] => Flow[Bits],
                mul_func_block: (Stream[Bits], Stream[Bits]) => Stream[Bits],

                rope_highPcs_mul_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                rope_toInt_func: Flow[Bits] => Flow[Bits],
                rope_fromInt_func: Flow[Bits] => Flow[Bits],

                quant_conv_func: Flow[Bits] => Flow[Bits],
                deQuant_int4_conv_func: Flow[Bits] => Flow[Bits],
                deQuant_int8_conv_func: Flow[Bits] => Flow[Bits],

                add_latency: Int,
                mul_latency: Int,
                acc_latency: Int,
                exp_latency: Int,
                div_latency: Int,
                deQuant_latency: Int,

                expo_func: Flow[Bits] => Flow[Bits],
                rsqrt_func: Flow[Bits] => Flow[Bits],
                lt_func: (Flow[Bits], Flow[Bits]) => Flow[Bool],

                fp16toFp32_func: Flow[Bits] => Flow[Bits],
                fp16toFp32_func_block: Stream[Bits] => Stream[Bits],
                fp32toFp16_func: Flow[Bits] => Flow[Bits],
                fp32mul_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                fp32mul_func_block: (Stream[Bits], Stream[Bits]) => Stream[Bits],
                fp32acc_func: Flow[Fragment[Bits]] => Flow[Fragment[Bits]],
                fp32rsqrt_func: Flow[Bits] => Flow[Bits],
                fp32add_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                fp32exp_func: Flow[Bits] => Flow[Bits],
                fp32div_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                fp32lt_func: (Flow[Bits], Flow[Bits]) => Flow[Bool],
                fp32sub_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                mix_mul_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],
                add_conv_func: (Flow[Bits], Flow[Bits]) => Flow[Bits],

                toFp32_latency: Int,
                toFp16_latency: Int,
                fp32Mul_latency: Int,
                fp32Add_latency: Int,
                fp32Acc_latency: Int,
                fp32Exp_latency: Int,
                fp32Div_latency: Int,

                dotMaxFirstDim: Int,
                axpyMaxFirstDim: Int,
                wkvOutFifoDepth: Int,
                vecP2sFifoDepth: Int,
                vecOutFifoDepth: Int,
                dataMoverSplit: Int = 1
              ) extends Component {

  val width = 16
  val bankLen = busWidth / 4
  val parallelWidth = width * bankLen
  val kvQuantWidth = 8
  val quantMaxIntFP16Init = 0x5bf8
  val idWidth = log2Up(numOfCore)

  val c2c = if (numOfCore != 1) new Bundle {
    val from = slave(Stream(Fragment(util.AxiFrame(Bits(width bits), userBit = 6, destBit = idWidth))))
    val to = master(Flow(Fragment(util.AxiFrame(Bits(width bits), userBit = 6, destBit = idWidth))))
  } else null

  val cmdGen = new GenMemCmdLenAlign(
    numOfCore = numOfCore,
    busWidth = busWidth,
    dim = dim,
    mlpDim = mlpDim,
    predDim = predDim,
    head = head,
    layer = layer,
    vocabSize = vocabSize,
    maxToken = maxToken,
    baseAddr = baseAddr,
    extTokenTag = tokenTag,
    dmaSplit = dataMoverSplit
  )

  val toAxiLite = new Bundle {
    val tokenCnt = out Bits (16 bits)
    val argMaxVld = out Bool()
    val argMaxIndex = out Bits (16 bits)
    val diagSampler = out Vec(Bits(32 bits), 2)
    val prefill = out Bool()
    val layerCnt = out Bits (8 bits)
    val diagPipe = out Vec(Bits(32 bits), 3)
    val diagVecOut = out Vec(Bits(32 bits), 3)
  }

  val tokenIndex = slave(Stream(util.AxiFrame(Bits(16 bits), userBit = 6)))
  val tokenIndexPipe = tokenIndex.toFlow.m2sPipe

  //  val attnQKVSplit = in UInt(4 bits) addTag (crossClockDomain)
  //  val attnOSplit = in UInt(4 bits) addTag (crossClockDomain)
  //  val mlpDenseGSplit = in UInt(4 bits) addTag (crossClockDomain)
  //  val lgSplit = in UInt(4 bits) addTag (crossClockDomain)
  //
  //  val attnQKVSplitPipe = Delay(attnQKVSplit, 2)
  //  val attnOSplitPipe = Delay(attnOSplit, 2)
  //  val mlpDenseGSplitPipe = Delay(mlpDenseGSplit, 2)
  //  val lgSplitPipe = Delay(lgSplit, 2)
  //
  //  cmdGen.status.attnQKVSplit := attnQKVSplitPipe
  //  cmdGen.status.attnOSplit := attnOSplitPipe
  //  cmdGen.status.mlpDenseGSplit := mlpDenseGSplitPipe
  //  cmdGen.status.lgSplit := lgSplitPipe

  val tokenIndexFifo = new StreamFifo(tokenIndex.payloadType, 64, forFMax = true)
  tokenIndexFifo.io.push.valid := tokenIndexPipe.valid
  tokenIndexFifo.io.push.tdata := tokenIndexPipe.tdata
  tokenIndexFifo.io.push.tuser := tokenIndexPipe.tuser
  cmdGen.io.tokenIndex << tokenIndexFifo.io.pop

  val m_axi = if (dataMoverSplit == 1) master(Axi4(
    Axi4Config(
      addressWidth = cmdAddrWidth,
      dataWidth = busWidth,
      idWidth = 4,
      useBurst = true,
      useCache = true,
      useId = true,
      useLen = true,
      useProt = true,
      useSize = true,
      arUserWidth = 4,
      awUserWidth = 4,
      useLast = true,
      useResp = true,
      useLock = false,
      useQos = false,
      useRegion = false
    )
  )) else null

  val m_axi_hp = if (dataMoverSplit > 1) Vec(master(Axi4(
    Axi4Config(
      addressWidth = cmdAddrWidth,
      dataWidth = busWidth / dataMoverSplit,
      idWidth = 4,
      useBurst = true,
      useCache = true,
      useId = true,
      useLen = true,
      useProt = true,
      useSize = true,
      arUserWidth = 4,
      awUserWidth = 4,
      useLast = true,
      useResp = true,
      useLock = false,
      useQos = false,
      useRegion = false
    ))), dataMoverSplit) else null

  val aresetn = in Bool()

  val postFix = if (cmdAddrWidth == 32) "" else "b" + cmdAddrWidth.toString
  val dmaMig = if (dataMoverSplit == 1) new AXIDataMoverWrapper(
    busWidth, busWidth, busWidth,
    "AxiDatamover" + busWidth.toString + postFix, cmdBytes = 5 + cmdAddrWidth / 8
  ) else null

  //  val s2mmStsVld = if (dataMoverSplit == 1) Bool() else null
  //  val s2mmStsData = if (dataMoverSplit == 1) Bits(8 bits) else null
  //  val mm2sStsVld = if (dataMoverSplit == 1) Bool() else null
  //  val mm2sStsData = if (dataMoverSplit == 1) Bits(8 bits) else null
  //  if (dataMoverSplit == 1) {
  //    s2mmStsVld := dmaMig.io.m_axis_s2mm_sts.valid
  //    s2mmStsData := dmaMig.io.m_axis_s2mm_sts.data
  //    mm2sStsVld := dmaMig.io.m_axis_mm2s_sts.valid
  //    mm2sStsData := dmaMig.io.m_axis_mm2s_sts.data
  //
  //    s2mmStsVld.addAttribute("mark_debug", "true")
  //    s2mmStsData.addAttribute("mark_debug", "true")
  //    mm2sStsVld.addAttribute("mark_debug", "true")
  //    mm2sStsData.addAttribute("mark_debug", "true")
  //  }

  val kvCacheLen = dim / head * maxToken / dataMoverSplit
  val kvSzLen = 4 * maxToken / dataMoverSplit
  val mlpULen = cmdGen.mmap.mlpDenseU_totalLen / dataMoverSplit
  val mlpDLen = cmdGen.mmap.mlpDenseD_totalLen / dataMoverSplit

  val splitMapList = List(0, kvCacheLen, kvSzLen, 0, mlpULen.toInt, mlpDLen.toInt, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  val dmaHp = if (dataMoverSplit > 1) new SplitAxiDatamover(
    busWidth, dataMoverSplit, 512, offsetTable = splitMapList, addressWidth = cmdAddrWidth
  ) else null

  //  val mm2sCmdReMap = if (cmdAddrWidth != 32) new AddressRemap(splitBaseAddr._1, splitBaseAddr._2, 32, cmdAddrWidth, cmdGen.mmap.denseWhereToSplit) else null
  //  val s2mmCmdReMap = if (cmdAddrWidth != 32) new AddressRemap(splitBaseAddr._1, splitBaseAddr._2, 32, cmdAddrWidth, cmdGen.mmap.denseWhereToSplit) else null

  val mm2sCmdReMap = if (cmdAddrWidth != 32) new AddressRemap(splitBaseAddr._1, splitBaseAddr._2, 32, cmdAddrWidth, cmdGen.mmap.denseWhereToSplit) else null
  val s2mmCmdReMap = if (cmdAddrWidth != 32) new AddressRemap(splitBaseAddr._1, splitBaseAddr._2, 32, cmdAddrWidth, cmdGen.mmap.denseWhereToSplit) else null

  if (cmdAddrWidth != 32) {
    mm2sCmdReMap.io.input << cmdGen.io.mm2sCmd
    s2mmCmdReMap.io.input << cmdGen.io.s2mmCmd
    println("first bank:", cmdGen.mmap.denseWhereToSplit, "second bank", cmdGen.mmap.denseTotalMem - cmdGen.mmap.denseWhereToSplit)
  }

  val mm2sCmdLocal = if (cmdAddrWidth == 32) cmdGen.io.mm2sCmd else mm2sCmdReMap.io.output
  val s2mmCmdLocal = if (cmdAddrWidth == 32) cmdGen.io.s2mmCmd else s2mmCmdReMap.io.output

  if (dataMoverSplit == 1) {
    dmaMig.io.m_axi_s2mm_aresetn := aresetn
    dmaMig.io.m_axi_mm2s_aresetn := aresetn
    dmaMig.io.m_axis_s2mm_cmdsts_aresetn := aresetn
    dmaMig.io.m_axis_mm2s_cmdsts_aresetn := aresetn

    cmdGen.io.mm2s << dmaMig.io.m_axis_mm2s
    dmaMig.io.s_axis_s2mm << cmdGen.io.s2mm.queue(512, latency = 2, forFMax = true)
    dmaMig.io.s_axis_mm2s_cmd.arbitrationFrom(mm2sCmdLocal)
    dmaMig.io.s_axis_mm2s_cmd.data := mm2sCmdLocal.payload
    dmaMig.io.s_axis_s2mm_cmd.arbitrationFrom(s2mmCmdLocal)
    dmaMig.io.s_axis_s2mm_cmd.data := s2mmCmdLocal.payload

    m_axi << dmaMig.io.m_axi
    dmaMig.io.m_axi.r.id.removeAssignments()
    dmaMig.io.m_axi.b.id.removeAssignments()
    dmaMig.io.m_axis_s2mm_sts.freeRun()
    dmaMig.io.m_axis_mm2s_sts.freeRun()
  }

  if (dataMoverSplit > 1) {
    dmaHp.aresetn := aresetn
    dmaHp.io.mm2s >> cmdGen.io.mm2s
    dmaHp.io.s2mm << cmdGen.io.s2mm
    dmaHp.io.mm2sCmd << mm2sCmdLocal
    dmaHp.io.s2mmCmd << s2mmCmdLocal
    (m_axi_hp, dmaHp.io.m_axi).zipped.foreach(_ << _)
  }

  val axi = new AxiBusDistributor(
    busWidth = busWidth,
    dim = dim,
    headDim = headDim,
    numOfCore = numOfCore,
    scaleBanks = dim / numOfCore * 16 / busWidth,
    maxToken = maxToken,
    lnScaleBusTag = lnScaleBusTag,
    denseBusTag = denseBusTag,
    kvCacheBusTag = kvCacheBusTag,
    sparseDotTagMap = sparseDotTagMap,
    sparseAxpyTagMap = sparseAxpyTagMap,
    denseCfgTag = denseCfgTag,
    sparseCfgTag = sparseCfgTag,
    lnSqrCfgTag = lnSqrCfgTag,
    kvCfgTag = kvCfgTag,
    mlpGTag = mlpGTag,
    fp16ToFp32 = fp16toFp32_func_block
  )

  val attn = new AttnSubMod(
    busWidth = busWidth,
    head = head,
    numOfCore = numOfCore,
    headDim = headDim,
    sqrtHeadDim = sqrtHeadDim,
    ropePoint = ropePoint,
    quantWidth = kvQuantWidth,
    quantMaxIntFP16Init = quantMaxIntFP16Init,
    maxToken = maxToken,
    ropeTagMap = ropeTagMap,
    quantTagMap = quantTagMap,
    softmaxTag = softmaxTag,
    qkMulTag = qkMulTag,
    mul_func = mul_func,
    add_func = add_func,
    sub_func = sub_func,
    div_func = div_func,
    acc_func = acc_func,
    highPcs_mul_func = rope_highPcs_mul_func,
    toInt_func = rope_toInt_func,
    fromInt_func = rope_fromInt_func,
    lt_func = lt_func,
    convert_func = quant_conv_func,
    exp_func = expo_func,
    mix_mul_func = mix_mul_func,
    add_conv_func = add_conv_func,
    fp32ToFp16Latency = toFp16_latency,
    fp16ToFp32 = fp16toFp32_func,
    fp32ToFp16 = fp32toFp16_func,
    fp32_lt_func = fp32lt_func,
    fp32_sub_func = fp32sub_func,
    fp32_acc_func = fp32acc_func,
    fp32_div_func = fp32div_func,
    fp32_exp_func = fp32exp_func
  )

  val ln = new NormSubModNew(
    id = id,
    dim = dim,
    numOfCore = numOfCore,
    lnInTagMap = lnInTagMap,
    attnLnTag = attnLnTag,
    logitsLnTag = logitsLnTag,
    fp16toFp32_func = fp16toFp32_func,
    fp16toFp32_func_block = fp16toFp32_func_block,
    fp32toFp16_func = fp32toFp16_func,
    fp32mul_func = fp32mul_func,
    fp32mul_func_block = fp32mul_func_block,
    fp32acc_func = fp32acc_func,
    fp32rsqrt_func = fp32rsqrt_func,
    fp32add_func = fp32add_func
  )

  val sOut = new ScalarOutSubMod(
    mlpDim = mlpDim,
    width = width,
    actLatency = 0,
    //    siluLatency = exp_latency + add_latency + div_latency + 1,
    siluLatency = fp32Exp_latency + fp32Add_latency + fp32Div_latency + toFp32_latency + toFp16_latency,
    index2UgTag = index2UgTag,
    ugMulTag = ugMulTag,
    filterTagMap = zeroFilterTagMap,
    tagSeqLenMap = zeroFilterTag2SeqLen,
    axpyInTag = axpyTensorInTag,
    act_func = act_func,
    mul_func = mul_func,
    lt_func = lt_func
  )

  val busIn = new BusInSubModNew(
    busWidth = busWidth,
    width = width,
    bankLen = bankLen,
    numOfCore = numOfCore,
    dim = dim,
    layer = layer,
    split = sgSplit,
    mlpOutTag = vecIn2ResTag.head,
    kvInTag = kvInTag,
    toResTag = vecIn2ResTag,
    toConvertTag = vecIn2ScalarTag,
    wkvOutFifoDepth = wkvOutFifoDepth,
    vecP2sFifoDepth = vecP2sFifoDepth,
    convert_latency = deQuant_latency,
    int4_conv = deQuant_int4_conv_func,
    int8_conv = deQuant_int8_conv_func,
    headDim = headDim
  )

  val vecOut = new VecOutSubMod(
    width = width,
    dim = dim,
    head = head,
    layer = layer,
    numOfCore = numOfCore,
    bankLen = bankLen,
    fifoDepth = vecOutFifoDepth,
    split = sgSplit,
    lnOutGateTag = lnOut2VecTag,
    dotOutGateTag = dotOut2VecTag,
    ropeOutGateTag = rope2VecTag,
    vLocalTag = vLocalTag,
    serial2VecOutTag = serial2VecOutTag,
    busIn2VecOutTag = busIn2VecOutTag,
    engine2VecOutTag = engine2VecOutTag,
    sqrtHeadDim = sqrtHeadDim,
    mul_func = mul_func
  )

  val resBuf = new ResidualBuffer(
    dim = dim,
    numOfCore = numOfCore,
    width = width,
    bankLen = bankLen,
    split = sgSplit
  )

  val resAdd = new SerialResAdd(
    id = id,
    dim = dim,
    numOfCore = numOfCore,
    width = width,
    addLatency = add_latency,
    resAddTag = resAddTag,
    add_func = add_func
  )

  val engine = new MulAddSGNew(
    numOfCore = numOfCore,
    split = sgSplit,
    width = width,
    bankLen = bankLen,
    dotMaxFirstDim = dotMaxFirstDim,
    axpyMaxFirstDim = axpyMaxFirstDim,
    mul_latency = mul_latency,
    add_latency = add_latency,
    acc_latency = acc_latency,
    add_func = add_func,
    acc_func = acc_func,
    mul_func_nonblock = mul_func,
    mul_func_block = mul_func_block,

    toFp32_func = fp16toFp32_func,
    toFp32_func_block = fp16toFp32_func_block,
    toFp16_func = fp32toFp16_func,
    fp32Mul_func = fp32mul_func,
    fp32Add_func = fp32add_func,

    fp32Acc_func = fp32acc_func,
    toFp32_latency = toFp32_latency,
    toFp16_latency = toFp16_latency,
    fp32Mul_latency = fp32Mul_latency,
    fp32Add_latency = fp32Add_latency,
    fp32Acc_latency = fp32Acc_latency,
    mlpScaleShift = (if (numOfCore == 1 && busWidth == 128 && headDim == 64)
      sys.env.get("EDGELLM_MLP_SCALE_SHIFT").map(_.toInt).getOrElse(0) else 0),
    mlpScaleTag = busIn2VecOutTag.head
  )

  val node = new AllGatherSubModNew(
    id = id,
    numOfCore = numOfCore,
    width = width,
    mlpDim = mlpDim,
    resOut2NodeTag = resOut2NodeTag,
    p2sOut2NodeTag = p2sOut2NodeTag,
    dotOut2NodeTag = dotOut2NodeTag,
    index2NodeTag = index2NodeTag,
    acc_func = acc_func
  )

  val cfgInsert = new InsertCfg(
    insertTag = cfgInsertTag
  )

  val sample = new GreedySampler(
    width = width,
    vocabSize = vocabSize,
    logitsTag = logitsTag,
    lt_func = lt_func,
    repetitionWindow = (if (numOfCore == 1 && busWidth == 128 &&
      sys.env.get("EDGELLM_REPETITION_PENALTY").contains("1")) 128 else 0)
  )

  //  val exp = new ExpFunc(
  //    port = 2,
  //    latency = exp_latency,
  //    lt_func = lt_func,
  //    exp_func = expo_func
  //  )

  //  val siluAct = new Silu(
  //    exp_latency = exp_latency,
  //    add_latency = add_latency,
  //    div_func = div_func,
  //    add_func = add_func,
  //    exp_func = expo_func
  //  )

  val siluAct = new SiluFp32(
    exp_latency = fp32Exp_latency,
    add_latency = fp32Add_latency,
    div_func = fp32div_func,
    add_func = fp32add_func,
    exp_func = fp32exp_func,
    toFp32_func = fp16toFp32_func,
    toFP16_func = fp32toFp16_func
  )

  val szPacker = new KvScaleZeroPacker(
    busWidth = busWidth,
    head = head / numOfCore,
    layer = layer,
    headDim = headDim
  )

  val cfgGen = new GenCfg(
    dim = dim,
    mlpDim = mlpDim,
    predDim = predDim,
    vocabSize = vocabSize,
    head = head,
    layer = layer,
    bankLen = bankLen,
    numOfCore = numOfCore,
    maxToken = maxToken
  )

  val stateGen = new StateGen(
    busInVecCnt = dim * width / busWidth / numOfCore,
    engineOutVecCnt = dim / bankLen / numOfCore,
    dotOutVecCnt = dim / numOfCore,
    layer = layer,
    head = head,
    numOfCore = numOfCore,
    maxToken = maxToken,
    lmHeadParamTag = lmHeadParamTag,
    attnVParamTag = attnVParamTag,
    mlpDParamTag = mlpDParamTag,
    tokenTag = tokenTag,
    mlpTensorTag = busIn2VecOutTag.head,
    vTensorTag = vTensorTag
  )

  //  stateGen.status.layerCnt.addAttribute("mark_debug","true")
  //  stateGen.status.token.addAttribute("mark_debug", "true")
  //  axi.int.bus.tuser.addAttribute("mark_debug", "true")
  //  engine.io.scalarOut.addAttribute("mark_debug", "true")

  cmdGen.local.bus >> axi.io.bus
  node.io.indexOut >> cmdGen.local.index
  cmdGen.local.kvBus.arbitrationFrom(szPacker.io.kvBus)
  cmdGen.local.kvBus.last := szPacker.io.kvBus.last
  cmdGen.local.kvBus.data := szPacker.io.kvBus.fragment
  cmdGen.local.kvBus.dest.clearAll()
  cmdGen.status.enPredictor := stateGen.status.enPredictor

  // from io

  attn.io.dotOut << engine.io.scalarOut

  //  exp.io.inputs(0) << attn.exp.to
  //  exp.io.outputs(0) >> attn.exp.from
  //  exp.io.inputs(1) << siluAct.exp.to
  //  exp.io.outputs(1) >> siluAct.exp.from

  siluAct.io.in << sOut.silu.to
  siluAct.io.out >> sOut.silu.from

  sOut.io.zfIndexOut >> node.io.indexIn
  sOut.io.allReduceOut << node.io.allReduceOut
  sOut.io.scalarOut >> engine.io.axpyIn

  ln.io.allGatherOut << node.io.allGatherOut
  ln.io.allReduceOut << node.io.allReduceOut
  busIn.io.p2sOut >> node.io.p2sOut

  axi.int.lnScale >> ln.io.lnScale
  axi.int.preScale >> engine.io.preScale
  axi.int.postScale >> engine.io.postScale
  axi.int.zeroInt4 >> busIn.io.zeroInt4
  axi.int.zeroInt8 >> busIn.io.zeroInt8

  busIn.io.bus << axi.int.bus
  busIn.io.wkv >> engine.io.wkvIn
  busIn.io.vecIn << engine.io.vecOut

  vecOut.io.dotOut << engine.io.scalarOut
  vecOut.io.vecOut >> engine.io.dotIn
  vecOut.io.engineVecIn << engine.io.vecOut

  resBuf.io.parallelOut >> engine.io.resAdd

  resAdd.io.dotOut << engine.io.scalarOut
  resAdd.io.output >> node.io.resOut
  if (numOfCore != 1) resAdd.io.fromAllReduce << node.io.allReduceOut

  engine.io.scalarOut >> node.io.dotOut

  cfgInsert.io.cfgIn << cfgGen.io.cfg
  cfgInsert.io.cfgOut >> engine.io.cfg
  cfgInsert.io.index << node.io.indexOut

  if (numOfCore != 1) {
    node.c2c.to >> c2c.to
    node.c2c.from << c2c.from
  }

  // submodules interconnection

  vecOut.io.lnOut << ln.io.lnOut
  vecOut.io.vLocal >> busIn.io.vLocal

  busIn.io.toResBuf >> resBuf.io.parallelIn
  busIn.io.directOut >> vecOut.io.busVecIn

  resBuf.io.serialOut >> resAdd.io.fromResBuf
  resBuf.io.serialIn << resAdd.io.toResBuf

  sOut.io.p2sOut.clearAll()
  sOut.io.gateIndexOut >> node.io.gateIndexIn
  sOut.io.ugIndexOut >> node.io.ugIndexIn
  sOut.io.allGatherIndexIn << node.io.indexOut

  attn.io.ropeOut >> vecOut.io.ropeOut
  attn.io.softmaxOut >> sOut.io.softmaxOut

  sample.io.logits << node.io.allReduceOut

  stateGen.io.busIn.valid := axi.int.bus.fire
  stateGen.io.busIn.fragment := axi.int.bus.tuser
  stateGen.io.busIn.last := axi.int.bus.last
  stateGen.io.gtCnt << cfgInsert.io.gtCnt
  stateGen.io.tokenIndexFlow.valid := tokenIndexPipe.fire
  stateGen.io.tokenIndexFlow.payload := tokenIndexPipe.tuser
  stateGen.io.engineOut.valid := engine.io.vecOut.valid
  stateGen.io.engineOut.payload := engine.io.vecOut.tuser
  stateGen.io.dotOut.valid := engine.io.scalarOut.valid
  stateGen.io.dotOut.payload := engine.io.scalarOut.tuser
  stateGen.status.argmaxVld := sample.io.argmax.valid
  stateGen.status.endOfDecode := sample.io.endOfDecode

  // Second-level diagnostics for first-layer stalls.  Sticky event bits show
  // which stages were ever reached; wrapping byte counters and last tags show
  // whether traffic continued beyond the first successful AXI burst.
  val diagEvents = Bits(16 bits).setAsReg().init(0)
  val diagCmdCnt = UInt(8 bits).setAsReg().init(0)
  val diagDmaLastCnt = UInt(8 bits).setAsReg().init(0)
  val diagBusLastCnt = UInt(8 bits).setAsReg().init(0)
  val diagMlpVecCnt = UInt(8 bits).setAsReg().init(0)
  val diagLastBusTag = Bits(6 bits).setAsReg().init(0)
  val diagLastVecTag = Bits(6 bits).setAsReg().init(0)
  val diagLastDotTag = Bits(6 bits).setAsReg().init(0)
  val diagStageEvents = Bits(16 bits).setAsReg().init(0)
  val diagTokenPathEvents = Bits(16 bits).setAsReg().init(0)

  diagEvents(0).setWhen(mm2sCmdLocal.valid)
  diagEvents(1).setWhen(mm2sCmdLocal.fire)
  diagEvents(2).setWhen(cmdGen.io.mm2s.valid)
  diagEvents(3).setWhen(cmdGen.io.mm2s.fire)
  diagEvents(4).setWhen(cmdGen.io.mm2s.fire && cmdGen.io.mm2s.last)
  diagEvents(5).setWhen(axi.int.bus.valid)
  diagEvents(6).setWhen(axi.int.bus.fire)
  diagEvents(7).setWhen(axi.int.bus.fire && axi.int.bus.last)
  diagEvents(8).setWhen(engine.io.vecOut.valid)
  diagEvents(9).setWhen(engine.io.vecOut.valid && engine.io.vecOut.tuser === busIn2VecOutTag.head)
  diagEvents(10).setWhen(engine.io.scalarOut.valid)
  diagEvents(11).setWhen(stateGen.status.nextLayer)
  diagEvents(12).setWhen(mm2sCmdLocal.valid && !mm2sCmdLocal.ready)
  diagEvents(13).setWhen(cmdGen.io.mm2s.valid && !cmdGen.io.mm2s.ready)
  diagEvents(14).setWhen(axi.int.bus.valid && !axi.int.bus.ready)

  // Deeper sticky probes retained for internal debug builds.  Board-side
  // diagPipe(0)[31:16] is reassigned below to the live residual-buffer probe.
  diagStageEvents(0).setWhen(busIn.io.directOut.valid)
  diagStageEvents(1).setWhen(busIn.io.toResBuf.valid)
  diagStageEvents(2).setWhen(busIn.io.wkv.valid)
  diagStageEvents(3).setWhen(busIn.io.wkv.fire)
  diagStageEvents(4).setWhen(cfgInsert.io.cfgOut.valid)
  diagStageEvents(5).setWhen(cfgInsert.io.cfgOut.fire)
  diagStageEvents(6).setWhen(ln.io.lnOut.valid)
  diagStageEvents(7).setWhen(vecOut.io.vecOut.valid)
  diagStageEvents(8).setWhen(vecOut.io.vecOut.fire)
  diagStageEvents(9).setWhen(engine.io.dotIn.valid)
  diagStageEvents(10).setWhen(engine.io.dotIn.fire)
  diagStageEvents(11).setWhen(engine.io.resAdd.valid)
  diagStageEvents(12).setWhen(resBuf.io.parallelOut.valid)
  diagStageEvents(13).setWhen(resAdd.io.output.valid)
  diagStageEvents(14).setWhen(attn.io.ropeOut.valid)
  diagStageEvents(15).setWhen(attn.io.softmaxOut.valid)

  // Token-to-LayerNorm path.  These occupy the previously unused upper
  // 16 bits of diagPipe(2), while the distributor remains in the low half.
  for (i <- 0 until 16) diagTokenPathEvents(i).setWhen(attn.io.diag(i))

  when(mm2sCmdLocal.fire) { diagCmdCnt := diagCmdCnt + 1 }
  when(cmdGen.io.mm2s.fire && cmdGen.io.mm2s.last) { diagDmaLastCnt := diagDmaLastCnt + 1 }
  when(axi.int.bus.fire && axi.int.bus.last) { diagBusLastCnt := diagBusLastCnt + 1 }
  when(engine.io.vecOut.valid && engine.io.vecOut.tuser === busIn2VecOutTag.head) {
    diagMlpVecCnt := diagMlpVecCnt + 1
  }
  when(axi.int.bus.fire) { diagLastBusTag := axi.int.bus.tuser }
  when(engine.io.vecOut.valid) { diagLastVecTag := engine.io.vecOut.tuser }
  when(engine.io.scalarOut.valid) { diagLastDotTag := engine.io.scalarOut.tuser }

  when(!aresetn) {
    diagEvents.clearAll()
    diagCmdCnt.clearAll()
    diagDmaLastCnt.clearAll()
    diagBusLastCnt.clearAll()
    diagMlpVecCnt.clearAll()
    diagLastBusTag.clearAll()
    diagLastVecTag.clearAll()
    diagLastDotTag.clearAll()
    diagStageEvents.clearAll()
    diagTokenPathEvents.clearAll()
  }
  // Live DataMover probe.  The tenth board run showed a permanently stalled
  // command at layer-8 Gate; retain its scheduler state in the low half and
  // use the high half to distinguish command, AXI-read, and stream stalls.
  val diagDmaLive = Bits(16 bits)
  if (dataMoverSplit == 1) {
    val diagMm2sStatus = Bits(8 bits).setAsReg().init(0)
    when(dmaMig.io.m_axis_mm2s_sts.fire) {
      diagMm2sStatus := dmaMig.io.m_axis_mm2s_sts.data
    }
    when(!aresetn) {
      diagMm2sStatus.clearAll()
    }
    diagDmaLive := dmaMig.io.mm2s_err.asBits ##
      dmaMig.io.m_axis_mm2s_sts.valid.asBits ## diagMm2sStatus ##
      mm2sCmdLocal.valid.asBits ## mm2sCmdLocal.ready.asBits ##
      dmaMig.io.m_axi.ar.valid.asBits ## dmaMig.io.m_axi.ar.ready.asBits ##
      dmaMig.io.m_axi.r.valid.asBits ## dmaMig.io.m_axi.r.ready.asBits
  } else {
    diagDmaLive.clearAll()
  }
  toAxiLite.diagPipe(0) := diagDmaLive ## cmdGen.io.diag
  // Compare the independent DDR-command and compute-configuration schedulers.
  // Low bytes retain command/DMA counts and the distributor event bitmap.
  // Live engine deadlock probe: current post-operation tag followed by
  // cfg, weight, AXPY scalar, pre-scale, and residual valid/ready.
  val diagEngineLive = Bits(16 bits)
  diagEngineLive := engine.io.postCfgTag ##
    engine.io.cfg.valid.asBits ## engine.io.cfg.ready.asBits ##
    engine.io.wkvIn.valid.asBits ## engine.io.wkvIn.ready.asBits ##
    engine.io.axpyIn.valid.asBits ## engine.io.axpyIn.ready.asBits ##
    engine.io.preScale.valid.asBits ## engine.io.preScale.ready.asBits ##
    engine.io.resAdd.valid.asBits ## engine.io.resAdd.ready.asBits
  toAxiLite.diagPipe(1) := diagEngineLive ## cmdGen.io.diagTag
  // Dense decoder live probe. Layout: DenseCase sel[15:14], misc group
  // counter[13:11], scale-word FIFO occupancy[10:7], decoded misc V/R[6:5],
  // zero V/R[4:3], scale V/R[2:1], main-data FIFO valid[0].
  val diagDenseLive = Bits(16 bits)
  diagDenseLive := axi.int.diagDeep(1).takeHigh(16)
  toAxiLite.diagPipe(2) := cfgGen.io.diag ## diagDenseLive

  // Decode-localization probe retained for optional Mul/Add investigation.
  val diagAttn0 = Bits(32 bits).setAsReg().init(0)
  val diagAttnCaptured = Bool().setAsReg().init(False)
  val diagDecodeTarget = stateGen.status.token === 2 && stateGen.status.layerCnt === 0

  when(diagDecodeTarget && engine.io.vecOut.valid &&
    engine.io.vecOut.tuser === kvCfgTag._2 && !diagAttnCaptured) {
    diagAttn0 := engine.io.vecOut.tdata.takeLow(32)
    diagAttnCaptured.set()
  }
  when(!aresetn) {
    diagAttn0.clearAll(); diagAttnCaptured.clear()
  }
  // Round32 probe: each word is layer-0/head-0/token-2 QK score in the high
  // half and its corresponding softmax probability in the low half.  Order:
  // local, cached-token-0, cached-token-1.
  // Round46: retain the two QK/probability pairs and expose the first two
  // FP16 attention weighted-sum outputs at layer0/head0/token2. This isolates
  // V accumulation from the following output projection/residual/MLP stages.

  // A dedicated readout selector has no connection to computation modes.
  val diagPage = in UInt (2 bits) addTag (crossClockDomain)
  val diagIndex = in UInt (13 bits) addTag (crossClockDomain)
  if (numOfCore == 1 && dataMoverSplit == 1 && busWidth == 128 && headDim == 64) {
    val statusCount = UInt(16 bits).setAsReg().init(0)
    val commandCount = UInt(16 bits).setAsReg().init(0)
    val packetCount = UInt(16 bits).setAsReg().init(0)
    val responseCount = UInt(16 bits).setAsReg().init(0)
    val lastStatus = Bits(8 bits).setAsReg().init(0)
    val statusErrors = Bits(3 bits).setAsReg().init(0)
    val responseError = Bool().setAsReg().init(False)
    val lastCommandAddress = Bits(32 bits).setAsReg().init(0)
    val lastCommandLength = Bits(23 bits).setAsReg().init(0)
    val lastWriteAddress = Bits(32 bits).setAsReg().init(0)
    when(dmaMig.io.m_axis_s2mm_sts.fire) {
      statusCount := statusCount + 1
      lastStatus := dmaMig.io.m_axis_s2mm_sts.data
      statusErrors := statusErrors | dmaMig.io.m_axis_s2mm_sts.data(6 downto 4)
    }
    when(s2mmCmdLocal.fire) {
      commandCount := commandCount + 1
      lastCommandAddress := s2mmCmdLocal.payload(63 downto 32)
      lastCommandLength := s2mmCmdLocal.payload(22 downto 0)
    }
    when(dmaMig.io.s_axis_s2mm.fire && dmaMig.io.s_axis_s2mm.last) {
      packetCount := packetCount + 1
    }
    when(m_axi.aw.fire) { lastWriteAddress := m_axi.aw.addr.asBits }
    when(m_axi.b.fire) {
      responseCount := responseCount + 1
      responseError.setWhen(m_axi.b.resp =/= B(0, 2 bits))
    }

    val projection = Bits(32 bits).setAsReg().init(0)
    val projectionCount = UInt(2 bits).setAsReg().init(0)
    when(diagDecodeTarget && engine.io.scalarOut.valid &&
      engine.io.scalarOut.tuser === resAddTag && projectionCount < 2) {
      when(projectionCount === 0) { projection(15 downto 0) := engine.io.scalarOut.tdata
      }.otherwise { projection(31 downto 16) := engine.io.scalarOut.tdata }
      projectionCount := projectionCount + 1
    }
    val mlpResult = Bits(32 bits).setAsReg().init(0)
    val mlpCaptured = Bool().setAsReg().init(False)
    when(diagDecodeTarget && engine.io.vecOut.valid &&
      engine.io.vecOut.tuser === busIn2VecOutTag.head && !mlpCaptured) {
      mlpResult := engine.io.vecOut.tdata.takeLow(32)
      mlpCaptured.set()
    }
    val captureMlpStages = sys.env.get("EDGELLM_DIAG_MLP").contains("1")
    val snapshotWords = Vec(Bits(32 bits), 3)
    if (captureMlpStages) {
      // Passive taps: accepted residual and scalar inputs plus emitted MLP output.
      // No ready/valid signal in the compute path depends on the readout logic.
      val residualSnapshot = new util.VectorSnapshot(bankLen, dim, 13)
      val ugSnapshot = new util.VectorSnapshot(1, mlpDim, 13)
      val postMlpSnapshot = new util.VectorSnapshot(bankLen, dim, 13)
      for (snapshot <- List(residualSnapshot, ugSnapshot, postMlpSnapshot)) {
        snapshot.io.index := diagIndex
      }
      residualSnapshot.io.input.valid := diagDecodeTarget && engine.io.resAdd.fire
      residualSnapshot.io.input.payload := engine.io.resAdd.payload
      ugSnapshot.io.input.valid := diagDecodeTarget && engine.io.axpyIn.fire &&
        engine.io.preCfgTag === busIn2VecOutTag.head
      ugSnapshot.io.input.payload := engine.io.axpyIn.payload
      postMlpSnapshot.io.input.valid := diagDecodeTarget && engine.io.vecOut.valid &&
        engine.io.vecOut.tuser === busIn2VecOutTag.head
      postMlpSnapshot.io.input.payload := engine.io.vecOut.tdata
      snapshotWords(0) := residualSnapshot.io.word
      snapshotWords(1) := ugSnapshot.io.word
      snapshotWords(2) := postMlpSnapshot.io.word
    } else {
    val avSnapshot = new util.VectorSnapshot(bankLen)
    val dotSnapshot = new util.VectorSnapshot(bankLen)
    val projectionSnapshot = new util.VectorSnapshot(1)
    for (snapshot <- List(avSnapshot, dotSnapshot, projectionSnapshot)) {
      snapshot.io.index := diagIndex.resize(11)
    }
    avSnapshot.io.input.valid := diagDecodeTarget && engine.io.vecOut.valid &&
      engine.io.vecOut.tuser === kvCfgTag._2
    avSnapshot.io.input.payload := engine.io.vecOut.tdata
    val projectionStart = diagDecodeTarget && engine.io.cfg.fire &&
      engine.io.cfg.payload.takeHigh(6).asUInt === resAddTag && !engine.io.cfg.payload(24)
    val captureDot = Reg(Bool()) init(False)
    captureDot.setWhen(projectionStart)
    val dotPacks = Reg(UInt(7 bits)) init(0)
    dotSnapshot.io.input.valid := diagDecodeTarget && (captureDot || projectionStart) &&
      engine.io.dotIn.fire && dotPacks < 64
    dotSnapshot.io.input.payload := engine.io.dotIn.payload
    when(dotSnapshot.io.input.valid) {
      dotPacks := dotPacks + 1
      when(dotPacks === 63) { captureDot.clear() }
    }
    projectionSnapshot.io.input.valid := diagDecodeTarget && engine.io.scalarOut.valid &&
      engine.io.scalarOut.tuser === resAddTag
    projectionSnapshot.io.input.payload := engine.io.scalarOut.tdata
    snapshotWords(0) := avSnapshot.io.word
    snapshotWords(1) := dotSnapshot.io.word
    snapshotWords(2) := projectionSnapshot.io.word
    }
    val pages = Vec(Vec(Bits(32 bits), 3), 4)
    pages(0)(0) := lastStatus ## statusErrors ##
      dmaMig.io.s_axis_s2mm.valid.asBits ## dmaMig.io.s_axis_s2mm.ready.asBits ##
      m_axi.aw.valid.asBits ## m_axi.aw.ready.asBits ## responseError.asBits ## statusCount.asBits
    pages(0)(1) := lastCommandAddress
    pages(0)(2) := lastWriteAddress
    pages(1)(0) := diagAttn0
    pages(1)(1) := projection
    pages(1)(2) := mlpResult
    pages(2)(0) := commandCount.asBits ## packetCount.asBits
    pages(2)(1) := statusCount.asBits ## responseCount.asBits
    pages(2)(2) := lastCommandLength ## lastStatus ## responseError.asBits
    pages(3) := snapshotWords
    for (slot <- 0 until 3) toAxiLite.diagVecOut(slot) := pages(diagPage)(slot)
  } else {
    toAxiLite.diagVecOut(0) := attn.io.diagProbe(0)
    toAxiLite.diagVecOut(1) := attn.io.diagProbe(1)
    toAxiLite.diagVecOut(2) := diagAttn0
  }

  szPacker.io.qScale << attn.io.quantScale
  szPacker.io.qZero << attn.io.quantZero
  szPacker.io.qOut << attn.io.afterQuant
  szPacker.io.kSzOut >> axi.io.kSzOut
  szPacker.io.vSzOut >> axi.io.vSzOut
  szPacker.io.nextLayer := stateGen.status.nextLayer
  szPacker.io.tokenIndexFlow.valid := tokenIndexPipe.fire
  szPacker.io.tokenIndexFlow.payload := tokenIndexPipe.tuser

  axi.io.token := stateGen.status.token
  axi.io.enPredictor := stateGen.status.enPredictor
  axi.io.postCfgTag := engine.io.postCfgTag
  axi.io.preCfgTag := engine.io.preCfgTag

  busIn.status.tokenNextHit := stateGen.status.tokenNextHit
  busIn.status.mlpNextHit := stateGen.status.mlpNextHit
  busIn.status.vNextHit := stateGen.status.vNextHit
  busIn.status.vLocalEnable := stateGen.status.vLocalEnable
  busIn.status.flushRes := stateGen.status.flushRes
  busIn.status.logitsGen := stateGen.status.logitsGen

  attn.status.token := stateGen.status.token
  ln.status.toLogitsGen := stateGen.status.toLogitsGen

  vecOut.status.tokenIndexFlow.valid := tokenIndexPipe.fire
  vecOut.status.tokenIndexFlow.payload := tokenIndexPipe.tuser

  sOut.status.enPredictor := stateGen.status.enPredictor
  cfgInsert.status.enPredictor := stateGen.status.enPredictor
  vecOut.status.enPredictor := stateGen.status.enPredictor

  cfgGen.status.enPredictor := stateGen.status.enPredictor
  cfgGen.status.tokenIndexFlow.valid := tokenIndexPipe.fire
  cfgGen.status.tokenIndexFlow.payload := tokenIndexPipe.tuser

  toAxiLite.tokenCnt := stateGen.status.token.asBits.resized
  toAxiLite.argMaxVld := sample.io.argmax.valid
  toAxiLite.argMaxIndex := sample.io.argmax.payload
  toAxiLite.diagSampler(0) := sample.io.diagResult
  toAxiLite.diagSampler(1) := sample.io.diagLogits
  toAxiLite.prefill := stateGen.status.prefill
  toAxiLite.layerCnt := stateGen.status.layerCnt.asBits.resized

  val cmdSel = if (numOfCore == 1 & dataMoverSplit == 1 || numOfCore == 4) in UInt (2 bits) addTag (crossClockDomain) else null
  if (numOfCore == 1 & dataMoverSplit == 1 || numOfCore == 4) {
    val cmdSelPipe = RegNext(RegNext(cmdSel))
    val enFatRelu = RegNext(RegNext(cmdSel =/= 0))
    cmdGen.status.cmdSel := cmdSelPipe
    sOut.status.enFatRelu := enFatRelu
  }
  else {
    sOut.status.enFatRelu.clear()
  }
}
