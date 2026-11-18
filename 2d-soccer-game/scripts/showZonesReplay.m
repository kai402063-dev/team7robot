function showZonesReplay(source, speed, videoFile)
%SHOWZONESREPLAY (F4/Yu demo) Replay a saved match with the 8 zones drawn on it.
%   showZonesReplay()                 newest build/animation-*/trace.mat
%   showZonesReplay(folderOrFile)     a given recording
%   showZonesReplay(source, speed)    playback speed, default 2 (x real time)
%   showZonesReplay(source, speed, 'demo.mp4')  export an MP4 instead of a window
%
%   Display only: it reads a saved trace and changes nothing. The zone the
%   ball is in lights up (blue team frame; red id = 9 - blue id). The panel
%   shows the blue and red zone ids with the 0.20 m hysteresis, the raw id
%   without hysteresis, the half used for Qin's statistics and whether the
%   ball is inside the +-0.15 m switch band. The counters at the bottom show
%   how many times the zone id changed with and without hysteresis.
%   Each team's DF block point is drawn twice (display only, the match is
%   not changed): hollow circle = V1 formula, filled diamond =
%   tdp.goalSideBlock. When the ball is close to a goal the circle jumps in
%   front of the ball and the diamond stays between ball and goal (6.3).
%   Keys: space = pause/resume, left/right = step back/forward 1 s, q = quit.

if nargin < 1 || isempty(source)
    root = fileparts(fileparts(mfilename('fullpath')));
    runs = dir(fullfile(root, 'build', 'animation-*', 'trace.mat'));
    if isempty(runs)
        error('No saved match found. Run start_2d once first, then try again.');
    end
    [~, k] = max([runs.datenum]);
    source = fullfile(runs(k).folder, runs(k).name);
end
if nargin < 2 || isempty(speed), speed = 2; end
if nargin < 3, videoFile = ''; end

rec = loadReplayRecording(source);
P = rec.P;  tr = rec.Trace;  c = replayColumns();
n = size(tr, 1);
bx = tr(:, c.ballX);  by = tr(:, c.ballY);
paused = tr(:, c.time) < tr(:, c.pauseUntil);

% ---------- precompute zones and halves for every frame ----------
Z = tdp.spatialZones(P);
raw = tdp.spatialZone(bx, by, 1, P);
zb = zeros(n, 1);  zr = zeros(n, 1);  pb = 0;  pr = 0;
for k = 1:n
    if paused(k), pb = 0; pr = 0; end          % a restart forgets the old zone
    pb = tdp.spatialZone(bx(k), by(k), 1, P, pb);  zb(k) = pb;
    pr = tdp.spatialZone(bx(k), by(k), 2, P, pr);  zr(k) = pr;
end
[half, ~, band] = tdp.ballHalf(bx, by, paused, P);
H = tdp.halfCodes();
live = ~paused;
rawChanges = cumsum([0; diff(raw) ~= 0 & live(2:end) & live(1:end-1)]);
hysChanges = cumsum([0; diff(zb)  ~= 0 & live(2:end) & live(1:end-1)]);

% ---------- figure ----------
font = 'Microsoft YaHei';
fig = figure('Name', 'Yu - 空间分区回放', 'Color', [.06 .08 .1], ...
    'NumberTitle', 'off', 'Position', [80 80 1400 720], 'KeyPressFcn', @onKey);
setappdata(fig, 'paused', false);  setappdata(fig, 'jump', 0);
ax = axes(fig, 'Position', [.02 .06 .68 .9]);
hold(ax, 'on');  axis(ax, 'equal');  axis(ax, 'off');
xlim(ax, [-P.L/2 - P.border, P.L/2 + P.border]);
ylim(ax, [-P.W/2 - .6, P.W/2 + .6]);
rectangle(ax, 'Position', [-P.L/2-P.border, -P.W/2-.6, P.L+2*P.border, P.W+1.2], ...
    'FaceColor', [.075 .23 .18], 'EdgeColor', 'none');

% zone colours: own half (blue's) cool, opponent half warm
cols = [ .20 .45 .95; .30 .60 .95; .35 .75 .85; .45 .80 .55;
         .85 .80 .35; .95 .65 .35; .95 .50 .40; .95 .35 .45];
hz = gobjects(8, 1);
for k = [3 4 5 6 2 7 1 8]          % big ones first, nested areas on top
    r = Z.rect(k, :);
    hz(k) = patch(ax, r([1 2 2 1]), r([3 3 4 4]), cols(k, :), ...
        'FaceAlpha', .18, 'EdgeColor', 'w', 'LineWidth', .8);
end
for k = 1:8
    r = Z.rect(k, :);
    cx = mean(r(1:2));  cy = r(4) - .25;
    if k == 3 || k == 6, cy = P.W/2 - .25; end
    if k == 2 || k == 7, cy = r(4) - .25; end
    text(ax, cx, cy, sprintf('蓝%d / 红%d', k, 9-k), 'Color', 'w', ...
        'FontName', font, 'FontSize', 9, 'HorizontalAlignment', 'center');
end
% pitch lines on top
plot(ax, [0 0], [-P.W/2 P.W/2], 'w-', 'LineWidth', 1.4);
th = linspace(0, 2*pi, 60);
plot(ax, P.centreD/2*cos(th), P.centreD/2*sin(th), 'w-');
rectangle(ax, 'Position', [-P.L/2 -P.W/2 P.L P.W], 'EdgeColor', 'w', 'LineWidth', 1.5);
for s = [-1 1]
    left = s*P.L/2 - P.goalD;  if s > 0, left = s*P.L/2; end
    gc = [.25 .57 1];  if s > 0, gc = [1 .4 .43]; end
    rectangle(ax, 'Position', [left -P.goalW/2 P.goalD P.goalW], 'EdgeColor', gc, 'LineWidth', 2.5);
end
% +-0.15 m switch band
patch(ax, P.v1MidlineBand*[-1 1 1 -1], P.W/2*[-1 -1 1 1], [1 1 1], ...
    'FaceAlpha', .10, 'EdgeColor', [1 1 1]*.8, 'LineStyle', ':');
text(ax, 0, -P.W/2 - .3, '±0.15 m 切换带', 'Color', [.85 .85 .85], ...
    'FontName', font, 'FontSize', 9, 'HorizontalAlignment', 'center');
text(ax, -P.L/2, P.W/2 + .35, '← 蓝队球门（蓝队往 +x 进攻）', 'Color', [.5 .7 1], 'FontName', font, 'FontSize', 10);
text(ax, P.L/2, P.W/2 + .35, '红队球门 →', 'Color', [1 .55 .6], 'FontName', font, ...
    'FontSize', 10, 'HorizontalAlignment', 'right');

% robots and ball
hr = gobjects(8, 1);  hh = gobjects(8, 1);  hn = gobjects(8, 1);
roleNames = {'GK','DF','MF','ST'};
for i = 1:8
    fc = [.2 .45 1];  if i > 4, fc = [1 .3 .35]; end
    hr(i) = rectangle(ax, 'Position', [0 0 2*P.robotR 2*P.robotR], 'Curvature', [1 1], ...
        'FaceColor', fc, 'EdgeColor', 'w');
    hh(i) = plot(ax, [0 0], [0 0], 'w-', 'LineWidth', 1.5);
    hn(i) = text(ax, 0, 0, roleNames{mod(i-1,4)+1}, 'Color', 'w', 'FontSize', 7, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center');
end
hb = rectangle(ax, 'Position', [0 0 2*P.ballR 2*P.ballR], 'Curvature', [1 1], ...
    'FaceColor', [1 .6 .1], 'EdgeColor', 'k', 'LineWidth', 1.2);
trail = plot(ax, nan, nan, '-', 'Color', [1 .7 .2 .5], 'LineWidth', 1);
% DF block points (handoff 6.3): hollow = V1 formula, filled = tdp.goalSideBlock
dfCol = [.45 .7 1; 1 .55 .6];
hOld = gobjects(2, 1);  hNew = gobjects(2, 1);  hLink = gobjects(2, 1);
for tm = 1:2
    hLink(tm) = plot(ax, nan, nan, ':', 'Color', dfCol(tm, :), 'LineWidth', 1);
    hOld(tm) = plot(ax, nan, nan, 'o', 'MarkerSize', 11, 'LineWidth', 1.6, 'Color', dfCol(tm, :));
    hNew(tm) = plot(ax, nan, nan, 'd', 'MarkerSize', 8, 'MarkerFaceColor', dfCol(tm, :), 'MarkerEdgeColor', 'w');
end
text(ax, P.L/2 + P.border, -P.W/2 - .3, 'DF 阻挡点：○ V1 公式   ◆ goalSideBlock 修正', ...
    'Color', [.85 .85 .85], 'FontName', font, 'FontSize', 9, 'HorizontalAlignment', 'right');

% side panel
pan = axes(fig, 'Position', [.72 .06 .27 .9], 'Visible', 'off');
xlim(pan, [0 1]);  ylim(pan, [0 1]);
txt = text(pan, 0, .98, '', 'Color', 'w', 'FontName', font, 'FontSize', 12, ...
    'VerticalAlignment', 'top', 'Interpreter', 'none');
text(pan, 0, .06, sprintf(['空格 暂停/继续   ←/→ 跳 1 秒   q 退出\n' ...
    '回放速度 %gx    记录：%s'], speed, shortName(rec.File)), ...
    'Color', [.6 .6 .6], 'FontName', font, 'FontSize', 9, 'Interpreter', 'none');

% ---------- playback ----------
if ~isempty(videoFile)
    % Export mode: render every step-th frame into an MP4 (no window needed).
    set(fig, 'Visible', 'off');
    vw = VideoWriter(videoFile, 'MPEG-4');
    vw.FrameRate = round(speed/P.dt/max(1, round(speed)));
    vw.Quality = 90;
    open(vw);  cleanup = onCleanup(@() close(vw));
    for k = 1:max(1, round(speed)):n
        draw(k);  drawnow;
        writeVideo(vw, getframe(fig));
    end
    clear cleanup;  close(fig);
    disp(['Saved ' videoFile]);
    return
end
k = 1;  step = max(1, round(speed));     % frames per redraw
while ishandle(fig) && k <= n
    jump = getappdata(fig, 'jump');
    if jump ~= 0
        k = min(max(1, k + round(jump/P.dt)), n);  setappdata(fig, 'jump', 0);
        draw(k);  drawnow;
    end
    if getappdata(fig, 'paused'), pause(.05); continue; end
    draw(k);
    drawnow limitrate;
    k = k + step;
    pause(step*P.dt/speed);
end
if ishandle(fig), draw(n); end

    function draw(k)
        row = tr(k, :);
        for i = 1:8
            x = row(c.x(i));  y = row(c.y(i));  a = row(c.th(i));
            set(hr(i), 'Position', [x-P.robotR, y-P.robotR, 2*P.robotR, 2*P.robotR]);
            set(hh(i), 'XData', [x x+.22*cos(a)], 'YData', [y y+.22*sin(a)]);
            set(hn(i), 'Position', [x, y-.27, 0]);
        end
        set(hb, 'Position', [bx(k)-P.ballR, by(k)-P.ballR, 2*P.ballR, 2*P.ballR]);
        k0 = max(1, k - round(2/P.dt));
        set(trail, 'XData', bx(k0:k), 'YData', by(k0:k));
        for j = 1:8
            on = zb(k) == j;
            set(hz(j), 'FaceAlpha', .18 + .42*on, 'LineWidth', .8 + 2.2*on);
        end
        if zb(k) > 0, nb = Z.names{zb(k)}; else, nb = 'OffPitch（出界）'; end
        if zr(k) > 0, nr = Z.names{zr(k)}; else, nr = 'OffPitch（出界）'; end
        state = '比赛进行中';  if paused(k), state = '暂停（进球/出界后重新开球）'; end
        flag = '';
        if raw(k) ~= zb(k) && ~paused(k), flag = '  ← 防抖保持中'; end
        bandTxt = '否';  if band(k), bandTxt = '是（战术可能仍保持上一个攻防状态）'; end
        ahead = {'', ''};
        for tm = 1:2
            [bNew, bOld] = tdp.goalSideBlock([bx(k) by(k)], tm, P.defDist, P);
            set(hOld(tm), 'XData', bOld(1), 'YData', bOld(2));
            set(hNew(tm), 'XData', bNew(1), 'YData', bNew(2));
            set(hLink(tm), 'XData', [bOld(1) bNew(1)], 'YData', [bOld(2) bNew(2)]);
            g = [-P.dirSign(tm)*P.L/2 0];
            if hypot(bOld(1)-g(1), bOld(2)-g(2)) > hypot(bx(k)-g(1), by(k)-g(2)) && ~paused(k)
                ahead{tm} = '在球前方 ✗ → 修正点在门侧';
            else
                ahead{tm} = '正常';
            end
        end
        lines = { ...
            sprintf('时间  %.1f s      比分  蓝 %d : %d 红', row(c.time), row(c.score(1)), row(c.score(2)))
            sprintf('状态  %s', state)
            ''
            sprintf('球的位置  x = %+.2f   y = %+.2f', bx(k), by(k))
            ''
            '【区域编号  spatialZone】'
            sprintf('蓝队视角  %d  %s', zb(k), nb)
            sprintf('红队视角  %d  %s', zr(k), nr)
            sprintf('不带防抖  %d%s', raw(k), flag)
            ''
            '【半场统计  ballHalf】'
            sprintf('半场  %s', H.names{half(k)+1})
            sprintf('在 ±0.15 m 切换带内  %s', bandTxt)
            ''
            '【区号变化次数（到当前为止）】'
            sprintf('不带防抖  %d 次', rawChanges(k))
            sprintf('带 0.20 m 防抖  %d 次', hysChanges(k))
            sprintf('防抖减少了  %d 次无意义的跳变', rawChanges(k) - hysChanges(k))
            ''
            '【DF 阻挡点  goalSideBlock】'
            sprintf('蓝队 V1 点  %s', ahead{1})
            sprintf('红队 V1 点  %s', ahead{2})};
        set(txt, 'String', strjoin(lines, newline));
    end

    function onKey(~, e)
        switch e.Key
            case 'space', setappdata(fig, 'paused', ~getappdata(fig, 'paused'));
            case 'rightarrow', setappdata(fig, 'jump', 1);
            case 'leftarrow', setappdata(fig, 'jump', -1);
            case 'q', close(fig);
        end
    end
end

function s = shortName(file)
[p, ~] = fileparts(file);  [~, s] = fileparts(p);
end
