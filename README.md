# TinyLlama on Zynq-7035 — 独立构建工程

基于 [llama-fpga](https://github.com/adamgallas/llama-fpga) 的 XC7Z035 单核 TinyLlama 移植。包含SpinalHDL源码、ROM表、30个IP配置Tcl、完整BD/PS配置、裸机C、独立构建/打包/写卡/回归入口。


## 实际完成的验证

- 本目录重新编译152份Scala和1份Java源码；生成RTL除Git注释外与Round55板测RTL一致。
- 30个独立IP有效参数、878项PS参数一致；36个总IP、器件、top及源码路径检查通过。
- 从零生成IP并完成综合、实现和bitstream；具体资源与时序见本次报告。
- 从新XSA创建standalone BSP，编译应用和新FSBL；应用内存不越入模型区域。
- 固定TinyLlama源revision，从原始权重重做GQA→MHA→FP-minmax导出。
- 从本目录Scala重新生成测试harness，三个XSim回归全部通过。
- BOOT中的新FSBL、PL、PS载荷已逐段核验；软件平台HWH与最终实现XSA一致。

## 使用入口

- [完整独立构建步骤](docs/INDEPENDENT_BUILD.md)：工具版本、参数、从新目录构建、冷启动流程。
- [系统架构](docs/ARCHITECTURE.md)及[原Round55验证边界](docs/VALIDATION.md)。
- [本次复现状态](REPRODUCTION_STATUS.json)和[evidence目录](evidence/reproduction_20261105/)。
- [模型来源与输入哈希](model/SOURCE.json)、[环境依赖](model/requirements.txt)。
- [第三方来源与许可待核实](THIRD_PARTY.md)。

```powershell
powershell -NoProfile -File scripts/build.ps1 -Stage All `
  -VivadoRoot 'D:/Xilinx/Vivado/2021.1' -VitisRoot 'D:/Xilinx/Vitis/2021.1' `
  -SbtCommand 'sbt' -ModelPython 'C:/your-env/python.exe' -PythonCommand 'python' -DownloadModel
```

工具路径按本机安装修改。需要空的build目录；权重、词表、BOOT在assets目录，不纳入源码包。当前本地原始checkpoint由已核验缓存提供，固定revision下载入口保留；本机此次未重新从网络下载2.2GB权重。

已有模型回答质量限制仍存在：原hello?/nice循环在2026-11-01十题回归中未复现，中文名称与中文算术仍失败。不宣称通用聊天可靠，也未测得统一的tokens/s或功耗。

