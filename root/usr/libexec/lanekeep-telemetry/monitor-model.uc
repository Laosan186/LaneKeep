// Pure monitoring decisions. No I/O and no destination data in state.
let ports=[12345,12346,12347,12348];
function abs(v){return v<0?-v:v;}
function valid(v){return (type(v)=='int'||type(v)=='double')&&v>=0&&v<1e12;}
function blank(){return {last:null,queues:{},gate:0,fd_active:false,critical_seen:false,high_count:0,recovery:0,fd_warn:false};}
function queue(v,p){let seen=false,nonzero=false;for(let k in ['tcp','data','udp']){let n=v['recv_'+k+'_'+p];if(valid(n)){seen=true;if(n>0)nonzero=true;}}return seen?nonzero:null;}
function advance(s,p){
 let same=s.last&&s.last.boot==p.boot&&s.last.epoch==p.epoch&&p.mono-s.last.mono>0&&p.mono-s.last.mono<=7.5&&abs((p.wall-s.last.wall)-(p.mono-s.last.mono))<=2;
 if(!same){s.queues={};s.gate=0;s.high_count=0;s.recovery=0;}
 if(s.last&&(s.last.boot!=p.boot||s.last.epoch!=p.epoch)){s.fd_active=false;s.fd_warn=false;s.critical_seen=false;}
 let fd=valid(p.v.core_fd)?p.v.core_fd:null,critical=fd!=null&&valid(p.limit)&&p.limit>0&&fd>=p.limit*0.9,high=fd!=null&&fd>=2000;
 let triggers=[],reasons=[],queue_active={};
 if(fd==null){s.high_count=0;s.recovery=0;}
 else if(high||critical){s.high_count=same?s.high_count+1:1;s.recovery=0;
  if(!s.fd_active){push(reasons,critical?'fd_critical':'fd_absolute');s.fd_active=true;s.critical_seen=critical;}
  else if(critical&&!s.critical_seen){push(reasons,'fd_critical');s.critical_seen=true;}
 }else{s.high_count=0;if(fd<1500){s.recovery=same?s.recovery+(p.mono-s.last.mono):0;if(s.recovery>=30){s.fd_active=false;s.fd_warn=false;s.critical_seen=false;}}else s.recovery=0;}
 for(let port in ports){let nonzero=queue(p.v,port),old=s.queues[port]||0,count=nonzero==true?(same?old+1:1):0;s.queues[port]=count;queue_active[port]=nonzero==null?null:count>=2;if(count==2)push(triggers,'queue_'+port);}
 let gate_closed=valid(p.v.gate)&&p.v.gate==0;s.gate=gate_closed?(same?s.gate+1:1):0;if(s.gate==2)push(triggers,'gate_closed');
 if(high&&s.high_count>=2)s.fd_warn=true;
 let fd_reasons=[...reasons],request=null;
 if(length(reasons))request={priority:'fd',light:false,reasons:[...reasons,...triggers]};
 else if(length(triggers))request={priority:'aux',light:length(filter(triggers,x=>x!='gate_closed'))==0,reasons:triggers};
 s.last={wall:p.wall,mono:p.mono,boot:p.boot,epoch:p.epoch};
 return {request,fd_first:length(fd_reasons)>0,fd_absolute:fd==null?null:s.fd_warn,fd_critical:critical,fd_active:s.fd_active,queue_active,gate_active:s.gate>=2,triggers:[...fd_reasons,...triggers],continuous:!!same};
}
function slot(records,priority){let choices=priority=='fd'?['fd-0','fd-1']:['aux-0','aux-1'];for(let name in choices)if(!records[name])return name;return records[choices[0]].wall<=records[choices[1]].wall?choices[0]:choices[1];}
export {ports,valid,blank,queue,advance,slot};
