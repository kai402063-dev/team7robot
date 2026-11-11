function [plans,m,v11] = v1TeamPlans(obs,team,prev,previousRequests,feedback,recovered,P,health,v11)
%V1TEAMPLANS Plan four fixed roles using only observed state and feedback.
% Team-local role numbers are GK=1, DF=2, MF=3, ST=4. Chaser is a global ID.
% 7 inputs: approved V1. 8 inputs: automatic recovery experiment (health).
% 9 inputs: approved V1 model, where the 8th input is last tick's 1x8 skill
% phases and the 9th the V1.1 monitor state (tdp.v11FallbackMemory). The V1.1
% rule runs only when P.v11Fallback is true; otherwise v11 passes through.
first = 1+4*(team-1);
midfielder = first+2;
striker = first+3;
t = obs(first).tSim;
direction = P.dirSign(team);
roles = [TdpRole.GK TdpRole.DF TdpRole.MF TdpRole.ST];
plans = repmat(intent(TdpAction.Stop,[0 0],0,0,TdpRole.Unknown),1,4);

m = prev;
m.chaser = 0;
m.ballSource = 0;
latest = -Inf;
available = false(1,4);
for local = 1:4
    i = first+local-1;
    plans(local).role = roles(local);
    available(local) = obs(i).selfValid && validRobot(obs(i),i,t,P);
    if available(local) && validBall(obs(i),t,P) && obs(i).ballStamp>latest
        latest = obs(i).ballStamp;
        m.ballSource = i;
    end
end
m.ballKnown = m.ballSource~=0;
finishCurrentKick = false;
if nargin<9, v11 = tdp.v11FallbackMemory(); end
if nargin==9 && isfield(P,'v11Fallback') && P.v11Fallback
    [m,v11] = updateTakeoverV11(m,prev,striker,midfielder,available(4), ...
        previousRequests,feedback,recovered,health,v11,t,P);
elseif nargin==8
    mfEligible = available(3) && validBall(obs(midfielder),t,P) && obs(midfielder).gameRunning;
    m = tdp.updateRecovery(m,prev,striker,midfielder,available(4),mfEligible, ...
        previousRequests,feedback,health,t,P);
    finishCurrentKick = m.recovering && ~m.cancelPending && m.releaseId~=0;
else
    m = updateTakeover(m,prev,striker,midfielder,available(4), ...
        previousRequests,feedback,recovered,t,P);
end

if ~obs(first).gameRunning
    m.phase = TdpTeamPhase.Hold;
    return
end
% Default shape is independent of all ball values, including invalid NaNs.
heading = 0;
if direction<0, heading = pi; end
keeperX = direction*(-P.L/2+P.v1KeeperInset);
defenderX = direction*(-P.L/2+P.defDist);
plans(1) = intent(TdpAction.Goto,[keeperX 0],heading,0,roles(1));
plans(2) = intent(TdpAction.Goto,[defenderX 0],heading,0,roles(2));
plans(3) = intent(TdpAction.Goto,[-direction*P.v1CounterDepth 0],heading,0,roles(3));
plans(4) = intent(TdpAction.Goto,[-direction*P.v1CounterDepth direction*P.v1SupportWidth],heading,0,roles(4));

if ~m.ballKnown
    m.phase = TdpTeamPhase.Search;
    if ~m.recovering
        if m.takeover && available(3)
            m.chaser = midfielder;
        elseif ~m.takeover && available(4)
            m.chaser = striker;
        end
    end
    if m.chaser~=0
        local = m.chaser-first+1;
        plans(local) = intent(TdpAction.Search,[0 0],heading,0,roles(local));
    end
else
    source = obs(m.ballSource);
    ball = [source.ball.x source.ball.y];
    forward = direction*ball(1);
    if forward>P.v1MidlineBand
        m.basePhase = TdpTeamPhase.Attack;
    elseif forward < -P.v1MidlineBand
        m.basePhase = TdpTeamPhase.Defend;
    end
    keeperY = clamp(0.5*ball(2),-P.goalW/2+P.robotR,P.goalW/2-P.robotR);
    plans(1) = positionIntent([keeperX keeperY],ball,roles(1));
    ownGoal = [-direction*P.L/2 0];
    threat = ball-ownGoal;
    distance = hypot(threat(1),threat(2));
    if distance>1e-9
        block = ownGoal + P.defDist*threat/distance;
    else
        block = [defenderX 0];
    end
    block(1) = direction*clamp(direction*block(1),-P.L/2+P.robotR,-P.robotR);
    plans(2) = positionIntent(insidePitch(block,P),ball,roles(2));
    m.phase = m.basePhase;
    if m.takeover
        m.phase = TdpTeamPhase.Fallback;
        if available(3) && (~m.recovering || finishCurrentKick), m.chaser = midfielder; end
    elseif m.basePhase==TdpTeamPhase.Attack
        m.chaser = striker;
        if available(4)
            p = obs(striker).robots(striker);
            support = supportPosition([p.x p.y],source,midfielder,direction,t,P);
            plans(3) = positionIntent(support,ball,roles(3));
        end
    else
        screen = [-direction*P.v1ScreenDepth 0.5*ball(2)];
        plans(3) = positionIntent(insidePitch(screen,P),ball,roles(3));
        if available(3) && looseForMidfielder(obs(midfielder),source,team,midfielder,ball,t,P)
            m.chaser = midfielder;
        end
    end
    if m.chaser~=0
        local = m.chaser-first+1;
        goal = [direction*P.L/2 0];
        speed = P.dribbleSpeed;
        if m.phase~=TdpTeamPhase.Defend && hypot(goal(1)-ball(1),goal(2)-ball(2))<P.shootDist
            speed = P.shotSpeed;
        end
        plans(local) = intent(TdpAction.Kick,goal,heading,speed,roles(local));
    end
end
for local = 1:4
    if ~available(local) || (local==4 && m.takeover) || (local==3 && m.recovering && ~finishCurrentKick)
        plans(local) = intent(TdpAction.Stop,[0 0],heading,0,roles(local));
    end
end
end

function m = updateTakeover(m,prev,st,mf,stAvailable,requests,feedback,recovered,t,P)
request = requests(st);
fb = feedback(st);
matching = kickRequest(request) && prev.chaser==st && fb.requestId==request.requestId && ...
    fb.stamp>=request.stamp && fb.stamp<=request.validUntil && fb.stamp<=t && ...
    t-fb.stamp<=P.kickTimeout && t<=request.validUntil+P.dt+1e-12;
newFailure = matching && fb.status==TdpStatus.Failed && fb.requestId>m.handledFailureId;
if newFailure
    m.failed = true;
    m.handledFailureId = fb.requestId;
end
if ~stAvailable || newFailure
    m.takeover = true;
    m.recovering = false;
    m.releaseId = uint32(0);
    m.releaseStamp = 0;
    return
end
if ~m.takeover || ~(recovered || prev.recovering), return; end
m = releaseTakeover(m,prev,mf,requests,feedback,t);
end

function [m,v] = updateTakeoverV11(m,prev,st,mf,stAvailable,requests,feedback,recovered,skills,v,t,P)
% Draft v1.1 section 6(d): take over after v11FailCount consecutive matched ST
% kick failures whose stamps span at most v11FailWindow; any matched Done
% resets the count. Unavailability still takes over at once, as in V1.
% T7: hand back once ST has been available for v11RecoverSeconds and the MF
% was not in Align/Kick on the last tick; a pending MF kick is still drained.
request = requests(st);
fb = feedback(st);
matching = kickRequest(request) && prev.chaser==st && fb.requestId==request.requestId && ...
    fb.stamp>=request.stamp && fb.stamp<=request.validUntil && fb.stamp<=t && ...
    t-fb.stamp<=P.kickTimeout && t<=request.validUntil+P.dt+1e-12;
if matching && fb.status==TdpStatus.Done
    v(1) = 0;
end
trigger = false;
if matching && fb.status==TdpStatus.Failed && fb.requestId>m.handledFailureId
    m.handledFailureId = fb.requestId;
    v(1) = min(v(1)+1,8);
    v(3:9) = v(4:10);
    v(10) = fb.stamp;
    k = P.v11FailCount;
    trigger = v(1)>=k && fb.stamp-v(11-k)<=P.v11FailWindow+1e-9;
end
if ~stAvailable || trigger
    m.takeover = true;
    m.failed = m.failed || trigger;
    m.recovering = false;
    m.releaseId = uint32(0);
    m.releaseStamp = 0;
    v(2) = -1;
    if stAvailable, v(2) = t; end
    return
end
if ~m.takeover, return; end
if v(2)<0, v(2) = t; end
busy = skills(mf)==double(TdpPhase.Align) || skills(mf)==double(TdpPhase.Kick);
stable = t-v(2)+1e-9>=P.v11RecoverSeconds && ~busy;
if ~(recovered || stable || prev.recovering), return; end
m = releaseTakeover(m,prev,mf,requests,feedback,t);
if ~m.takeover
    v(1) = 0;
    v(2) = -1;
end
end

function m = releaseTakeover(m,prev,mf,requests,feedback,t)
% A recovery signal cannot authorize a second kick while the MF is preparing.
request = requests(mf);
fb = feedback(mf);
if prev.recovering
    if ~(fb.requestId==prev.releaseId && terminal(fb.status) && ...
            fb.stamp>=prev.releaseStamp && fb.stamp<=t)
        return
    end
elseif kickRequest(request)
    finished = fb.requestId==request.requestId && terminal(fb.status) && ...
        fb.stamp>=request.stamp && fb.stamp<=t;
    if ~finished
        m.recovering = true;
        m.releaseId = request.requestId;
        m.releaseStamp = t;
        return
    end
end
m.takeover = false;
m.failed = false;
m.recovering = false;
m.releaseId = uint32(0);
m.releaseStamp = 0;
end

function p = supportPosition(st,ob,mf,d,t,P)
% Choose the less congested of two wing positions, in the team's frame.
left = insidePitch(st+[-d*P.v1SupportTrail d*P.v1SupportWidth],P);
right = insidePitch(st+[-d*P.v1SupportTrail -d*P.v1SupportWidth],P);
leftRoom = Inf;
rightRoom = Inf;
for i = 1:8
    if i~=mf && validRobot(ob,i,t,P)
        robot = ob.robots(i);
        leftRoom = min(leftRoom,hypot(left(1)-robot.x,left(2)-robot.y));
        rightRoom = min(rightRoom,hypot(right(1)-robot.x,right(2)-robot.y));
    end
end
p = left;
if rightRoom>leftRoom, p = right; end
end

function yes = looseForMidfielder(self,ob,team,mf,ball,t,P)
r = self.robots(mf);
yes = hypot(r.x-ball(1),r.y-ball(2))<=P.v1LooseRange && ...
    hypot(ob.ball.vx,ob.ball.vy)<=P.v1LooseSpeed;
if ~yes, return; end
opponentFirst = 1+4*(2-team);
for i = opponentFirst:opponentFirst+3
    if ~validRobot(ob,i,t,P)
        yes = false;
        return
    end
    opponent = ob.robots(i);
    if hypot(opponent.x-ball(1),opponent.y-ball(2))<=P.v1OpponentClearance
        yes = false;
        return
    end
end
end

function yes = validRobot(ob,id,t,P)
p = ob.robots(id);
age = t-ob.robotStamp(id);
yes = ob.robotValid(id) && isfinite(age) && age>=0 && age<=P.maxObservationAge && ...
    isfinite(p.x) && isfinite(p.y) && isfinite(p.th);
end

function yes = validBall(ob,t,P)
age = t-ob.ballStamp;
yes = ob.ballValid && isfinite(age) && age>=0 && age<=P.maxObservationAge && ...
    isfinite(ob.ball.x) && isfinite(ob.ball.y) && isfinite(ob.ball.vx) && isfinite(ob.ball.vy);
end

function a = positionIntent(p,ball,role)
a = intent(TdpAction.Goto,p,atan2(ball(2)-p(2),ball(1)-p(1)),0,role);
end

function a = intent(kind,target,heading,speed,role)
a = struct('type',kind,'target',target,'heading',heading,'speed',speed,'role',role);
end

function yes = kickRequest(request)
yes = (request.kind==TdpAction.Kick || request.kind==TdpAction.Tap) && request.requestId~=0;
end

function yes = terminal(status)
yes = status==TdpStatus.Done || status==TdpStatus.Failed || status==TdpStatus.Rejected;
end

function p = insidePitch(p,P)
p = [clamp(p(1),-P.L/2+P.robotR,P.L/2-P.robotR), ...
    clamp(p(2),-P.W/2+P.robotR,P.W/2-P.robotR)];
end

function v = clamp(v,low,high)
v = min(max(v,low),high);
end
