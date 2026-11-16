// Version 3 connection model. Pure validation, parsing and rendering; no I/O or dialing.
import * as caps from './caps.uc';

function bind(api) {
    function fail(code,key,message){api.fail(code,key,message);}
    function need(ok,code,key,message){if(!ok)fail(code,key,message);}
    function has(a,v){return index(a,v)>=0;}
    function copy(v){return json(sprintf('%J',v));}
    function dec(v,key){return api.decode(v,key);}
    function number(v,key,min,max){
        if(type(v)=='string'){need(match(v,/^[0-9]+$/)!=null,'param_invalid',key,'需要十进制整数');v=int(v);}
        need(type(v)=='int'&&v>=min&&v<=max,'param_invalid',key,'整数不在允许范围');return v;
    }
    function b64(v,key,binary){
        need(type(v)=='string'&&length(v)>0&&match(v,/^[A-Za-z0-9+\/_-]+={0,2}$/)!=null&&length(v)%4!=1,'base64_invalid',key,'Base64 格式不正确');
        let x=replace(replace(v,/-/g,'+'),/_/g,'/');
        if(index(x,'=')>=0)need(length(x)%4==0,'base64_invalid',key,'Base64 补位不正确');
        while(length(x)%4)x+='=';
        let value;try{value=b64dec(x);}catch(e){fail('base64_invalid',key,'Base64 无法解码');}
        need(type(value)=='string'&&b64enc(value)==x,'base64_invalid',key,'Base64 编码不规范');
        if(!binary)need(api.utf8_length(value)>=0&&!match(value,/[[:cntrl:]]/),'base64_invalid',key,'解码内容不是有效文本');
        return value;
    }
    function endpoint(server,port){
        need(api.str(server,253)&&length(server)>0,'param_invalid','server','服务器地址格式不正确');
        need(index(server,':')<0&&substr(server,0,1)!='[','address_unsupported','server','当前不接受 IPv6 服务器地址');
        if(match(server,/^[0-9.]+$/)){
            let p=split(server,'.');need(length(p)==4,'address_unsupported','server','不接受缩写或歧义地址');let a=[];
            for(let v in p){need(match(v,/^(0|[1-9][0-9]{0,2})$/)!=null&&int(v)<=255,'param_invalid','server','IPv4 地址格式不正确');push(a,int(v));}
            need(!(a[0]==0||a[0]==10||a[0]==127||a[0]>=224||a[0]==100&&a[1]>=64&&a[1]<=127||a[0]==169&&a[1]==254||a[0]==172&&a[1]>=16&&a[1]<=31||a[0]==192&&a[1]==168||a[0]==198&&a[1]>=18&&a[1]<=19),'address_unsupported','server','不接受回环、内网、链路本地、组播或 FakeIP 地址');
        }else{
            need(index(server,'.')>0,'address_unsupported','server','请输入完整服务器域名');
            for(let part in split(server,'.'))need(match(part,/^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/)!=null,'param_invalid','server','服务器域名格式不正确');
            need(!match(lc(server),/\.(localhost|local|lan|home|internal)$/),'address_unsupported','server','不接受本地域名');
        }
        number(port,'port',1,65535);
    }
    function authority(value,default_port){
        need(index(value,'[')<0&&index(value,']')<0,'address_unsupported','server','当前不接受 IPv6 服务器地址');
        let p=split(value,':');need(length(p)<=2&&length(p[0])>0,'param_invalid','server','地址与端口格式不正确');
        let out={server:p[0],port:length(p)==2?number(p[1],'port',1,65535):default_port};endpoint(out.server,out.port);return out;
    }
    function combo(n){
        let p=caps.get().protocols[n.protocol];if(!p)return null;
        let list=filter(p.combos,c=>!c.legacy&&c.security==n.security&&c.transport==n.transport&&(c.method==null||c.method==n.method));
        return length(list)==1?list[0]:null;
    }
    function published(n){let c=combo(n);return c!=null&&has(['trial','loopback','verified'],c.status);}
    function early_data(path){
        let pos=index(path,'?'),found=null;if(pos<0)return null;
        for(let p in split(substr(path,pos+1),'&')){
            if(!p)continue;let e=index(p,'='),key=dec(replace(e<0?p:substr(p,0,e),/\+/g,' '),'path');
            if(key!='ed')continue;
            need(found==null&&e>=0,'param_invalid','path','ed 参数不能重复或缺少值');
            let value=dec(replace(substr(p,e+1),/\+/g,' '),'path');found=number(value,'path',0,caps.get().limits.early_data_bytes);
        }
        return found;
    }
    function validate(n){
        let c=combo(n);if(!c&&n.protocol=='shadowsocks')fail('param_unsupported','method','不支持此加密方法');need(c!=null,'combo_unsupported','protocol','不支持此协议、安全与传输组合');
        for(let key in ['id','name','server','port',...c.required])need(n[key]!=null&&(type(n[key])!='string'||length(n[key])>0),'param_missing',key,'缺少必需字段');
        for(let key in keys(n)){
            need(has(c.fields,key),'param_unsupported',key,'此组合不接受该字段');
            let spec=caps.get().fields[key],value=n[key];
            need(spec!=null&&type(value)==spec.type,'param_invalid',key,'字段类型不正确');
            if(spec.type=='string')need(api.str(value,spec.max_bytes)&&api.utf8_length(value)>=0,'value_too_long',key,'字段超长或包含无效字符');
            if(spec.type=='int')number(value,key,spec.min,spec.max);
            if(spec.enum)need(has(spec.enum,value),'param_invalid',key,'字段取值不受支持');
            if(spec.type=='array'){
                need(length(value)<=spec.max_items,'limit_exceeded',key,'列表条目超过上限');
                for(let item in value)need(api.str(item,spec.item_max_bytes)&&match(item,/^[A-Za-z0-9.\/-]+$/)!=null,'param_invalid',key,'列表条目格式不正确');
            }
        }
        need(match(n.id,/^[a-z][a-z0-9_]{0,31}$/)!=null&&length(trim(n.name))>0,'param_invalid','name','节点编号或名称无效');endpoint(n.server,n.port);
        if(n.uuid!=null)need(match(n.uuid,/^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$/)!=null,'param_invalid','uuid','UUID 格式不正确');
        if(n.sni)need(match(n.sni,/^[A-Za-z0-9][A-Za-z0-9.-]*$/)!=null,'param_invalid','sni','SNI 格式不正确');
        if(n.fingerprint)need(match(n.fingerprint,/^[A-Za-z0-9_-]+$/)!=null,'param_invalid','fp','指纹格式不正确');
        if(c.flow)need(has(c.flow,n.flow||''),'combo_unsupported','flow','此传输不支持所选 Flow');
        if(c.modes)need(has(c.modes,n.mode??c.defaults.mode),'param_invalid','mode','传输模式不受支持');
        for(let key in ['host','authority'])if(n[key])need(match(n[key],/^[A-Za-z0-9][A-Za-z0-9.:-]*$/)!=null,'param_invalid',key,'Host 或 authority 格式不正确');
        if(n.path!=null){need(substr(n.path,0,1)=='/'&&substr(n.path,0,2)!='//'&&index(n.path,'#')<0&&index(n.path,'\\')<0,'param_invalid','path','路径须为本地绝对路径，不含片段或反斜杠');if(has(['ws','httpupgrade'],n.transport))early_data(n.path);}
        if(n.security=='reality'){
            need(match(n.public_key,/^[A-Za-z0-9_-]{43}$/)!=null,'param_invalid','pbk','REALITY 公钥格式不正确');
            need(match(n.short_id||'',/^([a-fA-F0-9]{2}){0,8}$/)!=null,'param_invalid','sid','Short ID 格式不正确');
            need(!n.mldsa65||match(n.mldsa65,/^[A-Za-z0-9_-]+$/)!=null,'param_invalid','pqv','ML-DSA 验证值格式不正确');
            if(n.spiderX!=null)need(substr(n.spiderX,0,1)=='/'&&!match(n.spiderX,/[[:cntrl:]\\]/)&&api.utf8_length(n.spiderX)>=1&&api.utf8_length(n.spiderX)<=256,'param_invalid','spx','REALITY 路径须为 1–256 字符且不含控制字符或反斜杠');
            if(n.import_hints!=null){let v=n.import_hints;need(type(v)=='object'&&length(keys(v))==1&&type(v.support_x25519mlkem768)=='bool'&&v.support_x25519mlkem768==true,'param_invalid','support-x25519mlkem768','兼容提示格式不正确');need(caps.hint_source_supported(n.fingerprint),'param_unsupported','fp','指纹未满足兼容要求，不会自动更改');}
        }
        if(n.protocol=='shadowsocks'&&substr(n.method,0,5)=='2022-'){
            let s=caps.get().protocols.shadowsocks.ss2022,parts=split(n.password,':');
            need(length(parts)<=s.max_key_segments,'limit_exceeded','password','密钥段数超过上限');
            if(n.method=='2022-blake3-chacha20-poly1305')need(length(parts)==1,'param_invalid','password','该方法只支持单段密钥');
            for(let key in parts){need(match(key,/^[A-Za-z0-9+/]+={0,2}$/)!=null&&length(key)%4==0,'param_invalid','password','2022 密钥须为标准 Base64');need(length(b64(key,'password',true))==s.key_bytes[n.method],'param_invalid','password','2022 密钥解码长度不正确');}
        }
        if(c.role=='rear_only'){
            let user=n.username||'',pass=n.password||'';
            need((length(user)>0)==(length(pass)>0),'param_invalid','username','用户名与密码须同时填写或同时留空');
            need(index(user,':')<0,'param_invalid','username','用户名不能包含冒号');
            if(n.protocol=='socks5')need(length(user)<=255&&length(pass)<=255,'value_too_long','password','SOCKS5 认证字段不得超过 255 字节');
        }
        return n;
    }
    function status(n){
        if(n.import_hints&&!caps.hint_allowed(n.fingerprint))return 'pending_verification';
        return published(n)?'ok':'pending_verification';
    }
    function render(n,context){
        validate(n);let c=combo(n);
        need(c.role!='rear_only'||c.direct_trial_reference==true||context=='chain_rear','role_restricted','protocol','后置节点不能生成独立出站');
        let out={protocol:n.protocol=='socks5'?'socks':n.protocol,settings:{},streamSettings:{network:n.transport,security:n.security}};
        if(n.protocol=='vless')out.settings={address:n.server,port:n.port,id:n.uuid,encryption:'none',flow:n.flow||''};
        else if(n.protocol=='vmess')out.settings={address:n.server,port:n.port,id:n.uuid,security:n.scy||'auto'};
        else if(n.protocol=='trojan')out.settings={address:n.server,port:n.port,password:n.password};
        else if(n.protocol=='shadowsocks')out.settings={address:n.server,port:n.port,method:n.method,password:n.password};
        else{out.settings={address:n.server,port:n.port};if(n.username){out.settings.user=n.username;out.settings.pass=n.password;}}
        let stream=out.streamSettings;
        if(n.security=='tls'){
            stream.tlsSettings={serverName:n.sni,allowInsecure:false};
            if(n.fingerprint)stream.tlsSettings.fingerprint=n.fingerprint;
            if(length(n.alpn||[]))stream.tlsSettings.alpn=copy(n.alpn);
        }else if(n.security=='reality'){
            let r={serverName:n.sni,fingerprint:n.fingerprint,publicKey:n.public_key,shortId:n.short_id||''};
            if(n.mldsa65)r.mldsa65Verify=n.mldsa65;if(n.spiderX!=null)r.spiderX=n.spiderX;stream.realitySettings=r;
        }
        if(n.transport=='ws')stream.wsSettings={path:n.path??'/',host:n.host||''};
        else if(n.transport=='httpupgrade')stream.httpupgradeSettings={path:n.path??'/',host:n.host||''};
        else if(n.transport=='grpc')stream.grpcSettings={serviceName:n.service_name||'',multiMode:(n.mode||'gun')=='multi',authority:n.authority||''};
        else if(n.transport=='xhttp')stream.xhttpSettings={path:n.path??'/',host:n.host||'',mode:n.mode||'auto'};
        return out;
    }
    function connection(n){
        validate(n);
        if(n.protocol=='vless'&&n.security=='reality'&&n.transport=='raw')return {fp_schema:1,protocol:'vless',combo:'vless-reality-raw',server:lc(n.server),port:n.port,sni:lc(n.sni),security:'reality',transport:'raw',auth:{uuid:lc(n.uuid),encryption:'none'},flow:n.flow||'',fp:n.fingerprint,reality:{public_key:n.public_key,short_id:lc(n.short_id||''),mldsa65:n.mldsa65||'',spiderX:n.spiderX??null},native_options:{mux:null,targetStrategy:null,reality_show:null},import_hints:n.import_hints||null};
        let c=combo(n),v={fp_schema:1,protocol:n.protocol,security:n.security,transport:n.transport};
        for(let key in c.fields){
            if(has(['id','name','protocol','security','transport'],key))continue;
            v[key]=n[key]??c.defaults[key]??null;
        }
        v.server=lc(n.server);if(n.sni)v.sni=lc(n.sni);if(n.uuid)v.uuid=lc(n.uuid);if(n.short_id)v.short_id=lc(n.short_id);
        if(has(['ws','httpupgrade'],n.transport))v.early_data_bytes=early_data(n.path??'/');
        return v;
    }
    function query(raw,protocol){
        let q={};for(let item in split(raw,'&')){
            if(!item)continue;let at=index(item,'=');need(at>0,'param_invalid','query','参数缺少名称或等号');
            let key=dec(substr(item,0,at),'query');need(match(key,/^[A-Za-z][A-Za-z0-9_-]{0,63}$/)!=null,'param_invalid','query','参数名格式不正确');
            need(!has(keys(q),key),'param_invalid',key,'参数重复');need(caps.classify(protocol,key)!='unknown','param_unsupported',key,'不支持此参数');
            q[key]=dec(substr(item,at+1),key);need(length(q[key])<=4096,'value_too_long',key,'参数超过长度上限');
        }return q;
    }
    function pair(value,key){let at=index(value,':');need(at>=0,'param_missing',key,'认证字段须包含明确分隔');return [substr(value,0,at),substr(value,at+1)];}
    function uri(line,protocol,port){
        let text=substr(line,index(line,'://')+3),name='',q='';let at=index(text,'#');
        if(at>=0){name=dec(substr(text,at+1),'name');text=substr(text,0,at);}
        at=index(text,'?');if(at>=0){q=substr(text,at+1);text=substr(text,0,at);}text=replace(text,/\/$/,'');
        let auth=null;at=index(text,'@');if(at>=0){need(index(substr(text,at+1),'@')<0,'param_invalid','credential','认证分隔有歧义，请使用百分号编码');auth=substr(text,0,at);text=substr(text,at+1);}
        let target=authority(text,port);return {server:target.server,port:target.port,credential:auth,name:name,params:query(q,protocol)};
    }
    function hints(n,q){
        if(q.spx!=null)n.spiderX=q.spx;
        if(q['support-x25519mlkem768']!=null){let v=q['support-x25519mlkem768'];need(has(['true','false'],v),'param_invalid','support-x25519mlkem768','兼容提示须为布尔字面量');need(v=='true','param_unsupported','support-x25519mlkem768','无已验证的独立关闭选项');n.import_hints={support_x25519mlkem768:true};}
    }
    function transported(protocol,u,number_id){
        let q=u.params,t=q.type||'raw';if(t=='tcp')t='raw';
        let security=q.security||(protocol=='trojan'?'tls':null);
        let n={id:'import_'+number_id,name:u.name||'导入节点 '+number_id,protocol:protocol,server:u.server,port:u.port,security:security,transport:t};
        need(u.credential!=null,'param_missing','credential','缺少认证字段');
        if(protocol=='vless'){
            need(q.encryption==null||q.encryption=='none','security_rejected','encryption','只接受 none 加密设置');n.uuid=dec(u.credential,'uuid');
            n.flow=q.flow??(security=='reality'&&t=='raw'?'xtls-rprx-vision':'');
        }else n.password=dec(u.credential,'password');
        for(let k in ['insecure','allowInsecure'])if(q[k]!=null)need(q[k]=='0','security_rejected',k,'不允许跳过证书验证');
        if(q.headerType!=null)need(t=='raw'&&q.headerType=='none','param_unsupported','headerType','只接受 raw 的 none 头部类型');
        if(security=='tls'){n.sni=q.sni||n.server;if(q.fp!=null)n.fingerprint=q.fp;if(q.alpn!=null)n.alpn=split(q.alpn,',');}
        else if(security=='reality'){
            need(q.alpn==null,'param_unsupported','alpn','固定 REALITY 模型不接受独立 ALPN 参数');
            n.sni=q.sni||n.server;n.fingerprint=q.fp||'chrome';n.public_key=q.pbk;n.short_id=q.sid||'';
            need(q.pqv==null||q.mldsa65Verify==null||q.pqv==q.mldsa65Verify,'param_invalid','pqv','别名参数冲突');n.mldsa65=q.pqv||q.mldsa65Verify||'';hints(n,q);
        }
        let mapped={path:'path',host:'host',serviceName:'service_name',mode:'mode',authority:'authority'};
        for(let k in keys(mapped))if(q[k]!=null)n[mapped[k]]=q[k];
        // Parameters understood by another combination must not be silently discarded.
        if(security!='reality')for(let k in ['pbk','sid','pqv','mldsa65Verify','spx','support-x25519mlkem768'])need(q[k]==null,'combo_unsupported',k,'此安全方式不接受该参数');
        validate(n);return n;
    }
    function flat_json(raw){
        need(api.utf8_length(raw)>=0,'param_invalid','vmess','JSON 编码不正确');let body=trim(raw);
        need(substr(body,0,1)=='{'&&substr(body,-1)=='}','param_invalid','vmess','需要扁平 JSON 对象');body=trim(substr(body,1,length(body)-2));let out={};
        while(length(body)){
            let k=match(body,/^("(?:[^"\\]|\\.)*")\s*:\s*/);need(k!=null,'param_invalid','vmess','JSON 键格式不正确');let key=json(k[1]);body=substr(body,length(k[0]));
            need(!has(keys(out),key),'param_invalid','vmess','JSON 参数重复');
            need(has(caps.get().protocols.vmess.json_keys,key),'param_unsupported',match(key,/^[A-Za-z][A-Za-z0-9_-]{0,63}$/)?key:'vmess','不支持此 JSON 参数');
            let v=match(body,/^("(?:[^"\\]|\\.)*"|-?(?:0|[1-9][0-9]*)|true|false|null)/);need(v!=null,'param_invalid',key,'JSON 值格式不正确');out[key]=json(v[1]);body=trim(substr(body,length(v[0])));
            if(!length(body))break;need(substr(body,0,1)==','&&length(trim(substr(body,1)))>0,'param_invalid','vmess','JSON 分隔不正确');body=trim(substr(body,1));
        }return out;
    }
    function vmess(line,number_id){
        let raw=b64(substr(line,8),'vmess',true),o=flat_json(raw);
        need(o.v==null||type(o.v)=='string'&&o.v=='2'||type(o.v)=='int'&&o.v==2,'param_invalid','v','仅接受版本 2 的 VMess 分享格式');
        for(let k in keys(o))if(!has(['port','aid','v'],k))need(type(o[k])=='string','param_invalid',k,'此 JSON 字段须为字符串');
        let t=o.net||'raw';if(t=='tcp')t='raw';let security=o.tls||'none';
        let n={id:'import_'+number_id,name:o.ps||'导入节点 '+number_id,protocol:'vmess',server:o.add,port:number(o.port,'port',1,65535),uuid:o.id,aid:number(o.aid??0,'aid',0,0),scy:o.scy||'auto',security:security,transport:t};
        if(security=='tls'){n.sni=o.sni||o.add;if(o.fp)n.fingerprint=o.fp;if(o.alpn)n.alpn=split(o.alpn,',');}
        else for(let k in ['sni','alpn','fp'])need(!o[k],'combo_unsupported',k,'无 TLS 组合不接受该字段');
        if(t=='grpc'){n.service_name=o.path||'';n.authority=o.host||'';n.mode=has(['gun','multi'],o.type)?o.type:'gun';need(!o.type||has(['none','gun','multi'],o.type),'param_unsupported','type','gRPC 模式不受支持');}
        else{need(!o.type||o.type=='none','param_unsupported','type','不接受伪装头');if(has(['ws','httpupgrade'],t)){n.path=o.path||'/';n.host=o.host||'';}else need(!o.path&&!o.host,'param_unsupported','path','此传输不接受路径或 Host');}
        validate(n);return n;
    }
    function shadowsocks(line,number_id){
        let rest=substr(line,5),name='',at=index(rest,'#');if(at>=0){name=dec(substr(rest,at+1),'name');rest=substr(rest,0,at);}
        let q='';at=index(rest,'?');if(at>=0){q=substr(rest,at+1);rest=substr(rest,0,at);}query(q,'shadowsocks');
        rest=replace(rest,/\/$/,'');let old=index(rest,'@')<0,encoded=false;
        if(old){rest=b64(rest,'ss',false);encoded=true;}
        let parts=split(rest,'@');need(length(parts)==2,'param_invalid','credential','认证分隔有歧义');
        let user=parts[0],credential;
        if(old)credential=pair(user,'password');
        else if(index(user,':')<0){credential=pair(b64(user,'password',false),'password');encoded=true;}
        else{let v=pair(user,'password');credential=[dec(v[0],'method'),dec(v[1],'password')];}
        let target=authority(parts[1],443),n={id:'import_'+number_id,name:name||'导入节点 '+number_id,protocol:'shadowsocks',server:target.server,port:target.port,security:'none',transport:'raw',method:credential[0],password:credential[1]};
        need(!encoded||substr(n.method,0,5)!='2022-','param_unsupported','userinfo','2022 分享格式须使用明文方法与百分号编码密钥');validate(n);return n;
    }
    function rear(line,protocol,number_id){
        let u;if(index(line,'://')>=0){let scheme=substr(line,0,index(line,'://'));need(protocol=='socks5'?has(['socks','socks5'],scheme):scheme=='http','combo_unsupported','scheme','协议与所选粘贴类型不符');u=uri(line,protocol,protocol=='socks5'?1080:8080);}
        else{
            let parts=split(line,':');need(length(parts)==2||length(parts)==4,'param_invalid','credential','快速粘贴只接受 host:port 或 host:port:user:pass，歧义字符请编码');
            u={server:parts[0],port:number(parts[1],'port',1,65535),name:'',credential:length(parts)==4?parts[2]+':'+parts[3]:null};
        }
        let n={id:'import_'+number_id,name:u.name||'导入节点 '+number_id,protocol:protocol,server:u.server,port:u.port,security:'none',transport:'raw'};
        if(u.credential!=null){let v=pair(u.credential,'username');need(index(v[1],':')<0,'param_invalid','password','认证分隔有歧义，请编码冒号');n.username=dec(v[0],'username');n.password=dec(v[1],'password');}
        if(protocol=='socks5')n.provider_udp=false;validate(n);return n;
    }
    function parse(line,number_id,quick){
        need(length(line)<=8192,'link_too_long','link','单条链接超过 8192 字节');
        if(quick){need(has(['socks5','http'],quick),'param_invalid','quick_protocol','快速粘贴类型无效');return rear(line,quick,number_id);}
        let at=index(line,'://'),scheme=substr(line,0,at);
        if(scheme=='vmess')return vmess(line,number_id);
        if(scheme=='ss')return shadowsocks(line,number_id);
        if(has(['socks','socks5','http'],scheme))return rear(line,scheme=='http'?'http':'socks5',number_id);
        need(has(['vless','trojan'],scheme),'scheme_unsupported','scheme','不支持此分享格式');
        return transported(scheme,uri(line,scheme,443),number_id);
    }
    return {endpoint:endpoint,combo:combo,validate:validate,published:published,status:status,render:render,connection:connection,parse:parse};
}
export { bind };
