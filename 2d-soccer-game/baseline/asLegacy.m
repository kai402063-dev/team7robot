function value=asLegacy(value)
%ASLEGACY Test-only conversion of typed interfaces to original strings.
if isstruct(value)
 for k=1:numel(value)
  fields=fieldnames(value);
  for j=1:numel(fields),value(k).(fields{j})=asLegacy(value(k).(fields{j}));end
 end
elseif isa(value,'TdpRole')
 names={'','GK','ST','DF','SP'};value=names{double(value)+1};
elseif isa(value,'TdpAction')
 names={'stop','goto','kick','search','tap'};value=names{double(value)+1};
elseif isa(value,'TdpEvent')
 names={'','Kick-off','GOAL! Blue','GOAL! Red','Goal kick','Corner','Kick-in'};value=names{double(value)+1};
end
end
