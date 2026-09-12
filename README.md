# Stateflow 实验

这是一个公开的 GitHub Actions 实验仓库：使用 MathWorks Stateflow 原生接口作为源模型前端和独立执行参照。本实验没有使用用户个人 MATLAB licence，也没有仓库 licence secret。

[公开模型与文件格式调查](docs/public-models.zh.md) · [单向导入边界](docs/import-architecture.zh.md) · [现成工具比较](docs/reused-frontends.zh.md) · [失败归因复核](docs/frontend-audit.zh.md) · [Stateflow 特性说明](docs/features.zh.md) · [独立的 SysML v2 实验](https://github.com/HansBug/sysmlv2-experiment) · [公开 workflow](https://github.com/HansBug/stateflow-experiments/actions)

本仓库实现受限的 Stateflow→FCSTM 单向导入：MathWorks API 抽取图结构，固定版本 MARS grammar 构建源 AST，pyfcstm 0.6.0 构建目标 AST/model 并执行语义检查。无法支持的特性会明确登记，不宣称覆盖整个 Stateflow 语言。

## 已验证能力

生命周期、层次状态、动作顺序、状态活动记录、转移优先级、覆盖率、测试管理器和 FlowRepair 回放均在公开 MATLAB Actions 中有可复现实验。SLDV 与 Simulink Coder 在当前环境因 licence 不可用而明确记录为 blocked。详细结果见 [`research/stateflow-observed.json`](research/stateflow-observed.json)。

原始 Door 正确/故障模型的回放产生 30,001 个样本，其中 15,995 个不同，首个差异在 14.006 秒。修复探针恢复了参考轨迹；这不是通用自动修复算法。

## 运行与查看

```bash
gh workflow run stateflow.yml --repo HansBug/stateflow-experiments
gh run download RUN_ID --repo HansBug/stateflow-experiments --dir evidence
```

导入 workflow 使用 MATLAB R2025b、Ubuntu 24.04、Python 3.11；会下载固定版本的 FlowRepair、CoCoSim、SLNET sample 和 MARS，抽取源事实并上传映射、拒绝和语义报告。完整批次为 **671 个文件、709 个 Chart、2 个通过（1 个公开、1 个自建）**；其余 707 个明确记录为 unsupported。分母和首个拒绝原因见 [批次结果](docs/import-results.zh.md)。

## 许可证与运行环境

MATLAB Actions 的公开项目许可证路径可以安装 Stateflow、Simulink Test、Coverage、Design Verifier 和 Coder，但本地 R2022b 实测只有仿真、覆盖率和 Test Manager 可用；SLDV 与 Coder 分别缺少对应许可证。Docker 可以固定环境，不能提供 MATLAB 许可证；当前采用文件交换的 MATLAB 批处理路径，不依赖 MATLAB Engine for Python。

## 导入范围与数据集边界

目标是确定、离散、固定周期、单活动路径的控制层次状态机。并行区域、异步事件/消息、连续内部动态、任意函数、history/junction、时间语义和位精确数值在没有专门规则前必须拒绝。原生模型能加载或运行，不等于已经适合 FCSTM 导入。

当前只做 Stateflow→FCSTM，保留源文件哈希、Chart 路径、SSID、目标元素和假设，暂不反向转换或自动修复。第三方模型和工具保留各自 licence，本仓库只提交清单、散列、统计和自写探针。

## 来源

- [MATLAB Actions licence](https://github.com/matlab-actions/setup-matlab#licensing)
- [Stateflow API](https://www.mathworks.com/help/stateflow/api/overview-of-the-stateflow-api.html)
- [FlowRepair](https://github.com/aitorarrietamarcos/StateflowRepairTool)
- [CoCoSim regression-test](https://github.com/coco-team/regression-test)
- [MARS](https://github.com/bzhan/mars)
- [SLNET](https://zenodo.org/records/4898432)

原始实验脚本采用 MIT；第三方材料按其各自条款使用。
