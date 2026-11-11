function P=v11FallbackConfig()
%V11FALLBACKCONFIG Opt in to the V1.1 striker-fallback proposal (section 6(d), T7).
% Draft v1.1 is a team PROPOSAL pending approval. Only trigger (d) "repeated
% action failure" and the T7 hand-back are modelled; triggers (a)-(c), the
% chaser token and the parallel FALLBACK region are not. Without these fields
% the approved V1 coordinator runs unchanged.
P=tdp.v1Config();
P.v11Fallback=true;
P.v11FailCount=3;        % N_fail: consecutive matched ST kick failures
P.v11FailWindow=20;      % T_fail_win (s): span of the last N_fail failures
P.v11RecoverSeconds=3.0; % T_recover (s): ST stable before hand-back
end
