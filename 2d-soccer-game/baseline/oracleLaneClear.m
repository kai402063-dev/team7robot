function ok = oracleLaneClear(a, b, obstacles, margin)
% true if no obstacle is within margin of the segment a-b
ok = true;  ab = b - a;  L2 = dot(ab, ab);
if L2 < 1e-9, return; end
for k = 1:size(obstacles,1)
    t = min(max(dot(obstacles(k,:) - a, ab)/L2, 0), 1);
    if norm(a + t*ab - obstacles(k,:)) < margin
        ok = false; return
    end
end
end
