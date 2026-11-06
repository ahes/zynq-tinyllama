# GitHub分享准备

工程定位为基于llama-fpga的TinyLlama Zynq-7035移植与验证。IP配置、PS预设、新XSA到BSP/FSBL构建和精确模型转换入口已经补齐，实际独立构建结果见根目录REPRODUCTION_STATUS.json。

新镜像冷启动回归待实物插卡/断电上电配合，尚未完成；旧板测记录单独保留。

公开前仍需核实上游代码和混入tokenizer代码的授权，保留相应版权和许可文本，详见THIRD_PARTY.md。没有擅自给混合源码添加统一MIT/Apache许可。

源码包排除assets中的权重、词表和启动二进制，以及build中的工具输出。BOOT/BIT等可以在对应授权和验证明确后单独作为Release资产，附上SHA256和冷启动证据；937MB模型不放普通Git。

原始中文失败和数值边界保留。没有统一tokens/s或功耗测量，不将上游其他平台的速度作为本板性能。板卡照片和演示视频可后续补充。

本次仅在本地构建和整理，尚未创建GitHub远端仓库或上传。
