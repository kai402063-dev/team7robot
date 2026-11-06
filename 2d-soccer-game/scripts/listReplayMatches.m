function matches = listReplayMatches(buildDirectory)
%LISTREPLAYMATCHES Find finished recordings in this project's build directory.
matches = struct('file', {}, 'label', {}, 'status', {});
if ~isfolder(buildDirectory)
    return
end
folders = dir(buildDirectory);
sortKeys = {};
for folder = folders([folders.isdir])'
    stamp = regexp(folder.name, ...
        '^(?:animation|run)-(\d{8}-\d{6}-\d{3})(?:-\d+)?$', 'tokens', 'once');
    if isempty(stamp)
        continue
    end
    directory = fullfile(folder.folder, folder.name);
    try
        match = readMatch(directory, stamp{1});
    catch
        % A malformed receipt or unreadable MAT file must not hide other runs.
        continue
    end
    if ~isempty(match)
        matches(end+1) = match; %#ok<AGROW>
        sortKeys{end+1} = stamp{1}; %#ok<AGROW>
    end
end
[~, order] = sort(sortKeys, 'descend');
matches = matches(order);
end

function match = readMatch(directory, stamp)
match = [];
file = fullfile(directory, 'trace.mat');
receiptFile = fullfile(directory, 'receipt.json');
if ~isfile(file) || ~isfile(receiptFile)
    return
end
receipt = jsondecode(fileread(receiptFile));
switch receipt.status
    case 'COMPLETED'
        state = '已完赛';
    case 'STOPPED_BY_USER'
        state = '提前停止';
    otherwise
        return
end

% Both LiveViewer2D and tdpRun store these metrics for the recorded steps.
steps = receipt.metrics.steps;
dt = receipt.parameters.dt;
goals = receipt.metrics.goals;
validateattributes(steps, {'numeric'}, {'scalar','positive','finite','integer'});
validateattributes(dt, {'numeric'}, {'scalar','positive','finite'});
validateattributes(goals, {'numeric'}, {'numel',2,'nonnegative','integer','finite'});
if ~receipt.metrics.finite
    return
end
info = whos('-file', file, 'P', 'trace');
params = info(strcmp({info.name}, 'P'));
trace = info(strcmp({info.name}, 'trace'));
if isempty(params) || ~strcmp(params.class, 'struct') || ~isequal(params.size, [1 1]) || ...
        isempty(trace) || ~strcmp(trace.class, 'double') || ~isequal(trace.size, [steps 98])
    return
end
started = datetime(stamp, 'InputFormat', 'yyyyMMdd-HHmmss-SSS', ...
    'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
seconds = round(steps * dt, 2);
label = sprintf('%s    蓝 %d : %d 红    %02d:%05.2f    %s', ...
    char(started), goals(1), goals(2), floor(seconds/60), mod(seconds,60), state);
match = struct('file', file, 'label', label, 'status', receipt.status);
end
