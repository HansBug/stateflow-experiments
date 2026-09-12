# Stateflow 现成工具：复用决定与实测边界

本实验选择 **MathWorks Stateflow API 读取结构和配置，MARS 的 Lark grammar/AST 解析状态与转移标签，再映射到 pyfcstm**。不自行解析 SLX/MDL，不用正则表达式翻译动作。这个选择只覆盖已声明的控制器子集，不代表 MARS 或本导入器支持全部 Stateflow。

| 工具 | 已核实的可复用产物 | 本次验证层级与决定 |
|---|---|---|
| [MathWorks Stateflow API](https://www.mathworks.com/help/stateflow/api/overview-of-the-stateflow-api.html) | Chart、State、Transition、Data、层次、SSID、优先级及配置；原生加载/模拟 | 已在公开 Actions 实测；作为主结构前端和后续轨迹 oracle。LabelString 仍是文本，API 本身没有提供通用公开动作 AST |
| [MARS](https://github.com/bzhan/mars/tree/5659710bc0fae06d05518bd7d80f11a3138cf679) | `ss2hcsp/matlab/parser.py` 的 Lark grammar/transformer；`function.py` 的表达式、语句、StateOperate、TransitionLabel AST；Stateflow→HCSP/Isabelle 转换和测试 | 已接入并运行；本次只依赖 grammar/AST，不先转 HCSP 再转 FCSTM。460 个示例模型加入原生抽取批次 |
| [NASA CoCoSim](https://github.com/NASA-SW-VnV/CoCoSim/tree/ebb91b7dfbc52bfe5074766281fd3fb8446976c9) | MATLAB ANTLR grammar、`Matlab-Parser.jar`、`EM2JSON`、Stateflow→Lustre 转换 | JAR 已运行五个探针。适合作为扩展 MATLAB 动作语法、研究 junction 路径及动作顺序的参考；不是当前完整标签前端的直接替代 |
| [ConQAT/CQSE Simulink Library for Java 的公开 fork](https://github.com/harmanpa/SimulinkLibraryForJava/tree/7214ec7033c4bf37c68e328f11531cdd9497322d) | `SimulinkModelBuilder`、`StateflowBuilder`、typed chart/state/junction/transition 图 | 已读源代码，未运行兼容性矩阵。`StateflowState.getLabel()` 返回字符串；不是动作 AST。候选无 MATLAB 结构读取器，尚不能声称支持本调查发现的所有新版容器布局 |
| [SLX2MDL](https://github.com/mdstepha/SLX2MDL/tree/e96605ab88c8e17a52b7345d3920437207fdb86a) | SLX→旧 MDL 格式转换，包含 Stateflow 结构处理 | 源码与用途核实；不提供 FCSTM 的执行语义映射。若旧工具只收 MDL，才需要接这一层 |

## 为什么当前没有整体改用 CoCoSim

`EM2JSON.InputStreamToIR` 直接执行 ANTLR lexer/parser、ParseTreeWalker 和 JSONEmitter，没有以 lexer/parser 错误计数阻止部分 AST 输出。[可复现实验](../research/probe_cocosim.py) 与 [原始结果](../research/cocosim-parser-observed.json) 显示：

- `x = 1;`：输出 assignment AST，无错误。
- `y = x ~= 0;`：输出关系运算 AST，无错误。
- `x = ;`：stderr 报语法错误，但输出只含 `x` 的部分 AST，退出码仍为 0。
- 整段状态标签、整段转移标签：作为 MATLAB script 解析会报错，仍有部分 AST。

因此复用它时必须安装拒绝恢复结果的错误监听器，不能只看退出码或 JSON 能否解码。其 Stateflow `TransitionLabelParser.m` 还使用 `regexprep` 和递归文本拆分，输出 event/condition/action 字符串；这不是我们要求的整段标签 typed AST 接口。CoCoSim 的优点在于已经实现复杂 Stateflow→Lustre 路径，可作为后续语义规则的参考，而不是把其所有预处理直接移植进来。

## MARS 也需要边界检查

MARS 仓库公开了 Stateflow→HCSP、Stateflow→Isabelle 和形式操作语义相关实现。这里复用的是这些工作已有的语言解析部分；没有声称继承它们的语义证明。实际接入时发现 upstream transformer 对无 `entry:` 等角色的单条赋值会丢弃，而对 Sequence 又可能当成 entry。我们的包装明确拒绝这种输入，避免静默丢动作。

MARS 的 `SL_Diagram(location)` 图读取入口对文件调用 `minidom.parse`，其转换测试使用导出的 `.xml`。它不能被当作已经验证过的通用 SLX/MDL 容器读取器。该语料还有 238 个 XML、104 个 Isabelle theory 和 129 个文本产物；本次原生批量器只枚举 456 SLX + 4 MDL，避免把导出物重复算成源模型。

仅增加两类声明式 grammar alternatives：`~=`/`<>` 不等式，以及旧标签 `Name/` 后接显式动作角色。表达式与语句映射检查 MARS 的 AST 类，不进行文本替换。原生默认转移的空标签可能返回精确的 `?`，只对此特定原生哨兵值做归一化；其他标签全部交给语法分析器。`check_import.py` 固定这些边界。

当前拒绝 condition action、junction/history、事件、并行状态、任意函数和 composite during。前两项尤其需要源语言的路径搜索与副作用规则；找到现成代码只减少实现成本，不会让这些语义自动等价于 FCSTM effect。

## 工程和研究分工

优先保留这个独立仓库中的 batch/JSON 适配器：官方结构前端 → 学术工具 AST → 限定规则 → FCSTM AST/model → 语义报告。无需把 MATLAB 或整个 MARS 安装进 pyfcstm，也无需新增常驻服务。以后要减少 MATLAB 依赖，应拿 ConQAT/MARS 图读取器与官方 API 在同一固定语料上做结构差分，再决定是否替换。

第三方仓库按 commit checkout，不把其代码重新标成本仓库 MIT：ConQAT 此 fork 有 Apache-2.0 文本；CoCoSim 源文件带 NASA notices；MARS 本次所读根目录未找到明确 LICENSE。公开可访问与可任意再分发是不同事实。原始模型及工具从各自上游取得，研究记录保留来源和固定版本。
