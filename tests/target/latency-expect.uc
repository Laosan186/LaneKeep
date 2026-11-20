// SPDX-License-Identifier: GPL-3.0-only
// Expected node-test results for each latency-stub.uc mode. ARGV: result file, mode, seconds taken.
import * as fs from 'fs';
let r=json(fs.readfile(ARGV[0]) || 'null'),mode=ARGV[1],took=int(ARGV[2]);
let ok=r?.ok==true&&r.status=='ok'&&r.measurement_version==3&&r.ip=='203.0.113.9'&&r.country=='ZZ'&&type(r.elapsed_ms)=='int';
let first=ok&&r.latency_basis=='first_request'&&r.connect_ms==null;
let expect={
 normal: ok&&r.latency_basis=='warm'&&r.elapsed_ms>=60&&r.elapsed_ms<300&&r.connect_ms>=280&&r.elapsed_ms<r.connect_ms,
 noka: first&&r.elapsed_ms>=280&&r.elapsed_ms<1500,           // no keep-alive: first request only
 bad204: first&&r.elapsed_ms>=280&&r.elapsed_ms<1500,         // latency probe failed: exit lookup time
 stall: r?.ok==false&&r.status=='timeout'&&took<=16,           // exit lookup never answers
 silentclose: first&&r.elapsed_ms>=280&&r.elapsed_ms<1500,    // warm request fails: keep the first sample
 slowwarm: first&&r.elapsed_ms>=280&&r.elapsed_ms<1500,       // warm request past the deadline
 pingstall: r?.ok==false&&r.status=='timeout'&&took<=16        // whole probe still ends within the wait window
}[mode];
if(!expect)printf('%J\n',r);
exit(expect?0:1);
