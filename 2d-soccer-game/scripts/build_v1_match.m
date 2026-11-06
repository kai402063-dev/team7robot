function build_v1_match()
%BUILD_V1_MATCH Generate the V1 team-state dictionary and eight-robot model.
root=tdpSetup();
if bdIsLoaded('tdpV1Match'),close_system('tdpV1Match',0);end
file=fullfile(root,'models','TdpV1Types.sldd');
if isfile(file)
    dictionary=Simulink.data.dictionary.open(file);
else
    dictionary=Simulink.data.dictionary.create(file);
    addDataSource(dictionary,'TdpTypes.sldd');
end
section=getSection(dictionary,'Design Data');
state=tdp.v1TeamMemory();
fields=fieldnames(state);
elements=Simulink.BusElement.empty;
for i=1:numel(fields)
    field=fields{i};
    value=state.(field);
    element=Simulink.BusElement;
    element.Name=field;
    element.Dimensions=size(value);
    if isenum(value)
        element.DataType=['Enum: ' class(value)];
    elseif islogical(value)
        element.DataType='boolean';
    else
        element.DataType=class(value);
    end
    elements(i)=element;
end
bus=Simulink.Bus;
bus.Elements=elements;
if exist(section,'V1TeamBus')
    setValue(getEntry(section,'V1TeamBus'),bus);
else
    addEntry(section,'V1TeamBus',bus);
end
saveChanges(dictionary);close(dictionary);
build_match('tdpV1Match');
end
