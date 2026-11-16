// Pure subscription policy. No URL, credentials or upstream error text in errors.
let LIMITS={sources:8,items:500,body:2097152,cache:4194304,total:16777216,work:6291456,headers:16384,redirects:3,seconds:60,connect_seconds:10,rpc:65536,page:50};
let DEFAULT_UA='v2rayN';
function bad(code){die(code||'subscription_invalid');}
function uuid(v){return type(v)=='string'&&match(v,/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/)!=null;}
function source_id(v){return type(v)=='string'&&match(v,/^sub_[a-f0-9]{24}$/)!=null;}
function public_v4(value){
 if(type(value)!='string'||!match(value,/^(0|[1-9][0-9]{0,2})(\.(0|[1-9][0-9]{0,2})){3}$/))return false;
 let a=map(split(value,'.'),x=>int(x));for(let x in a)if(x>255)return false;
 // IANA special-use ranges, including documentation, benchmarking and FakeIP.
 if(a[0]==0||a[0]==10||a[0]==127||a[0]>=224||a[0]==100&&a[1]>=64&&a[1]<=127||a[0]==169&&a[1]==254||a[0]==172&&a[1]>=16&&a[1]<=31||a[0]==192&&a[1]==168)return false;
 if(a[0]==192&&(a[1]==0&&a[2]==0||a[1]==0&&a[2]==2||a[1]==88&&a[2]==99||a[1]==31&&a[2]==196||a[1]==52&&a[2]==193||a[1]==175&&a[2]==48)||a[0]==198&&(a[1]==18||a[1]==19||a[1]==51&&a[2]==100)||a[0]==203&&a[1]==0&&a[2]==113)return false;
 return true;
}
function addresses(values){
 if(type(values)!='array'||!length(values)||length(values)>64)bad('address_unsupported');let out=[];
 for(let ip in values){if(!public_v4(ip))bad('address_unsupported');if(index(out,ip)<0)push(out,ip);}return sort(out);
}
function url(value){
 if(type(value)!='string'||length(value)>4096||match(value,/[[:cntrl:][:space:]\\]/)||match(value,/%(0[0-9a-f]|1[0-9a-f]|7f)/i))bad('param_invalid');
 let m=match(value,/^https:\/\/([^\/?#]+)([^#]*)$/);if(!m)bad('security_rejected');
 let a=match(m[1],/^([A-Za-z0-9][A-Za-z0-9.-]*)(:([1-9][0-9]{0,4}))?$/);if(!a)bad('address_unsupported');
 let host=lc(a[1]),port=a[3]?int(a[3]):443,path=m[2]||'/';if(port>65535||substr(host,-1)=='.'||length(host)>253)bad('param_invalid');
 if(match(host,/^[0-9.]+$/)){if(!public_v4(host))bad('address_unsupported');}
 else {
  if(!match(host,/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/)||match(host,/(^|\.)(localhost|local|internal|home|lan|invalid|test|example|onion)$/)||match(host,/\.(localhost|local|home\.arpa)$/))bad('address_unsupported');
  for(let label in split(host,'.'))if(length(label)>63)bad('param_invalid');
  // Reject libc alternate numeric address notation instead of asking it to resolve.
  if(match(host,/(^|\.)(0x[0-9a-f]+|[0-9]+)$/))bad('address_unsupported');
 }
 if(substr(path,0,1)=='?')path='/'+path;if(substr(path,0,1)!='/')bad('param_invalid');
 return {host,port,path,origin:'https://'+host+(port==443?'':':'+port),value:'https://'+host+(port==443?'':':'+port)+path};
}
function redirect(current,location){
 if(type(location)!='string'||!length(location)||length(location)>4096||match(location,/[[:cntrl:][:space:]\\#]/))bad('security_rejected');
 if(match(location,/^[A-Za-z][A-Za-z0-9+.-]*:/))return url(location);
 if(substr(location,0,2)=='//')return url('https:'+location);
 let path=location;if(substr(path,0,1)=='?')path=split(current.path,'?')[0]+path;
 else if(substr(path,0,1)!='/'){let base=split(current.path,'?')[0],parts=split(base,'/');pop(parts);path=join('/',parts)+'/'+path;}
 let q=index(path,'?'),query=q>=0?substr(path,q):'',parts=[];
 for(let part in split(q>=0?substr(path,0,q):path,'/')){if(part=='.')continue;if(part=='..'){if(length(parts)>1)pop(parts);}else push(parts,part);}
 return url(current.origin+join('/',parts)+query);
}
function ua(value){value=value||DEFAULT_UA;if(type(value)!='string'||length(value)>256||match(value,/[[:cntrl:]]/))bad('param_invalid');return value;}
function usage(value){
 if(value==null)return null;if(type(value)!='string'||length(value)>1024)bad('param_invalid');let out={};
 for(let part in split(value,';')){let m=match(trim(part),/^(upload|download|total|expire)=([0-9]{1,16})$/);if(!m||out[m[1]]!=null)bad('param_invalid');let n=int(m[2]);if(n<0||n>9007199254740991)bad('param_invalid');out[m[1]]=n;}
 return out;
}
function source(input,old,revision,id,at,confirm_direct){
 if(type(input)!='object')bad('param_invalid');for(let k in keys(input))if(index(['id','name','url','ua','channel'],k)<0)bad('param_unsupported');
 let s={id:old?.id||id,name:input.name,url:input.url||old?.url,ua:ua(input.ua),channel:input.channel||'proxy',revision,created_at:old?.created_at||at};
 if(!source_id(s.id)||!uuid(revision)||type(s.name)!='string'||!length(trim(s.name))||length(s.name)>80||match(s.name,/[[:cntrl:]]/))bad('param_invalid');url(s.url);
 if(index(['proxy','direct'],s.channel)<0)bad('param_invalid');
 if(s.channel=='direct'&&old?.channel!='direct'&&confirm_direct!=true)bad('direct_confirmation_required');
 s.direct_confirmed=s.channel=='direct'&&(old?.direct_confirmed==true||confirm_direct==true);if(s.channel=='direct'&&!s.direct_confirmed)bad('direct_confirmation_required');return s;
}
export {LIMITS,DEFAULT_UA,uuid,source_id,public_v4,addresses,url,redirect,ua,usage,source};
