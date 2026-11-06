%MAIN_ROBOCUP2D  2D 4 v 4 NAO6 RoboCup soccer simulation (ENG5325, Stage 1).
%   Run this script. Edit simParams.m to change the pitch, robot limits,
%   gains, match length or animation speed.
%
%   Loop each time step:
%     1. behaviour  (teamBehaviour)  -> what each robot wants to do
%     2. skills     (kickSkill / goToPose) -> body velocity commands, kicks
%     3. models     (robotModel, ballModel) -> move robots and ball
%     4. contacts   (collisions)     -> robot-robot and robot-ball
%     5. rules      (rulesCheck)     -> goals, out of play, restarts
%     6. drawing    (updateGraphics)

clear; clc;
P = simParams();
rng(P.seed);
[robots, ball, state] = initState(P);
mem = struct('striker', {0, 0});            % behaviour memory per team
h = initGraphics(P, robots, ball);

nSteps = round(P.Tmatch / P.dt);
nR = numel(robots);
tic;
for step = 1:nSteps
    state.t = step * P.dt;
    playing = state.t >= state.pauseUntil;  % ball frozen during restarts

    % 1-2. behaviour and skills
    cmds = zeros(nR, 3);
    kicked = false;
    if mod(step, 2), order = [1 2]; else, order = [2 1]; end   % fair kick priority
    for team = order
        [acts, mem(team)] = teamBehaviour(robots, ball, team, mem(team), P);
        idx = find([robots.team] == team);
        for a = 1:numel(idx)
            i = idx(a);
            robots(i).role = acts(a).role;
            if strcmp(acts(a).type, 'kick')
                [cmds(i,:), doKick, kv] = kickSkill(robots(i), ball, acts(a).target, ...
                    acts(a).speed, robots, i, playing && ~kicked, P);
                if doKick
                    ball.vx = kv(1);  ball.vy = kv(2);
                    robots(i).cool = P.kickCooldown;
                    state.lastTouch = team;
                    if acts(a).speed >= P.shotSpeed && strcmp(acts(a).role, 'ST')
                        state.shots(team) = state.shots(team) + 1;
                    end
                    kicked = true;
                end
            else
                cmds(i,:) = goToPose(robots(i), acts(a).target, acts(a).heading, ...
                    robots, i, ball, false, P);
            end
        end
    end

    % 3-5. models, contacts, rules
    robots = robotModel(robots, cmds, P);
    if playing
        ball = ballModel(ball, P);
    end
    [robots, ball, state] = collisions(robots, ball, state, playing, P);
    if playing
        if state.lastTouch > 0
            state.touchTime(state.lastTouch) = state.touchTime(state.lastTouch) + P.dt;
        end
        [robots, ball, state] = rulesCheck(robots, ball, state, P);
    end

    % 6. drawing
    if mod(step, P.drawEvery) == 0
        if ~isvalid(h.ax), disp('Window closed - simulation stopped.'); break; end
        updateGraphics(h, robots, ball, state, P);
        drawnow limitrate;
        if P.realtime
            lag = state.t - toc;
            if lag > 0, pause(lag); end
        end
    end
end

poss = 100 * state.touchTime / max(sum(state.touchTime), eps);
fprintf('\nFull time: Blue %d - %d Red\n', state.score(1), state.score(2));
fprintf('Shots:      Blue %d - %d Red\n', state.shots(1), state.shots(2));
fprintf('Possession: Blue %.0f%% - %.0f%% Red (by last touch)\n', poss(1), poss(2));
