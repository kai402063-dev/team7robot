function [robots, ball, state] = rulesCheck(robots, ball, state, P)
%RULESCHECK  (WP B) Goals and ball out of play.
%   Simplified restarts: goal -> kick-off; touchline -> kick-in;
%   goal line -> goal kick or corner depending on who touched it last.
if abs(ball.x) > P.L/2 + P.ballR        % whole ball over the goal line
    sx = sign(ball.x);
    attacker = 1 + (sx < 0);          % team attacking this end
    if abs(ball.y) < P.goalW/2
        state.score(attacker) = state.score(attacker) + 1;
        [robots, ball] = kickoffReset(robots, ball, P);
        state.pauseUntil = state.t + P.restartPause;
        state = setMsg(state, sprintf('GOAL! %s', teamName(attacker)), 2.5);
        return
    end
    sy = sign(ball.y); if sy == 0, sy = 1; end
    if state.lastTouch == attacker   % attacker put it out -> goal kick
        ball.x = sx*(P.L/2 - P.goalAreaL);  ball.y = sy*P.goalAreaW/2;
        state = setMsg(state, 'Goal kick', 1.5);
    else                             % defender put it out -> corner
        ball.x = sx*(P.L/2 - 0.25);  ball.y = sy*(P.W/2 - 0.25);
        state = setMsg(state, 'Corner', 1.5);
    end
    ball.vx = 0; ball.vy = 0;
    state.pauseUntil = state.t + P.outPause;
elseif abs(ball.y) > P.W/2 + P.ballR    % whole ball over the touchline
    ball.y = sign(ball.y)*(P.W/2 - 0.25);
    ball.x = min(max(ball.x, -P.L/2 + 0.25), P.L/2 - 0.25);
    ball.vx = 0; ball.vy = 0;
    state.pauseUntil = state.t + P.outPause;
    state = setMsg(state, 'Kick-in', 1.5);
end
end

function state = setMsg(state, msg, dur)
state.msg = msg;  state.msgUntil = state.t + dur;
end

function s = teamName(t)
if t == 1, s = 'Blue'; else, s = 'Red'; end
end
