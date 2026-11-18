function [id, f, lat] = spatialZone(x, y, team, P, prevId, margin)
%   [id, f, lat] = tdp.spatialZone(x, y, team, P)
%   [id, f, lat] = tdp.spatialZone(x, y, team, P, prevId)
%   [id, f, lat] = tdp.spatialZone(x, y, team, P, prevId, margin)
%
%   x, y    world position(s) of the BALL CENTRE or a robot centre (arrays ok)
%   team    1 blue or 2 red; the answer is in that team's frame, so
%           spatialZone(x,y,1) == spatialZone(-x,-y,2) always.
%   prevId  last id of the same object (scalar or same size), 0/[] = none.
%           Hysteresis: the old zone is kept while the point is no more
%           than P.zoneHysteresis (default 0.20 m) from that zone. To enter
%           a neighbour the point must therefore go 0.20 m past the line,
%           and the same 0.20 m back to return: separate enter and exit
%           thresholds with a 0.40 m band, centred on the marked line.
%   margin  how far outside the pitch lines a point is still clamped onto
%           the pitch. Default P.ballR: a ball that only partly crosses a
%           line is still in play (same rule as Referee2D). Beyond that the
%           id is 0 (OffPitch: out, a goal, or waiting for the restart).
%           Use margin = Inf for robots, which may stand in the 1 m border.
%   f, lat  team-frame coordinates (before clamping).
%
%   Independent of tactics: only geometry from P is used.

if nargin < 5 || isempty(prevId), prevId = 0; end
if nargin < 6 || isempty(margin), margin = P.ballR; end
hyst = 0.20;
if isfield(P,'zoneHysteresis'), hyst = P.zoneHysteresis; end

s = P.dirSign(team);
f = s.*x;
lat = s.*y;
h = P.L/2;  w = P.W/2;
off = ~isfinite(f) | ~isfinite(lat) | abs(f) > h + margin | abs(lat) > w + margin;
fc = min(max(f, -h), h);
lc = min(max(lat, -w), w);

Z = tdp.spatialZones(P);
id = rawZone(fc, lc, Z);

if any(prevId(:) ~= 0) && hyst > 0
    if isscalar(prevId), prevId = repmat(prevId, size(id)); end
    for k = 1:8
        sel = prevId == k & id ~= k & ~off;
        if any(sel(:))
            d = regionDistance(fc(sel), lc(sel), Z.rect(k,:), Z.rect(max(Z.hole(k),1),:), Z.hole(k) > 0);
            keep = false(size(id));
            keep(sel) = d <= hyst + 1e-12;
            id(keep) = k;
        end
    end
end
id(off) = 0;
end

function id = rawZone(f, lat, Z)
R = Z.rect;
id = 6*ones(size(f));
id(f <= R(5,2)) = 5;
id(f <= R(4,2)) = 4;
id(f <= R(3,2)) = 3;
id(inRect(f, lat, R(7,:))) = 7;
id(inRect(f, lat, R(8,:))) = 8;
id(inRect(f, lat, R(2,:))) = 2;
id(inRect(f, lat, R(1,:))) = 1;
end

function in = inRect(f, lat, r)
in = f >= r(1) & f <= r(2) & lat >= r(3) & lat <= r(4);
end

function d = regionDistance(f, lat, r, hole, hasHole)
% Distance from each point to the region "rectangle r minus rectangle hole".
dx = max(max(r(1) - f, 0), f - r(2));
dy = max(max(r(3) - lat, 0), lat - r(4));
d = hypot(dx, dy);
if ~hasHole, return; end
inside = inRect(f, lat, hole);
if ~any(inside), return; end
% Inside the hole: distance to the nearest hole side that lies inside r.
fi = f(inside); li = lat(inside);
e = inf(size(fi));          % same shape as fi (codegen-safe in Simulink)
if hole(1) > r(1), e = min(e, fi - hole(1)); end
if hole(2) < r(2), e = min(e, hole(2) - fi); end
if hole(3) > r(3), e = min(e, li - hole(3)); end
if hole(4) < r(4), e = min(e, hole(4) - li); end
d(inside) = e;
end
