# Round55 验证记录

本页描述2026-11-01已有的冷启动板测及实现结果。整理发布草稿不等于重新上板测试；`evidence/round55/` 保留该轮原始记录。

| 输入 | 结果 |
| --- | --- |
| hello? | 49 token，EOS；未出现旧循环，回答仍冗长 |
| nice，连续第二轮 | 53 token，EOS；未出现旧循环，仍模板化 |
| 你叫什么，连续第三轮 | 答非所问，128 token截断 |
| 用中文回答: 2+2=?，reset后 | 20 token，EOS；西班牙语，未答出4 |
| 英文2+2 | 7 token，EOS；2+2=4 |
| 法国首都 | 7 token，EOS；Paris |
| Hello World C | 31 token，EOS；提取代码的 GCC c99/Wall/Wextra/Werror 检查通过 |
| 记住apple | 31 token，EOS；包含Apple |
| 追问记忆词 | 30 token，EOS；包含apple |
| 30条编程tips | 128 token截断，回到You> |

十次回答无推理超时；最终 DMA interr/decerr/slverr/AXI response error 均false，四类计数一致（43392 mod65536）。语义判定包含人工审阅与字面启发式，不是标准化问答基准。原始输入、输出、stop reason和探针见 UART 日志、同名 inputs/analysis JSON、`semantic_review.json` 和 `round55_final_probe.json`。

重复故障定位：Round54 hello? 的首个分叉在第19个输出token，CPU选择 appreciate，板上选择found；参考logit仅差0.015625。强制CPU沿found继续，能重现同样循环。已捕获前64个板上ID逐项匹配这条CPU路径。这证明该重复可由模型与贪心路径产生，并不证明所有FPGA算术均正确。仅两层KV样本做过比较，全模型位精确一致性未建立。

Round55 的已有 XSim 记录包括：65536种FP16位模式穷举；32000词表12扫描；64词表140扫描，含128窗口保留/淘汰、复位、气泡、错标签、负logit、EOS、末索引、NaN和tie。当前草稿的独立重放入口见构建说明；它使用既有生成RTL。

Vivado2021.1实现：LUT42341、FF44793、BRAM142、DSP116；WNS+1.049ns、WHS+0.026ns；78833网络完整布线、0布线错误。DRC为0 Error、0 Critical、86 Warning、29 Advisory，不能写为“无警告”。

## 已测镜像身份

| 文件 | 字节数 / SHA256 |
| --- | --- |
| BOOT Round55 | 13507592；`F4942B274C1CA1974EDC567992E75EFF2D48A3AF09EDBDFF3EFB91DD62DE9281` |
| 生成RTL | `79F76E083A664B16F2B347586C8D8D3F53001F7CF3475FDD976A55856C5796BF` |
| 模型llm.bin | 937803776；`2C24393F3F0715C231C35DC1EDD1851EC3ED45AB5ACC0C753A632A944CE1A5F0` |
| 词表tkz.bin | `8FE75741DA265962CCB42E4EF257816E75ECD6BD20D290FDB5ABB3FACF715326` |

源码包保留该RTL为 `evidence/round55/DataPath_xN_reference.v`；重新生成的生产RTL除Git注释外与其一致。源码包不含上表的启动镜像、模型或词表，本地新构建输出位于assets和build目录。已有镜像哈希仅用于身份核对，不保证新环境重建后得到同一二进制哈希。长期基线Round52与已测候选Round55分别保留，二者不能混称。
