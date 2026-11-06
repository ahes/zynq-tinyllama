# 独立目录复现流程

工程输入全部位于本目录。需要另行安装Vivado/Vitis2021.1、Java17和sbt1.9.9；模型转换使用Python3.11及 `model/requirements.txt` 的固定依赖。工具安装目录可以在命令行指定，无须沿用作者盘符。

## 四项复现内容

1. **硬件配置**：`hardware/Sources/IP/` 有30份从已测IP定义导出的Tcl；`hardware/Sources/BD/system.tcl` 包含完整PS、总线、时钟、复位和地址映射。`board/ps7_config.tcl` 单独保存878项PS配置。创建后对比器件、top、36个总IP、PS全部配置及源码路径；所有硬件输入来自本目录或安装工具。
2. **软件**：`scripts/build_software.tcl` 从本地新XSA创建standalone平台，启用xilffs，编译Round55应用并从工具模板新建FSBL，不使用旧BSP、旧FSBL或旧ELF。
3. **模型**：`model/SOURCE.json` 固定TinyLlama-1.1B-Chat-v1.0的revision和七个输入文件的SHA256；从原始权重展开MHA后以fp-minmax重导出。需要匹配937803776字节模型和词表的既有板测哈希。
4. **干净构建和板测**：从空的build目录运行整板构建、打包载荷核验，再写SD并进行冷启动。构建通过和冷启动通过分开记录；未发生的板测不能用旧日志替代。

## 从新解压目录构建

先按 `model/requirements.txt` 配置Python环境。当前已验证环境使用torch2.6.0+cu124，在CPU上执行模型转换；其余直接依赖及完整观测版本见 `model/environment_observed.json`。首次编译需要下载sbt/Maven依赖，首次模型准备需要网络访问Hugging Face。

```powershell
powershell -NoProfile -File scripts/build.ps1 -Stage All `
  -VivadoRoot 'D:/Xilinx/Vivado/2021.1' `
  -VitisRoot 'D:/Xilinx/Vitis/2021.1' `
  -SbtCommand 'sbt' `
  -ModelPython 'C:/your-python-environment/python.exe' `
  -PythonCommand 'python' -DownloadModel
```

替换上述工具位置即可。目录中已有完整原始checkpoint且符合 `model/SOURCE.json` 时，省略 `-DownloadModel`。模型文件在 `assets/`，不纳入源码Git或源码ZIP。

脚本按RTL→硬件→软件→模型→打包顺序运行，也可以用 `-Stage RTL/Hardware/Software/Model/Package` 单独运行一个阶段。硬件项目或模型输出已存在时拒绝覆盖；重做干净验证请从源码包解压到另一个新目录。

`hardware/build.tcl` 从零创建项目并运行综合、实现和write_bitstream；setup或hold不通过会终止。`scripts/package_boot.py` 检查应用内存不越入0x01000000模型区域，并逐段核对BOOT里的新FSBL、PL及PS载荷。

## 模块仿真

```powershell
powershell -NoProfile -File scripts/test_decode.ps1 `
  -VivadoRoot 'D:/Xilinx/Vivado/2021.1' -PythonCommand 'python' `
  -Regenerate -SbtCommand 'sbt'
```

该命令从本目录Scala重新生成harness，再执行65536位模式穷举、32000词表扫描和128窗口边界测试。

## SD与冷启动

打包通过后，`assets/sdcard/` 应包含 `BOOT.BIN`、`llm.bin`、`tkz.bin`。核验记录为 `build/package/verification.json`。只能将这三个已核验文件写入对应板卡的FAT32 SD卡，备份原BOOT，写后回读哈希并安全弹出。

冷启动必须关断板卡电源、插入SD，再上电。串口115200/UTF-8，端口号按实际指定。新的构建仍保留Round55程序banner；需要同时记录新BOOT写卡回读哈希和实际冷启动日志来确定镜像身份，单凭banner不足以区分原板测镜像和此次重建镜像。

十题回归的控制、DMA和内容结果应独立记录。中文名称和中文数学原本失败，复现不要求把它们改成通过；若数值、token路径或结果改变，要保留差异并调查。

## 状态与限制

完整状态以本次 `build/` 中实际报告和新的冷启动证据为准。旧 `evidence/round55/` 是2026-11-01参考记录，不作为此次冷启动完成的证明。上游源码许可仍需确认，本地技术复现准备不代表GitHub公开发布已经完成。
