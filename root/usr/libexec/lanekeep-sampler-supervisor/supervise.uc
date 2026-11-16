// One child per invocation; procd alone supplies the fixed 60-second unlimited retry.
import * as fs from 'fs';
import * as store from './store.uc';
function mono(){return +(split(fs.readfile('/proc/uptime')||'0',' ')[0]);}
function process(pid){
    let m=match(fs.readfile('/proc/'+pid+'/stat')||'',/^([0-9]+) \(.*\) (.*)$/);
    if(!m)return null;let f=split(trim(m[2]),/\s+/);
    return {pid:int(m[1]),state:f[0],start:int(f[19])};
}
let guard=store.lock();if(!guard)exit(75);
let parent=process('self'),boot=trim(fs.readfile('/proc/sys/kernel/random/boot_id')||'');
if(!parent||!match(boot,/^[a-f0-9-]{36}$/))exit(70);
let saved=store.read();if(saved&&saved.boot!=boot)exit(70);
let state=saved||{version:1,boot,recording_since_wall:time(),recording_since_mono:mono(),launches:0,exits:0,event_count:0,ring_overwritten:0,last_exit:null};
let child=null,initial=null,forwarded=null,stopping=null,forced=null;
function relay(signum){
    if(index([1,2,15],signum)<0)return;
    forwarded=signum;if(stopping==null)stopping=mono();
    let p=child?process(child):null;
    if(p&&initial&&p.start==initial.start)system(['/bin/kill','-'+signum,''+child],1000);
}
signal('TERM',relay);signal('INT',relay);signal('HUP',relay);
// Fixed shell text; exec preserves the actual wait target. No sampler output is read.
let proc=fs.popen("printf '%s\\n' \"$$\"; exec /usr/bin/ucode -g 10000 /usr/libexec/lanekeep-telemetry/daemon.uc >/dev/null 2>&1",'r');
if(!proc)exit(70);
let line=proc.read('line');
if(!match(line||'',/^[0-9]+\n$/)){proc.close();exit(70);}
child=int(trim(line));initial=process(child);let started=mono(),wall=time();
state.supervisor_pid=parent.pid;state.supervisor_start=parent.start;
state.child_pid=child;state.child_start=initial?.start;
state.started_wall=wall;state.started_mono=started;state.retry_seconds=60;state.phase='running';
try{store.event(state,{event:'started',wall,mono:started,pid:child,start:initial?.start});}catch(e){}
if(stopping!=null)relay(forwarded);
while(true){
    let p=process(child);
    if(!p||p.state=='Z'||(initial&&p.start!=initial.start))break;
    // Signals can only target this wait object's child with its original start identity.
    if(stopping!=null&&mono()-stopping>=5&&initial&&p.start==initial.start&&forced==null){
        forced=9;system(['/bin/kill','-9',''+child],1000);
    }
    sleep(250);
}
// fs.proc.close returns the real exit code or a negative terminating signal.
let rc=proc.close(),ended=mono();state.phase='exited';state.exited_wall=time();state.exited_mono=ended;
try{store.event(state,{event:'exited',wall:time(),mono:ended,pid:child,start:initial?.start,runtime_seconds:ended-started,rc,forwarded_signal:forwarded,forced_signal:forced});}catch(e){}
exit(rc==0?0:1);
