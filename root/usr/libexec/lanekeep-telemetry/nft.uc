// Read-only NETLINK_NETFILTER subset for fixed aggregate counters and gate lease.
// Linux UAPI: GETTABLE=1, GETSETELEM=13, GETOBJ=19. Never RESET/NEW/DEL.
import * as socket from 'socket';
function mono(){let t=clock(true);return t[0]+t[1]/1e9;}
function le(v,n){let s='';for(let i=0;i<n;i++){s+=chr(v&255);v=v>>8;}return s;}
function uint(s,offset,n,big){if(type(s)!='string'||offset+n>length(s))die('short_integer');let v=0;if(big){for(let i=offset;i<offset+n;i++)v=v*256+ord(s,i);}else{for(let i=offset+n-1;i>=offset;i--)v=v*256+ord(s,i);}if(v<0||v>9007199254740991)die('integer_precision');return v;}
function attr(id,s){let n=4+length(s),pad=(4-n%4)%4;return le(n,2)+le(id,2)+s+substr('\0\0\0',0,pad);}
function attrs(s){let out=[];for(let i=0;i<length(s);){let n=uint(s,i,2,false),type=uint(s,i+2,2,false)&16383;if(n<4||i+n>length(s))die('attribute_length');push(out,{type,data:substr(s,i+4,n-4)});i+=((n+3)>>2)*4;}return out;}
function get(a,t){for(let x in a)if(x.type==t)return x.data;return null;}
function name(a,t){let s=get(a,t);if(!s||substr(s,-1)!='\0')die('name');return substr(s,0,length(s)-1);}
function query(){let conn=null;
 try{
  conn=socket.create(16,socket.SOCK_RAW|socket.SOCK_CLOEXEC,12);if(!conn)return null;
  let deadline=mono()+1.0,seq=0,out={nftables:[]};
  function request(kind,body,dump){
   if(index([1,13,19],kind)<0)die('read_only');let id=++seq,payload='\x01\x00\x00\x00'+body,request=le(16+length(payload),4)+le(2560+kind,2)+le(dump?769:1,2)+le(id,4)+le(0,4)+payload;
   if(conn.send(request,socket.MSG_DONTWAIT)!=length(request))die('send');let result=[],done=false,bytes=0;
   while(!done){let wait=int((deadline-mono())*1000);if(wait<=0||!length(socket.poll(wait,conn)||[]))die('deadline');let data=conn.recv(8192,socket.MSG_DONTWAIT);if(!data)die('recv');bytes+=length(data);if(bytes>32768)die('size_limit');
    for(let pos=0;pos<length(data);){let n=uint(data,pos,4,false),type=uint(data,pos+4,2,false),flags=uint(data,pos+6,2,false),seen=uint(data,pos+8,4,false);if(n<16||pos+n>length(data)||seen!=id||flags&16)die('message');let message=substr(data,pos+16,n-16);pos+=((n+3)>>2)*4;
     if(type==2){let errno=uint(message,0,4,false);if(errno==4294967294)return null;if(errno!=0)die('netlink_error');done=true;continue;}
     if(type==3){done=true;continue;}
     if(type!=2560+(kind==1?0:kind==13?12:18)||length(message)<4||ord(message,0)!=1)die('reply_type');push(result,attrs(substr(message,4)));if(!(flags&2))done=true;
    }
   }return result;
  }
  let table=request(1,attr(1,'lanekeep_phone\0'),false);if(!table||length(table)!=1||name(table[0],1)!='lanekeep_phone')die('table');push(out.nftables,{table:{name:'lanekeep_phone',handle:uint(get(table[0],4),0,8,true)}});
  for(let key in ['obs_udp443','obs_853','blocked_forward','blocked_input']){
   let r=request(19,attr(1,'lanekeep_phone\0')+attr(2,key+'\0')+attr(3,'\0\0\0\x01'),false);if(r==null)continue;
   if(length(r)!=1||name(r[0],1)!='lanekeep_phone'||name(r[0],2)!=key||uint(get(r[0],3),0,4,true)!=1)die('counter_identity');let v=attrs(get(r[0],4));push(out.nftables,{counter:{table:'lanekeep_phone',name:key,handle:uint(get(r[0],6),0,8,true),packets:uint(get(v,2),0,8,true),bytes:uint(get(v,1),0,8,true)}});
  }
  let elements=request(13,attr(1,'lanekeep_dns_gate\0')+attr(2,'healthy_data\0'),true);if(elements==null)die('gate_missing');let set={table:'lanekeep_dns_gate',name:'healthy_data',elem:[]};
  for(let row in elements){if(name(row,1)!='lanekeep_dns_gate'||name(row,2)!='healthy_data')die('gate_identity');for(let item in attrs(get(row,3)||'')){let e=attrs(item.data),key=attrs(get(e,1)||''),value=get(key,1),expires=get(e,5);if(value&&length(value)==4&&expires)push(set.elem,{val:uint(value,0,4,false),expires:uint(expires,0,8,true)});}}
  push(out.nftables,{set});conn.close();return out;
 }catch(e){if(conn)conn.close();return null;}
}
export { query };
