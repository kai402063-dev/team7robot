# 开发中实际遇到的错误

| 现象 | 本次定位出的原因 | 先查什么 / 已采取的修复 | 证据 |
|---|---|---|---|
| matlab -batch 退出 1、没有有效输出 | 沙箱/继承动态库环境下启动失败；清除 ROS 库变量的独立主机进程可运行 | 使用 run_matlab.sh，检查 MATLAB 可执行路径；不要操作已开桌面 | evidence/0 早期尝试与环境回执 |
| JSON 字段名非法 | Real-Time_Workshop 含连字符 | MATLAB 字段名用 makeValidName；原许可名保留用于 license 调用 | evidence/0 失败日志 |
| Git 无作者身份 | 本机未配作者 | 仅本任务命令级 Codex 身份，不改全局配置 | 决策 D007 |
| Unit Delay 无 OutDataTypeStr 参数 | 该块不支持这项参数写法 | 用初始总线值推断类型；别照搬 Constant 的参数 | evidence/2/build-02.log |
| P 同时来自字典与模型工作区 | 数据定义重复 | 字典只存总线，P/初态/回放放模型工作区 | evidence/2/build-03.log |
| requestId read-before-write | 默认转换未初始化输出 | 初始化全部跨拍数据，保留运行诊断 | evidence/2/build-04.log |
| 总线数组 8×1 与 1×8 不一致 | MATLAB Function 推断方向与端口不同 | set_data_size 显式声明，模板统一行数组 | evidence/2 编译日志 |
| Stateflow 父状态反复重入 | 转换曲线中点越出 Active 边界 | 修正中点与父框边界；检查层级警告 | evidence/2 构建迭代日志 |
| To Workspace 记录索引越界 | 矩阵信号保存成 1×width×time | 用 recordRows 规范为 time×width | evidence/2 早期测试日志 |
| screener 通过但模型编译失败 | `for i=supporter` 的变量尺寸循环不支持 | 改为 `for k=1:numel(supporter)`，重跑 1000 组等价 | evidence/3/build-01.log |
| 比赛回执结构体赋值不相容 | 空结构体数组的字段初始化不完整 | 第一条记录直接赋值，其后追加 | evidence/3/validation-01.log |
| 碰撞修复纯 MATLAB 通过、模型编译失败 | 循环可能零次，worst 在部分路径未定义 | 循环前初始化并验证迭代次数正整数 | evidence/3/repairs-build-01.log |
| “未使用参数”审计误报 | 匹配了 XML 属性名，而不是参数表达式 | 仅检查 P 元素文本；保留第一次假阳性 | evidence/3/b-unused-parameters*.json |
| 测试文件解析 Illegal use of end | 局部测试函数模式多写一个 end | 每个 function 各闭合一次；不再给已经结束的顶层函数追加 end | evidence/3、evidence/6 早期日志 |
| 默认噪声长跑末位差异放大 | 编译数值路径与解释数值路径存在舍入差异 | 看第一处输入/输出、指标、种子；不强改阈值制造一致 | docs/COMPAT_COMPARISON.md |

排错顺序：先确认脚本和模型同一提交，再看最早的主错误，最后看下游“无法推断尺寸”等连带错误。保留失败尝试目录；不能覆盖后仅提交成功日志。新发现的问题应加到本表并链接实际证据。

干净手册审阅另外发现：表格内的 `&#124;` 在代码跨度中可能保留字面值，不能直接复制为 MATLAB `||`。转换条件现放在单独围栏代码块；转换表只作索引。还修正了不存在的单测试名称。手搭图必须接入自己的回放模型，否则只测试生成库并不能证明手搭图正确。

## 独立读者复现中发现的手册错误

新 clone 的批处理发现转换条件中的 HTML 实体在代码块内不会变成 MATLAB 运算符。现在条件以 T1…T14 围栏代码块给出。测试名 `testNormalCompletion` 不存在，已更正为 `testNormalFeedback`。最关键的问题是手搭图原本没有明确接到回放入口：现在 `build_learning_replay` 生成独立外壳，`runReplay(P,s,'myKickReplay')` 明确选择自己的图，并用半超时试验证明测试实际运行它。首次读者日志和修订复验分开保存，不覆盖失败记录。

独立审计用 Stateflow API 重画时，假设删除 Idle/Active 会同时删尽全部子状态，空图断言失败。改为明确删除每个子状态、再删父状态，记录状态计数从 7 逐次到 0 后再重建。此处是审计脚本的错误；GUI 的全选删除与 API 的对象删除不能混为一谈。失败证据与新尝试分别归档。

## ROS 外层编译

第一次把 `tdpTemplates` 直接放进解码 MATLAB Function，编译报结构体读取后不能再增加字段；改为在 BridgeDecode 一次性构造固定字段。随后反馈保持环中的 held 被推断为可变尺寸矩阵；在构建脚本中明确 frame、previous、held 为 `[1 20]`、quality 为 `[1 6]` 后，真实模型回放通过。沙箱内 MATLAB 一次无输出退出，沿用阶段0已验证的主机独立批处理路径。失败日志分别在 evidence/4/attempt-01…03，通过为 attempt-04。

## M2组合复现中的发现等待

单独ROS验证通过后，组合流程切换为不用daemon的新CLI节点，1 s发现时间不足，再次出现Unknown topic。完整失败目录build/m2-integrated-01和evidence/6/m2-integrated-01保留。已把两个取证程序统一为明确3 s发现、最多3次查询，每次原文各存一份；这只影响取证启动等待，不改变仿真tSim或控制算法。

## 干净 clone 的相机首帧启动竞态

3334d3c 的最终全量复现在二维与 ROS 101 帧门通过后，M2 motion 报 `No ROS graph evidence receipt`，动作帧数和执行数均为 0。`camera.json` 与实际缓冲区存在，但没有 `camera-ros.json`：前者只证明 Webots 相机读取成功。观察器停在等待图像，随后出现的 `ExternalShutdownException` 是失败清理的结果。完整失败归档在 `evidence/6/clean-final-02-failed/`。

源码中控制器先发布一帧 volatile 图像，再等待 graph-ready；观察器必须先收到图像才写 graph-ready。volatile 表示晚加入的订阅者不会自动收到历史消息，因此 DDS 发现稍慢时可能丢失这唯一首帧，形成相互等待。修复在启动握手期间重新发布同一采集时刻的相机图像和时钟，等待中不调用物理步进。250 ms 是墙钟重发间隔，不是控制周期；仿真仍为 20 ms 物理步、40 ms 控制步。后续要先查本地缓冲区、ROS接收回执、图发现回执三层，不得用第一层替代后两层。

参数表重生成时还出现 Matplotlib 无法写默认用户配置、转用临时目录的警告。两个绘图入口现在都在 import matplotlib 前设置 `MPLCONFIGDIR=build/matplotlib`，重跑生成成功且未再出现该警告；见 `evidence/6/figure-cache-01/`。这不改变图中输入数据。

## 全场跑完却提示 `TDP:V1SourceDrift`

预检种子 1 完成了 600 秒比赛及重复回放，随后整个分片在最后一次指纹核对时失败。两份清单显示运行期间工作树中的观测适配器有改动。逐场回执的 PASS 只对应那一场；分片回执为 FAIL。这次尝试单独保留。要复现，先提交运行源码，在新目录克隆该提交，再从新 MATLAB 进程运行 `reproduce_v1`。运行时只写新的证据目录。核对 `matches/source-before.json` 和 `matches/source-after.json` 的指纹，确认分片、汇总和外层回执各自通过。[预检失败回执](../../evidence/tactics-v1/matrix-longcheck-01/receipt.json)

## 按下 Pause 后哪个时刻才可当作停帧

一次真实窗口验收中，六项动画测试通过后，两个按墙钟延迟采集的“暂停”样本仍有不同的比赛时刻。原先按钮一收到请求就显示 `Paused`，而 MATLAB 驱动在下一次事件轮询时才调用 `pause(sm)`。现在点击后显示 `Pausing...`，监测到求解器状态实际为 `paused` 时才显示 `Paused` 并更新停帧。若有兴趣复查，运行图形验证器，在回执 `controls.samples` 对照请求、确认、保持和继续的引擎状态、时间与帧号。确认后的记录及显示时钟在继续之前应完全相同。等待超过 15 秒会将运行标为失败，停止及关窗仍可使用。[修复前的失败记录](../../evidence/tactics-v1/viewer-01/artifacts/receipt.json) · [按钮操作说明](live_animation.md)
