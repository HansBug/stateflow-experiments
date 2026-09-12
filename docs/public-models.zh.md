# Stateflow 公开模型：来源、格式与导入价值

截至 2026-09-12。结论：**先用 FlowRepair 获得故障与原生回放证据，用 CoCoSim/GPCA 补充控制器结构与性质，用 SLNET 扩大来源；MathWorks 工程参考模型用于检验工程依赖和适用边界。** 这些来源均能取得文件；已完成的原生批次覆盖 74 个 FlowRepair 文件、134 个 CoCoSim 文件、2 个 SLNET 样本和 460 个 MARS 文件，详见 [转换批次结果](import-results.zh.md)。可下载、含有 Chart、能原生执行、可转换，是四个独立条件。

## 已确认的来源

| 来源 | 性质与用途 | 实际取得的格式/内容 | 当前证据与障碍 |
|---|---|---|---|
| [FlowRepair](https://github.com/aitorarrietamarcos/StateflowRepairTool/tree/6c5ba07962d972d3eade2448e7212faf74e11a50) | 论文公开的控制器真实故障基准；首选诊断/复现实验入口 | `ModelsWithRealFaults` 下 74 个 `.slx`；配套 `.m`、`.mat` 和正确/故障/变体模型 | 74 个文件已原生提取；其中 7 个还有详细 native API 探针，Door 原始正确/故障对已仿真。74 是文件数，不能写成 74 个真实故障或独立系统。论文报告的故障单位要另按论文清单对应 |
| [CoCoSim regression-test](https://github.com/coco-team/regression-test/tree/70369bce666880805dcfdc325139ecdc8938a42d/stateflow) | 学术工具回归语料，含 GPCA 输液泵控制案例，也含人工语义用例和未支持特性 | `stateflow/` 直接检出的 130 个 `.mdl`、4 个 `.slx`；另有 `.mdl.autosave`、ZIP、Lustre `.lus`、SMT `.smt2`、trace XML | 其中 14 个 `.mdl` 文件名含 GPCA；不是 14 个独立输液泵。抽看 Alarm、Top Level Mode 的原始 MDL。适合层次、动作、性质与追踪；134 个文件已完成原生抽取，138 个 Chart 的转换状态另见批次报告 |
| [MARS](https://github.com/bzhan/mars/tree/5659710bc0fae06d05518bd7d80f11a3138cf679) | Stateflow→HCSP/Isabelle 学术工具的行为语义案例 | `Examples/Stateflow` 下 456 个 `.slx`、4 个 `.mdl`，另有 XML/theory/文本导出物 | 460 个原生源文件完成抽取，得到 494 个 Chart，当前均明确不支持转换；也是本导入器所复用 grammar/AST 的来源。不能把测试变体当作 460 个独立工程 |
| [SLNET / Zenodo 4898432](https://zenodo.org/records/4898432) | 来自 GitHub/MATLAB Central 的第三方 Simulink 语料，混合实际项目、教学与工具测试 | 外层 `SLNET.zip` 3,890,228,029 字节；内层项目 ID ZIP；`slnet_v1.sqlite` 与 README | 数据库有 225 个 GitHub 项目、2,612 个 MATLAB Central 项目，登记 9,117 个模型文件。**这不是 Stateflow 数量。** 已按 HTTP Range 抽取数据库与一个项目并检查内部 SLX，未扫描全部语料 |
| [MathWorks DC-DC converter](https://github.com/mathworks/model-based-design-dc-dc-converter/tree/d7b9daded06c55d51526bd63acea4e4dedcb4a46) | 工程参考应用，非已证明的工业故障数据集 | 控制器 `.slx`，外部 `.sldd` 字典、`.mat` 场景/基线、`.mldatx` 测试文件 | `OperatingModeAndErrorLogic.slx` 含 1 Chart、15 state、26 transition、5 junction，存在 AND state 和时间标签；不能直接纳入单活动路径子集 |
| [MathWorks HEV](https://github.com/mathworks/Simscape-Hybrid-Electric-Vehicle-Model/tree/2f90b4857b577657d5159ec969c4e2e784c65f4f) | 混合动力汽车参考应用，适合从连续 plant 中选取监督控制器 | `HEVPowerSplitControl_refsub.mdl` 是 **OPC 文本 XML 包**，含 3 个 Chart；项目还依赖引用子系统和 Simscape plant | 3 个 Chart 的 state/transition/junction 分别为 5/26/11、3/7/2、5/14/3。未发现 AND state 或时间函数标签只是筛查结果；junction、浮点阈值、输入与采样仍需处理 |

FlowRepair 论文：[FlowRepair, IST 192:108010](https://doi.org/10.1016/j.infsof.2025.108010)。
SLNET 论文：[MSR 2022](https://doi.org/10.1145/3524842.3528001)。
CoCoSim 仓库 README 明确同时包含尚未支持的 Stateflow constructs，不能把全部回归文件当作已验证可转换集合。

[2018 curated corpus 的 GitHub 入口](https://github.com/corpussimulink/corpus)本次查询为空仓库，不能列为当前已取得的数据。没有为此把无关的同名 SLNet 神经网络仓库算进来。

## 文件格式不能只看扩展名

本轮实际检查了以下布局，结果和文件 SHA-256 保存在 [model-formats-observed.json](../research/model-formats-observed.json)。

| 容器 | 实际例子 | 图数据位置 | 对导入的意义 |
|---|---|---|---|
| 新一些的 SLX / ZIP + XML | FlowRepair、DC-DC | `simulink/stateflow/machine.xml`、`chart_<id>.xml` 及 relationships | Chart 可能分片；不能只读 blockdiagram.xml |
| 旧 SLX / ZIP + XML | SLNET 中 2014 年 Mealy/Moore 示例 | `simulink/blockdiagram.xml` 内嵌 `<Stateflow>` | 不存在独立 stateflow 目录仍可以有真实 Chart |
| 传统 MDL 文本 | GPCA Alarm、Top Level Mode | `Model { ... }` 后的 `Stateflow { machine { ... } chart { ... } state { ... } ... }` | 用 ID、chart、treeNode 等字段关联对象；需要 MDL 前端或原生 API，不能当 XML 读 |
| 新 MDL / OPC text | HEV 控制器 | `# MathWorks OPC Text Package`，`__MWOPC_PART_BEGIN__` 分隔 XML 部件，末尾有 package end marker | `.mdl` 也可能保存类似 SLX 的分片 XML 内容 |

旧 SLX 抽样来自 `SLNET_v1/SLNET_GitHub/21655911.zip`，对应 `morganp/Stateflow_examples`；两份 Chart 都有 5 个 state、6 个 transition。它们是教学示例，只用于确认容器兼容性。该项目还带 Verilog 导出物，导出物不能重复计为源模型。抽样路径、文件散列、数据库计数见 [slnet-observed.json](../research/slnet-observed.json)。SQLite 中 `GitHub_Projects.id` / `MATC_Projects.id` 关联各表的 `File_ID`；保留项目 URL、`version_sha`、`file_path` 和 licence，避免丢失来源。

数据库的 block type 不能直接给出 Stateflow 覆盖率。仅查 `StateSpace`、`Subsystem` 或文件名都不足以识别可用的控制 Chart；后续应解包源模型、辨别普通 Chart、MATLAB Function、truth table 等对象，再作原生复核。

配套文件也有语义影响：

- `.sldd` 保存参数、类型、枚举和字典引用；抽取的 DC-DC 字典本身也是 ZIP/XML，但不能把其中 XML 当成完整已求值符号表。
- `.m` 是初始化/测试/运行脚本；`.mat` 可能是激励、参数、基线或故障定位结果，必须按所在项目解释。
- `.mldatx` 是测试/记录等应用数据的容器，具体含义取决于产生它的工具，不能一律当状态机。
- `.slxp` 等受保护模型与 S-function 二进制不提供等同于源 Chart 的可转换信息；依赖这些内容的输入需要另报缺失依赖。

## 最小技术路线

`项目与依赖 → MATLAB batch 加载 → Stateflow API 源事实 → 接受子集检查 → FCSTM + 映射 + 假设/拒绝报告`。

无需全 Python。MATLAB 负责原始模型与类型/采样上下文；后续可用 Python 或其他语言做有限的表达式转换和 FCSTM 输出。公开 Actions 的原生能力和 licence 实测见 [README](../README.md)。Docker 可以固定运行环境，不能提供 MATLAB licence。ZIP/XML/MDL 离线盘点先服务于筛选；[model_formats.py](../research/model_formats.py) 只盘点容器，传统 MDL 的数量是声明行计数，不是完整对象解析。

```bash
python research/model_formats.py --check
python research/model_formats.py path/to/model.slx path/to/model.mdl --output inventory.json
```

不要先写完整 Simulink 求解器、通用 MATLAB/C 编译器、HTTP 服务或反向转换器。原生 API 返回的 guard/action 字符串现已接入 MARS grammar/AST；它没有自动完成从 MATLAB/C 到 FCSTM 的语义转换。

## 为后续学术实验保留什么

初始选择应同时满足：控制器边界明确、周期明确、单活动层次路径、有限可解释的 guard/赋值、可独立回放。先筛选 FlowRepair；时间或 plant 是故障机制的一部分时，应保留并验证环境假设，不能删除它们之后继续声称复现原故障。HEV 的三个 Chart 可作为后续 junction 与工程输入的候选；DC-DC 的 AND 结构可作为范围外拒绝实例；GPCA 可补充结构和性质覆盖。本次逐项转换的接受/拒绝记录见 [批次结果](import-results.zh.md)。

每次导入保存：源项目 revision、文件散列、依赖清单、MATLAB release、Chart 路径、chart-local SSID、目标 state/transition/variable 标识、映射类型与语义假设。使用列表表示一对多/多对一降解映射。`Stateflow.Id` 是会话 ID；SSID 也必须与源文件及 Chart 身份组合使用。保留这些信息可把 FCSTM 反例、复现输入和根因投影回源元素；**本阶段不实现源补丁或反向转换。**

评价按项目/概念系统切分，再在系统内部区分正确版、真实故障版与派生变体；不能把近重复模型分到训练和测试两边。分别统计获取、加载、语义适用、转换、行为对照五个阶段的分母，保留拒绝理由。引用 SLNET 元数据的 CC-BY-4.0 时也应保留项目原 licence；本仓库只提交清单、散列、统计与自写探针，没有重分发第三方源模型。
