function updateGraphics(h, robots, ball, state, P)
%UPDATEGRAPHICS  Move the robot and ball graphics to the current state.
for k = 1:numel(robots)
    r = robots(k);
    set(h.body(k), 'XData', r.x + P.robotR*h.cx, 'YData', r.y + P.robotR*h.cy);
    set(h.head(k), 'XData', r.x + [0 1.6*P.robotR*cos(r.th)], ...
                   'YData', r.y + [0 1.6*P.robotR*sin(r.th)]);
    set(h.lbl(k), 'Position', [r.x, r.y - 1.9*P.robotR, 0], ...
                  'String', sprintf('%d %s', r.num, r.role));
end
set(h.ball, 'XData', ball.x + P.ballR*h.cx, 'YData', ball.y + P.ballR*h.cy);
msg = '';
if state.t < state.msgUntil, msg = ['   ' state.msg]; end
set(h.title, 'String', sprintf('Blue %d - %d Red      t = %5.1f s%s', ...
    state.score(1), state.score(2), state.t, msg));
end
