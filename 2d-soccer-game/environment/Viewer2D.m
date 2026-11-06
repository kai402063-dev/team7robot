function fig=Viewer2D(trace,index,P,file)
%VIEWER2D Render a logged state without affecting control or physics.
if nargin<2,index=size(trace,1);end
if nargin<3,P=tdp.defaultConfig();end
fig=figure('Visible','off','Color','w');ax=axes(fig);hold(ax,'on');axis(ax,'equal');
rectangle(ax,'Position',[-P.L/2 -P.W/2 P.L P.W],'FaceColor',[.2 .55 .3],'EdgeColor','k');
plot(ax,[0 0],[-P.W/2 P.W/2],'w-');a=linspace(0,2*pi,100);plot(ax,P.centreD/2*cos(a),P.centreD/2*sin(a),'w-');
row=trace(index,:);
for i=1:8
 color=[.15 .4 .95];if i>4,color=[.9 .15 .15];end
 fill(ax,row(i)+P.robotR*cos(a),row(i+8)+P.robotR*sin(a),color);
 plot(ax,row(i)+[0 .25*cos(row(i+16))],row(i+8)+[0 .25*sin(row(i+16))],'k-');
 text(ax,row(i),row(i+8),num2str(i),'Color','w','HorizontalAlignment','center');
end
fill(ax,row(57)+P.ballR*cos(a),row(58)+P.ballR*sin(a),'w');
xlim(ax,[-5.5 5.5]);ylim(ax,[-4 4]);xlabel(ax,'x (m)');ylabel(ax,'y (m)');
title(ax,sprintf('t = %.2f s; Blue %d : %d Red',row(61),row(62),row(63)));
if nargin>=4,exportgraphics(fig,file,'Resolution',140);end
end
