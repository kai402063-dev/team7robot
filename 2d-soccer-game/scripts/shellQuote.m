function q=shellQuote(value)
%SHELLQUOTE Quote one POSIX shell argument, preserving spaces and apostrophes.
quote=char(39);replacement=char([39 34 39 34 39]);
q=[quote strrep(char(value),quote,replacement) quote];
end
