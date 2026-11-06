function [rgb,ErrorCode]=DecodeBgra(bytes,width,height,rowStep,encodingCode)
%DECODEBGRA Fixed CameraTop adapter; this is not ROS Toolbox Read Image.
% ErrorCode: 0 success, 1 encoding, 2 dimensions/stride, 3 byte count.
rgb=zeros(120,160,3,'uint8');ErrorCode=uint8(0);
if encodingCode~=uint8(1),ErrorCode=uint8(1);return;end
if width~=160||height~=120||rowStep~=640,ErrorCode=uint8(2);return;end
if numel(bytes)~=76800||~isa(bytes,'uint8'),ErrorCode=uint8(3);return;end
bgra=permute(reshape(bytes,4,160,120),[3 2 1]);
rgb=bgra(:,:,[3 2 1]);
end
