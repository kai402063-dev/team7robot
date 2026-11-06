function chart=add_matlab_block(path,script,position,types)
%ADD_MATLAB_BLOCK Build an EML block and annotate explicit bus boundaries.
add_block('simulink/User-Defined Functions/MATLAB Function',path,'Position',position);
chart=find(sfroot,'-isa','Stateflow.EMChart','Path',path);chart.Script=script;
if nargin>3
 for k=1:size(types,1)
  d=find(chart,'-isa','Stateflow.Data','Name',types{k,1});d.DataType=types{k,2};
  if size(types,2)>2 && ~isempty(types{k,3}),d.Scope=types{k,3};end
 end
end
end
