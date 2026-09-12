# Stateflow → FCSTM：当前边界

本阶段仅做 **Stateflow → FCSTM 单向导入**，输出模型、源映射、假设和拒绝报告。完整的数据与格式调研见 [公开模型调查](public-models.zh.md)。SysML v2 的解析器比较与实验已独立迁到 [HansBug/sysmlv2-experiment](https://github.com/HansBug/sysmlv2-experiment)。

入口采用 `项目文件与依赖 → MATLAB batch / Stateflow API → 源事实 → 子集检查 → FCSTM`。MATLAB、Java、Node 均无需成为 pyfcstm 的安装依赖。用 CLI 和文件交换即可，当前不需要服务平台。已有 ZIP/XML 盘点只负责筛选；原生 API 的 label 字符串仍需要有限的动作/表达式解析。

接受目标是确定、离散、固定周期、一次只有一条活动状态路径的控制 HSM。检查有效采样、初值、层次、默认转移、冲突优先级、变量类型与动作顺序。未知采样不能用 Chart 的 `-1` 自动补齐；并行区域、消息/异步触发、连续内部动态、任意函数与未处理的 history/junction 必须明确拒绝或先实现专门的降解规则。

Stateflow `during` 不能直接按名称转换成 FCSTM 的普通 composite `during before/after`。Condition action 的候选路径搜索副作用也不能一律视为选中转移之后的 effect。时间条件转换需要明确采样相位、进入/复位时刻、阈值取整与首拍；数值转换需要明确整数范围、溢出/饱和、浮点误差。FCSTM BMC 的数学 Int/Real 不自动提供 Stateflow 的位精确等价保证。

最低导入验收是：原生事实有来源，接受/拒绝有理由，FCSTM 可解析执行，初始化及每个选定观测边界的状态、变量和输出可对照，反例与根因可定位到源元素。一次具体轨迹一致不等于完整语义等价证明。

源映射保留文件散列、Chart 路径、SSID、FCSTM 元素标识与映射规则；允许一对多和多对一。它服务于诊断、复现和根因证据，不要求反向转换。历史实验中的人工修改/保存探针继续保留，作为此前已验证的 API 能力；它们不是本阶段实现导入器的前置要求。
