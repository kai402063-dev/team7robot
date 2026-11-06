function P=recoveryConfig()
%RECOVERYCONFIG Opt in to the automatic striker handback experiment.
P=tdp.v1Config();
P.v1AutoRecovery=true;
P.v1RecoveryHealthySeconds=0.50;
P.v1HealthDropWindow=zeros(8,2);
end
