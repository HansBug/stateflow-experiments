# Stateflow 导入批次结果

**官方抽取已覆盖全部选定文件，当前 FCSTM 转换覆盖仍很窄。** [完整成功 Actions 批次](https://github.com/HansBug/stateflow-experiments/actions/runs/34703956252) 使用 MATLAB R2025b、Ubuntu 24.04.5（image `20260907.300.1`）、Python 3.11、pyfcstm 0.6.0 和 Lark 1.2.2。Workflow 已固定到此次实际使用的 Ubuntu 24.04。

[机器可读逐项状态](../research/import-observed.json) 保留 revision、源文件和 native snapshot SHA256、Chart、结果和首个拒绝原因；Actions artifact 另有完整源事实、目标 FCSTM、映射和语义报告。

| 来源 | 原生源文件 | 成功抽取 Chart | 转换通过 Chart | 明确不支持 Chart |
|---|---:|---:|---:|---:|
| FlowRepair | 74 | 74 | 0 | 74 |
| CoCoSim | 134 | 138 | 1 | 137 |
| SLNET 所选教学项目 | 2 | 2 | 0 | 2 |
| MARS | 460 | 494 | 0 | 494 |
| 自建 canary | 1 | 1 | 1 | 0 |
| 合计 | 671 | 709 | 2 | 707 |

所有选定源文件都完成原生抽取。原转换批次没有 extraction error、no-chart、source-parser error、target error 或 semantic error 记录，但前置拒绝遮住了标签解析失败；[后续独立审计](frontend-audit.zh.md) 对全部 9,292 条标签实测发现适配器拒绝 1,037 条。**去掉自建例，公开数据是 670 个文件、708 个 Chart，仅 1 个 Chart 转换通过。不能声称大部分公开模型可以转换。** 670 个外部源文件只有 594 种 SHA256 内容，且即使内容不同也可能只是近似变体，不能当作等量独立系统。

当前外部 accepted 为 CoCoSim `regression_tests/Hierarchy4.mdl`（SHA256 `b2a183d5d7adf46996f41822e18bc69be24f9d2bf46be3779d45548be69499d0`）。它有两个依据输入条件选择的默认目标，以及各目标的 entry 赋值；不是完整的复杂应用控制器。自建例另覆盖嵌套状态、guard、赋值、entry/exit 和 leaf during，CI 检查的是本次 MATLAB 现场抽取的 canary。

## 首个拒绝原因

| 原因 | Chart 数 |
|---|---:|
| junction/history 结构 | 298 |
| 显式 event 对象 | 188 |
| graphical/MATLAB function | 172 |
| 数据维度不能确定为 scalar | 38 |
| 未知符号 | 3 |
| 转移事件标签 | 3 |
| 并行状态 | 3 |
| condition action | 1 |
| 缺失默认入口 | 1 |

这是 first-blocker 统计，不是完整特征普查。某 Chart 先因 junction 拒绝，其余动作可能尚未解析；没有 parser-error 记录不表示全部 709 个 Chart 的所有标签都通过了语法解析。实现某一项也不代表该行所有模型马上转换成功。

FlowRepair 的首个障碍为 data_shape 30、junction 39、unknown_symbol 3、transition_event 1、condition_action 1。其真实故障模型当前没有 accepted，之前 Door 正确/故障对的原生回放证据不能当作 Door 已导入 FCSTM 的证据。MARS 的首个障碍为 junction 173、event 143、function 172、data_shape 4、transition_event 2；它是语义特征压力测试集合，包含大量超出本控制器子集的行为。

## 能证明什么

成功记录必须构建 `StateMachineDSLProgram` 和 `StateMachine`，并通过 `inspect_model(enable_verify=True)` 的 error 检查；warning/info 原样保留。目标 DSL 由源 AST 元素映射后序列化，源标签没有经过正则替换式翻译。

接受判据是声明的周期控制器抽象下的目标有效性。源宿主调度、`-1` 继承采样、位宽/溢出、浮点细节和完整逐拍等价没有由此得到证明。映射保留配置与假设，支持后续环境建模、源定位和诊断实验，不要求反向转换。

对扩大覆盖最值得先处理的是：用官方编译/项目上下文补齐维度与类型；补足有限的 MARS 标签 grammar；参考 MARS/CoCoSim 已有语义实现处理 junction 路径，严格区分 condition action 与选中路径后的 effect。[原生复核](frontend-audit.zh.md) 已确认 Door 的 7 个 `-1` 尺寸声明在编译后全部是 scalar，当前拒绝来自我们的上下文缺失。事件、函数、并行仍需各自规则，不能为了提高成功率删除它们。公开语料目前主要验证了前端可获取性和拒绝边界，不能代替后续语义对照或诊断算法评价。

## 环境证据

此前 [R2022b + Ubuntu 22.04 批次](https://github.com/HansBug/stateflow-experiments/actions/runs/34702030059) 已抽取 211 文件、215 Chart。旧脚本曾有 empty-array 抽取错误，已修复；这些不属于模型不支持。

R2022b 搬到 Ubuntu 24.04 时，[加载第一个模型即因 libmwdastudio.so 失败](https://github.com/HansBug/stateflow-experiments/actions/runs/34703793887)，不计入语料覆盖统计。当前 R2025b + Ubuntu 24.04 的完整成功批次才是上表依据。它仍使用公开 MATLAB Actions 的官方许可路径，没有提供个人 MATLAB licence 或仓库 licence secret。
