function h = initGraphics(P, robots, ball)
%INITGRAPHICS  Create the pitch and one graphics object per robot and ball.
h.ax = drawPitch(P);
t = linspace(0, 2*pi, 24);
h.cx = cos(t);  h.cy = sin(t);
teamCol = {[0.2 0.4 1], [0.9 0.2 0.2]};
for k = 1:numel(robots)
    col = teamCol{robots(k).team};
    if robots(k).isGK, col = 0.6*col; end
    h.body(k) = patch(h.ax, robots(k).x + P.robotR*h.cx, robots(k).y + P.robotR*h.cy, col, ...
                      'EdgeColor', 'k', 'LineWidth', 1);
    h.head(k) = plot(h.ax, [0 0], [0 0], 'k', 'LineWidth', 2);
    h.lbl(k)  = text(h.ax, 0, 0, '', 'FontSize', 8, 'FontWeight', 'bold', ...
                     'Color', 'w', 'HorizontalAlignment', 'center');
end
h.ball  = patch(h.ax, ball.x + P.ballR*h.cx, ball.y + P.ballR*h.cy, [1 0.5 0], ...
                'EdgeColor', 'k');
h.title = title(h.ax, '', 'FontSize', 13);
updateGraphics(h, robots, ball, struct('t',0,'score',[0 0],'msg','','msgUntil',0), P);
end
