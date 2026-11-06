function value=requireKnown(value)
%REQUIREKNOWN Reject an unknown decoded JSON null instead of substituting zero.
assert(~isempty(value) && all(isfinite(value),'all'),'TDP:UnknownParameter','An explicit sourced value or documented assumption is required.');
end
