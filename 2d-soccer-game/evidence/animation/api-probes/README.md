# 实时动画 API 探针回执

这些是子代理 animation_api_review 在独立、无显示的 MATLAB R2026b `-batch` 进程中获得的工具输出摘录；原进程 stdout 由执行工具收集，以下 `.log` 是从工具返回逐字摘录并加上会话分隔说明，**不是原始 stdout 重定向文件**。缓存均在本工作树 build/ 下。没有修改模型、源码、只读输入或用户已打开的 MATLAB。

## 已验证

- `initialize(simulation(SimulationInput))` 后，`tdpMatch/Record` 存在 RuntimeObject，NumOutputPorts=1；保持模型原优化设置时，PostOutputs 监听注册成功，并收到前 9 帧。
- `tdpMatch/Records`（To Workspace）不能作为 RuntimeObject/监听目标，关闭 BlockReduction 仍失败。不要把这个错误归因于 tdpMatch 控制或物理。
- `step(sm)` 后可读取 `sm.SimulationOutput.records`。真实模型 2 s/40 步所得 40×98 trace 与 `runMatch(P)` 完全一致，最大差为 0；循环含 getter 耗时 3.9130 s，因此不适合作为本机默认 20 FPS 动画后端。
- `start(sm)` 在真实模型中返回后状态为 running。`pause(sm)` 后等候 0.2 s，Time 固定 0.45 s，监听行数固定 9。
- 内存 Clock→Gain→ToWorkspace 小模型：initialize 后挂监听、start、pause、`sm=setModelParameter(sm,'PacingRate','2')`、resume、每次 pause(0.05) 的外层事件循环全程完成；40 个回调、40 个记录。
- 此 R2026b 实测最后一步/自然结束状态为 inactive，Time=NaN；只在非 inactive 时调用 stop，避免 already Inactive 警告。

## 未验证或失败

- 真实 tdpMatch 的首次连续运行探针在暂停稳定性输出后没有完成；该进程被诊断性 SIGINT 中断，exit 130。当时后续语句没有阶段打印，无法定位在设置倍率、resume 还是等待循环；它使用 pause(0.001) 的等待间隔，不能据此断言某个 API 本身有缺陷。
- 有阶段打印、pause(0.05)、10 s 仿真看门狗和 180 s 外部上限的真实模型重跑，按父代理停止新探针的指示在初始化阶段中断，exit 130。它没有验收价值。
- 因此这里**没有**声称真实模型完整连续监听 40 帧与 runMatch 等价；最终 runner 测试需要补齐该门。step 等价性与小模型连续执行的证据应分别使用。
- 小模型的变速后恢复到结束为 2.0352 s，不能用它宣称精确达到 2 倍墙钟速度。Native pacing 是近似减速机制，不是硬实时保证。

## 推荐接口

```matlab
sm = simulation(simin);
initialize(sm);
h = add_exec_event_listener('tdpMatch/Record', 'PostOutputs', ...
    @(block,event) viewer.showFrame(reshape(double(block.OutputPort(1).Data),1,98)));
start(sm);
% Keep h alive. Process UI flags outside the listener.
% Use pause(sm), resume(sm), setModelParameter(sm,'PacingRate','2').
% Check Status before stop(sm); read sm.SimulationOutput.records at the end.
```

监听只更新图元，外层循环处理暂停、继续、关闭和倍率。为已运行的模型设置 preflight 拒绝，避免接管用户仿真。无需修改 StartFcn 或 Model UserData，也无需依赖内部带空格的 Stateflow S-Function 路径。

## 官方来源（2026-11-06 查阅）

- https://www.mathworks.com/help/simulink/slref/add_exec_event_listener.html
- https://www.mathworks.com/help/simulink/slref/simulink.simulation.start.html
- https://www.mathworks.com/help/simulink/slref/simulink.simulation.step.html
- https://www.mathworks.com/help/simulink/slref/simulink.simulation.stop.html
- https://www.mathworks.com/help/simulink/slref/simulink.simulationinput.setmodelparameter.html
- https://www.mathworks.com/help/simulink/slref/simulationpacingoptions.html

私有 GUI 验收可使用已存在且动态库解析成功的 `/home/fayne/Applications/MATLAB/R2026b/sys/Xvfb/bin/glnxa64/Xvfb`。只给任务子进程设置 DISPLAY，并只清理自己的 Xvfb；现有 run_matlab.sh 会移除 DISPLAY，不适合直接承载该 GUI 验收。
