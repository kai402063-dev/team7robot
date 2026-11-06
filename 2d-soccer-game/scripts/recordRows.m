function rows=recordRows(raw)
%RECORDROWS Convert To Workspace 1-by-width-by-time arrays into time rows.
if ndims(raw)==3
 rows=reshape(permute(raw,[3 1 2]),size(raw,3),[]);
else
 rows=raw;
end
end
