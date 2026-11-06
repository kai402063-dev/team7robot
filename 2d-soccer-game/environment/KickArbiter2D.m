function observations=KickArbiter2D(observations,plans,tSim,P)
%KICKARBITER2D Preserve A's alternating priority and one kick per step.
order=1:8;if mod(round(tSim/P.dt),2)==0,order=[5:8 1:4];end
claimed=false;
for k=1:8
 i=order(k);observations(i).allowKick=~claimed;
 g=CoreGeometry(observations(i),plans(i),tSim,P);
 if g.ready,claimed=true;end
end
end
