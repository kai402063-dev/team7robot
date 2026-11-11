function v=v11FallbackMemory()
%V11FALLBACKMEMORY Initial per-team state of the V1.1 fallback monitor.
% v(1)    consecutive matched ST kick failures since the last success
% v(2)    tSim from which ST has been continuously stable in takeover; -1 = unset
% v(3:10) stamps of the most recent failures, newest last (v11FailCount <= 8)
v=[0 -1 zeros(1,8)];
end
