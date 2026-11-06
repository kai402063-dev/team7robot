function build_types()
%BUILD_TYPES Generate fixed bus definitions without relying on a saved path.
root=tdpSetup();P=tdp.defaultConfig();T=tdpTemplates(P);
file=fullfile(root,'models','TdpTypes.sldd');
if isfile(file),delete(file);end
D=Simulink.data.dictionary.create(file);sec=getSection(D,'Design Data');
names=fieldnames(T);
for k=1:numel(names)
 name=names{k};value=T.(name);fields=fieldnames(value);elements=Simulink.BusElement.empty;
 for j=1:numel(fields)
  key=fields{j};v=value.(key);e=Simulink.BusElement;e.Name=key;e.Dimensions=size(v);
  if isstruct(v)
   mapping=struct('robots','Robot','ball','Ball','referee','Referee','feedback','Feedback','actuator','Actuator');
   e.DataType=['Bus: ' mapping.(key) 'Bus'];
  elseif isenum(v),e.DataType=['Enum: ' class(v)];
  elseif islogical(v),e.DataType='boolean';else,e.DataType=class(v);end
  elements(j)=e;
 end
 bus=Simulink.Bus;bus.Elements=elements;addEntry(sec,[name 'Bus'],bus);
end

saveChanges(D);close(D);
end
