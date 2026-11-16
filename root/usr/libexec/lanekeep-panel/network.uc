// SPDX-License-Identifier: GPL-3.0-only
// Resolve the selected OpenWrt logical interface; never assume a device or subnet.
import * as fs from 'fs';
import * as uci from 'uci';
import * as ubus from 'ubus';
let cached;
function number(ip) {
 if(type(ip)!='string'||!match(ip,/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/))return null;
 let n=0;for(let p in split(ip,'.')){let v=int(p);if(v<0||v>255||sprintf('%d',v)!=p)return null;n=n*256+v;}return n;
}
function address(n){let a=[];for(let i=0;i<4;i++){unshift(a,sprintf('%d',n%256));n=int(n/256);}return join('.',a);}
function context() {
 if(cached)return cached;
 let c=uci.cursor(),name=c.get('lanekeep_runtime','main','lan_interface')||'lan';
 if(!match(name,/^[A-Za-z0-9_]{1,32}$/))die('invalid_lan_interface');
 let conn=ubus.connect();if(!conn)die('ubus_unavailable');let s=conn.call('network.interface.'+name,'status',{});conn.disconnect();
 let ips=s?.['ipv4-address'];if(type(ips)!='array'||length(ips)!=1)die('lan_requires_one_ipv4_subnet');
 let ip=ips[0].address,mask=ips[0].mask,dev=s.l3_device||s.device,n=number(ip);
 if(n==null||type(mask)!='int'||mask<8||mask>30||!match(dev||'',/^[A-Za-z0-9_.:-]{1,32}$/))die('invalid_lan_network');
 let size=1;for(let i=mask;i<32;i++)size*=2;let net=int(n/size)*size;
 cached={name,device:dev,address:ip,network:net,broadcast:net+size-1,subnet:address(net)+'/'+mask,ipv6:s['ipv6-address']||[],ipv6_prefix:s['ipv6-prefix-assignment']||[]};return cached;
}
function member(ip){let n=number(ip),c=context();return n!=null&&n>c.network&&n<c.broadcast&&ip!=c.address;}
function expand(text){let c=context();return replace(replace(replace(replace(text,'__LAN_ADDRESS__',c.address),'__LAN_DEVICE__',c.device),'__LAN_SUBNET__',c.subnet),'__LAN_BROADCAST__',address(c.broadcast));}
export {number,address,context,member,expand};
