// All writes are in tmpfs. Fixed 128 x 512 byte event slots plus <=4096 byte state.
import * as fs from 'fs';
import * as model from './model.uc';
let ROOT='/tmp/lanekeep-sampler-supervisor',CAPACITY=128,SLOT_BYTES=512,STATE_BYTES=4096;
function directory() {
    let mounts=fs.readfile('/proc/mounts')||'';
    if(!match(mounts,/(^|\n)[^ ]+ \/tmp tmpfs /))die('tmp_not_ram');
    let s=fs.lstat(ROOT);
    if(!s){if(!fs.mkdir(ROOT,0700))die('mkdir');s=fs.lstat(ROOT);}
    if(s?.type!='directory'||s.uid!=0||(s.mode&0777)!=0700)die('directory');
}
function path(name,max_bytes) {
    if(name!='lock'&&name!='state.json'&&name!='state.next'&&name!='events.ring')die('filename');
    let p=ROOT+'/'+name,s=fs.lstat(p);
    if(s&&(s.type!='file'||s.uid!=0||(s.mode&0777)!=0600||s.size>max_bytes))die('file');
    return p;
}
function lock() {
    directory();let p=path('lock',0),f=fs.open(p,'a',0600);
    // No CLOEXEC: the child inherits this lock, avoiding a second sampler if we die.
    if(!f||!f.lock('xn')){if(f)f.close();return null;}
    return f;
}
function read() {
    directory();let p=path('state.json',STATE_BYTES);if(!fs.lstat(p))return null;
    let x=json(fs.readfile(p));
    if(x?.version!=1||!match(x.boot||'',/^[a-f0-9-]{36}$/)||
       !model.uint(x.launches)||!model.uint(x.exits)||!model.uint(x.event_count))die('state_schema');
    return x;
}
function write(state) {
    let p=path('state.json',STATE_BYTES),n=path('state.next',STATE_BYTES),s=sprintf('%J\n',state);
    if(length(s)>STATE_BYTES)die('state_capacity');
    let f=fs.open(n,'w',0600);if(!f)die('state_open');
    let written=f.write(s);f.close();if(written!=length(s)||!fs.rename(n,p))die('state_write');
}
function event(state,value) {
    let clean=model.clean_event(value);if(!clean)die('event_schema');
    let seq=state.event_count,text=sprintf('%d\n%J\n%d\n',seq,clean,seq);
    if(length(text)>SLOT_BYTES)die('event_capacity');
    let p=path('events.ring',CAPACITY*SLOT_BYTES),f=fs.open(p,fs.lstat(p)?'r+':'w+',0600);
    if(!f)die('ring_open');f.seek((seq%CAPACITY)*SLOT_BYTES,0);
    let written=f.write(sprintf('%-'+SLOT_BYTES+'s',text));f.close();if(written!=SLOT_BYTES)die('ring_write');
    state.event_count++;state.ring_overwritten=state.event_count>CAPACITY?state.event_count-CAPACITY:0;
    if(clean.event=='started')state.launches++;
    else{state.exits++;state.last_exit=clean;}
    write(state);
}
export { lock, read, write, event, ROOT, CAPACITY, SLOT_BYTES, STATE_BYTES };
