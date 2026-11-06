function writeJson(file,value)
%WRITEJSON Write a UTF-8 receipt. Callers own unique attempt directories.
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0,'TDP:Output','Cannot open output');
c=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
