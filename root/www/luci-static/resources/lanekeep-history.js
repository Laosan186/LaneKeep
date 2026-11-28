'require lanekeep.i18n as lk';
'use strict';
'require baseclass';
'require rpc';
'require lanekeep as panel';
'require lanekeep-telemetry-client as telemetry';
function read(window,snapshot,healthDate){return telemetry.read(window,snapshot,healthDate);}
function plain(s){return String(s||'').replace(/TPROXY/g,lk.text("透明代理")).replace(/conntrack/g,lk.text("连接数")).replace(/门控/g,lk.text("保护开关")).replace(/Xray/g,lk.text("代理程序")).replace(/WAN/g,lk.text("外网")).replace(/代理程序句柄/g,lk.text("代理程序句柄"));}
var mark=rpc.declare({object:'lanekeep_telemetry',method:'mark',expect:{}});
var colors=["var(--lk-color-0c6d58)","var(--lk-color-c07625)","var(--lk-color-386db7)","var(--lk-color-b14d64)","var(--lk-color-675ca5)","var(--lk-color-65756e)"];
var eventNames={sampler_started:lk.text("采样启动"),gate_open:lk.text("保护开关开放"),gate_closed:lk.text("保护开关关闭"),core_start_attempt:lk.text("核心启动尝试"),core_restart_attempt:lk.text("核心重启尝试"),core_running:lk.text("核心运行"),core_rollback:lk.text("应用回退"),rules_apply:lk.text("规则应用"),wan_restored:lk.text("外网恢复"),wan_lost:lk.text("外网断开"),default_node_changed:lk.text("默认节点切换"),user_mark:lk.text("现在卡"),wall_clock_changed:lk.text("系统时钟校正")};
function svg(name,attrs,text){var e=document.createElementNS('http://www.w3.org/2000/svg',name);Object.keys(attrs||{}).forEach(function(k){e.setAttribute(k,attrs[k]);});if(text!=null)e.textContent=text;return e;}
function format(v,unit){if(v==null||!isFinite(v))return '—';if(unit==='B/s'||unit==='B'){var n=v,u=unit;['Ki','Mi','Gi'].some(function(p){if(n<1024)return true;n/=1024;u=p+(unit==='B/s'?'B/s':'B');return false;});return n.toFixed(n<10?2:1)+' '+u;}return (Math.abs(v)<10?v.toFixed(2):v.toFixed(1))+(unit?' '+unit:'');}
function clockLabel(w){return panel.foundation.time.plain(w);}
function axisLabel(w,span){return panel.foundation.time.axis(w,span>=43200);}
function t(zh,en){return lk.language==='en'?en:zh;}
function explainMetric(m){
 var fixed={
  gate:[lk.text("代理通道的保护开关。1 表示开放，0 表示关闭，受保护的流量会受到限制。"),lk.text("平时一般是 1；卡顿时如果变成 0，可对照下方探针和时间线，看看是不是检测失败触发了保护。")],
  wan_up_state:[lk.text("路由器对外上网接口的连接状态。1 表示接口在线，0 表示接口断开。"),lk.text("变成 0 时先关注外网连接；保持 1 只表示接口在线，不保证每个网站都能打开。")],
  probe_ms:[lk.text("路由器原有的小测试完成一轮需要多久。1000 ms 就是 1 秒；图上保留每个时间段中最慢的一轮。"),lk.text("比平时明显变高，说明这一轮检测变慢了。它不是你的网页打开耗时，也不是点击“测试默认节点”的结果。")],
  probe_ok:[lk.text("平均每秒有多少轮小测试成功。比如 0.5 轮/s，大约就是每 2 秒成功 1 轮。"),lk.text("这是成功的轮数，不是成功率；与失败轮数、保护开关状态一起看，不能把 0.5 理解成只成功了一半。")],
  probe_fail:[lk.text("平均每秒有多少轮小测试失败，包括未通过检查或没等到回应的轮次。"),lk.text("持续出现失败时值得关注；只有“0”才表示这段已采到的数据里没有失败，“—”表示没拿到数。")],
  nft_udp443:[lk.text("非按需组送到这段处理链的 UDP443 数据包。网页或视频可能使用这种传输方式；这里统计每秒来了多少个包。"),lk.text("这是包数，不是打开了几个网站，也不是拦截请求次数。一次连接可以产生很多包，不包含专用代理入口里面的端口流量。")],
  nft_853:[lk.text("四个组送到这段处理链、端口为 853 的数据包，常用于加密的域名查询。这里统计每秒来了多少个包。"),lk.text("一次查询可能产生多个包，所以不能当作查询次数；也不能代表所有加密 DNS 流量。")],
  nft_forward:[lk.text("转发兜底规则每秒实际丢掉多少个包。“转发”指路由器替设备把数据送往别处。"),lk.text("数字增加表示这条兜底保护在拦包；偶发增加不一定影响使用，若与卡顿同时持续升高，再结合保护开关和事件看。")],
  nft_input:[lk.text("接收兜底规则每秒实际丢掉多少个包。“接收”指数据送给路由器自身处理。"),lk.text("它只统计这条兜底规则，不是所有防火墙拦截的总数。持续升高且同时卡顿时值得进一步排查。")],
  tcp_retrans:[lk.text("整台路由器的 TCP 通信中，数据发出去后没收到确认、又重新发送的次数，按每秒计算。"),lk.text("偶尔重发很常见；若比平时持续高很多且同时卡顿，可能有丢包或拥堵。不能仅凭它判断是哪台设备或哪条线路。")],
  tcp_timeout:[lk.text("整台路由器的 TCP 通信中，等待回应超时的次数，按每秒计算。"),lk.text("它不是“多少个网页打不开”。持续升高时可结合重传、保护开关和队列一起看，单独这一项不能定位原因。")],
  cpu:[lk.text("整台路由器的处理器有多忙。这里把所有核心合起来看，100% 表示整体算力都很忙。"),lk.text("短暂升高很正常；持续接近满负荷并伴随卡顿才值得关注。页面从 85% 起提示异常，这个百分比不是网速。")],
  mem_used:[lk.text("目前已经占用、不能立即拿来用的内存。MiB 可以大致理解为常说的 MB，1 MiB 约等于 1.05 MB。"),lk.text("内存占用高不一定卡，要与“可用内存”一起看。关注它是否持续上涨、可用空间是否越来越少。")],
  mem_available:[lk.text("系统估计还能提供给程序使用的内存，包含可以回收利用的部分缓存。"),lk.text("数值越低，剩余余量越少；本页低于 128 MiB 会提示关注。这里说的是运行内存，不是存文件的闪存空间。")],
  conntrack:[lk.text("路由器正在跟踪的通信记录数，可以理解为它手里的“连接账本”。刚结束、等待过期的记录也可能还在。"),lk.text("一台设备可以产生很多条，所以这不是在线设备数，也不是正在打开的网站数。单看数量高低不能判断故障。")],
  core_fd:[lk.text("代理程序 当前占着多少个系统“句柄”，主要用来管理网络连接，也包含文件等资源。"),lk.text("可以理解为程序手里同时拿着多少张工作凭证；它不是设备数。通常随流量起落，持续增长且不回落时值得关注。")],
  default_tcp:[lk.text("代理程序 到默认节点服务器、目前已建立的 TCP 连接有多少条。"),lk.text("它不是使用代理的人数；空闲时少或为 0 都可能正常。有人上网却长期为 0，并且探针也失败时，再一起排查。")],
  core_uptime:[lk.text("当前这一轮 代理程序 核心已经连续运行多久。"),lk.text("重启后会重新计时；它和路由器开机时长不是一回事。")]
 };
 if(fixed[m.id])return fixed[m.id];
 var load=/^load(1|5|15)$/.exec(m.id);
 if(load)return [lk.text("过去 ")+load[1]+lk.text(" 分钟，平均有多少任务正在用处理器，或在等待处理器、磁盘等资源。"),lk.text("这不是百分比。1 分钟值更容易反映刚发生的变化，5/15 分钟值看持续趋势；单个数字不能直接换算成“卡不卡”。")];
 var queue=/^recv_(tcp|data|udp)_([0-9]+)$/.exec(m.id);
 if(queue){var group=({'12345':lk.text("常规组"),'12346':lk.text("全局 组"),'12347':lk.text("增强组"),'12348':lk.text("按需组")})[queue[2]]||lk.text("这条通道"),prefix=group+lk.text("的透明代理入口（")+queue[2]+'）。';
  if(queue[1]==='tcp')return [prefix+lk.text("已经建立连接、但还在排队等 代理程序 接手的 TCP 连接数。"),lk.text("通常应很快被接走；持续不为 0 或越来越多，说明新连接在排队，可能对应网页“等着打不开”。")];
  if(queue[1]==='data')return [prefix+lk.text("TCP 数据已经到达系统，但 代理程序 还没来得及读走的字节数。"),lk.text("短暂出现后回落通常只是正常排队；持续堆积才值得关注。B 是字节，KiB 约为常说的 KB，它不是每秒网速。")];
  return [prefix+lk.text("UDP 接收队列占用的空间，用来观察有没有数据积压；其中可能包含系统管理数据包的开销。"),lk.text("短暂起落不一定有问题；持续不回落时值得关注。它不是视频大小、丢包数量或网速，也不能直接与 TCP 队列作一比一比较。")];
 }
 var traffic=/^(wan|group_(standard|global|enhanced|ondemand)|out_(.+))_(up|down)$/.exec(m.id);
 if(traffic){var up=traffic[4]==='up',direction=up?lk.text("上传"):lk.text("下载"),meaning;
  if(traffic[1]==='wan')meaning=lk.text("路由器外网接口每秒")+(up?lk.text("向外发出"):lk.text("从外面收到"))+lk.text("的数据量，反映这条外网线路上的整体")+direction+lk.text("流量。");
  else if(traffic[2])meaning=({standard:lk.text("常规"),global:lk.mode('global'),enhanced:lk.text("增强"),ondemand:lk.text("按需")})[traffic[2]]+lk.text("组经 代理程序 处理的")+direction+lk.text("数据量，按每秒计算；包含该组已配置的专用代理入口，不包含绕过 代理程序 的流量。");
  else{var target=({'proxy-default':lk.text("默认代理节点的数据通道"),'dns-protected':lk.text("默认代理节点的域名查询通道"),'direct':lk.text("直接连接目标的出口，不经过代理节点"),block:lk.text("阻断出口")})[traffic[3]]||lk.text("指定节点 ")+traffic[3].replace(/^node-/,'');meaning=lk.text("经“")+target+'”'+(up?lk.text("发出去"):lk.text("收回来"))+lk.text("的数据量，按每秒计算。");}
  if(traffic[3]==='block')return [lk.text("原本想用它观察被阻断流量的字节数，但当前核心不能可靠提供这个数字。"),lk.text("显示“—”或不可采集，不用 0 来表示“没有拦截”。")];
  return [meaning,lk.text("KiB/s、MiB/s 可以大致理解为 KB/s、MB/s；这是当前用量，不是测速结果或带宽上限。看视频、下载时升高很正常。")+(traffic[1]==='wan'?lk.text("外网接口与 代理程序 的统计范围不同，数字不必完全相等。"):lk.text("这组数字与 WAN 的统计范围不同，不宜直接要求相加后完全一致。"))];
 }
 return [lk.text("这是按标注单位记录的聚合读数；“—”表示未取得可靠数据。"),lk.text("先对照卡顿发生的时间看变化，不能仅凭一个数字判断原因。")];
}
function explanations(metrics){
 return E('div',{'class':('lanekeep-chart-explanations')+" lk-legacy-1",'data-lk-style':"lk-legacy-1"},[
  E('dl',{'class':"lk-legacy-2"},metrics.reduce(function(items,m,k){var info=explainMetric(m);items.push(
   E('dt',{'data-metric':m.id,'class':'lk-metric-label lk-series-'+k%colors.length},m.label),
   E('dd',{'class':"lk-legacy-3"},info[0]),E('dd',{'class':"lk-legacy-4"},lk.text("怎么看：")+info[1])
  );return items;},[]))
 ]);
}
function chart(data,metrics,title,range,fold){
 var node=E('section',{'class':'lanekeep-history-chart lk-chart-card'}),defs=data.latest.defs,rows=data.rows||[],indices=metrics.map(function(m){return defs.indexOf(m);});
 node.appendChild(E('div',{'class':'lk-chart-head'},[E('h4',{},title),E('div',{'class':'lk-chart-legend'},metrics.map(function(m,k){return E('span',{'class':'lk-legend lk-series-'+k%colors.length},m.label);}))]));var picture=svg('svg',{viewBox:'0 0 960 175',role:'img','aria-label':title,'class':"lk-legacy-5"}),left=70,right=945,top=12,bottom=133,max=0;
 rows.forEach(function(r){indices.forEach(function(i){if(r.values[i]!=null&&r.mono>=range.start&&r.mono<=range.end)max=Math.max(max,r.values[i]);});});if(max<=0)max=1;
 function x(t){return left+(t-range.start)/(range.end-range.start)*(right-left);}
 for(var i=0;i<=3;i++){var y=top+(bottom-top)*i/3;picture.appendChild(svg('line',{x1:left,x2:right,y1:y,y2:y,stroke:"var(--lk-color-dfe9e5)"}));picture.appendChild(svg('text',{x:left-8,y:y+4,'text-anchor':'end',fill:"var(--lk-color-576a64)",'font-size':11},format(max*(3-i)/3,metrics[0].unit)));}
 for(var j=0;j<=4;j++){var at=range.start+(range.end-range.start)*j/4;picture.appendChild(svg('text',{x:x(at),y:158,'text-anchor':j===0?'start':j===4?'end':'middle',fill:"var(--lk-color-576a64)",'font-size':11},axisLabel(data.latest.wall-(data.latest.mono-at),range.end-range.start)));}
 (data.events||[]).forEach(function(e){if(e.mono<range.start||e.mono>range.end)return;var line=svg('line',{x1:x(e.mono),x2:x(e.mono),y1:top,y2:bottom,stroke:e.kind==='user_mark'?"var(--lk-color-c44d45)":"var(--lk-color-9bada4)",'stroke-dasharray':'3 3'});line.appendChild(svg('title',{},(eventNames[e.kind]||e.kind)+' · '+clockLabel(e.wall)));picture.appendChild(line);});
 metrics.forEach(function(m,k){var idx=indices[k],path='',connected=false,prev=null,step=data.window==='30m'||data.snapshot!=='none'?10:120;
  rows.forEach(function(r){var v=r.values[idx];if(r.mono<range.start||r.mono>range.end||v==null){connected=false;return;}if(prev!=null&&(r.mono-prev>step||r.mono<=prev))connected=false;path+=(connected?'L':'M')+x(r.mono).toFixed(2)+','+(bottom-(v/max)*(bottom-top)).toFixed(2)+' ';connected=true;prev=r.mono;});
  picture.appendChild(svg('path',{d:path,fill:'none',stroke:colors[k%colors.length],'stroke-width':1.7,'vector-effect':'non-scaling-stroke'}));
 });node.appendChild(picture);node.appendChild(fold('explain:'+title,t('这张图怎么看','How to read this chart'),[explanations(metrics)],false,'lk-tip'));return node;
}
function groups(defs,category){var list=[];function add(title,filter){var a=defs.filter(filter);if(a.length)list.push([title,a]);}
 if(category==='traffic'){add(lk.text("外网接口"),function(d){return /^wan_(up|down)$/.test(d.id);});['standard','global','enhanced','ondemand'].forEach(function(g){add(({standard:lk.text("常规"),global:lk.mode('global'),enhanced:lk.text("增强"),ondemand:lk.text("按需")})[g]+lk.text("组 · 代理程序 载荷"),function(d){return d.id.indexOf('group_'+g+'_')===0;});});var outs={};defs.filter(function(d){return d.id.indexOf('out_')===0&&d.id.indexOf('out_block_')!==0;}).forEach(function(d){var id=d.id.replace(/_(up|down)$/,'');(outs[id]||(outs[id]=[])).push(d);});Object.keys(outs).forEach(function(k){list.push([outs[k][0].label.replace(/上传$/,''),outs[k]]);});}
 if(category==='health'){add(lk.text("保护开关与外网"),function(d){return d.id==='gate'||d.id==='wan_up_state';});add(lk.text("每轮探针耗时 · 每分钟取最大值"),function(d){return d.id==='probe_ms';});add(lk.text("探针成败速率"),function(d){return /^probe_(ok|fail)$/.test(d.id);});add(lk.text("端口包计数与兜底丢弃"),function(d){return d.id.indexOf('nft_')===0;});add(lk.text("全局 TCP 重传 / 超时"),function(d){return /^tcp_/.test(d.id);});}
 if(category==='resources'){[['CPU',/^cpu$/],[lk.text("内存"),/^mem_/],[lk.text("负载"),/^load/],[lk.text("连接跟踪"),/^conntrack$/],[lk.text("代理程序句柄（FD）"),/^core_fd$/],[lk.text("默认节点 TCP"),/^default_tcp$/]].forEach(function(p){add(p[0],function(d){return p[1].test(d.id);});});}
 if(category==='queues')[12345,12346,12347,12348].forEach(function(p){add(p+lk.text(" TCP 监听队列"),function(d){return d.id==='recv_tcp_'+p;});add(p+lk.text(" TCP 数据队列"),function(d){return d.id==='recv_data_'+p;});add(p+lk.text(" UDP 队列"),function(d){return d.id==='recv_udp_'+p;});});return list;
}

var healthNames={fd_absolute:lk.text("代理程序句柄异常增高（≥2000）"),gate_closed:lk.text("健康检测未通过，保护开关关闭"),wan_down:lk.text("WAN 接口断开"),core_unknown:lk.text("未取得代理程序运行信息"),fd_high:lk.text("代理程序句柄接近上限（≥90%）"),fd_full:lk.text("代理程序句柄达到上限"),cpu_high:lk.text("整机 CPU ≥85%"),memory_low:lk.text("可用内存 <128 MiB"),stats_unavailable:lk.text("代理程序 聚合统计不可用"),metrics_incomplete:lk.text("关键运行指标缺失，不能判定正常"),observation_gap:lk.text("记录中断，期间运行情况未知"),clock_changed:lk.text("系统时钟变化，时间覆盖需核对")};
function healthName(code){var q=/^queue_(12345|12346|12347|12348)$/.exec(code);return q?lk.text("入口 ")+q[1]+lk.text(" 接收队列积压"):healthNames[code]||lk.text("未知记录类型");}
function healthTime(t){return panel.foundation.time.marker(t);}
function healthEvidence(e){var a=[],v=e.evidence||{};if(/^fd_/.test(e.code)&&e.peak!=null)a.push(lk.text("代理程序句柄峰值 ")+e.peak+(v.fd_limit!=null?lk.text(" / 上限 ")+v.fd_limit:''));if(/^queue_/.test(e.code)){if(v.tcp!=null)a.push(lk.text("TCP 待接峰值 ")+v.tcp+lk.text(" 条"));if(v.data!=null&&v.data>0)a.push(lk.text("TCP 数据峰值 ")+format(v.data,'B'));if(v.udp!=null&&v.udp>0)a.push(lk.text("UDP 队列峰值 ")+format(v.udp,'B'));}if(e.code==='cpu_high')a.push(lk.text("峰值 ")+format(e.peak,'%'));if(e.code==='memory_low')a.push(lk.text("最低 ")+format(e.peak,'MiB'));return a.join('；')||lk.text("按已采集状态记录；不推断具体线路或站点原因");}
function healthPanel(j,selected,onSelect){
 var box=E('section',{'class':('lanekeep-health-journal')+" lk-legacy-6",'data-lk-style':"lk-legacy-6"});
 if(!j){box.appendChild(panel.notice(lk.text("故障留存尚未启用；当前曲线仍为内存历史。")));return box;}
 box.appendChild(E('p',{},lk.text("保留 30 个日历日，重启后可查看。按 US 时间每日零点汇总前一天；今天仍在记录。只保留运行故障与必要数值，不含访问站点、目标 IP 或逐条连接。")));
 if(j.detail_error)box.appendChild(panel.notice(j.detail_error,true));
 if(!j.storage_ok)box.appendChild(panel.notice(lk.text("持久记录暂不可用；原有文件保留。当前显示不能视为已写入设备。"),true));
 var days=(j.days||[]).slice().reverse();if(!days.length){box.appendChild(E('p',{},lk.text("尚无运行记录。")));return box;}
 var chosen=days.find(function(d){return d.date===selected;})||days[0];
 var select=E('select',{'aria-label':lk.text("运行总结日期")},days.map(function(d){return E('option',{value:d.date,selected:d.date===chosen.date?'selected':null},d.date+(d.closed?'':lk.text(" · 记录中")));}));select.value=chosen.date;select.addEventListener('change',function(){onSelect(select.value);});box.appendChild(select);
 var counts=Object.keys(chosen.counts||{}).map(function(k){return healthName(k)+' '+chosen.counts[k]+lk.text(" 次");});
 var result=chosen.result==='normal'?lk.text("一切正常（全天已采集指标未发现异常）"):chosen.result==='incomplete'?lk.text("记录不完整，不能判定全天正常"):chosen.result==='issues'?lk.text("当天有运行异常"):lk.text("今天仍在记录");
 box.appendChild(E('p',{'class':"lk-legacy-7"},result));
 box.appendChild(E('p',{},lk.text("已覆盖 ")+panel.duration(chosen.observed)+lk.text(" / 当天 ")+panel.duration(chosen.end-chosen.start)+(chosen.incomplete?lk.text("；存在未覆盖时段。"):'。')));
 if(counts.length)box.appendChild(E('p',{},counts.join('；')));else if(!chosen.closed)box.appendChild(E('p',{},lk.text("已记录时段内暂未发现异常。")));
 if(chosen.overflow)box.appendChild(panel.notice(lk.text("当天明细达到 ")+j.detail_limit_per_day+lk.text(" 条上限；另有 ")+chosen.overflow+lk.text(" 条计入上面的分类次数。"),true));
 var rows=(chosen.events||[]).slice().reverse().map(function(e){var status=({active:lk.text("仍在发生"),recovered:lk.text("已恢复"),continued:lk.text("跨日继续"),unconfirmed:lk.text("恢复时间未确认")})[e.status]||lk.text("未知");return E('tr',{},[E('td',{},healthTime(e.start)),E('td',{},healthTime(e.end)),E('td',{},[E('strong',{},healthName(e.code)),E('div',{},healthEvidence(e))]),E('td',{},panel.duration(Math.floor(e.seconds))+(e.status==='unconfirmed'?lk.text("（已观测部分或记录间隔）"):'')),E('td',{},status)]);});
 if(rows.length)box.appendChild(E('div',{'class':"lk-legacy-8"},E('table',{'class':'table'},[E('tr',{},[lk.text("发生时间"),lk.text("恢复/边界时间"),lk.text("异常描述"),lk.text("持续时长"),lk.text("状态")].map(function(x){return E('th',{},x);} ))].concat(rows))));
 return box;
}


function monitorPanel(m){
 var box=E('section',{'class':('lanekeep-monitor-history')+" lk-legacy-6",'data-lk-style':"lk-legacy-6"});if(!m)return box;
 function table(headers,rows){return E('table',{'class':'table'},[E('tr',{},headers.map(function(x){return E('th',{},x);}))].concat(rows.map(function(row){return E('tr',{},row.map(function(x){return E('td',{},x==null?lk.text("缺测"):String(x));}));})));}
 function counts(title,o,labels){return E('p',{},title+'\uff1a'+Object.keys(o||{}).map(function(k){return ((labels||{})[k]||k)+' '+o[k];}).join(' / '));}
 var group={standard:lk.text("常规"),global:lk.mode('global'),enhanced:lk.text("增强"),ondemand:lk.text("按需"),direct:lk.mode('direct'),router:lk.text("路由器"),unknown:lk.text("未知")},dest={captured_original_public:lk.text("透明代理原始公网目标"),node_server:lk.text("节点服务器"),direct_public:lk.text("直连公网"),lan:lk.text("局域网/本机"),broadcast:lk.text("广播"),multicast:lk.text("组播"),public_unclassified:lk.text("公网（节点地址未解析）"),unknown:lk.text("未知")};
 box.appendChild(E('p',{},m.storage_ok?lk.text("代理程序句柄达到 2000 时单独保留快照；四组入口排队和保护开关按连续两次样本判断。"):lk.text("监控保存异常，不能据此判定正常。")));
 box.appendChild(E('p',{},lk.text("代理程序句柄专用 2 份快照；排队和保护开关共用另外 2 份，不会覆盖句柄快照。日峰值只覆盖已采样时段。")));
 box.appendChild(table([lk.text("日期"),lk.text("代理程序句柄采样峰值"),lk.text("峰值时间"),lk.text("句柄有效采样覆盖"),lk.text("间隔 / 缺测"),lk.text("实际记录范围")],(m.days||[]).slice().reverse().map(function(d){return [d.date,d.fd_peak,healthTime(d.fd_peak_at),panel.duration(Math.floor(d.covered_seconds||0)),d.gap_count||0,healthTime(d.first)+' \u2014 '+healthTime(d.last)];})));
 (m.snapshots||[]).slice().sort(function(a,b){return b.wall-a.wall;}).forEach(function(s){var c=s.connections||{},parts=[E('summary',{},healthTime(s.wall)+' \u00b7 '+(s.priority==='fd'?lk.text("代理程序句柄专用"):lk.text("排队 / 保护开关"))+lk.text(" · 代理程序句柄 ")+(s.fd==null?lk.text("缺测"):s.fd)),E('p',{},(s.reasons||[]).map(function(k){return k==='fd_critical'?lk.text("代理程序句柄达到上限的 90%"):k==='fd_absolute'?lk.text("代理程序句柄达到 2000"):healthName(k);}).join(' / '))];
  if(s.light)parts.push(E('p',{},lk.text("轻量快照：保护开关、代理程序句柄、入口排队情况及前后指标。")));
 else{parts.push(E('p',{},c.partial?lk.text("采集不完整；以下只是已读部分。"):lk.text("以下为 程序连接/连接跟踪条目，不等于代理内层请求数。")),counts(lk.language==='en'?'TCP connections by transparent entry':'各透明入口 TCP 连接',c.tcp_connections_by_entry),counts(lk.text("各设备组 TCP 连接"),c.tcp_connections_by_group,group),counts(lk.text("出站 程序连接 去向"),c.socket_destinations,dest),counts(lk.text("各设备组连接跟踪"),c.conntrack_by_group,group),counts(lk.language==='en'?'Conntrack entries by transparent entry':'各透明入口连接跟踪',c.conntrack_by_entry),counts(lk.text("节点 TCP 状态"),c.node_tcp_states),counts(lk.text("连接跟踪去向"),c.conntrack_destinations,dest));
 parts.push(table([lk.text("来源设备组"),lk.text("协议"),lk.text("目标端口类别"),lk.text("条目数")],(c.conntrack_top10||[]).map(function(t){return [group[t.group]||t.group,t.protocol,t.destination_port_class,t.count];})));}
 parts.push(E('p',{},lk.text("前后指标样本 ")+(s.window_samples||0)+'\uff1b'+(s.window_complete?lk.text("后窗口已结束"):lk.text("正在收集后窗口"))));box.appendChild(E('details',{},parts));});
 return box;
}

function render(initial,defaultNode){
 var host=E('div',{'class':'lanekeep-history lk-monitor'}),content=E('div',{'class':'lk-monitor-content'}),notice=E('div',{'role':'status'}),window='30m',snapshot='none',category='health',healthDay=null,data=initial,received=initial&&initial._received||performance.now(),timer=null,ticker=null,inFlight=false,disposed=false,failed=!initial,lastOld=null,opened={};
 // Content repaints every 5 s; keep each fold's open state across repaints.
 function fold(id,summary,body,defaultOpen,cls){var isTip=cls==='lk-tip',d=E('details',{'class':(cls||'lk-fold')+(isTip?'':' lk-disclosure'),open:(opened[id]!=null?opened[id]:defaultOpen)?'':null},[E('summary',{},isTip?[E('span',{'class':'lk-tip-icon','aria-hidden':'true'},'!'),E('span',{},summary)]:summary),E('div',{'class':isTip?'lk-tip-body':'lk-disclosure-body'},body)]);d.addEventListener('toggle',function(){opened[id]=d.open;});return d;}
 var windows=E('select',{'class':'cbi-input-select','aria-label':t('时间范围','Time range')},['30m','6h','24h'].map(function(w){return E('option',{value:w},({'30m':lk.text("过去 30 分钟"),'6h':lk.text("过去 6 小时"),'24h':lk.text("过去 24 小时")})[w]);}));
 var categoryButtons={},categories=E('div',{'class':('lanekeep-history-categories')+" lk-legacy-10",role:'group','aria-label':lk.text("图表分类"),'data-lk-style':"lk-legacy-10"});
 ['health','traffic','resources','queues'].forEach(function(c){var b=panel.button(({health:t('保护与网络质量','Protection & network'),traffic:t('流量','Traffic'),resources:t('系统资源','System resources'),queues:t('接收队列','Receive queues')})[c],function(){category=c;selectCategory();paint();});b.setAttribute('class','lanekeep-history-category');b.title=({health:lk.text("保护开关、拦截与 TCP"),traffic:lk.text("外网、四组与出口"),resources:lk.text("连接与系统资源"),queues:lk.text("四组接收队列")})[c];categoryButtons[c]=b;categories.appendChild(b);});
 function selectCategory(){Object.keys(categoryButtons).forEach(function(c){var selected=c===category,b=categoryButtons[c];b.setAttribute('aria-pressed',selected?'true':'false');b.classList.add('lk-chart-tab');});}
 var button=panel.button(lk.text("现在卡"),function(){button.disabled=true;mark().then(function(r){notice.replaceChildren(panel.notice(r.message||lk.text("标记未完成"),!r.ok));}).catch(function(){notice.replaceChildren(panel.notice(lk.text("标记请求失败，请先查看采样状态。"),true));}).finally(function(){button.disabled=false;refresh();});},true);
 button.title=t('觉得网络卡的时候点一下，图上会画一条红线，并保存前后 10 分钟的数据，方便对照。','Click when the network feels slow to mark the moment and keep 10 minutes of data around it.');
 host.append(E('span', {hidden:''}),E('div',{'class':'lk-monitor-toolbar'},[E('div',{'class':"lk-legacy-11"},categories),E('div',{'class':'lk-monitor-tools'},[windows,button])]),notice,content);selectCategory();
 function paint(){
  if(!data||!data.ok||!data.latest){lastOld=true;host.classList.toggle('lanekeep-history-stale',true);content.replaceChildren(panel.notice(data&&data.message||lk.text("监控停了：历史采样暂不可读。"),true));button.disabled=true;return;}
  var l=data.latest; l.defs=(l.defs||[]).map(function(d){return Object.assign({},d,{label:d.id==='conntrack'?lk.text("连接数"):d.id==='core_fd'?lk.text("代理程序句柄（FD）"):plain(d.label)});}); var now=data.now+(performance.now()-received)/1000,age=now-l.mono,issues=l.issues||[],old=failed||age>20,headline=old?lk.text("监控停了：样本超过 20 秒未更新或现在读不到；下面仅为最后读到的历史，不能代表现在正常"):issues.length?lk.text("异常：")+issues.map(function(i){return plain(i.message)+lk.text("，已观测持续 ")+Math.max(0,Math.floor(now-i.since))+lk.text(" 秒");}).join('；'):lk.text("正常：当前已采集指标未见异常");
  lastOld=old;host.classList.toggle('lanekeep-history-stale',old);button.disabled=old;var name=defaultNode&&defaultNode.id===l.default_node?defaultNode.name:l.default_node,uptimeIndex=l.defs.findIndex(function(d){return d.id==='core_uptime';}),uptime=l.row.values[uptimeIndex],restart=l.restarts==null?'—':String(l.restarts)+(l.restarts_partial?lk.text("（仅启用记录后）"):'');
  var state=old?'stale':issues.length?'warn':'ok',zone=panel.foundation.time.zoneName();
  var body=[E('div',{'class':'lk-monitor-status lk-state-'+state},[E('span',{'class':'lk-monitor-dot','aria-hidden':'true'}),E('div',{},[E('strong',{},headline),E('div',{'class':'lk-monitor-meta'},[
   E('span',{},lk.text("默认节点：")+(name||'—')),E('span',{},t('代理程序已运行 ','Core uptime ')+(uptime==null?'—':panel.duration(uptime))),E('span',{},t('开机以来重启尝试 ','Restart attempts ')+restart),E('span',{},t('最新采样 ','Latest sample ')+clockLabel(l.wall))])])])];
  body.push(fold('about',t('关于这些数据：保留多久、怎么读图','About this data and how to read the charts'),[
   panel.notice(plain(l.scope)),
   E('p',{},lk.text("5 秒数据保留 1 小时，1 分钟数据保留 24 小时；断电丢失。曲线空白表示缺值、计数归零或采样中断。此页不发外网探测。")),
   E('p',{},t('读图：从左到右是时间，各张图同一位置对应同一时刻。灰色竖虚线是当时发生的事件（悬停可看名称），红色竖线是“标记卡顿”。曲线空白表示没有可靠数据，不代表数值为 0。','Time runs left to right; dashed lines are events, red lines are your slowness marks. Gaps mean no reliable data, not zero.')),
   zone?E('p',{},t('页面时间均为路由器时区：','All times use the router time zone: ')+zone):null
  ].filter(Boolean),false,'lk-tip'));
  if(l.restarts_partial)body.push(panel.notice(lk.text("本次开机在启用记录前的重启次数未知；此处只显示已记录的启动尝试，不补造历史。")));
  var range={start:data.now-data.span,end:data.now};
  if(snapshot!=='none'){var snap=(l.snapshots||[]).find(function(s){return ''+s.slot===snapshot;});if(snap){range={start:snap.mark-600,end:snap.mark+600};body.push(panel.notice(lk.text("快照 ")+snapshot+'：'+(snap.complete?lk.text("前后对比已完成"):lk.text("正在收集标记后的 10 分钟"))+lk.text("；标记前不足 10 分钟时保留实际已有数据。")));}}
  if((l.snapshots||[]).length||snapshot!=='none'){var snapButtons=E('div',{'class':"lk-legacy-13 lk-snapshots"},[E('span',{'class':'lk-muted-line'},t('卡顿快照：','Slowness snapshots: '))]);(l.snapshots||[]).forEach(function(s){snapButtons.appendChild(panel.button(lk.text("快照 ")+s.slot+' · '+(s.complete?lk.text("完成"):lk.text("采集中")),function(){snapshot=''+s.slot;refresh();}));});if(snapshot!=='none')snapButtons.appendChild(panel.button(lk.text("返回时间线"),function(){snapshot='none';refresh();}));body.push(snapButtons);}
  var chartGroups=groups(l.defs,category),grid=E('div',{'class':'lk-chart-list'});chartGroups.forEach(function(g){grid.appendChild(chart(data,g[1],g[0],range,fold));});body.push(grid);
  var metrics=[];chartGroups.forEach(function(g){g[1].forEach(function(m){metrics.push(m);});});
  body.push(fold('readings',lk.text("当前读数与采样时间")+t('（'+metrics.length+' 项）',' ('+metrics.length+')'),[E('div',{'class':"lk-legacy-15"},E('table',{'class':'table'},[E('tr',{'class':'tr'},[lk.text("指标"),lk.text("数值"),lk.text("采样时间 / 新鲜度")].map(function(s){return E('th',{'class':'th'},s);})),].concat(metrics.map(function(m){var idx=l.defs.indexOf(m),at=l.row.sources[m.source],value=l.row.values[idx],stale=old||(at!=null&&now-at>20);return E('tr',{'class':'tr'},[E('td',{'class':'td'},m.label),E('td',{'class':'td'},format(value,m.unit)),E('td',{'class':'td'},at==null?'—':healthTime(l.wall-(l.mono-at))+(stale?lk.text(" · 过期"):' · '+Math.max(0,Math.floor(now-at))+lk.text(" 秒前")))]);}))))],false));
  var events=(data.events||[]).filter(function(e){return e.mono>=range.start&&e.mono<=range.end;}).slice(-30).reverse();
  body.push(fold('events',lk.text("时间线事件（最近 30 条）")+t(' · '+events.length+' 条',' · '+events.length),[events.length?E('ul',{'class':'lk-event-list'},events.map(function(e){return E('li',{},[E('span',{'class':'lk-event-time'},clockLabel(e.wall)),E('span',{},eventNames[e.kind]||e.kind)]);})):E('p',{'class':'lk-muted-line'},t('这段时间没有事件。','No events in this range.'))],false));
  if(category==='health'&&window==='30m'&&snapshot==='none'){var rounds=(data.probes||[]).filter(function(p){return p.mono>=range.start;});body.push(fold('probes',lk.text("每轮探针记录 · ")+rounds.length+lk.text(" 轮（仅聚合结果和耗时）"),[E('div',{'class':"lk-legacy-16"},E('table',{'class':'table'},rounds.slice().reverse().map(function(p){return E('tr',{},[E('td',{},healthTime(p.wall)),E('td',{},p.ok?lk.text("成功"):lk.text("失败")),E('td',{},p.ms+' ms')]);})))],false));}
  body.push(fold('health',lk.text("故障记录与每日运行总结"),[healthPanel(l.health,healthDay,function(d){healthDay=d;refresh();})],true));
  body.push(fold('monitor',lk.text("自动诊断与每日代理程序句柄峰值"),[monitorPanel(l.monitor)],false));
  if((l.unavailable||[]).length)body.push(E('p',{'class':'lk-muted-line'},lk.text("当前不能可靠采集的项目")+'：'+(l.unavailable||[]).map(plain).join('；')+lk.text("。显示“—”，不能由零字节推断没有拦截。")));
  content.replaceChildren.apply(content,body);
 } function schedule(){clearTimeout(timer);if(!document.hidden&&!disposed)timer=setTimeout(refresh,5000);}
 function refresh(){if(disposed)return;if(!host.isConnected){dispose();return;}if(document.hidden||inFlight){schedule();return;}inFlight=true;read(window,snapshot,healthDay||'').then(function(r){data=r;received=r&&r._received||performance.now();failed=!r||r.ok!==true;paint();}).catch(function(){failed=true;paint();notice.replaceChildren(panel.notice(lk.text("刷新失败；已有数字超过 20 秒会标为过期。"),true));}).finally(function(){inFlight=false;schedule();});}
 function visibility(){if(!host.isConnected){dispose();return;}clearTimeout(timer);if(!document.hidden)refresh();}
 function dispose(){disposed=true;clearTimeout(timer);clearInterval(ticker);document.removeEventListener('visibilitychange',visibility);}
 windows.addEventListener('change',function(){window=windows.value;snapshot='none';refresh();});document.addEventListener('visibilitychange',visibility);paint();schedule();ticker=setInterval(function(){if(disposed)return;if(!host.isConnected){dispose();return;}var old=failed||!data||!data.latest||data.now+(performance.now()-received)/1000-data.latest.mono>20;if(old!==lastOld)paint();},1000);return host;
}
return baseclass.extend({read:read,render:render,format:format,groups:groups,explainMetric:explainMetric,healthPanel:healthPanel,monitorPanel:monitorPanel});
