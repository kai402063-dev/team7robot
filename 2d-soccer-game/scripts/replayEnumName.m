function name=replayEnumName(className,value)
%REPLAYENUMNAME Member name of a Tdp* enumeration for a logged numeric value.
% The trace stores enumerations as doubles. Names are read from the project's
% own enumeration classes so this file never keeps a second copy of them.
% An unknown class or value returns the number as text, never a guess.
persistent cache
if isempty(cache),cache=containers.Map('KeyType','char','ValueType','any');end
if ~isKey(cache,className)
    table=struct('values',[],'names',{{}});
    try
        [members,names]=enumeration(className);
        table.values=reshape(double(members),1,[]);
        table.names=reshape(names,1,[]);
    catch
        % Class not on the path: fall through to numeric text below.
    end
    cache(className)=table;
end
table=cache(className);
index=find(table.values==value,1);
if isempty(index)
    name=sprintf('%g',value);
else
    name=table.names{index};
end
end
