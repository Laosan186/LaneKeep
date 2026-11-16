// Pure pagination; all rows are retained in one bounded 15-second RAM snapshot.
let MAX_JSON=2097152,MAX_WIRE=917504,TTL=15;
function max(a,b){return a>b?a:b;}
function ceil_div(n,d){return int((n+d-1)/d);}
function pad(n){return (n+3)&~3;}
function wire(k,v){
 let t=type(v),n=0;
 if(t=='array'){for(let a in v)n+=wire('',a);}
 else if(t=='object'){for(let name,a in v)n+=wire(name,a);}
 else if(t=='string')n=length(v)+1;else if(t=='bool')n=1;else if(t=='double')n=8;else if(t=='int')n=v>=-2147483648&&v<=2147483647?4:8;
 return pad(4+pad(2+length(k)+1)+n);
}
function wire_total(data){let n=4;for(let k,v in data)n+=wire(k,v);return n;}
function error(code,message){return {ok:false,code,message};}
function start(data,id,at,selection){
 if(!data?.ok)return data||error('read_failed','监控暂不可读');
 if(type(data.rows)!='array'||type(data.probes)!='array'||type(data.events)!='array')return error('read_invalid','监控历史格式不完整');
 if(length(data.rows)>1440||length(data.probes)>2048||length(data.events)>512)return error('read_capacity','历史数据超出已核实容量，未截断数据');
 let bytes=length(sprintf('%J',data));if(bytes>MAX_JSON)return error('read_capacity','历史读取缓存超过容量，未截断数据');
 let count=max(1,max(ceil_div(length(data.rows),360),max(ceil_div(length(data.probes),512),ceil_div(length(data.events),128))));
 return {ok:true,id,at,data,selection,json_bytes:bytes,page_count:count};
}
function page(cache,args,at){
 if(!cache?.ok||type(args?.read_id)!='string'||args.read_id!=cache.id||at<cache.at||at-cache.at>=TTL)return error('read_expired','本轮历史已过期，请完整重新读取');
 if(args.window!=cache.selection.window||args.snapshot!=cache.selection.snapshot||args.health_date!=cache.selection.health_date)return error('read_mismatch','历史读取范围已改变，请完整重新读取');
 let index=args.page;if(type(index)!='int'||index<0||index>=cache.page_count)return error('read_page','历史页码无效');
 let d=cache.data,out={...d,read_id:cache.id,page:index,page_count:cache.page_count,total_rows:length(d.rows),total_probes:length(d.probes),total_events:length(d.events),expires_in:max(0,TTL-(at-cache.at)),window_start:d.now-d.span,read_consistent:true,
  rows:slice(d.rows,index*360,(index+1)*360),probes:slice(d.probes,index*512,(index+1)*512),events:slice(d.events,index*128,(index+1)*128)};
 if(index!=0)delete out.latest;
 out.read_scope='完整历史按同一次内存快照分批读取；只拼接同一读取编号，缺页时不显示为完整';
 if(wire_total(out)>MAX_WIRE)return error('read_capacity','本页超过安全传输容量，未截断数据');
 return out;
}
function current(data){
 if(!data?.ok)return data||error('read_failed','监控暂不可读');
 let out={...data,window:'now',span:0,read_id:'',page:0,page_count:1,read_consistent:true,window_start:data.now,
  rows:slice(data.rows||[],-1),probes:slice(data.probes||[],-12),events:slice(data.events||[],-8),read_scope:'当前状态摘要：最近一条采样、最多十二轮检测和八条事件；完整历史在详细数据中分页读取'};
 out.total_rows=length(out.rows);out.total_probes=length(out.probes);out.total_events=length(out.events);
 if(wire_total(out)>MAX_WIRE)return error('read_capacity','当前状态超过安全传输容量，未截断指标');
 return out;
}
export {start,page,current,wire,wire_total,MAX_JSON,MAX_WIRE,TTL};
