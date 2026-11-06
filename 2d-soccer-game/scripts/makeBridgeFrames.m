function frames=makeBridgeFrames(P,N)
%MAKEBRIDGEFRAMES Canonical recorded observation stream with dropouts and age.
frames=zeros(N,20);
for k=1:N
 t=round((k-1)*P.dt*1e9)/1e9;x=-max(0.2,0.5-0.012*(k-1));
 frames(k,:)=[1 t t x 0 0 1 0 0 0 0 1 t 1 0 0 t 0.3 0.07 k];
end
if N>=80
 frames(20:22,20)=19;frames(30:34,12)=0;frames(40:43,14)=0;
 frames(50:55,3)=frames(50:55,2)-1;frames(65:68,3)=frames(65:68,2)+0.1;
 frames(75:80,16)=1;frames(75:80,15)=6;
end
end
