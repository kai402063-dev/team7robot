function robots = robotModel(robots, cmds, P)
%ROBOTMODEL  (WP A) Omnidirectional walking model with NAO6-like limits.
%   cmds(k,:) = [vx vy w] in the robot body frame.
xlim_ = P.L/2 + P.border - P.robotR;
ylim_ = P.W/2 + P.border - P.robotR;
for k = 1:numel(robots)
    vx = cmds(k,1); vy = cmds(k,2); w = cmds(k,3);
    % speed limits (forward/backward/sideways ellipse)
    vx = min(max(vx, -P.vBack), P.vFwd);
    vy = min(max(vy, -P.vSide), P.vSide);
    if vx >= 0, vxl = P.vFwd; else, vxl = P.vBack; end
    m = sqrt((vx/vxl)^2 + (vy/P.vSide)^2);
    if m > 1, vx = vx/m; vy = vy/m; end
    w = min(max(w, -P.wMax), P.wMax);

    th = robots(k).th;
    vxw = cos(th)*vx - sin(th)*vy;
    vyw = sin(th)*vx + cos(th)*vy;
    robots(k).x  = min(max(robots(k).x + vxw*P.dt, -xlim_), xlim_);
    robots(k).y  = min(max(robots(k).y + vyw*P.dt, -ylim_), ylim_);
    robots(k).th = angWrap(th + w*P.dt);
    robots(k).vxw = vxw; robots(k).vyw = vyw;
    robots(k).cool = max(0, robots(k).cool - P.dt);
end
end
