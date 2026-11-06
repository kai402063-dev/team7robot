function ok=laneClearLesson(a,b,obstacles,margin)
ab=b-a; squaredLength=dot(ab,ab);ok=true;
if squaredLength<1e-9,return;end
for n=1:size(obstacles,1)
fraction=max(0,min(1,dot(obstacles(n,:)-a,ab)/squaredLength));
separation=norm(a+fraction*ab-obstacles(n,:));
if separation < margin,ok=false;return;end
end
end
