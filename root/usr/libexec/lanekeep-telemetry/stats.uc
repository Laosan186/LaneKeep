// Fixed loopback QueryStats client. No user API, reset, log, external connection,
// or general RPC facility. Bounded HTTP/2 + protobuf subset; fail closed on drift.
import * as socket from 'socket';
function mono(){let c=clock(true);return c[0]+c[1]/1e9;}
function b(s,i){if(i>=length(s))die('short_frame');return ord(s,i);}
function frame(t,f,id,s){let n=length(s);return chr((n>>16)&255,(n>>8)&255,n&255,t,f,0,0,0,id)+s;}
function vint(s,p,bits){let v=b(s,p.i++)&((1<<bits)-1);if(v<((1<<bits)-1))return v;let shift=0;while(shift<35){let x=b(s,p.i++);v+=(x&127)*(1<<shift);if(!(x&128))return v;shift+=7;}die('integer_limit');}
function str(s,p){let h=b(s,p.i)&128,n=vint(s,p,7);if(n>8192||p.i+n>length(s))die('header_limit');let x=substr(s,p.i,n);p.i+=n;return {h:!!h,s:x};}
function headers(s,state){
 let p={i:0};while(p.i<length(s)){
  let x=b(s,p.i),idx;
  if(x&128){idx=vint(s,p,7);if(idx==8)state.http=true;else if(idx>61||idx==0)die('dynamic_header');continue;}
  if(x&32 && !(x&64)){if(vint(s,p,5)!=0)die('dynamic_size');continue;}
  idx=vint(s,p,x&64?6:4);if(idx>61)die('dynamic_name');
  let name=idx==0?str(s,p):{h:false,s:idx==8?':status':idx==31?'content-type':''};let val=str(s,p);
  if(!name.h&&name.s==':status'&&!val.h&&val.s=='200')state.http=true;
  // RFC7541 Appendix B encoding of grpc-status; status zero is 00000 + EOS padding.
  if((!name.h&&name.s=='grpc-status')||(name.h&&name.s=='\x9a\xca\xc8\xb2\x12\x34\xda\x8f'))state.grpc=(!val.h&&val.s=='0')||(val.h&&val.s=='\x07');
 }
}
function pv(s,p){let n=0,shift=0;while(shift<63){let x=b(s,p.i++);n+=(x&127)*(1<<shift);if(!(x&128)){if(n>9007199254740991)die('counter_precision');return n;}shift+=7;}die('counter_limit');}
function field(s,p){let key=pv(s,p),wire=key&7,n;if(wire==0)return {n:key>>3,v:pv(s,p)};if(wire==2){n=pv(s,p);if(n>65535||p.i+n>length(s))die('protobuf_limit');let v=substr(s,p.i,n);p.i+=n;return {n:key>>3,v};}die('protobuf_wire');}
function decode(s){
 let p={i:0},out={};while(p.i<length(s)){let f=field(s,p);if(f.n!=1||type(f.v)!='string')die('protobuf_field');let a={i:0},name=null,value=0;while(a.i<length(f.v)){let x=field(f.v,a);if(x.n==1)name=x.v;else if(x.n==2)value=x.v;else die('stat_field');}
 if(type(name)!='string'||!match(name,/^(inbound|outbound)>>>[a-zA-Z0-9_-]{1,80}>>>traffic>>>(uplink|downlink)$/)||type(value)!='int'||value<0||length(keys(out))>=256)die('stat_not_aggregate');out[name]=value;}
 return out;
}
function query(port){
 if(port!=10085&&port!=19483)return null;let conn=null;
 try{
  let deadline=mono()+1.5;
  conn=socket.connect({address:'127.0.0.1',port},null,{family:socket.AF_INET,socktype:socket.SOCK_STREAM},200);if(!conn)return null;
  let path='/xray.app.stats.command.StatsService/QueryStats';
  let h='\x83\x86\x04'+chr(length(path))+path+'\x01\x09'+'127.0.0.1'+'\x0f\x10\x10'+'application/grpc'+'\x00\x02te\x08trailers';
  // Disable HPACK dynamic table; omit request fields => pattern empty, reset false.
  let request='PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n'+frame(4,0,0,'\x00\x01\x00\x00\x00\x00')+frame(1,4,1,h)+frame(0,1,1,'\x00\x00\x00\x00\x00');
  if(conn.send(request,socket.MSG_DONTWAIT)!=length(request))die('send');
  let buf='',data='',header='',end=false,pending=false,state={http:false,grpc:false},frames=0,total=0;
  while(!end){
   if(mono()>=deadline)die('deadline');
   if(length(buf)<9){let ev=socket.poll(int((deadline-mono())*1000),conn);if(!length(ev||[]))die('timeout');let part=conn.recv(16384,socket.MSG_DONTWAIT);if(!length(part||''))die('eof');buf+=part;total+=length(part);if(total>65536)die('response_limit');continue;}
   let n=b(buf,0)*65536+b(buf,1)*256+b(buf,2),t=b(buf,3),flags=b(buf,4),id=b(buf,8);if(n>32768||b(buf,5)||b(buf,6)||b(buf,7))die('frame_limit');
   if(length(buf)<9+n){let ev=socket.poll(int((deadline-mono())*1000),conn);if(!length(ev||[]))die('timeout');let part=conn.recv(16384,socket.MSG_DONTWAIT);if(!length(part||''))die('eof');buf+=part;total+=length(part);if(total>65536)die('response_limit');continue;}
   let payload=substr(buf,9,n);buf=substr(buf,9+n);if(++frames>64)die('frame_count');
   if(t==4){if(!(flags&1))conn.send(frame(4,1,0,''),socket.MSG_DONTWAIT);continue;}
   if(t==6){if(!(flags&1))conn.send(frame(6,1,0,payload),socket.MSG_DONTWAIT);continue;}
   if(t==7||t==3)die('reset');if(t==8)continue;if(id!=1)die('stream');
   if(t==0){if(flags&8){let pad=b(payload,0);payload=substr(payload,1,length(payload)-1-pad);}data+=payload;if(length(data)>60000)die('data_limit');if(flags&1)end=true;}
   else if(t==1||t==9){if(flags&8||flags&32)die('unsupported_header_padding');header+=payload;if(length(header)>16384)die('header_limit');if(flags&1)pending=true;if(flags&4){headers(header,state);header='';if(pending)end=true;}}
   else die('frame_type');
  }
  conn.close();conn=null;
  if(!state.http||!state.grpc||length(data)<5||b(data,0)!=0)die('grpc_status');
  let len=b(data,1)*16777216+b(data,2)*65536+b(data,3)*256+b(data,4);if(len!=length(data)-5)die('grpc_length');return decode(substr(data,5));
 }catch(e){if(conn)conn.close();return null;}
}

export { decode, query };
