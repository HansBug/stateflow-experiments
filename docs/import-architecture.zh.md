# Stateflow 与 SysML v2：导入技术方案和研究边界

建议让 Stateflow 承担原生执行对照和真实故障实验入口，让 SysML v2 承担标准建模语言入口。两者共用已有 FCSTM 后端，但各自保留源语言前端、语义限制和回写机制。不要为导入目标重写完整 SysML 编译器，也不要先承诺完整 Stateflow 兼容。

本文区分三件事：已有工具提供的能力、本仓库实测通过的能力、下一步导入器需要实现的能力。最新 Stateflow 执行结果见仓库 README、`research/stateflow-observed.json` 和对应 Actions artifacts。[实际通过的 Actions 运行](https://github.com/HansBug/stateflow-experiments/actions/runs/34692475531)覆盖原生创建/提取/仿真/修改/保存重载、动作顺序、优先级、覆盖率、harness、Test Manager 和公开模型回放；SLDV/Coder 明确记录为授权受阻。

## 1. 仓库与进程边界

| 位置 | 应负责 | 不应负责 |
|---|---|---|
| 本实验仓库 | 原生 API、授权、仿真、分析、数据集复现的可重复实验 | 对外宣称完整导入或行为等价 |
| 后续 Stateflow 适配仓库 | MATLAB 源事实导出、适用性检查、受限转换、源模型补丁、原生回放 | 实现 MATLAB 或整个 Simulink 运行时 |
| 后续 SysML v2 适配仓库 | 官方 workspace 的加载/校验/语义提取，周期控制 profile 的检查和转换 | 重写 KerML/SysML 名称解析、类型系统和标准库 |
| pyfcstm | 已有模型、仿真、代码生成、BMC、诊断和证据接口 | 安装时强制依赖 MATLAB、Java 或 Node |

现在只需要这个公开实验仓库。正式导入器的仓库在接受子集与输入输出契约确定后再创建；两个适配器可以各自发布和升级。先用 CLI + JSON/文件交换。Docker 可以固定 Java、标准库和工具版本，但不是必要的通信架构，也不解决 MATLAB 授权。没有明确并发或部署需求时，不先写 HTTP 服务、任务队列和远程模型平台。

## 2. Stateflow：MATLAB 原生前端优先

**主路线：`.slx/.mdl` → MATLAB/Stateflow API → 源事实 → 子集检查/转换 → FCSTM。**

MATLAB 负责加载模型、解析其配置、解析 Stateflow 对象、保存源补丁以及原生仿真；Python 负责调用批处理、读取结构化产物、转换和分析。当前公共 Actions 授权不支持 MATLAB Engine API for Python，所以先采用 batch + 文件交换。实际 R2022b 实验中，Stateflow、Coverage、Test Manager 能运行；SLDV 在转换模型时无法签出 Design Verifier licence，Simulink Coder 也无法签出 Real-Time_Workshop licence。安装成功不等于授权可用；当前不能把 SLDV 测试生成/证明或 Coder 当作无需额外授权的必备步骤。

应提取的信息包括：

- 原始文件散列、MATLAB release、模型/Chart 路径、Chart 的激活方式和采样配置。
- 状态父子关系、分解方式、初始与普通转移、实际端点、优先级、guard、condition action、transition action、entry/during/exit action。
- 输入、输出、局部变量的类型、大小、初值、枚举定义和数值转换设置。
- 事件、消息、函数、junction、history、并行区域等待支持或拒绝的源特性。
- 回写定位：源文件散列 + Chart 身份 + 元素 SSIdNumber。`Id` 是会话内标识，不能作为长期定位；SSIdNumber 也不是跨所有模型的全局 ID。

本仓库的 `snapshot_chart` 只是源事实探针，目前没有覆盖上述全部字段，也不是完整导入格式。

MATLAB API 也没有替我们完成动作语言前端：许多 guard/action 属性仍以字符串返回。正式适配器仍需解析明确允许的表达式和赋值子集，绑定到已提取的数据符号，并检查副作用与类型。不要把任意 MATLAB/C 代码交给 Python `eval`，也不要用字符串替换宣称语义转换完成。可调查复用 CoCoSim 的相关解析/转换经验，但当前没有验证可直接移植的模块；实现整个 MATLAB/C 编译器不属于这里的任务边界。

**为什么不先纯 Python 读 SLX？** 标准库足以做 ZIP/XML 盘点，适合语料筛查，本仓库已有这样的脚本。但“发现一个 XML 状态节点”不等于掌握版本差异、继承采样、库引用、类型、编译配置和执行语义。[SLX2MDL](https://github.com/mdstepha/SLX2MDL) 可复用其格式转换经验，却不能因此省掉原生行为对照。应等 MATLAB 授权或部署成为真实瓶颈后，再增加离线解析前端，并用同一语义合同测试约束它。

[CoCoSim](https://github.com/NASA-SW-VnV/CoCoSim) 已经研究 Stateflow/Simulink 子集到形式化表示的转换、验证和追踪。因此“Stateflow 转换到一个中间表示”本身不足以形成清楚的新颖性。它更适合作为相关工作和后续可比较的基线；它的语义范围和部署依赖仍需与本研究范围逐项对照。

## 3. SysML v2：复用官方链接语义，不再重写编译器

**主路线：SysML workspace + 匹配标准库 → 官方 Pilot/Xtext/EMF → 选定 state usage 的已解析语义 → 周期控制 profile → FCSTM。**

已有 [sysml-v2-pilot-gt](https://github.com/HansBug/sysml-v2-pilot-gt) 的 JAR 包含足够的官方运行时。`research/sysml/LinkedStateProbe.java` 实测完成了：

1. 加载 2026-07 官方标准库；校验两个独立输入资源，二者均无诊断。
2. 跨资源解析 `exhibit state controller : Controller`。
3. 读取 transition 的 source、target 和 Boolean guard。
4. 读取继承自 state definition 的用户状态和转移，以及源文本范围。
5. 对不存在的类型产生语义错误。

这说明不需要为了导入自己重写语法、跨文件引用和基础类型解析。它不证明所有 redefinition、specialization、multiplicity、嵌套状态和执行语义已经处理完毕。

前端应直接读取官方 typed API 的相关元素，如 `StateUsage`、`StateDefinition`、`TransitionUsage`。不要把整个 EMF 对象图序列化后交给 Python 重新推理，也不要把继承标准库产生的所有成员当作用户控制状态。对一个具有上下文的 usage 建立有效成员集合，显式处理或拒绝 redefinition、多个实例和未解析代理。源代码范围和被引用定义范围都需要保留。

现有工具的定位：

| 工具 | 适合复用的能力 | 当前限制 |
|---|---|---|
| sysml-v2-pilot-gt | 官方 parser、模型类、可复用的官方 workspace API | 当前 CLI 的 parse/semantic-json 不是完整链接契约；同一状态定义的 generic JSON 探针在本环境出现 ConcurrentModificationException，而直接官方 workspace 探针成功 |
| sysmlv2-ls-service | 已有 Node 部署和诊断接口 | 当前 API 仅做 validate；固定的旧 sysml-2ls 已停止维护，面向 2024-12 草案，不能默认充当当前标准的主前端 |
| pysysmlv2 | Python 侧语法树和状态切片 | 完整 linking/类型语义仍需投入；为这次导入重建编译器不经济 |
| Syside Automator | Python API、现成的 SysML 语义工具 | 商业授权路径；Python 接口不等于免费或纯 Python 实现 |

官方 Pilot 与匹配标准库应一起固定版本。优先在独立适配仓库使用 Java 21 CLI，Python 调用该工具；用户不必在 pyfcstm 的 Python 包依赖中承担 JVM。

## 4. 接受边界必须先于转换

目标范围仍是确定、离散、周期采样的控制 HSM，一次只有一条活动状态路径。原生模型合法、能画图、能通过语法校验，均不足以说明属于这个范围。

- 初始支持单一固定采样任务、明确初值、排他层次、可解析的 guard/赋值，以及明确的转移选择规则。
- 并行区域、异步事件/消息、任意 host code、Simulink-based state、连续内部动态，不应静默近似。
- 对 history、junction 链、condition action、外部函数等特性逐项确定受限语义；未实现的特性应给出源位置和拒绝原因。Stateflow 在候选路径搜索中执行的 condition action，与 FCSTM 在验证失败时回滚候选变量的机制尤其需要比较，不能一律当作选中转移后的 effect。
- SysML `do action`、Stateflow `during`、FCSTM `during` 不能按名称直接相互替换。尤其 FCSTM 复合状态普通 `during before/after` 与每轮 aspect 的职责不同。
- SysML 模型需要明确周期激活、输入采样、转移冲突处理、一次控制步边界。不能擅自给一般 SysML 行为加上“每周期执行一次”的解释，也不能随便用文本顺序确定标准未给出的优先级。
- Stateflow `after(T,sec)` 转成周期计数，需要建立并验证采样周期、进入时刻、计数复位、阈值取整和首次执行的对应关系。仅发现 `T/Ts` 是整数还不构成等价证据。
- 必须说明数值语义。Stateflow 的有限位宽、饱和/溢出和 IEEE 浮点不能无条件当作数学整数/实数。当前 FCSTM BMC 的 Int/Real 配置不自动提供 Stateflow 位精确证明；优先使用可约束且能验证不溢出的整数控制子集。

不支持的输入应得到“未支持/需要额外假设”的明确结果，而不是“导入成功但行为近似”。源事实提取器与适用性检查分开，才能既保留失败案例，又不把它们算成成功转换。

## 5. 行为、回写与论文证据

最低完整闭环是：源模型 → 导入 → 同输入执行对照 → 定位到源元素 → 应用一个有前置条件的源补丁 → 原生重新加载与回放 → 独立验证。

行为比较至少包括初始化和每个观测边界的活动叶状态、输入输出、相关变量、动作顺序以及终止/错误状态；明确比较初始化帧还是首个周期之后，不能为了对齐输出随意移动一拍。内部辅助变量或伪状态需要说明观测投影，不能让它们改变原生可观测行为。

源补丁应检查模型散列、元素身份和旧值，并另存为候选文件。MATLAB API 负责 Stateflow 补丁；SysML 文本补丁使用源范围并重新交给官方前端解析和校验。不以整个文件重写作为默认修复方式。

原生回放对具体反例提供重要的独立执行证据，但回放成功不是完整语义等价证明。SLDV 的分析结束状态也不等于证明成功，必须查看 objective 的实际结果。本次公共授权下 SLDV 受阻，其生成测试/证明/反例回放分支尚未跑通；这不阻止以原生仿真作为具体行为对照，并继续使用已有 FCSTM BMC。对修复应使用未参与构造候选的测试或性质，报告超时、未决、失败与接受率。

研究贡献应围绕外部 issue/症状复现、环境假设、根因定位到源元素、受约束的源级修复以及独立验证组织。Stateflow 能提供外部真实故障与原生执行环境；SysML v2 能检验方法是否可跨建模语言复用。两个前端可以支撑同一方法研究，但不能用更多格式替代对方法有效性的实验。

## 6. 数据集的实际边界

对固定 FlowRepair 提交 `6c5ba07962d972d3eade2448e7212faf74e11a50` 的离线 XML 盘点见 `research/flowrepair-inventory.json`：74 个 SLX 文件，72 个含 `sec)` 标签片段，5 个含 Integrator block。这是筛查提示，不是完整语义分类。目录和文件包含正确版、故障版、其他变体；不能当作 74 个独立系统或 74 个独立故障。

这次原生提取的 7 个 Chart 都报告 `INHERITED` 激活与 `-1` 采样值，这进一步说明不能仅凭 Chart 配置就认定有效采样周期。Door 的原始模型含连续 plant 与 `after(10,sec)`。可以先完整原生复现故障，再判断是否能在不消除故障机制的前提下抽出控制器。抽取后需要明确环境假设，并重新证明原故障可复现；否则该模型只适合作为范围外对照。本次完整原生回放在 30,001 个点中复现了 15,995 个输出差异，首次差异为 14.006 秒；按正确版的已知差异修改转移 SSID 16 的源状态和优先级后，保存的候选恢复了该输入下全部参考输出。这验证源级回写操作，没有实现自动修复搜索，也没有验证其他测试或证明一般正确性。修复一个人造 guard 同样只能证明工具链可用，不能替代真实故障上的有效性实验。

## 7. 下一步最小交付

Stateflow：先固定一个很窄、可执行对照的 chart 子集，完成一个真实故障的源级导入/回写闭环；若该故障需要时间条件，先将时间映射作为明确实验变量。

SysML v2：在已通过的官方 workspace 探针上增加有效状态成员、初始路径、guard/effect、源定位和拒绝报告，选择一个显式遵守周期控制 profile 的模型完成导入。先不追求整个 SysML 行为语言。

共同的验收条件：支持的模型通过原生/独立语义对照，不支持的模型明确拒绝，故障和补丁可追溯到源，环境假设和工具版本可重复。不要以“成功导出 JSON”或“成功生成 FCSTM 文本”作为完成标准。

## 参考

- [MATLAB Actions licensing](https://github.com/matlab-actions/setup-matlab#licensing)
- [Batch token availability](https://www.mathworks.com/support/batch-tokens.html)
- [Stateflow API](https://www.mathworks.com/help/stateflow/api/overview-of-the-stateflow-api.html)
- [Official SysML v2 Pilot](https://github.com/Systems-Modeling/SysML-v2-Pilot-Implementation)
- [Legacy sysml-2ls status](https://github.com/sensmetry/sysml-2ls)
- [Syside Automator](https://docs.sensmetry.com/latest/automator/index.html)
- [FlowRepair dataset](https://github.com/aitorarrietamarcos/StateflowRepairTool)
