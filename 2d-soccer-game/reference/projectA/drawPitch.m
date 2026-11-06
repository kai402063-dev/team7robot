function ax = drawPitch(P)
%DRAWPITCH  (WP B) Draw the KidSize pitch from Table 1 of the spec.
fig = figure('Name', 'ENG5325 RoboCup 2D Simulation', 'Color', 'w');
ax = axes(fig);  hold(ax, 'on');  axis(ax, 'equal');
L = P.L; W = P.W; b = P.border;
xlim(ax, [-L/2-b, L/2+b]);  ylim(ax, [-W/2-b, W/2+b]);
set(ax, 'Color', [0.13 0.55 0.13], 'XColor', 'none', 'YColor', 'none');
lw = 2; c = 'w';
rectangle(ax, 'Position', [-L/2-b, -W/2-b, L+2*b, W+2*b], ...
          'FaceColor', [0.13 0.55 0.13], 'EdgeColor', 'none');
rectangle(ax, 'Position', [-L/2, -W/2, L, W], 'EdgeColor', c, 'LineWidth', lw);
plot(ax, [0 0], [-W/2 W/2], c, 'LineWidth', lw);                       % halfway line
rectangle(ax, 'Position', [-P.centreD/2, -P.centreD/2, P.centreD, P.centreD], ...
          'Curvature', [1 1], 'EdgeColor', c, 'LineWidth', lw);           % centre circle
plot(ax, 0, 0, 'w+', 'MarkerSize', 8, 'LineWidth', lw);
for s = [-1 1]
    xg = s*L/2;
    % goal area and penalty area
    rectangle(ax, 'Position', [min(xg, xg - s*P.goalAreaL), -P.goalAreaW/2, P.goalAreaL, P.goalAreaW], ...
              'EdgeColor', c, 'LineWidth', lw);
    rectangle(ax, 'Position', [min(xg, xg - s*P.penAreaL), -P.penAreaW/2, P.penAreaL, P.penAreaW], ...
              'EdgeColor', c, 'LineWidth', lw);
    plot(ax, xg - s*P.penMark, 0, 'w+', 'MarkerSize', 8, 'LineWidth', lw); % penalty mark
    % goal (blue defends -x, red defends +x)
    if s < 0, gc = [0.2 0.4 1]; else, gc = [0.9 0.2 0.2]; end
    rectangle(ax, 'Position', [min(xg, xg + s*P.goalD), -P.goalW/2, P.goalD, P.goalW], ...
              'FaceColor', [0.85 0.85 0.85], 'EdgeColor', gc, 'LineWidth', 3);
end
end
