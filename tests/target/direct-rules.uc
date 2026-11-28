// SPDX-License-Identifier: GPL-3.0-only
// Checks one generator output: the direct inbound's four rules come after every other rule,
// and every other rule is tagged for other inbounds, so direct traffic meets only its own rules.
// Usage: ucode direct-rules.uc OUTPUT_DIR
import * as fs from 'fs';
let config=json(fs.readfile(ARGV[0]+'/config.json')),rules=config.routing.rules,problems=[],first=null;
for(let i=0;i<length(rules);i++){
    let tags=rules[i].inboundTag;
    if(type(tags)!='array'||!length(tags)){push(problems,'rule '+i+' has no inboundTag');continue;}
    if(index(tags,'direct-transparent')<0)continue;
    if(length(tags)!=1)push(problems,'rule '+i+' shares direct-transparent with other inbounds');
    if(first==null)first=i;
}
let direct=first==null?[]:slice(rules,first);
if(length(direct)!=4||length(filter(direct,r=>r.inboundTag?.[0]=='direct-transparent'))!=4)push(problems,'direct rules are not the last four rules');
else {
    let d=direct[0];
    if(d.outboundTag!='direct-router-dns'||d.port!='53'||d.network!='tcp,udp'||length(d.ip||[])!=1||!match(d.ip[0],/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/32$/)||d.domain!=null)push(problems,'first direct rule is not router DNS on the LAN address');
    if(direct[1].outboundTag!='block'||direct[2].outboundTag!='block'||direct[3].outboundTag!='direct'||direct[3].network!='tcp,udp'||direct[3].ip!=null||direct[3].domain!=null||direct[3].port!=null)push(problems,'direct rules are not router DNS, block, block, then direct for everything');
}
// Router DNS is forwarded unchanged to dnsmasq on loopback, on the short idle level dns-idle.uc adds.
let router_dns=filter(config.outbounds,o=>o.tag=='direct-router-dns');
if(length(router_dns)!=1||router_dns[0].protocol!='dns'||sprintf('%J',router_dns[0].settings)!=sprintf('%J',{rewriteAddress:'127.0.0.1',rewritePort:53,rules:[{action:'direct'}],userLevel:53}))push(problems,'router-DNS outbound missing or changed');
if(config.policy?.levels?.['53']?.connIdle!=15)push(problems,'policy level 53 missing');
let inbound=filter(config.inbounds,i=>i.tag=='direct-transparent');
if(length(inbound)!=1||inbound[0].port!=12349||inbound[0].sniffing?.enabled!=false||inbound[0].streamSettings?.sockopt?.tproxy!='tproxy')push(problems,'direct inbound missing or changed');
printf('%J\n',{ok:!length(problems),problems});
exit(length(problems)?1:0);
