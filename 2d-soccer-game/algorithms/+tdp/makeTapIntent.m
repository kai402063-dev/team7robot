function intent=makeTapIntent(ball,team,P)
%MAKETAPINTENT New gentle-touch action with an explicit speed parameter.
intent=struct('type',TdpAction.Tap,'target',[ball.x+P.dirSign(team) ball.y], ...
 'heading',0,'speed',P.tapSpeed,'role',TdpRole.ST);
end
