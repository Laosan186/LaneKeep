// SPDX-License-Identifier: GPL-3.0-only
// Compares previous-release output with this release for one scenario without the direct group
// in use. Usage: ucode direct-diff.uc OLD_OUTPUT NEW_OUTPUT
// Only these differences are allowed; everything else, including every other global, enhanced,
// on-demand and standard rule, must stay identical:
//   - config.json gains the direct-transparent inbound, its four rules and the direct-router-dns
//     outbound, and the internal port block range grows from 12345-12348 to 12345-12349;
//   - phone-pilot.nft gains a two-line comment, the capture_direct chain, the standard/direct sets
//     and their two dispatch lines, and capture_global, capture_enhanced and capture_ondemand each
//     end in a comment and a TCP/UDP drop after their TPROXY rule (added after 1.0.2);
//   - members.nft gains the two flush lines for the new sets;
//   - normalized-rules.json and summary.json gain the unassigned choice and the two groups.
import * as fs from 'fs';
let OLD=ARGV[0],NEW=ARGV[1],problems=[];
function canonical(v){if(type(v)=='object')return '{'+join(',',map(sort(keys(v)),k=>sprintf('%J',k)+':'+canonical(v[k])))+'}';if(type(v)=='array')return '['+join(',',map(v,canonical))+']';return sprintf('%J',v);}
function read(dir,name){let t=fs.readfile(dir+'/'+name);if(t==null)push(problems,'missing '+dir+'/'+name);return t;}
let removed=[];
function direct_item(v){
    if(type(v)!='object')return false;
    if(v.tag=='direct-transparent'||v.tag=='direct-router-dns')return true;
    let tags=v.inboundTag;
    if(type(tags)=='array'&&index(tags,'direct-transparent')>=0){
        if(length(tags)!=1)push(problems,'direct-transparent shares a rule with other groups: '+canonical(v));
        return true;
    }
    return false;
}
// Undo the allowed differences so the remainder can be compared exactly.
function normalize(v){
    if(type(v)=='array'){let out=[];for(let x in v){if(direct_item(x)){push(removed,x);continue;}push(out,normalize(x));}return out;}
    if(type(v)=='object'){let out={};for(let k in keys(v))out[k]=normalize(v[k]);return out;}
    if(type(v)=='string')return replace(v,'12345-12349','12345-12348');
    return v;
}
function json_same(name,drop){
    let a=read(OLD,name),b=read(NEW,name);if(a==null||b==null)return;
    a=json(a);b=json(b);
    if(drop)drop(b);
    let before=length(removed),nb=normalize(b),count=length(removed)-before;
    if(canonical(a)!=canonical(nb))push(problems,name+' differs beyond the allowed changes');
    return count;
}
let direct_in_config=json_same('config.json');
if(direct_in_config!=6)push(problems,'config.json: expected 1 direct inbound, 4 direct rules and 1 router-DNS outbound, removed '+direct_in_config);
let expected=[
    {listen:'0.0.0.0',port:12349,protocol:'dokodemo-door',settings:{followRedirect:true,network:'tcp,udp'},sniffing:{enabled:false},streamSettings:{sockopt:{tproxy:'tproxy'}},tag:'direct-transparent'}
];
let seen_inbound=filter(removed,x=>x.tag=='direct-transparent');
if(length(seen_inbound)!=1||canonical(seen_inbound[0])!=canonical(expected[0]))push(problems,'direct inbound differs from the documented one');
let router_dns=filter(removed,x=>x.tag=='direct-router-dns');
if(length(router_dns)!=1||canonical(router_dns[0])!=canonical({protocol:'dns',settings:{rewriteAddress:'127.0.0.1',rewritePort:53,rules:[{action:'direct'}],userLevel:53},tag:'direct-router-dns'}))
    push(problems,'router-DNS outbound differs from the documented one');
let rules=filter(removed,x=>x.tag==null);
if(length(rules)!=4||rules[0].outboundTag!='direct-router-dns'||rules[0].port!='53'||rules[0].network!='tcp,udp'||length(rules[0].ip||[])!=1||!match(rules[0].ip[0],/^[0-9.]+\/32$/)||rules[0].domain!=null||
   rules[1].outboundTag!='block'||rules[2].outboundTag!='block'||rules[3].outboundTag!='direct'||rules[3].network!='tcp,udp'||rules[3].ip!=null||rules[3].domain!=null||rules[3].port!=null)
    push(problems,'direct rules are not router DNS, block, block, then direct for everything');
for(let name in ['invariant-template.json','invariant-output.json'])json_same(name);
json_same('normalized-rules.json',function(d){delete d.unassigned;if(d.groups){delete d.groups.standard;delete d.groups.direct;}});
let sa=read(OLD,'summary.json'),sb=read(NEW,'summary.json');
if(sa!=null&&sb!=null){
    sa=json(replace(sa,OLD,'STAGE'));sb=json(replace(sb,NEW,'STAGE'));
    delete sb.unassigned;delete sb.unassigned_change;
    if(canonical(sa)!=canonical(sb))push(problems,'summary.json differs beyond the unassigned fields');
}
// nft: remove the documented additions, then require the old text exactly.
let old_nft=read(OLD,'phone-pilot.nft'),new_nft=read(NEW,'phone-pilot.nft');
if(old_nft!=null&&new_nft!=null){
    // The tail drop is the same text in three chains: remove it only right after each chain's own
    // TPROXY rule and before the chain ends.
    let tail="\n        # No socket on this inbound (core start, stop or failure): drop, never another mode's chain.\n        meta l4proto { tcp, udp } counter drop";
    for(let port in ['12346','12347','12348']){
        let accept='        meta l4proto { tcp, udp } tproxy to :'+port+' meta mark set 0x7610 counter name captured accept';
        if(index(new_nft,accept+tail+'\n    }\n')<0)push(problems,'phone-pilot.nft: no tail drop after the TPROXY to '+port);
        else new_nft=replace(new_nft,accept+tail+'\n    }\n',accept+'\n    }\n');
    }
    let out=[],skipped={},block=null;
    for(let line in split(new_nft,'\n')){
        if(block!=null){if(line=='    }'){skipped[block]=(skipped[block]||0)+1;block=null;}continue;}
        if(line=='    chain capture_direct {'||line=='    set lanekeep_grp_standard {'||line=='    set lanekeep_grp_direct {'){block=line;continue;}
        if(line=='# Direct group: internal ports on every router address are dropped, except DNS to the LAN address;'||
           line=="# all other traffic, router DNS included, uses the core's direct inbound."||
           line=='        ip saddr @lanekeep_grp_standard jump capture_phone'||line=='        ip saddr @lanekeep_grp_direct jump capture_direct'){skipped[line]=(skipped[line]||0)+1;continue;}
        push(out,line);
    }
    if(length(keys(skipped))!=7)push(problems,'phone-pilot.nft: expected 7 documented additions, found '+length(keys(skipped)));
    for(let k in keys(skipped))if(skipped[k]!=1)push(problems,'phone-pilot.nft: addition repeated: '+k);
    if(join('\n',out)!=old_nft)push(problems,'phone-pilot.nft differs beyond the documented additions');
}
let old_members=read(OLD,'members.nft'),new_members=read(NEW,'members.nft');
if(old_members!=null&&new_members!=null){
    let kept=filter(split(new_members,'\n'),l=>!match(l,/lanekeep_grp_(standard|direct)( |$)/));
    if(join('\n',kept)!=old_members)push(problems,'members.nft differs beyond the two new sets');
}
printf('%J\n',{ok:!length(problems),problems});
exit(length(problems)?1:0);
