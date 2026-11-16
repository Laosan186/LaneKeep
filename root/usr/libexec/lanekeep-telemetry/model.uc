// Pure aggregate calculations. Counter reset, source epoch, staleness and gaps.
function mono(){let t=clock(true);return t[0]+t[1]/1e9;}
function round(v){return v==null?null:int(v*1000+0.5)/1000.0;}
function delta(value,stamp,epoch,previous){
 if(value==null||stamp==null)return null;
 if(!previous||previous.value==null||epoch!=previous.epoch)return null;
 let dt=stamp-previous.stamp;
 if(dt<=0||dt>10||value<previous.value)return null;
 return round((value-previous.value)*1.0/dt);
}
function metric(id,label,unit,source,mode,roll){return {id,label,unit,source,mode,roll:roll||'mean'};}
function definitions(){
 let a=[];
 function add(id,label,unit,source,mode,roll){push(a,metric(id,label,unit,source,mode,roll));}
 add('wan_up','WAN 上传','B/s','net','rate');add('wan_down','WAN 下载','B/s','net','rate');
 for(let g in ['standard','global','enhanced','ondemand'])for(let d in ['up','down'])add('group_'+g+'_'+d,({standard:'常规',global:'全局',enhanced:'增强',ondemand:'按需'})[g]+(d=='up'?'上传':'下载'),'B/s','stats','rate');
 for(let tag in ['proxy-default','dns-protected','direct','block'])for(let d in ['up','down'])add('out_'+tag+'_'+d,({ 'proxy-default':'默认节点数据','dns-protected':'默认节点 DNS',direct:'直连',block:'阻断字节（不可采集）'})[tag]+(d=='up'?'上传':'下载'),'B/s','stats','rate');
 for(let k in ['udp443','853','forward','input'])add('nft_'+k,({udp443:'非按需 UDP443 到达包', '853':'四组 853 到达包',forward:'forward 兜底丢弃',input:'input 兜底丢弃'})[k],'包/s','nft','rate');
 add('gate','门控（1 开放 / 0 关闭）','','gate','gauge','min');add('probe_ok','探针成功','轮/s','gate','rate');add('probe_fail','探针失败','轮/s','gate','rate');add('probe_ms','采样期间探针最大耗时','ms','probe','gauge','max');
 add('core_fd','Xray 文件描述符','个','proc','gauge','max');add('core_uptime','核心运行时长','秒','proc','gauge');add('default_tcp','到默认节点已建立 TCP','条','proc','gauge','max');
 for(let p in [12345,12346,12347,12348]){add('recv_tcp_'+p,p+' TCP 待接连接','条','proc','gauge','max');add('recv_data_'+p,p+' TCP 接收队列','B','proc','gauge','max');add('recv_udp_'+p,p+' UDP 接收队列','B','proc','gauge','max');}
 add('conntrack','conntrack','条','system','gauge','max');add('tcp_retrans','全局 TCP 重传','次/s','system','rate');add('tcp_timeout','全局 TCP 超时','次/s','system','rate');
 add('cpu','CPU 使用率','%','system','computed','max');add('mem_used','已用内存','MiB','system','gauge','max');add('mem_available','可用内存','MiB','system','gauge','min');
 for(let n in [1,5,15])add('load'+n,n+' 分钟负载','','system','gauge','max');
 add('wan_up_state','WAN（1 在线 / 0 断开）','','net','gauge','min');return a;
}
function evaluate(values,defs){
 let v={};for(let i=0;i<length(defs);i++)v[defs[i].id]=values[i];let issues=[];
 if(v.gate==0)push(issues,'门控关闭');if(v.wan_up_state==0)push(issues,'WAN 断开');
 if(v.core_uptime==null)push(issues,'核心运行信息缺失');if(v.cpu!=null&&v.cpu>=85)push(issues,'CPU ≥85%');if(v.mem_available!=null&&v.mem_available<128)push(issues,'可用内存 <128MiB');
 for(let p in [12345,12346,12347,12348])if(v['recv_tcp_'+p]>0||v['recv_data_'+p]>65536||v['recv_udp_'+p]>65536){push(issues,'入口 '+p+' 接收队列积压');}
 if(v.gate==null)push(issues,'门控信息缺失');return issues;
}
function add_roll(bucket,row,defs){
 if(!bucket){bucket={start:row.mono,end:row.mono,wall:row.wall,count:0,values:[],weight:[],bad:[],sources:row.sources,epoch:row.epoch};}
 let dt=bucket.count?row.mono-bucket.end:5;bucket.end=row.mono;bucket.wall=row.wall;bucket.sources=row.sources;bucket.count++;
 for(let i=0;i<length(defs);i++){
  let v=row.values[i];if(v==null||dt<=0||dt>10){bucket.bad[i]=true;continue;}
  let how=defs[i].roll;
  if(how=='min')bucket.values[i]=bucket.values[i]==null?v:min(bucket.values[i],v);
  else if(how=='max')bucket.values[i]=bucket.values[i]==null?v:max(bucket.values[i],v);
  else{bucket.values[i]=(bucket.values[i]||0)+v*dt;bucket.weight[i]=(bucket.weight[i]||0)+dt;}
 }
 return bucket;
}
function finish_roll(b,defs){let a=[];for(let i=0;i<length(defs);i++){let v=b.values[i];push(a,b.bad[i]||v==null?null:round(defs[i].roll=='mean'?v*1.0/b.weight[i]:v));}return {mono:b.end,wall:b.wall,epoch:b.epoch,sources:b.sources,values:a,coverage:b.count};}

export { mono, round, delta, metric, definitions, evaluate, add_roll, finish_roll };

function min(a,b){return a<b?a:b;}
function max(a,b){return a>b?a:b;}
function abs(a){return a<0?-a:a;}
