// Typed numeric records only. A positive exit 137 is never interpreted as a signal.
function finite_number(v) {
    return (type(v)=='int'||type(v)=='double')&&v==v&&v>-1e15&&v<1e15;
}
function uint(v) { return finite_number(v)&&v>=0&&v%1==0; }
function decode_exit(rc) {
    if(!finite_number(rc)||rc%1!=0||rc < -64||rc>255)
        return {kind:'unknown',exit_code:null,signal:null};
    if(rc<0)return {kind:'signal',exit_code:null,signal:-rc};
    return {kind:'exit',exit_code:rc,signal:null};
}
function clean_event(x) {
    if(type(x)!='object'||(x.event!='started'&&x.event!='exited'))return null;
    let r={version:1,event:x.event};
    for(let k in ['wall','mono','pid','start','runtime_seconds'])
        r[k]=finite_number(x[k])&&x[k]>=0?x[k]:null;
    if(x.event=='exited'){
        let d=decode_exit(x.rc);r.kind=d.kind;r.exit_code=d.exit_code;r.signal=d.signal;
        r.forwarded_signal=(x.forwarded_signal==1||x.forwarded_signal==2||x.forwarded_signal==15)?x.forwarded_signal:null;
        r.forced_signal=x.forced_signal==9?9:null;
    }
    return r;
}
export { finite_number, uint, decode_exit, clean_event };
