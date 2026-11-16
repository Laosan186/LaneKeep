// Read-only aggregate collector. Endpoint addresses and socket tuples stay local
// to this function and are never returned, logged or saved in history.
import * as fs from 'fs';
import * as ubus from 'ubus';
import * as stats from './stats.uc';
import * as nftapi from './nft.uc';
import { mono } from './model.uc';
let bus=ubus.connect(),last_wan_device=null;
function doc(p){try{return json(fs.readfile(p));}catch(e){return null;}}
function number(p){let s=trim(fs.readfile(p)||'');return match(s,/^[0-9]+$/)?int(s):null;}
function keyvals(s){let o={};for(let l in split(s||'','\n')){let m=match(l,/^([^=]+)=(.*)$/);if(m)o[m[1]]=m[2];}return o;}
function proc_address(s){let a=iptoarr(s);if(!a||index([4,16],length(a))<0)return null;let v='';for(let i=0;i<length(a);i+=4)for(let j=3;j>=0;j--)v+=sprintf('%02X',a[i+j]);return v;}
function proto(s){let lines=split(s||'','\n'),o={};for(let i=0;i+1<length(lines);i+=2){let k=split(trim(lines[i]),/\s+/),v=split(trim(lines[i+1]),/\s+/);if(k[0]!=v[0])continue;for(let j=1;j<length(k);j++)o[k[0]+k[j]]=int(v[j]);}return o;}
function collect(port){
 let out={raw:{},sources:{},epochs:{},core_start:null,default_node:null,node_ids:[],wan:null,gate:null};let r=out.raw;
 let svc;try{svc=bus.call('service','list',{name:'lanekeep-xray'})?.['lanekeep-xray']?.instances;}catch(e){}
 let cfg=doc('/etc/lanekeep-proxy/config.json'),ns=doc('/etc/lanekeep-proxy/nodes.json');out.default_node=ns?.default_node;out.node_ids=map(ns?.nodes||[],n=>n.id);
 let pid=svc?.core?.running==true?svc.core.pid:null,process=pid?fs.readfile('/proc/'+pid+'/stat'):null,pm=match(process||'',/^.*\) (.*)$/),pf=pm?split(trim(pm[1]),/\s+/):[];
 let start=length(pf)>19?int(pf[19]):null;out.core_pid=pid;out.core_start=start;out.epochs.stats=start;out.epochs.proc=start;
 if(pid&&start!=null){
  r.core_uptime=max(0,mono()-start/100.0);let fds=fs.lsdir('/proc/'+pid+'/fd'),owned={};r.core_fd=fds==null?null:length(fds);
  let lm=match(fs.readfile('/proc/'+pid+'/limits')||'',/Max open files\s+([0-9]+)/);out.fd_limit=lm?int(lm[1]):null;
  for(let fd in fds||[]){let m=match(fs.readlink('/proc/'+pid+'/fd/'+fd)||'',/^socket:\[([0-9]+)\]$/);if(m)owned[m[1]]=true;}
  let def=filter(cfg?.outbounds||[],o=>o.tag=='proxy-default')[0],server=def?.settings?.vnext?.[0]||def?.settings?.servers?.[0]||def?.settings,target=server?proc_address(server.address):null,target_port=server?.port;
  if(target&&index(['hysteria','hysteria2'],def?.protocol)<0)r.default_tcp=0;
  let seen={};for(let p in [12345,12346,12347,12348]){r['recv_tcp_'+p]=null;r['recv_data_'+p]=null;r['recv_udp_'+p]=null;}
  for(let filename in ['tcp','tcp6','udp','udp6']){
   let f=fs.open('/proc/net/'+filename,'r');if(!f)continue;let data=f.read('all'),is_tcp=substr(filename,0,3)=='tcp';
   for(let line in split(data||'','\n')){let a=split(trim(line),/\s+/);if(length(a)<10||!owned[a[9]])continue;
    let local=split(a[1],':'),remote=split(a[2],':'),p=int(local[1],16),q=split(a[4],':'),rx=int(q[1],16);
    if(is_tcp&&a[3]=='01'&&target!=null&&(remote[0]==target||remote[0]=='0000000000000000FFFF0000'+target)&&int(remote[1],16)==target_port)r.default_tcp++;
    if(index([12345,12346,12347,12348],p)>=0){let key=(is_tcp?(a[3]=='0A'?'recv_tcp_':'recv_data_'):'recv_udp_')+p;r[key]=(r[key]||0)+rx;seen[key]=true;}
   }f.close();
  }
 }
 out.sources.proc=mono();
 let s=stats.query(port);if(s!=null){
  let sum={};for(let name in keys(s)){let m=match(name,/^(inbound|outbound)>>>([a-zA-Z0-9_-]+)>>>traffic>>>(uplink|downlink)$/);if(!m)continue;let side=m[1],tag=m[2],dir=m[3]=='uplink'?'up':'down';
   if(side=='inbound'){let g=({'standard-transparent':'standard','global-transparent':'global','enhanced-transparent':'enhanced','ondemand-transparent':'ondemand'})[tag],d=match(tag,/^dedicated-(global|enhanced|ondemand)-[0-9]+$/);if(d)g=d[1];if(g){let k='group_'+g+'_'+dir;sum[k]=(sum[k]||0)+s[name];}}
   else if(tag!='block'&&(index(['proxy-default','dns-protected','direct'],tag)>=0||match(tag,/^node-[a-z0-9_-]+$/)))sum['out_'+tag+'_'+dir]=s[name];
  }for(let k in keys(sum))r[k]=sum[k];out.sources.stats=mono();
 }
 let nft=nftapi.query();
 let lease=false,table_id=null,counter_ids=[];
 if(nft){for(let x in nft.nftables||[]){if(x.table?.name=='lanekeep_phone')table_id=x.table.handle;
  if(x.counter?.table=='lanekeep_phone'){let key=({obs_udp443:'udp443',obs_853:'853',blocked_forward:'forward',blocked_input:'input'})[x.counter.name];if(key){r['nft_'+key]=x.counter.packets;push(counter_ids,x.counter.name+':'+x.counter.handle);}}
  if(x.set?.table=='lanekeep_dns_gate'&&x.set.name=='healthy_data')for(let e in x.set.elem||[]){let v=e.elem||e;if(v.val==30241&&v.expires>0)lease=true;}
 }out.sources.nft=mono();out.epochs.nft=table_id+':'+join(',',sort(counter_ids));}
 let gate=keyvals(fs.readfile('/tmp/lanekeep-dns-gate/status')),fresh=match(gate.uptime_seconds||'',/^[0-9]+$/)&&mono()-int(gate.uptime_seconds)>=0&&mono()-int(gate.uptime_seconds)<=10;
 if(fresh&&nft){r.gate=gate.state=='OPEN'&&lease&&pid!=null&&svc?.dns_gate?.running==true?1:0;out.gate=r.gate;out.sources.gate=+gate.uptime_seconds;
  for(let pair in [['probe_ok','successes'],['probe_fail','failures'],['probe_ms','probe_elapsed_ms']])if(match(gate[pair[1]]||'',/^[0-9]+$/))r[pair[0]]=int(gate[pair[1]]);
 }out.epochs.gate=trim(fs.readfile('/tmp/lanekeep-dns-gate/watchdog.lock/owner')||'');
 let wan;try{wan=bus.call('network.interface.wan','status',{});}catch(e){}
 out.local_addresses=map(wan?.['ipv4-address']||[],a=>a.address);
 if(wan){if(match(wan.l3_device||'',/^[a-zA-Z0-9_.:-]{1,32}$/))last_wan_device=wan.l3_device;if(wan.up==false){r.wan_up_state=0;out.sources.net=mono();}}
 if(wan&&last_wan_device){
  let dev=last_wan_device,carrier=number('/sys/class/net/'+dev+'/carrier');out.wan=dev;r.wan_up_state=wan.up==false||carrier==0?0:wan.up==true&&carrier==1?1:null;
  for(let l in split(fs.readfile('/proc/net/dev')||'','\n')){let m=match(l,/^\s*([^:]+):\s*(.*)$/);if(m&&m[1]==dev){let v=split(trim(m[2]),/\s+/);r.wan_down=int(v[0]);r.wan_up=int(v[8]);}}
  out.sources.net=mono();out.epochs.net=dev+':'+r.wan_up_state;
 }
 let cpu=match(fs.readfile('/proc/stat')||'',/^cpu\s+([^\n]+)/),mem={};
 if(cpu){let a=map(split(trim(cpu[1]),/\s+/),x=>int(x)),total=0;for(let i=0;i<min(8,length(a));i++)total+=a[i];r.cpu_total=total;r.cpu_busy=total-a[3]-a[4];}
 for(let l in split(fs.readfile('/proc/meminfo')||'','\n')){let m=match(l,/^([A-Za-z]+):\s*([0-9]+)/);if(m)mem[m[1]]=int(m[2]);}
 if(mem.MemAvailable!=null&&mem.MemTotal!=null){r.mem_available=mem.MemAvailable/1024.0;r.mem_used=(mem.MemTotal-mem.MemAvailable)/1024.0;}
 let load=split(trim(fs.readfile('/proc/loadavg')||''),/\s+/);if(length(load)>=3){r.load1=+load[0];r.load5=+load[1];r.load15=+load[2];}
 r.conntrack=number('/proc/sys/net/netfilter/nf_conntrack_count');let snmp=proto(fs.readfile('/proc/net/snmp')),netstat=proto(fs.readfile('/proc/net/netstat'));r.tcp_retrans=snmp['Tcp:RetransSegs'];r.tcp_timeout=netstat['TcpExt:TCPTimeouts'];out.sources.system=mono();out.epochs.system='boot';
 out.mono=mono();out.wall=time();return out;
}

export { collect };

function min(a,b){return a<b?a:b;}
function max(a,b){return a>b?a:b;}
function abs(a){return a<0?-a:a;}
