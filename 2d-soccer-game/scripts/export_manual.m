function export_manual()
%EXPORT_MANUAL Generate numbers and figures; never invent expected results.
root=tdpSetup();out=fullfile(root,'docs','generated');n=manualMeasurements();writeJson(fullfile(out,'manual_numbers.json'),n);
P=tdp.defaultConfig();writeJson(fullfile(out,'config.json'),P);export_contracts();
f=fopen(fullfile(out,'manual_numbers.md'),'w');c=onCleanup(@()fclose(f));
fprintf(f,'# 脚本生成的教学结果\n\n来源：scripts/manualMeasurements.m；不得手工修改。\n\n| 项目 | 实测值 | 单位 |\n|---|---:|---|\n');
fprintf(f,'| 首步 4 号前向请求 | %.15g | m/s |\n| 首步 4 号 x | %.15g | m |\n| 90 步滚动距离 | %.15g | m |\n| 最终球速 | %.15g | m/s |\n',n.firstCommand,n.firstRobot4X,n.rollingDistance,n.finalBallSpeed);
fprintf(f,'\n闭环 Unit Delay 输出：`%s`。平铺图 phase：`%s`。\n\n',mat2str(n.delayLesson,12),mat2str(n.flatPhases));
fprintf(f,'## 无反馈时的手走周期表\n\n每拍都来自真实 Stateflow 回放；速度列省略，完整记录在 JSON。\n\n| k | tSim (s) | phase | requestId | kind | stamp (s) | validUntil (s) |\n|---|---:|---|---:|---:|---:|---:|\n');
for k=1:size(n.replay,1)
 r=n.replay(k,:);fprintf(f,'| %d | %.2f | %s | %d | %d | %.2f | %.2f |\n',k-1,(k-1)*P.dt,char(string(TdpPhase(r(3)))),r(2),r(1),r(10),r(11));
end
clear c;
a=runA(1,0,10);fig=Viewer2D(a.trace,200,P,fullfile(out,'match_snapshot.png'));close(fig);
[status,output]=system('python3 scripts/export_stateflow_docs.py');assert(status==0,output);
[status,output]=system('python3 scripts/export_parameter_docs.py');assert(status==0,output);
[status,output]=system('python3 scripts/export_source_map.py');assert(status==0,output);
[status,output]=system('python3 scripts/export_manual_figures.py');assert(status==0,output);
[status,output]=system('bash scripts/render_course.sh');assert(status==0,output);
export_m2_manual;
end
