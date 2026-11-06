# 从 ControllerCore.slx 提取的完整状态文本

```matlab
Idle
en,du:
 phase=TdpPhase.Idle;
 requestId=requestId+uint32(1);
```

```matlab
Active
en,du:
 if P.mode==TdpMode.Compat || phase~=TdpPhase.Kick
     requestId=requestId+uint32(1);
 end
```

```matlab
Search
en: phase=TdpPhase.Search;
```

```matlab
Approach
en: phase=TdpPhase.Approach;
```

```matlab
Align
en: phase=TdpPhase.Align;
```

```matlab
Kick
en:
 phase=TdpPhase.Kick;
 requestId=requestId+uint32(1);
 kickStart=tSim;
 kickTarget=g.target;
 kickSpeed=g.speed;
```

```matlab
Recover
en:
 phase=TdpPhase.Recover;
 recoverStart=tSim;
```

| 起点 | 终点 | 优先级 | 条件 / 动作 |
| --- | --- | --- | --- |
| DEFAULT | Search | 1 | [T1](#t1) |
| Align | Kick | 3 | [T2](#t2) |
| Align | Search | 1 | [T3](#t3) |
| Approach | Search | 1 | [T4](#t4) |
| Recover | Search | 1 | [T5](#t5) |
| Search | Approach | 1 | [T6](#t6) |
| Align | Approach | 2 | [T7](#t7) |
| Approach | Align | 2 | [T8](#t8) |
| Kick | Recover | 1 | [T9](#t9) |
| Kick | Recover | 2 | [T10](#t10) |
| Kick | Recover | 3 | [T11](#t11) |
| DEFAULT | Idle | 1 | [T12](#t12) |
| Active | Idle | 1 | [T13](#t13) |
| Idle | Active | 1 | [T14](#t14) |

复制下面代码块中的原文；表格只负责索引和优先级，避免竖线转义破坏 MATLAB 条件。

### T1

DEFAULT → Search；优先级 1

```matlab

```

### T2

Align → Kick；优先级 3

```matlab
[g.ready]
```

### T3

Align → Search；优先级 1

```matlab
[~g.ballVisible]
```

### T4

Approach → Search；优先级 1

```matlab
[~g.ballVisible && g.intent~=TdpAction.Goto]
```

### T5

Recover → Search；优先级 1

```matlab
[tSim-recoverStart>=P.recoverTime]
```

### T6

Search → Approach；优先级 1

```matlab
[g.ballVisible || g.intent==TdpAction.Goto]
```

### T7

Align → Approach；优先级 2

```matlab
[g.distance>P.alignExit || g.intent==TdpAction.Goto]
```

### T8

Approach → Align；优先级 2

```matlab
[g.distance<P.alignEnter && g.intent~=TdpAction.Goto]
```

### T9

Kick → Recover；优先级 1

```matlab
[fb.requestId==requestId && (fb.status==TdpStatus.Done || fb.status==TdpStatus.Failed || fb.status==TdpStatus.Rejected)]
```

### T10

Kick → Recover；优先级 2

```matlab
[tSim-kickStart>=P.kickTimeout]
```

### T11

Kick → Recover；优先级 3

```matlab
[~g.ballVisible]
```

### T12

DEFAULT → Idle；优先级 1

```matlab
{requestId=uint32(0);kickStart=0;kickTarget=[0 0];kickSpeed=0;recoverStart=0;}
```

### T13

Active → Idle；优先级 1

```matlab
[~g.safe || (~g.running && P.mode==TdpMode.Delayed)]
```

### T14

Idle → Active；优先级 1

```matlab
[g.safe && (g.running || P.mode==TdpMode.Compat)]
```

