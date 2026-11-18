function C = halfCodes()
%HALFCODES (Y3) Numeric codes returned by tdp.ballHalf.
%   Plain doubles, so they can be stored in a numeric trace or a CSV.
C = struct('Stoppage',0,'BlueHalf',1,'RedHalf',2,'Midline',3, ...
    'OutOfPlay',4,'Goal',5,'Unknown',6);
C.names = {'Stoppage','BlueHalf','RedHalf','Midline','OutOfPlay','Goal','Unknown'};
end
