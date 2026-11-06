# 来源与许可状态

本地草稿尚未选择全仓库许可证，不应把整个目录直接标为 MIT 或 Apache-2.0。

| 内容 | 来源与状态 |
| --- | --- |
| 加速器架构、Scala 工程与部分模型工具 | [adamgallas/llama-fpga](https://github.com/adamgallas/llama-fpga)，本地检出的 HEAD 为 `60e0cb867717bfa3a0e283f1669841e232f15d04`，含本地改动。该提交根目录未找到 LICENSE/COPYING；需要核实适用授权。 |
| tokenizer 算法 | 上游 README 声明来自 [karpathy/llama2.c](https://github.com/karpathy/llama2.c)。发布前应核对实际复制部分、版本及保留其许可文本。 |
| 7035 移植、修复与辅助脚本 | 本地工程修改；与上游源码存在混合，需在明确第三方条款后确定适用许可证。 |
| 模型权重及词表 | TinyLlama-1.1B-Chat-v1.0，固定revision及输入SHA256见 `model/SOURCE.json`。源码包不附权重；本地独立转换已匹配原板测模型和词表哈希。模型仓库标明Apache-2.0；分发权重时需遵守其对应条款。 |
| FPGA IP、BSP、FSBL、板卡预设 | AMD/Xilinx 工具及板卡供应商资源。未打包生成 IP、BSP、FSBL 或厂商预设，使用者需从对应来源获得。 |

保留的 [上游 README](docs/upstream_README.md) 提供论文和致谢信息，其性能表针对其他平台，不是本项目7035测量结果。公开分享时应保留上游署名和引用，明确哪些内容是移植与新增修复。

这里记录的是已查到的材料与待核实事项，不作未经核实的授权推断。GitHub 对许可证的说明：[Licensing a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)。
