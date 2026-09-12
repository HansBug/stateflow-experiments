# Stateflow 特性说明：为什么当前导入会拒绝

下面的例子使用 Stateflow 常见写法。它们先解释图的含义，再说明当前 FCSTM 导入边界。**拒绝一个特性表示尚未定义等价映射，不表示 Stateflow 或模型本身错误。**

## 普通状态与层次状态

```text
[*] -> Locked
Locked -> Open : [key == 1]
Open -> Locked : [close == 1]
```

`Locked`、`Open` 是状态；箭头是转移；方括号是 guard。若一个状态内部还包含子状态，例如 `Door` 里面有 `Closed`、`Opening`、`Opened`，就是层次状态。当前导入器可以处理单活动路径的层次结构，并把它们映射为 FCSTM 的嵌套 state。

## entry、during、exit 动作

```text
Idle
entry: y = 0;
during: y = y + 1;
exit: y = 0;
```

进入、保持活动、离开状态时分别执行 entry、during、exit。`during` 受 Stateflow 调度和采样时间控制。当前 FCSTM 映射只接受可明确定位的 entry/exit 赋值；复合状态的 during 需要先规定每拍执行顺序，因此明确拒绝。

## 事件与时间触发

```text
Closed -> Open : button_press
Open -> Alarm : after(10,sec)
```

事件触发要求宿主在某个时刻投递 `button_press`；`after(10,sec)` 依赖进入状态的时钟、采样周期和首拍取整。FCSTM 的周期转移没有同一套事件队列和时钟语义，所以当前将 event、message、时间条件记为 unsupported，而不是把它们当普通 guard。

## junction 与 history

```text
[*] -> J
J -> A : [x > 0]
J -> B : [x <= 0]
```

junction 是转移路径中的决策节点，一个入口可以经过多个条件分支；history 还会记住上一次离开复合状态时的子状态。要正确导入，必须实现路径搜索、优先级、短路和动作副作用。当前转换器只接受状态到状态的直接边，因此把 junction/history 作为明确缺口。

## condition action 与 transition action

```text
A -> B : condition(x > 0) { x = x - 1; }
```

condition action 在判断路径时执行，失败后是否回滚、多个候选路径如何排序都会影响结果；transition effect 则是在选中边之后执行。两者不能简单合并成一段 effect。当前只映射已选转移后的简单赋值 effect，condition action 暂时拒绝。

## 并行（AND）状态

```text
Controller
  ├─ Power: On / Off
  └─ Network: Up / Down
```

进入 `Controller` 时，`Power` 和 `Network` 两个区域同时活动；一次事件可能同时触发两条路径。FCSTM 当前模型假设只有一条活动路径，因此并行状态拒绝。删除一个区域会改变行为，不能作为“兼容转换”。

## graphical function、MATLAB Function 与宿主代码

```text
function resetCounter()
  counter = 0;
end
```

函数可能读写数据、调用外部函数或依赖 MATLAB/C 类型规则。仅把函数名变成 FCSTM action 会丢失副作用和错误处理。当前保留源元素并报告 function 缺口，后续需要基于动作 AST、符号表和调用关系定义安全子集。

## 数据尺寸 `-1` 与编译上下文

Stateflow API 的 `Props.Array.Size = -1` 表示尺寸继承自端口、信号或模型配置，并不等于数组。FlowRepair Door 的 7 个端口就是例子：声明值全是 `-1`，MATLAB R2025b 编译后宽度却全部为 1、维度为 `[1,1]`。因此导入前应保存编译后的 width、dimension、datatype；只看声明字段会产生假阳性的 `data_shape` 拒绝。

## 这些拒绝怎样进入论文实验

每个拒绝都应记录：源文件和 Chart 哈希、SSID、特性名称、最小示例、是否由官方编译接受、转换器拒绝位置。当前批次的首个拒绝是统计快捷方式，不代表模型只含这一种特性；标签解析审计和原生编译对照见 [失败归因复核](frontend-audit.zh.md)。
