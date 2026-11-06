function tests=test_camera
tests=functiontests(localfunctions);
end
function testChannelAndPixelOrder(t)
b=zeros(76800,1,'uint8');b(1:8)=uint8([10 20 30 255 40 50 60 255]);
[r,e]=DecodeBgra(b,160,120,640,uint8(1));verifyEqual(t,e,uint8(0));
verifyEqual(t,reshape(r(1,1,:),1,3),uint8([30 20 10]));verifyEqual(t,reshape(r(1,2,:),1,3),uint8([60 50 40]));
end
function testErrors(t)
b=zeros(76800,1,'uint8');[~,e]=DecodeBgra(b,160,120,640,uint8(0));verifyEqual(t,e,uint8(1));
[~,e]=DecodeBgra(b,120,160,640,uint8(1));verifyEqual(t,e,uint8(2));
[~,e]=DecodeBgra(b(1:end-1),160,120,640,uint8(1));verifyEqual(t,e,uint8(3));
end
