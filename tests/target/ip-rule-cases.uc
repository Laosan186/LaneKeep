// SPDX-License-Identifier: GPL-3.0-only
// Unit cases for ip-rule.uc. Run on an OpenWrt test machine: ucode tests/target/ip-rule-cases.uc
import * as ip from '../../root/usr/libexec/lanekeep-panel/ip-rule.uc';
let cases=[
 ['1.2.3.4',null,true,'1.2.3.4'],['1.2.3.4/32',null,true,'1.2.3.4'],[' 1.2.3.0/24 ',null,true,'1.2.3.0/24'],['8.0.0.0/7',null,true,'8.0.0.0/7'],
 ['172.32.0.0/11',null,true,'172.32.0.0/11'],['100.128.0.1',null,true,'100.128.0.1'],['223.255.255.255',null,true,'223.255.255.255'],['1.0.0.0/8',null,true,'1.0.0.0/8'],
 ['1.2.3.4/24',null,false,'host'],['192.168.77.5',null,false,'reserved'],['198.18.0.1',null,false,'reserved'],['198.19.255.255',null,false,'reserved'],
 ['10.0.0.0/8',null,false,'reserved'],['0.0.0.0/0',null,false,'format'],['224.0.0.1',null,false,'reserved'],['255.255.255.255',null,false,'reserved'],
 ['100.64.0.1',null,false,'reserved'],['172.16.0.0/12',null,false,'reserved'],['127.0.0.1',null,false,'reserved'],['169.254.1.1',null,false,'reserved'],
 ['192.0.2.1',null,false,'reserved'],['198.51.100.0/24',null,false,'reserved'],['203.0.113.9',null,false,'reserved'],['192.0.0.0/8',null,false,'reserved'],
 ['1.2.3',null,false,'format'],['01.2.3.4',null,false,'format'],['1.2.3.256',null,false,'format'],['1.2.3.4/33',null,false,'format'],['1.2.3.4/0',null,false,'format'],
 ['1.2.3.4/08',null,false,'format'],['abc',null,false,'format'],['1.2.3.4/',null,false,'format'],['',null,false,'format'],[null,null,false,'format'],['::1',null,false,'format'],
 // The selected LAN subnet is read from OpenWrt and may lie outside the private ranges.
 ['11.0.0.5','11.0.0.0/24',false,'reserved'],['11.0.0.0/16','11.0.0.0/24',false,'reserved'],['11.0.0.128/25','11.0.0.0/24',false,'reserved'],
 ['11.0.1.0/24','11.0.0.0/24',true,'11.0.1.0/24'],['11.0.0.5','not-a-subnet',true,'11.0.0.5'],['11.0.0.5','11.0.0.0/40',true,'11.0.0.5']
];
let fails=[];
for(let c in cases){let r=ip.normalize(c[0],c[1]);let ok=c[2]?(r.ok&&r.value==c[3]):(!r.ok&&r.code==c[3]);if(!ok)push(fails,{input:c[0],lan:c[1],got:r});}
let canonical=[ip.canonical('1.2.3.4'),ip.canonical('1.2.3.4/32'),ip.canonical('1.2.3.0/24')];
if(canonical[0]!=true||canonical[1]!=false||canonical[2]!=true)push(fails,{canonical});
printf('%J\n',{total:length(cases),fails});
exit(length(fails)?1:0);
