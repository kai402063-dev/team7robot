function m=matchMetrics(trace,P)
%MATCHMETRICS Report geometry violations separately from command suppression.
N=size(trace,1);overlapSteps=0;overlapPairs=0;maxPenetration=0;
outsidePitch=0;outsideBorder=0;requested=0;blocked=0;
[r,~,~]=tdp.initialState(P);oldX=[r.x];oldY=[r.y];
firstTouch=NaN;
for k=1:N
 x=trace(k,1:8);y=trace(k,9:16);anyOverlap=false;
 for i=1:7,for j=i+1:8
  p=2*P.robotR-hypot(x(i)-x(j),y(i)-y(j));
  if p>1e-8,overlapPairs=overlapPairs+1;anyOverlap=true;maxPenetration=max(maxPenetration,p);end
 end,end
 overlapSteps=overlapSteps+anyOverlap;
 outsidePitch=outsidePitch+sum(abs(x)+P.robotR>P.L/2+1e-8 | abs(y)+P.robotR>P.W/2+1e-8);
 outsideBorder=outsideBorder+sum(abs(x)+P.robotR>P.L/2+P.border+1e-8 | abs(y)+P.robotR>P.W/2+P.border+1e-8);
 asks=hypot(trace(k,73:80),trace(k,81:88))>1e-10;
 moved=hypot(x-oldX,y-oldY)>1e-10;requested=requested+sum(asks);blocked=blocked+sum(asks & ~moved);
 if isnan(firstTouch) && trace(k,64)>0,firstTouch=trace(k,61);end
 oldX=x;oldY=y;
end
m=struct('goals',trace(end,62:63),'shots',trace(end,66:67),'firstTouchSeconds',firstTouch, ...
 'steps',N,'overlapSteps',overlapSteps,'overlapPairSamples',overlapPairs,'maximumPenetrationMetres',maxPenetration, ...
 'outsidePitchRobotSamples',outsidePitch,'outsideBorderRobotSamples',outsideBorder, ...
 'translationRequests',requested,'blockedTranslationSamples',blocked,'blockedTranslationRatio',blocked/max(1,requested), ...
 'finite',all(isfinite(trace),'all'));
end
