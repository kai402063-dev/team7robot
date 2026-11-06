function memory=ObservationHistory(P)
%OBSERVATIONHISTORY Initialize a fixed 21-sample channel with invalid entries.
T=tdpTemplates(P);empty=T.Observation;empty.robotValid(:)=false;empty.ballValid=false;empty.selfValid=false;
memory=repmat(empty,1,21);
end
