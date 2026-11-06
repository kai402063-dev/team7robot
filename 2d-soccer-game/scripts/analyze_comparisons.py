"""Summarize measured differences without reclassifying noisy runs as exact."""
import json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
receipt=json.loads((root/'evidence/3/attempt-02/receipt.json').read_text())
rows=receipt['comparisons']
summary={
 'zeroNoiseStepTolerancePass':all(r['maximumDifference']<=1e-12 for r in rows if r['kickNoise']==0),
 'defaultNoiseStepTolerancePass':all(r['maximumDifference']<=1e-12 for r in rows if r['kickNoise']!=0),
 'goalsShotsFirstTouchIdentical':all(all(r['oracle'][key]==r['migrated'][key] for key in ('goals','shots','firstTouchSeconds')) for r in rows),
 'maximumZeroNoiseDifference':max(r['maximumDifference'] for r in rows if r['kickNoise']==0),
 'maximumDefaultNoiseDifference':max(r['maximumDifference'] for r in rows if r['kickNoise']!=0),
 'allFinite':all(r['migrated']['finite'] for r in rows),
 'elapsedSeconds':receipt['elapsedSeconds'],'fortyMilliseconds':receipt['fortyMilliseconds'],
 'traceHashes':[]}
for file in sorted((root/'build').glob('match-*.mat')):
 summary['traceHashes'].append({'path':str(file.relative_to(root)),'bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
out=root/'evidence/3/COMPAT_RECEIPT.json';assert not out.exists();out.write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items() if k!='traceHashes'},indent=2))
