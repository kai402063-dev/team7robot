function [records,quality]=runFrameReplay(P,frames,online)
%RUNFRAMEREPLAY Compare identical observation decoding and actual Core instances.
if nargin<3,online=false;end
if online,model='tdpRosProxy';else,model='tdpFrameReplay';end
cleanup=onCleanup(@()BridgeSocket('close',[])); %#ok<NASGU>
s=Simulink.SimulationInput(model);s=s.setVariable('P',P,'Workspace',model);
s=s.setVariable('frames',frames,'Workspace',model);
s=s.setModelParameter('StopTime',num2str((size(frames,1)-1)*P.dt,17));
out=sim(s);records=recordRows(out.records);quality=recordRows(out.quality);
end
