// SPDX-License-Identifier: GPL-3.0-only
// User destination rules for one public IPv4 address or network. Pure functions, no I/O.
// Private, loopback, multicast, documentation and FakeIP ranges are rejected, and so is the
// selected LAN subnet when given, so an IP rule never overlaps the LAN or the FakeIP pool.
let RESERVED=[
    ['0.0.0.0',8],['10.0.0.0',8],['100.64.0.0',10],['127.0.0.0',8],['169.254.0.0',16],
    ['172.16.0.0',12],['192.0.0.0',24],['192.0.2.0',24],['192.168.0.0',16],['198.18.0.0',15],
    ['198.51.100.0',24],['203.0.113.0',24],['224.0.0.0',4],['240.0.0.0',4]
];
function span(prefix) { let size=1; for(let i=prefix;i<32;i++) size*=2; return size; }
function number(text) {
    let m=match(text,/^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$/);
    if(!m) return null;
    let n=0;
    for(let i=1;i<=4;i++) {
        if(length(m[i])>1 && substr(m[i],0,1)=='0') return null;
        let part=int(m[i]); if(part>255) return null;
        n=n*256+part;
    }
    return n;
}
function dotted(n) {
    let parts=[];
    for(let i=0;i<4;i++) { unshift(parts,sprintf('%d',n%256)); n=int((n-n%256)/256); }
    return join('.',parts);
}
// Returns {ok:true,value} with the canonical text, or {ok:false,code:'format'|'host'|'reserved'}.
// lan is the selected LAN subnet as 'a.b.c.d/n'; an unreadable value adds no extra range.
function normalize(value, lan) {
    if(type(value)!='string') return {ok:false,code:'format'};
    let text=trim(value), slash=index(text,'/'), address=text, prefix=32;
    if(length(text)>18) return {ok:false,code:'format'};
    if(slash>=0) {
        address=substr(text,0,slash); let p=substr(text,slash+1);
        if(!match(p,/^[0-9]{1,2}$/) || (length(p)>1 && substr(p,0,1)=='0')) return {ok:false,code:'format'};
        prefix=int(p);
        if(prefix<1 || prefix>32) return {ok:false,code:'format'};
    }
    let start=number(address);
    if(start==null) return {ok:false,code:'format'};
    let size=span(prefix);
    if(start%size!=0) return {ok:false,code:'host'};
    let ranges=slice(RESERVED), m=match(lan || '',/^([0-9.]+)\/([0-9]{1,2})$/);
    if(m && number(m[1])!=null && int(m[2])>=1 && int(m[2])<=32) push(ranges,[m[1],int(m[2])]);
    for(let r in ranges) {
        let base=number(r[0]), width=span(r[1]);
        base-=base%width;
        if(start<base+width && base<start+size) return {ok:false,code:'reserved'};
    }
    return {ok:true,value:prefix==32?dotted(start):dotted(start)+'/'+prefix};
}
function canonical(value) { let r=normalize(value); return r.ok && r.value==value; }
export { normalize, canonical };
