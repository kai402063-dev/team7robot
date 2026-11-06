function result = runA(seed,kickNoise,duration,dt)
%RUNA Headless oracle with the exact main_robocup2d.m lines 15-67 order.
% Only duration, pacing, seed, noise and optional period are overridden.
root=fileparts(fileparts(mfilename('fullpath')));oldPath=path;oldRng=rng;
c=onCleanup(@()restore(oldPath,oldRng));
addpath(fullfile(root,'reference','projectA'),'-begin');
P=simParams();P.seed=seed;P.Tmatch=duration;P.realtime=false;
if nargin>=2 && ~isempty(kickNoise),P.kickNoise=kickNoise;end
if nargin>=4,P.dt=dt;end
rng(P.seed,'twister');[robots,ball,state]=initState(P);
mem=struct('striker',{0,0});nSteps=round(P.Tmatch/P.dt);nR=numel(robots);
trace=zeros(nSteps,98);firstTouch=NaN;
for step=1:nSteps
 state.t=step*P.dt;playing=state.t>=state.pauseUntil;
 cmds=zeros(nR,3);kicked=false;
 if mod(step,2),order=[1 2];else,order=[2 1];end
 for team=order
  [acts,mem(team)]=teamBehaviour(robots,ball,team,mem(team),P);
  idx=find([robots.team]==team);
  for a=1:numel(idx)
   i=idx(a);robots(i).role=acts(a).role;
   if strcmp(acts(a).type,'kick')
    [cmds(i,:),doKick,kv]=kickSkill(robots(i),ball,acts(a).target, ...
     acts(a).speed,robots,i,playing && ~kicked,P);
    if doKick
     ball.vx=kv(1);ball.vy=kv(2);robots(i).cool=P.kickCooldown;
     state.lastTouch=team;
     if acts(a).speed>=P.shotSpeed && strcmp(acts(a).role,'ST')
      state.shots(team)=state.shots(team)+1;
     end
     kicked=true;
    end
   else
    cmds(i,:)=goToPose(robots(i),acts(a).target,acts(a).heading,robots,i,ball,false,P);
   end
  end
 end
 robots=robotModel(robots,cmds,P);
 if playing,ball=ballModel(ball,P);end
 [robots,ball,state]=collisions(robots,ball,state,playing,P);
 if state.lastTouch>0 && isnan(firstTouch),firstTouch=state.t;end
 if playing
  if state.lastTouch>0,state.touchTime(state.lastTouch)=state.touchTime(state.lastTouch)+P.dt;end
  [robots,ball,state]=rulesCheck(robots,ball,state,P);
 end
 trace(step,:)=encodeTrace(robots,ball,state,mem,cmds,kicked);
end
result=struct('parameters',P,'trace',trace,'robots',robots,'ball',ball,'state',state, ...
 'memory',mem,'firstTouch',firstTouch);
end
function restore(p,r)
path(p);rng(r);
end
