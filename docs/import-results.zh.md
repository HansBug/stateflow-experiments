# Stateflow 导入批次结果

固定的 211 文件原生批次（74 FlowRepair、134 CoCoSim、2 SLNET 样本、1 自建例）在 [Actions 34702030059](https://github.com/HansBug/stateflow-experiments/actions/runs/34702030059) 完成抽取，得到 215 个 Chart。先前 empty-array 抽取错误已经修复，不能把旧脚本的错误算作源模型不支持。

使用当前 MARS AST 转换器复跑上述原生快照：2 个 Chart 通过 pyfcstm AST/model/semantic inspection；213 个明确不支持，没有 source parser 或 target error。通过的外部模型为 CoCoSim `regression_tests/Hierarchy4.mdl`，另一个为自建验证例。数据依次受 junction、event、数据形状、并行等阻碍；统计的是首个阻碍，不是完整特征普查。

加入 MARS 的 460 个模型后的完整批次尚待 Actions 完成，完成后在此更新对应数据。文件、Chart、独立系统并不等价；FlowRepair 和 MARS 都有相近变体或测试案例，不能按文件数声称独立真实工业系统的数量。

成功只表示所声明控制器 profile 下的目标有效性；源采样/宿主、整数位宽、浮点细节和全部逐拍语义等价没有因此得到证明。诊断 warning/info 原样保留。
