function a = angWrap(a)
%ANGWRAP  Wrap an angle to [-pi, pi] (no toolbox needed).
a = atan2(sin(a), cos(a));
end
