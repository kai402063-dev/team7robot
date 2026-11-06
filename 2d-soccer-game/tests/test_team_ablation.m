function tests=test_team_ablation()
%TEST_TEAM_ABLATION Check per-team intervention boundaries and archived endpoints.
tests=functiontests(localfunctions);
end

function testBothStrikersRecoverOnlySelectedTeamHandsBack(t)
c=v1TraceColumns();
for dt=[.05 .04]
    for automatic=[2 1]
        teams=(1:2)==automatic;
        manual=3-automatic;
        P=tdp.teamRecoveryConfig(teams);
        P.dt=dt;
        P.Tmatch=2;
        P.v1UnavailableWindow([4 8],:)=repmat([0 .32],2,1);
        P.v1RecoveryWindow(manual,:)=[1.4 1.6];
        [~,model]=matchSimulationInput(P);
        verifyEqual(t,model,'tdpTeamRecoveryMatch');
        [~,q,h]=runMatch(P);
        early=q(:,c.time)<=.32;
        middle=q(:,c.time)>=1.0 & q(:,c.time)<1.35;
        late=q(:,c.time)>=1.7;
        verifyTrue(t,all(q(early,c.takeover)==1,'all'));
        verifyEqual(t,q(middle,c.takeover),repmat(double(~teams),nnz(middle),1));
        verifyTrue(t,all(q(late,c.takeover)==0,'all'));
        verifySize(t,h,[round(P.Tmatch/dt) 53]);
        released=zeros(1,2);
        for side=1:2
            at=find(diff(q(:,c.takeover(side)))==-1);
            assertEqual(t,numel(at),1);
            released(side)=q(at+1,c.time);
        end
        verifyLessThan(t,released(automatic),1);
        verifyGreaterThanOrEqual(t,released(manual),1.4-1e-10);
        fprintf('ABLATION_ISOLATION %s\n',jsonencode(struct('dt',dt, ...
            'autoBlueRed',teams,'handbackSecondsBlueRed',released)));
    end
end
end

function testWrongNumberStopAndFeedbackLossStayOnSelectedTeam(t)
% Each striker is preparing ID 17. Both receive a different Stop ID before the kick is ready.
h=v1RecoveryColumns();
c=v1TraceColumns();
for automatic=[2 1]
    teams=(1:2)==automatic;
    experimental=4*automatic;
    manual=4*(3-automatic);
    P=tdp.teamRecoveryConfig(teams);
    P.Tmatch=2*P.dt;
    P.v1UnavailableWindow([4 8],:)=repmat([0 1],2,1);
    P.v1HealthDropWindow([4 8],:)=repmat([0 1.5*P.dt],2,1);
    T=tdpTemplates(P);
    world=T.World;
    for id=[4 8]
        world.actuator(id).active=true;
        world.actuator(id).seenId=uint32(17);
        world.actuator(id).feedback.requestId=uint32(17);
        world.actuator(id).feedback.status=TdpStatus.Running;
    end
    [input,model]=matchSimulationInput(P);
    input=input.setVariable('world0',world,'Workspace',model);
    run=sim(input);
    q=recordRows(run.tacticsRecords);
    health=recordRows(run.recoveryRecords);
    verifyEqual(t,q(:,c.kind([4 8])),repmat(double(TdpAction.Stop),2,2));
    verifyTrue(t,all(q(:,c.requestId([4 8]))~=17,'all'));
    verifyEqual(t,q(:,c.status(manual)),repmat(double(TdpStatus.Failed),2,1));
    verifyEqual(t,q(:,c.feedbackId(manual)),[17;17]);
    verifyEqual(t,q(:,c.status(experimental)),double([TdpStatus.None;TdpStatus.Rejected]));
    verifyEqual(t,q(1,c.feedbackId(experimental)),0);
    verifyEqual(t,q(2,c.feedbackId(experimental)),q(2,c.requestId(experimental)));
    verifyEqual(t,health(:,h.stamp(experimental)),[0;2*P.dt],'AbsTol',1e-12);
    verifyEqual(t,health(2,h.activeId(experimental)),17);
    verifyEqual(t,health(2,h.activeId(manual)),0);
    fprintf('ABLATION_FEEDBACK %s\n',jsonencode(struct('autoBlueRed',teams, ...
        'strikers',[4 8],'status',q(:,c.status([4 8])),'feedbackIds',q(:,c.feedbackId([4 8])))));
end
end

function testManualTeamRetainsLegacyAuthorizer(t)
% The legacy manual handback can use releaseId, but has no strict ID gate.
% Construct both active MF handbacks, then present an otherwise legal new ID.
for automatic=[2 1]
    teams=(1:2)==automatic;
    P=tdp.recoveryConfig();P.v1AutoRecoveryTeams=teams;
    T=tdpTemplates(P);
    world=T.World;world.referee.t=1;
    obs=V1Observation2D(world,1,P);
    blue=tdp.recoveryTeamMemory();blue.chaser=3;blue.recovering=true;
    blue.releaseId=uint32(17);blue.releaseDeadline=1.8;
    red=blue;red.chaser=7;
    plans=repmat(T.Intent,1,8);
    raw=repmat(T.Request,1,8);
    for mf=[3 7]
        plans(mf).type=TdpAction.Kick;
        raw(mf).kind=TdpAction.Kick;raw(mf).requestId=uint32(18);
        raw(mf).stamp=.8;raw(mf).validUntil=1.8;
    end
    previous=raw;previous(3).requestId=uint32(17);previous(7).requestId=uint32(17);
    feedback=repmat(T.Feedback,1,8);
    effective=V1AuthorizeRequests(raw,plans,obs,blue,red,previous,feedback,P);
    manualMf=4*(3-automatic)-1;automaticMf=4*automatic-1;
    verifyEqual(t,effective(manualMf),raw(manualMf));
    verifyEqual(t,effective(automaticMf).kind,TdpAction.Stop);
    verifyEqual(t,effective(automaticMf).requestId,uint32(17));
end
end

function testHomogeneousEndpointsMatchArchivedEntireTrajectories(t)
root=fileparts(fileparts(mfilename('fullpath')));
archive=fullfile(root,'evidence','recovery-v1','clean-01');
c=v1TraceColumns();
for dt=[.05 .04]
    seed=5;
    if dt==.04,seed=11;end
    for automatic=[false true]
        P=tdp.teamRecoveryConfig(repmat(automatic,1,2));
        P.dt=dt;P.seed=seed;P.Tmatch=600;
        policy='v1';
        if automatic,policy='recovery';end
        game=sprintf('dt%02d-seed%02d',round(1000*dt),seed);
        expected=jsondecode(fileread(fullfile(archive,policy,game,'artifact.json')));
        [trace,tactics,health]=runMatch(P);
        arrays=struct('trace',trace,'tactics',tactics);
        if automatic,arrays.recovery=health;end
        redTakeover=tactics(:,c.takeover(2));
        verifyTrue(t,any(redTakeover==1));
        verifyEqual(t,any(diff(redTakeover)==-1),automatic);
        digests=struct();
        for field=fieldnames(arrays)'
            name=field{1};
            verifySize(t,arrays.(name),expected.arrays.(name).shape');
            digests.(name)=rowMajorHash(arrays.(name));
            verifyEqual(t,digests.(name),expected.arrays.(name).sha256LittleEndianDoublesRowMajor);
        end
        fprintf('ABLATION_ENDPOINT %s\n',jsonencode(struct('configuration',policy, ...
            'case',game,'steps',size(trace,1),'redReleases',nnz(diff(redTakeover)==-1), ...
            'digests',digests)));
    end
end
end

function hex=rowMajorHash(matrix)
% Match the NumPy little-endian, C-order contract in the archived receipts.
values=reshape(matrix.',[],1);
[~,~,endian]=computer;
if endian=='B',values=swapbytes(values);end
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(typecast(values,'int8'));
hex=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
end
