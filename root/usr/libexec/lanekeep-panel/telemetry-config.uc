// Observability only. No match, verdict, ordering, node or group changes.
function enable(config){
 if(config.api!=null||config.stats!=null||config.policy!=null)die('unexpected_statistics_baseline');
 config.stats={};config.api={tag:'lanekeep-stats-api',listen:'127.0.0.1:10085',services:['StatsService']};
 config.policy={system:{statsInboundUplink:true,statsInboundDownlink:true,statsOutboundUplink:true,statsOutboundDownlink:true}};
 return config;
}
function nft(text){
 let count=0;
 text=replace(text,'    counter blocked_input {}','    counter blocked_input {}\n    counter obs_udp443 {}\n    counter obs_853 {}');
 for(let g in ['phone','global','enhanced','ondemand']){
  let old='    chain capture_'+g+' {\n';
  if(index(text,old)<0)die('capture_anchor');
  let extra='        meta l4proto { tcp, udp } th dport 853 counter name obs_853\n';
  if(g!='ondemand')extra+='        udp dport 443 counter name obs_udp443\n';
  text=replace(text,old,old+extra);count++;
 }
 if(count!=4)die('capture_count');return text;
}

export { enable, nft };
