import * as policy from './subscription-policy.uc';
function bad(){die('fetch_failed');}
function bad_header_bytes(value){for(let i=0;i<length(value);i++){let n=ord(substr(value,i,1));if(n<=8||n>=10&&n<=31||n==127)return true;}return false;}
function head(raw){
 let at=index(raw,'\r\n\r\n');if(at<0){if(length(raw)>policy.LIMITS.headers)bad();return null;}
 if(at+4>policy.LIMITS.headers)bad();let lines=split(substr(raw,0,at),'\r\n'),m=match(lines[0],/^HTTP\/1\.[01] ([0-9]{3}) [^\r\n]*$/),headers={};if(!m)bad();
 for(let i=1;i<length(lines);i++){let p=index(lines[i],':');if(p<1||!match(substr(lines[i],0,p),/^[A-Za-z0-9-]+$/))bad();let key=lc(substr(lines[i],0,p)),value=trim(substr(lines[i],p+1));if(headers[key]!=null||bad_header_bytes(value))bad();headers[key]=value;}
 if(headers['content-encoding']!=null&&lc(headers['content-encoding'])!='identity')bad();
 let transfer=lc(headers['transfer-encoding']||'identity');if(index(['identity','chunked'],transfer)<0||transfer=='chunked'&&headers['content-length']!=null)bad();
 let size=null;if(headers['content-length']!=null){if(!match(headers['content-length'],/^[0-9]{1,8}$/))bad();size=int(headers['content-length']);if(size>policy.LIMITS.body)bad();}
 return {status:int(m[1]),offset:at+4,headers,transfer,size};
}
function parse_http(raw){
 let h=head(raw);if(!h||length(raw)-h.offset>policy.LIMITS.body)bad();let body=substr(raw,h.offset);
 if(h.transfer=='chunked'){
  let at=0,decoded='',complete=false,count=0;
  while(at<length(body)&&count++<32768){let end=index(substr(body,at),'\r\n');if(end<1||end>128)bad();let m=match(substr(body,at,end),/^([a-fA-F0-9]{1,8})(;[^\r\n]*)?$/);if(!m)bad();let n=int(m[1],16);at+=end+2;
   if(!n){if(substr(body,at)!='\r\n')bad();complete=true;break;}
   if(n>policy.LIMITS.body||length(decoded)+n>policy.LIMITS.body||at+n+2>length(body)||substr(body,at+n,2)!='\r\n')bad();decoded+=substr(body,at,n);at+=n+2;
  }if(!complete)bad();body=decoded;
 }else if(h.size!=null&&h.size!=length(body))bad();
 if(h.status==200&&!length(body))bad();return {status:h.status,body,location:h.headers.location,usage:policy.usage(h.headers['subscription-userinfo']),content_type:lc(h.headers['content-type']||'')};
}
function build_config(node,host,target_port,listen_port,address,channel){
 policy.addresses([address]);if(index(['proxy','direct'],channel)<0)bad();
 let tls={tag:'subscription-tls',protocol:'freedom',settings:{domainStrategy:'AsIs'},streamSettings:{network:'raw',security:'tls',tlsSettings:{serverName:host,alpn:['http/1.1'],allowInsecure:false},sockopt:{}}},outs=[tls];
 if(channel=='proxy'){
  let outbound=json(sprintf('%J',node));outbound.tag='subscription-node';outbound.streamSettings=outbound.streamSettings||{};outbound.streamSettings.sockopt={mark:30242};tls.streamSettings.sockopt.dialerProxy='subscription-node';push(outs,outbound);
 }else tls.streamSettings.sockopt.mark=30242;
 return {log:{access:'none',error:'none',loglevel:'none',dnsLog:false},inbounds:[{listen:'127.0.0.1',port:listen_port,protocol:'dokodemo-door',settings:{address,port:target_port,network:'tcp'}}],outbounds:outs};
}
export {head,parse_http,build_config};
