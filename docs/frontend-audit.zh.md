# Stateflow 失败归因复核

**本轮没有确认 MathWorks 官方前端缺陷。已确认的障碍分别在我们读取的上下文、复用的 MARS 标签语法、以及尚未实现的转换规则。** 本报告不提高历史转换成功数，也不把原生加载成功当作整个模型已经可执行或可转换。

## 归因判定顺序

Stateflow 失败先按“官方读取/编译 → 第三方标签前端 → 我们的目标映射”分层：

1. MATLAB/Stateflow 官方 API 能打开并抽取 Chart，且 R2025b 编译通过，说明容器和官方读取入口可用；声明尺寸为 `-1` 这类信息仍要用 compiled context 补全，不能直接当作官方错误。
2. MARS、CoCoSim 等第三方 parser 的拒绝或部分 AST 只说明该工具的 grammar/错误处理能力。MATLAB 原生编译接受、MARS 拒绝注释标签的最小对照已经复现，因此应登记为第三方前端覆盖缺口。
3. 官方对象已读出而我们因 junction、event、function、并行、调度或动作时机拒绝时，这是转换 profile 边界。任何 source-parser error 必须保留原标签、Chart/文件哈希和 parser 诊断；退出码为 0 的部分 AST 也不能当作成功解析。

当前没有“官方 API/编译拒绝而独立成熟前端确认接受”的最小反例，所以没有把 MathWorks 前端列为已确认 bug。要升级为官方 candidate，必须固定 MATLAB release、模型哈希、最小 `.slx/.mdl`、官方诊断和独立对照结果。

[机器可读证据](../research/frontend-observed.json) 包含语料快照 SHA256、上游版本、逐条拒绝标签的定位与哈希、解析结果统计、原生编译事实。完整标签诊断可从固定语料快照重跑。原生编译来自 [Actions 34705633100](https://github.com/HansBug/stateflow-experiments/actions/runs/34705633100)，MATLAB R2025b、Ubuntu 24.04，实验脚本提交 `1306829`；标签审计在 Python 3.10、Lark 1.2.2、固定 MARS commit 上执行。

## 官方读取与我们的元数据缺口

原批次的 671 个文件、709 个 Chart 均完成官方 API 抽取。这证明所选 SLX/MDL 容器可以由官方入口读取；没有逐个编译所有外部模型。

复核原生编译了三个模型：含 MATLAB `%` 注释的自建控制器、含 C `//` 注释的自建控制器、原始 FlowRepair `door_1/Door_Model_Correct.slx`。三者全部通过。

Door 的 6 个输入和 1 个输出，`Props.Array.Size` 都是 `-1`，但编译后的所有端口宽度均为 1、所有端口维度均为 `[1, 1]`。`-1` 在这里是继承声明，不能当作数组证据。我们的转换器只看声明尺寸，缺少编译后的上下文，因此报 `data_shape`。

这是一个已确认的接入缺口，不是官方取不到尺寸。其他 37 个以 `data_shape` 首先拒绝的 Chart 尚未逐个作同样的编译核实；也不能声称补上尺寸就能转完 Door，它还有时间行为、宿主调度和其他动作需要处理。

## MARS 标签解析覆盖被前置拒绝遮住了

原转换器在解析标签前会先拒绝 junction、event、function 等。因此原批次中 `source-parser error = 0` 只描述执行到的分支，不能说明全部标签都解析成功。

本次 [audit_labels.py](../research/audit_labels.py) 绕过这些转换门槛，逐条把官方抽取的 9,292 个状态/转移标签交给固定版本的 MARS 原解析器和我们的适配器。同一原生空默认转移 `?` 哨兵对两者采用相同归一化，其他标签原样输入。

| 结果 | 标签数 | 含义 |
|---|---:|---|
| 两者接受 | 7,930 | 仅说明产生源 AST，尚未验证 AST 语义完整性 |
| 仅适配器接受 | 325 | 已有声明式 grammar 扩展覆盖的方言写法 |
| 两者拒绝 | 970 | 当前 MARS grammar/transformer 也不能解析；不能统称原模型非法 |
| 仅适配器拒绝 | 67 | 我们主动拒绝无显式 entry/during/exit 角色的状态动作 |

适配器总拒绝数为 **1,037**，其中 C 标签 930，MATLAB 标签 107。970 个共同拒绝中，CoCoSim 930、FlowRepair 34、MARS 6；67 个主动拒绝中，FlowRepair 64、SLNET sample 3。统计包含原批次的 7 条 synthetic canary 标签；两个新增注释探针单独记录，不混入语料统计。

最直接的对照是：MATLAB 原生编译接受的两条含注释标签，MARS 原解析器和我们的适配器都拒绝。语料中还出现 C 运算写法、续行、其他控制语法等拒绝。因此 **MARS 是有限的学术前端，不能当完整 MATLAB/C Stateflow 标签解析器使用**。这些类别尚未逐条经过官方编译；已证明的是至少存在合法输入被当前语法拒绝。

也检查了 MARS 自己的 `SL_Diagram.parse_stateflow_xml()`：它把 label 直接传给同样的 `state_op_parser` / `transition_parser`，没有一个被我们漏调的统一注释预处理步骤。它的图读取器针对 XML 导出物，不是通用 SLX/MDL 读取器。

67 条主动拒绝不能算适配器退化：既有探针显示 upstream 会丢弃无角色的单条 Assign，而对 Sequence 又可能解释为 entry。当前适配器宁可明确拒绝，避免静默丢动作；这不意味着 67 条都发生同一种丢失。

## 转换规则仍然是独立障碍

历史的 707 个拒绝 Chart 中，首个原因有 junction/history 298、event 188、function 172、data_shape 38。前三项是我们的规则边界；原生 API 已能发现这些对象，不能归因于文件读取器不认识它们。first-blocker 不是互斥的模型特征普查，也不能与标签数量相加。

后续先补编译后的数据尺寸/类型，再把动作语言分清楚、验证成熟 grammar 的覆盖，随后处理 junction 路径和动作顺序。condition action 的执行时机、事件/函数、时间语义和并行需要各自规则，不能通过删标签或大量正则替换提高成功率。现有官方结构入口可以保留，MARS 的覆盖需要重新限定或由更合适的语言前端补充。

## 复现

从[导入批次](https://github.com/HansBug/stateflow-experiments/actions/runs/34703956252)下载 `corpus-source.json`，安装 requirements 并准备固定 MARS checkout，按 README 的步骤操作。然后：

```bash
gh workflow run audit.yml --repo HansBug/stateflow-experiments
gh run download RUN_ID --repo HansBug/stateflow-experiments --dir artifacts/native-audit
python research/audit_labels.py \
  evidence/stateflow-import-source/corpus-source.json artifacts/label-audit.json \
  --native artifacts/native-audit/stateflow-frontend-audit/frontend-audit.json
python check_import.py evidence/stateflow-import-source/corpus-source.json
```

原生 workflow 要求三个模型全部编译成功；标签脚本要求这两条原生合法注释继续复现当前解析器的拒绝。如果后续修复解析器，要更新对应的缺陷复现断言和报告。历史转换结果仍是 2 个 accepted Chart（1 public + 1 synthetic），不是本次审计后新增了转换能力。
