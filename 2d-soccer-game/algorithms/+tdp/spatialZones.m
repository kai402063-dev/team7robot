function Z = spatialZones(P)
%SPATIALZONES (F4/Yu) Named pitch zones in the TEAM frame.
%   Z = tdp.spatialZones(P)
%   Team frame (same as v1TeamPlans / V1.2): f = dirSign(team)*x,
%   lat = dirSign(team)*y. Own goal line f = -L/2, midline f = 0, opponent
%   goal line f = +L/2. Red is the point mirror of blue, so ONE table serves
%   both teams. Every zone is built from a pitch marking or a third line:
%
%     id  name            region (team frame, default 9 x 6 pitch)
%     1   OwnGoalArea     f in [-4.5,-3.5], |lat| <= 1.5   (goal area)
%     2   OwnPenaltyArea  f in [-4.5,-2.5], |lat| <= 2.5   minus zone 1
%     3   OwnThird        f in [-4.5,-1.5], full width     minus zones 1-2
%     4   OwnMiddle       f in (-1.5, 0]                   own half of middle third
%     5   OppMiddle       f in ( 0, 1.5]
%     6   OppThird        f in ( 1.5, 4.5]                 minus zones 7-8
%     7   OppPenaltyArea  f in [ 2.5, 4.5], |lat| <= 2.5   minus zone 8
%     8   OppGoalArea     f in [ 3.5, 4.5], |lat| <= 1.5
%     0   OffPitch        outside the pitch (see tdp.spatialZone)
%
%   Tie rules on a line: a marked area owns its own lines (football rule);
%   the unmarked third lines and the midline belong to the zone nearer the
%   OWN goal. Ids grow from own goal to opponent goal, so "ball in zones
%   1..3" reads like the old "forward <= -1.5".
%
%   Fields: names (1x8), rect (8x4 [fMin fMax latMin latMax]),
%   hole (1x8, id of the zone cut out of this rectangle, 0 = none),
%   depthLines (team-frame f of every boundary across the pitch).

h = P.L/2;
w = P.W/2;
t = -h + P.L/3;                                  % own third line, -1.5 m
pa = [-h, -h + P.penAreaL, -P.penAreaW/2, P.penAreaW/2];
ga = [-h, -h + P.goalAreaL, -P.goalAreaW/2, P.goalAreaW/2];
Z.names = {'OwnGoalArea','OwnPenaltyArea','OwnThird','OwnMiddle', ...
           'OppMiddle','OppThird','OppPenaltyArea','OppGoalArea'};
Z.rect = [ga;
          pa;
          -h  t  -w w;
          t   0  -w w;
          0  -t  -w w;
          -t  h  -w w;
          -pa(2) h pa(3:4);
          -ga(2) h ga(3:4)];
Z.hole = [0 1 2 0 0 7 8 0];
Z.depthLines = sort([-h, ga(2), pa(2), t, 0, -t, -pa(2), -ga(2), h]);
end
