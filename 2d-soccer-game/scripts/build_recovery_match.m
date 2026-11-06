function build_recovery_match()
%BUILD_RECOVERY_MATCH Create only the opt-in recovery dictionary and model.
root=tdpSetup();
if bdIsLoaded('tdpRecoveryMatch'),close_system('tdpRecoveryMatch',0);end
file=fullfile(root,'models','TdpRecoveryTypes.sldd');
if isfile(file)
    dictionary=Simulink.data.dictionary.open(file);
else
    dictionary=Simulink.data.dictionary.create(file);
    addDataSource(dictionary,'TdpTypes.sldd');
end
section=getSection(dictionary,'Design Data');
writeBus(section,'RecoveryTeamBus',tdp.recoveryTeamMemory());
writeBus(section,'V1HealthBus',tdp.v1Health());
saveChanges(dictionary);close(dictionary);
build_match('tdpRecoveryMatch');
end

function writeBus(section,name,values)
fields=fieldnames(values);
elements=Simulink.BusElement.empty;
for i=1:numel(fields)
    field=fields{i};
    value=values.(field);
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
if exist(section,name)
    setValue(getEntry(section,name),bus);
else
    addEntry(section,name,bus);
end
end
