function export_v1_contracts(outDir)
%EXPORT_V1_CONTRACTS Regenerate documentation from the executing V1 types.
root=tdpSetup();
if nargin<1
    outDir=fullfile(root,'docs','generated');
end
if ~isfolder(outDir), mkdir(outDir); end
P=tdp.v1Config();
tdp.validateV1Config(P);
memory=tdp.v1TeamMemory();
columns=v1TraceColumns();
writeJson(fullfile(outDir,'v1_config.json'),P);
writeJson(fullfile(outDir,'v1_memory.json'),memory);
writeJson(fullfile(outDir,'v1_columns.json'),columns);
walk=midlineReplay(P);
writeJson(fullfile(outDir,'v1_handwalk.json'),walk);

file=fullfile(outDir,'v1_contracts.md');
fid=fopen(file,'w','n','UTF-8');
assert(fid>=0,'TDP:V1Export','Cannot write the V1 contract table.');
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# V1 运行配置、团队记忆与记录列\n\n');
fprintf(fid,'由 `scripts/export_v1_contracts.m` 从当前工程生成。类型、尺寸、默认值和列号均取自可执行定义。\n\n');
fprintf(fid,'## 启用 V1 时增加或覆盖的参数\n\n');
fprintf(fid,'完整实际配置见 [v1_config.json](v1_config.json)。其余继承字段的单位及出处见[基线参数表](parameters.md)。\n\n');
fprintf(fid,'| 参数 | 类型 | 尺寸 | 默认值 | 单位 | 来源和用途 |\n|---|---|---|---|---|---|\n');
paramInfo={
    'v1Enabled','开关','实施选择。启用八机器人 V1 比赛模型';
    'mode','枚举','实施选择。Delayed 接入技能阶段、搜索转动和关联反馈';
    'rulesProfile','枚举','教学规则。默认 CourseSimplified，规则配置与战术配置分开';
    'freezeDuringPause','开关','配置覆盖。Delayed 执行器和授权层遇停赛均阻止运动';
    'v1MidlineBand','m','教学设定。半场切换死区的半宽，边界相等时保留原相位';
    'v1SupportTrail','m','教学设定。进攻 MF 支援点相对 ST 的后移量';
    'v1SupportWidth','m','教学设定。左右候选支援点及 ST 反击接应点的侧移量';
    'v1LooseRange','m','教学设定。防守时 MF 可以争自由球的最大距离';
    'v1LooseSpeed','m/s','教学设定。自由球允许的最大速度模长';
    'v1OpponentClearance','m','教学设定。判自由球时每个已确认对手距球须严格大于此值';
    'v1KeeperInset','m','教学设定。GK 站位离己方球门线向场内的距离';
    'v1ScreenDepth','m','教学设定。MF 中央防守目标距中线向本方的距离';
    'v1CounterDepth','m','教学设定。ST 反击接应及 MF 未知球保持点距中线向本方的距离';
    'v1UnavailableWindow','s','定向测试。每个机器人一行，不可用时 Poses 无效，身体仍在场';
    'v1BlindWindow','s','定向测试。每个机器人一行，令本机球观测无效';
    'v1StaleWindow','s','定向测试。每个机器人一行，球采集时刻设为超过最大年龄';
    'v1StopWindow','s','定向测试。全场一行，撤去比赛运行许可';
    'v1RecoveryWindow','s','定向测试。每队一行，向协调器给出显式 ST 恢复信号';
    'v1FailWindow','s','定向测试。每个机器人一行，该窗内准备完成的踢球执行强制失败'};
base=tdp.defaultConfig();
newFields=setdiff(fieldnames(P),fieldnames(base));
assert(all(ismember(newFields,paramInfo(:,1))),'TDP:V1Export','Missing V1 parameter description.');
for k=1:size(paramInfo,1)
    key=paramInfo{k,1};v=P.(key);
    fprintf(fid,'| %s | %s | %s | %s | %s | %s |\n',key,class(v),mat2str(size(v)), ...
        displayValue(v),paramInfo{k,2},paramInfo{k,3});
end
fprintf(fid,'\n时间窗每行是起始和结束秒数，包含起点，不包含终点。两个端点相同表示禁用。8 行按全局机器人 1–8 排列，2 行按蓝队、红队排列。\n\n');
fprintf(fid,'## V1TeamBus 初值\n\n每队持有一份标量结构，每拍用一个 Unit Delay 保存。\n\n');
fprintf(fid,'| 字段 | 类型 | 初值 | 单位与含义 |\n|---|---|---|---|\n');
memInfo={
    'basePhase','团队枚举。最近有效观测确认的基础攻防，初次中线自由开球为 Attack';
    'phase','团队枚举。本拍对外显示的模式';
    'chaser','全局机器人号 1–8，0 表示本队无人获准追球';
    'failed','布尔。本队 ST 的匹配执行失败已锁存';
    'recovering','布尔。正在等待 MF 旧动作终态，暂缓交还';
    'releaseId','请求号。待结束的 MF 动作，0 表示当前无等待';
    'handledFailureId','请求号。最后一次已处理的 ST 失败，用于去重';
    'ballKnown','布尔。本队本拍选到了有效且新鲜的球观测';
    'ballSource','全局机器人号。提供所选观测的队员，0 表示无来源';
    'takeover','布尔。MF 临时责任已锁存，球未知时仍保存';
    'releaseStamp','s。发起本次 MF 撤权的仿真时刻，过滤过早的终态反馈'};
assert(isequal(fieldnames(memory),memInfo(:,1)),'TDP:V1Export','Update the team-memory catalog.');
for k=1:size(memInfo,1)
    key=memInfo{k,1};v=memory.(key);
    fprintf(fid,'| %s | %s | %s | %s |\n',key,class(v),displayValue(v),memInfo{k,2});
end
fprintf(fid,'\n## tacticsRecords 的列号\n\n所有列存为 double。双列按蓝队、红队顺序；八列按全局机器人 1–8 顺序。布尔量以 0/1 保存。\n\n');
fprintf(fid,'| 字段 | 列号 | 单位或枚举 | 信号含义 |\n|---|---|---|---|\n');
columnInfo={
    'time','s','本拍 tSim';
    'phase','TdpTeamPhase','两队对外模式';
    'basePhase','TdpTeamPhase','两队基础攻防相位';
    'chaser','全局号','两队本拍追球授权人，0 表示无人';
    'ballKnown','布尔','两队是否有可用球观测';
    'ballSource','全局号','两队选中的观测源，0 表示无来源';
    'failed','布尔','两队 ST 匹配失败锁存';
    'running','布尔','裁判与场景给出的本拍比赛许可';
    'kicker','全局号','环境在本拍确实踢球的机器人，0 表示无人';
    'available','布尔','个人可用且定位有效、新鲜';
    'ballFresh','布尔','个人球观测有效、新鲜';
    'intent','TdpAction','队级计划动作类型';
    'rawKind','TdpAction','各个人 Core 的原始请求类型';
    'kind','TdpAction','授权层实际交给执行器的请求类型';
    'requestId','请求号','有效请求编号，须与机器人号一同匹配';
    'status','TdpStatus','执行器返回的反馈状态';
    'feedbackId','请求号','执行器反馈关联的请求编号';
    'skill','TdpPhase','个人 Stateflow 技能阶段';
    'targetX','m','队级意图的场地目标 x，按 intent 区分站位或踢球方向目标';
    'targetY','m','队级意图的场地目标 y';
    'ballAge','s','本拍 tSim 减去本机球采集时刻，与 ballFresh 一起解释';
    'rawId','请求号','授权前 Core 请求编号';
    'executions','次','执行器累计接受的踢球动作次数，包含随后失败/取消的尝试';
    'feedbackStamp','s','本次记录的反馈采集时刻，反馈可保持上一状态';
    'validUntil','s','实际请求的最后有效时刻';
    'stamp','s','实际请求的发出时刻';
    'rawSpeed','m/s','原始请求所带的踢球目标速度';
    'speed','m/s','实际请求所带的踢球目标速度';
    'takeover','布尔','两队当前是否锁存 MF 临时责任';
    'recovering','布尔','两队是否正在取消 MF 旧动作并等待交还'};
assert(isequal(fieldnames(columns),columnInfo(:,1)),'TDP:V1Export','Update the tactics trace catalog.');
for k=1:size(columnInfo,1)
    key=columnInfo{k,1};idx=columns.(key);
    fprintf(fid,'| %s | %s | %s | %s |\n',key,columnLabel(idx),columnInfo{k,2},columnInfo{k,3});
end
fprintf(fid,'\n## 中线五拍回放\n\n输入按既定顺序送入当前协调器。这里的结果是函数回放，整场比赛另行验收。红队输入 x 取反。\n\n');
fprintf(fid,'| tSim (s) | 蓝队输入 x (m) | 蓝队输出 | 红队镜像输出 |\n|---:|---:|---|---|\n');
for k=1:numel(walk.time)
    fprintf(fid,'| %.2f | %.2f | %s | %s |\n',walk.time(k),walk.blueBallX(k), ...
        char(string(TdpTeamPhase(walk.bluePhase(k)))),char(string(TdpTeamPhase(walk.redPhase(k)))));
end
end

function out=midlineReplay(P)
T=tdpTemplates(P);
x=[-.20 .04 .16 -.10 -.16];
time=1+(0:numel(x)-1)*P.dt;
phases=zeros(2,numel(x));
requests=repmat(T.Request,1,8);
feedback=repmat(T.Feedback,1,8);
for team=1:2
    memory=tdp.v1TeamMemory();
    memory.basePhase=TdpTeamPhase.Defend;
    for k=1:numel(x)
        world=T.World;
        world.referee.t=time(k);
        world.ball.x=P.dirSign(team)*x(k);
        observations=V1Observation2D(world,time(k),P);
        [~,memory]=tdp.v1TeamPlans(observations,team,memory,requests,feedback,false,P);
        phases(team,k)=double(memory.phase);
    end
end
out=struct('time',time,'blueBallX',x,'bluePhase',phases(1,:),'redPhase',phases(2,:));
end

function s=displayValue(v)
if isenum(v)
    s=char(string(v));
elseif islogical(v)
    if v,s='true';else,s='false';end
else
    s=mat2str(v,15);
end
end

function s=columnLabel(i)
if isscalar(i)
    s=num2str(i);
else
    s=sprintf('%d–%d',i(1),i(end));
end
end
