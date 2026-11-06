function export_contracts()
%EXPORT_CONTRACTS Generate type/shape tables directly from canonical values.
P=tdp.defaultConfig();T=tdpTemplates(P);names=fieldnames(T);rows=struct([]);
fid=fopen(fullfile('docs','generated','interfaces.md'),'w','n','UTF-8');c=onCleanup(@()fclose(fid));
fprintf(fid,'# 由 tdpTemplates 生成的接口字段\n\n| 总线 | 字段 | 类型 | 尺寸 |\n| --- | --- | --- | --- |\n');
for i=1:numel(names)
 fields=fieldnames(T.(names{i}));
 for j=1:numel(fields)
  v=T.(names{i}).(fields{j});row=struct('bus',[names{i} 'Bus'],'field',fields{j},'type',class(v),'size',size(v));
  rows=[rows row];fprintf(fid,'| %s | %s | %s | %s |\n',row.bus,row.field,row.type,mat2str(row.size));
 end
end
writeJson(fullfile('docs','generated','interfaces.json'),rows);
end
