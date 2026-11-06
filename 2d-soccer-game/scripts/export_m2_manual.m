function export_m2_manual()
%EXPORT_M2_MANUAL Generate measured values and true sensor/trajectory figures.
root=tdpSetup();n=manualM2Measurements();writeJson(fullfile(root,'docs/generated/m2_numbers.json'),n);
f=fopen(fullfile(root,'docs/generated/m2_numbers.md'),'w');cleanup=onCleanup(@()fclose(f));
fprintf(f,'# M2 实测数字（脚本生成）\n\n来自已提交真实ROS/Webots记录；每次测试重新分析记录并重放Core。位移/速度是V5仿真结果，不是NAO6实测。\n\n| 字段（名称含单位） | 值 |\n|---|---|\n');
keys=fieldnames(n);for k=1:numel(keys),fprintf(f,'| %s | %.15g |\n',keys{k},n.(keys{k}));end
fprintf(f,'\n动作事件每20 ms检查；sampled字段来自40 ms观测。motionEvent位移取动作结束瞬间，sampled位移取ballEvaluationTimeSeconds所示的随后观测，不能互换。\n');
[status,output]=system('python3 scripts/export_m2_figures.py');assert(status==0,output);
end
