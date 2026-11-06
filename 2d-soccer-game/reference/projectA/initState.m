function [robots, ball, state] = initState(P)
%INITSTATE  Create the two teams, the ball and the match state.
k = 0;
for team = 1:2
    for n = 1:P.nPerTeam
        k = k + 1;
        robots(k).team  = team;          %#ok<AGROW>
        robots(k).num   = n;
        robots(k).isGK  = (n == 1);      % player 1 is the goalkeeper
        robots(k).role  = '';
        robots(k).x = 0; robots(k).y = 0; robots(k).th = 0;
        robots(k).vxw = 0; robots(k).vyw = 0;   % world velocity
        robots(k).cool = 0;                      % kick cooldown timer
    end
end
ball  = struct('x', 0, 'y', 0, 'vx', 0, 'vy', 0);
state = struct('t', 0, 'score', [0 0], 'lastTouch', 0, ...
               'pauseUntil', 0, 'msg', 'Kick-off', 'msgUntil', 2, ...
               'shots', [0 0], 'touchTime', [0 0]);
[robots, ball] = kickoffReset(robots, ball, P);
end
