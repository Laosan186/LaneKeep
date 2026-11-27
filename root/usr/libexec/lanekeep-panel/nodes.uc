// Stage B private node model. No function returns credentials except to trusted local code.
import * as fs from 'fs';
import * as caps from './caps.uc';
import * as hashes from './node-fingerprint.uc';
import * as protocols from './protocol-model.uc';
import * as chain_model from './chain-model.uc';
import * as udp_model from './chain-udp.uc';
// ucode binds closures in source order; declare shared bindings before use.
let trial, minimum_version, validate_new_fields, display_name, canonical, changed_fields, modern, chains, udp;
let model_error=null;
function fail(code,param,message){model_error={code:code,param:param||'',message:message};die('node_validation');}
function take_error(){let e=model_error;model_error=null;return e;}
function require_value(ok,code,param,message){if(!ok)fail(code,param,message);}
function bad() { die('invalid_node_data'); }
function cp(x) { return json(sprintf('%J',x)); }
function str(x,n) { return type(x)=='string' && length(x)<=n && !match(x,/[[:cntrl:]]/); }
function member(a,v) { return index(a,v)>=0; }
function valid_node_id(id) { return str(id,32) && match(id,/^[a-z][a-z0-9_]{0,31}$/)!=null; }
function mask(v) { if(!v) return ''; return length(v)<=8?'********':substr(v,0,4)+'…'+substr(v,-4); }
let secrets=['username','uuid','password','public_key','short_id','mldsa65','obfs_password','spiderX'];
let fields=['id','name','protocol','server','port','uuid','password','sni','flow','fingerprint','public_key','short_id','mldsa65','alpn','insecure','obfs','obfs_password','spiderX','import_hints','security','transport','path','host','service_name','mode','authority','method','scy','aid','username','provider_udp','source','front','rear','udp','udp_expected_ip','hop_ports','pin_sha256','hop_interval','up_mbps','down_mbps'];
let hy2_fields=['hop_ports','pin_sha256','hop_interval','up_mbps','down_mbps'];
// HY2 share-link extensions are declared here, not in capabilities.json: user
// confirmations are bound to that file's hash and must survive this addition.
let hy2_params=['mport','pinSHA256'];
// Port union as in official Hysteria: comma list of ports or "a-b" ranges; mport also accepts "a:b".
// Returns the sorted, merged canonical text, or null for one port equal to the main port.
function hop_value(value,param,main,colon){
    let msg='端口跳跃须为端口或“起点-终点”区间，用逗号分隔';
    require_value(type(value)=='string'&&length(value)>0&&length(value)<=128,'param_invalid',param,msg);
    let parts=split(value,','),ranges=[],merged=[],total=0;
    require_value(length(parts)<=8,'limit_exceeded',param,'端口跳跃最多 8 段');
    for(let part in parts){
        let p=split(trim(part),colon?/[-:]/:'-'),last=p[length(p)-1];
        require_value(length(p)<=2&&match(p[0],/^[0-9]{1,5}$/)!=null&&match(last,/^[0-9]{1,5}$/)!=null,'param_invalid',param,msg);
        let a=int(p[0]),b=int(last);
        require_value(a>=1&&b<=65535&&a<=b,'param_invalid',param,'端口须在 1–65535 之间，区间起点不能大于终点');
        push(ranges,[a,b]);
    }
    for(let r in sort(ranges,(x,y)=>x[0]-y[0])){let top=length(merged)?merged[length(merged)-1]:null;if(top&&r[0]<=top[1]+1){if(r[1]>top[1])top[1]=r[1];}else push(merged,[r[0],r[1]]);}
    for(let r in merged)total+=r[1]-r[0]+1;
    if(total==1){require_value(merged[0][0]==main,'param_invalid',param,'端口跳跃至少需要两个端口');return null;}
    return join(',',map(merged,r=>r[0]==r[1]?sprintf('%d',r[0]):sprintf('%d-%d',r[0],r[1])));
}
// Official Hysteria normalizes the pin by lowercasing and removing ':' and '-'.
function pin_value(value,param){
    let msg='证书指纹须为 64 位十六进制 SHA-256，可带冒号';
    require_value(type(value)=='string'&&length(value)<=128,'param_invalid',param,msg);
    let v=lc(replace(value,/[:-]/g,''));
    require_value(match(v,/^[0-9a-f]{64}$/)!=null,'param_invalid',param,msg);return v;
}
// Form-only HY2 tuning: neither the official URI nor v2rayN links carry these values.
// Hop interval in seconds (Xray minimum 5); 30 is the default and is not stored.
function interval_value(value,param){
    let msg='跳跃间隔须为 5–3600 秒的整数',s=type(value)=='int'?sprintf('%d',value):value;
    let m=type(s)=='string'?match(lc(trim(s)),/^([0-9]{1,4}) *s?$/):null;
    require_value(m!=null,'param_invalid',param,msg);
    let v=int(m[1]);require_value(v>=5&&v<=3600,'param_invalid',param,msg);return v==30?null:v;
}
// Bandwidth in Mbps for Brutal congestion control, as in the official client.
function mbps_value(value,param){
    let msg='带宽须为 1–10000 的整数，单位 Mbps',s=type(value)=='int'?sprintf('%d',value):value;
    let m=type(s)=='string'?match(lc(trim(s)),/^([0-9]{1,5}) *(m|mbps)?$/):null;
    require_value(m!=null,'param_invalid',param,msg);
    let v=int(m[1]);require_value(v>=1&&v<=10000,'param_invalid',param,msg);return v;
}
function connection_only(n){let out=cp(n);delete out.source;return out;}
function source_valid(s){if(type(s)!='object'||length(keys(s))!=4||!match(s.id||'',/^sub_[a-f0-9]{24}$/)||!match(s.item_id||'',/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/)||type(s.id)!='string'||type(s.item_id)!='string'||type(s.fp_schema)!='int'||s.fp_schema!=1||type(s.fp)!='string'||!match(s.fp||'',/^[a-f0-9]{64}$/))fail('param_invalid','source','来源关联格式不正确');}
function extended(n){return !member(['vless','hysteria2'],n.protocol)||length(filter(['security','transport','path','host','service_name','mode','authority','method','scy','aid','username','provider_udp'],k=>member(keys(n),k)))>0;}
function role(n){return n.protocol=='chain'?'chain':'single';}
function combo(n){if(n.protocol=='chain')return null;return extended(n)?modern.combo(connection_only(n)):filter(caps.get().protocols[n.protocol]?.combos||[],c=>c.legacy==true)[0]||null;}
function available(n,store){if(n?.protocol=='chain')return chains.available(n,store);return extended(n)?modern.published(connection_only(n))&&(!n.import_hints||caps.hint_allowed(n.fingerprint)):!n.import_hints||caps.hint_allowed(n.fingerprint);}
function assert_reference(n,store){if(n?.protocol=='chain'){chains.validate(n,store,true);return;}if(!n)fail('param_invalid','node','指定节点不存在');if(role(n)=='rear_only')fail('role_restricted','node','后置节点不能直接用于规则、兜底、专用入口或默认出口');if(!available(n))fail('verification_pending','node','此组合尚未完成必要验证');}
function assert_default(n){if(n?.protocol=='chain'||member(['socks5','http'],n?.protocol))fail('role_restricted','default_node','链或 SOCKS5/HTTP 不能设为默认节点');if(trial(n))fail('trial_default_forbidden','default_node','未验证试用节点不能设为默认节点');assert_reference(n);}
function combo_id(n){if(n.protocol=='chain')return n.udp?'chain-udp':'chain-tcp';return extended(n)?modern.combo(connection_only(n))?.id:n.protocol=='vless'?'vless-reality-raw':'hysteria2-tls';}
function render(n) {
    if(n.protocol=='chain')fail('role_restricted','chain','链必须使用专用生成器');
    if(extended(n))return modern.render(connection_only(n));
    let out=n.native_outbound?cp(n.native_outbound):{};
    if(n.protocol=='vless') {
        out.protocol='vless';out.settings=out.settings || {};
        // Preserve native flat/vnext encoding and all pre-existing non-credential options.
        if(out.settings.vnext) {
            let v=out.settings.vnext[0],u=v.users[0];v.address=n.server;v.port=n.port;u.id=n.uuid;u.encryption='none';u.flow=n.flow;
        } else {out.settings.address=n.server;out.settings.port=n.port;out.settings.id=n.uuid;out.settings.encryption='none';out.settings.flow=n.flow;}
        out.streamSettings=out.streamSettings || {};out.streamSettings.network=out.streamSettings.network || 'raw';out.streamSettings.security='reality';
        let r=out.streamSettings.realitySettings || {};r.serverName=n.sni;r.fingerprint=n.fingerprint;r.publicKey=n.public_key;r.shortId=n.short_id;
        if(n.mldsa65) r.mldsa65Verify=n.mldsa65;else delete r.mldsa65Verify;
        if(n.spiderX!=null) r.spiderX=n.spiderX;
        out.streamSettings.realitySettings=r;
    } else {
        out.protocol='hysteria';out.settings={version:2,address:n.server,port:n.port};
        out.streamSettings={network:'hysteria',security:'tls',tlsSettings:{serverName:n.sni},hysteriaSettings:{version:2,auth:n.password}};
        if(length(n.alpn || [])) out.streamSettings.tlsSettings.alpn=n.alpn;
        // Xray 26.10.21 checks every handshake against the pin; a leaf match replaces CA validation.
        if(n.pin_sha256) out.streamSettings.tlsSettings.pinnedPeerCertSha256=n.pin_sha256;
        // Official Hysteria hopping: random first port, new local socket and port every interval (30 s default).
        // udphop must stay the last finalmask.udp entry; remoteIPs would replace the server address.
        if(n.hop_ports) out.streamSettings.finalmask={udp:[{type:'udphop',settings:{mode:'intervalLocal,intervalRemote',interval:n.hop_interval??30,remotePorts:n.hop_ports}}]};
        // Xray's default congestion: Brutal at min(up, server receive rate) when both are known, else BBR
        // (the official client would use up alone when the server reports none); down is sent to the
        // server as this client's receive rate.
        if(n.up_mbps||n.down_mbps){let q={};if(n.up_mbps)q.brutalUp=sprintf('%dmbps',n.up_mbps);if(n.down_mbps)q.brutalDown=sprintf('%dmbps',n.down_mbps);if(!out.streamSettings.finalmask)out.streamSettings.finalmask={};out.streamSettings.finalmask.quicParams=q;}
        // Fixed Xray version has not validated obfuscation extensions. Reject rather than drop.
    }
    delete out.tag;delete out.streamSettings.sockopt;
    return out;
}
function validate_store(store) {
    if(type(store)!='object' || type(store.version)!='int' || !member([1,2,3,4,5,6,7],store.version) || (store.default_node!='' && !valid_node_id(store.default_node)) || type(store.nodes)!='array' || length(store.nodes)>21) bad();
    for(let k in keys(store)) if(!member(['version','default_node','nodes'],k)) bad();
    if(length(sprintf('%J\n',store))>524288)fail('limit_exceeded','nodes','面板试用节点库最多 21 条 / 512 KiB');
    if(store.version<4&&(length(store.nodes)>21||length(sprintf('%J\n',store))>524288))fail('param_invalid','version','扩大容量需要节点库版本 4');
    let ids={},names={},found=false;
    for(let n in store.nodes) {
        if(type(n)!='object') bad();
        if(n.protocol=='chain'){if(store.version<minimum_version(n))fail('param_invalid','version','链字段需要匹配的节点库格式');chains.shape(n);if(ids[n.id]||names[n.name])fail('param_invalid','name','节点编号或名称重复');ids[n.id]=true;names[n.name]=true;if(n.id==store.default_node)found=true;continue;}
        for(let k in ['front','rear','udp','udp_expected_ip','udp_verification'])if(member(keys(n),k))fail('param_unsupported',k,'普通节点不接受链字段');
        if(member(keys(n),'source')){source_valid(n.source);if(store.version<4)fail('param_invalid','version','来源关联需要节点库版本 4');}
        if(extended(n)){
            if(store.version<3)fail('param_invalid','version','扩展字段需要节点库版本 3');modern.validate(connection_only(n));
            if(ids[n.id]||names[n.name])fail('param_invalid','name','节点编号或名称重复');
            ids[n.id]=true;names[n.name]=true;if(n.id==store.default_node)found=true;continue;
        }
        for(let k in keys(n)) if(!member(fields,k) && k!='native_outbound') bad();
        if(minimum_version(n)>store.version)fail('param_invalid','version','新字段需要匹配的节点库版本');
        validate_new_fields(n,false);
        if(!valid_node_id(n.id) || ids[n.id] || !str(n.name,80) || !length(trim(n.name)) || names[n.name]) bad();
        ids[n.id]=true;names[n.name]=true;if(n.id==store.default_node) found=true;
        if(!member(['vless','hysteria2'],n.protocol) || !str(n.server,253) || !match(n.server,/^[A-Za-z0-9][A-Za-z0-9.:-]*$/) || type(n.port)!='int' || n.port<1 || n.port>65535) bad();
        if(!str(n.sni,253) || !match(n.sni,/^[A-Za-z0-9][A-Za-z0-9.-]*$/)) bad();
        for(let k in secrets) if(n[k]!=null && !str(n[k],4096)) bad();
        if(n.protocol=='vless') {
            if(!match(n.uuid || '',/^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$/) || !member(['xtls-rprx-vision','xtls-rprx-vision-udp443'],n.flow) || !str(n.fingerprint,32) || !match(n.fingerprint,/^[a-zA-Z0-9_-]+$/) || !match(n.public_key || '',/^[A-Za-z0-9_-]{43}$/) || !match(n.short_id || '',/^([a-fA-F0-9]{2}){0,8}$/)) bad();
            if(n.mldsa65 && !match(n.mldsa65,/^[A-Za-z0-9_-]+$/)) bad();
            if(n.native_outbound!=null) {
                let o=n.native_outbound;
                for(let k in keys(o)) if(!member(['protocol','settings','streamSettings','mux','targetStrategy','sendThrough'],k)) bad();
                if(o.protocol!='vless' || o.streamSettings?.security!='reality' || !member(['raw','tcp'],o.streamSettings?.network) || o.streamSettings?.sockopt!=null || o.proxySettings!=null || o.sendThrough!=null) bad();
                for(let k in keys(o.streamSettings)) if(!member(['network','security','realitySettings','rawSettings','tcpSettings'],k)) bad();
            }
        } else {
            if(!length(n.password || '') || n.obfs || n.obfs_password || n.native_outbound!=null) bad();
            if(n.insecure!=null && (type(n.insecure)!='bool' || n.insecure==true)) bad();
            if(n.alpn!=null) {if(type(n.alpn)!='array' || length(n.alpn)>8) bad();for(let a in n.alpn) if(!str(a,40)||!match(a,/^[a-zA-Z0-9.\/-]+$/)) bad();}
        }
    }
    if(store.default_node!=''){if(!found)bad();assert_default(filter(store.nodes,n=>n.id==store.default_node)[0]);}for(let n in store.nodes)if(n.protocol=='chain')chains.validate(n,store,false);return store;
}
function read_store(path) {
    if(fs.lstat(path)?.type!='file' || fs.stat(path).size>524288) bad();
    let store=json(fs.readfile(path));if(store.version<4&&fs.stat(path).size>524288)bad();return validate_store(store);
}
function migrate(config) {
    let outs=filter(config.outbounds,o=>o.tag=='proxy-default');if(length(outs)!=1) bad();let o=cp(outs[0]);delete o.tag;delete o.streamSettings.sockopt;
    let s=o.settings,v=s.vnext?s.vnext[0]:s,u=s.vnext?v.users[0]:s,r=o.streamSettings.realitySettings;
    return validate_store({version:1,default_node:'a',nodes:[{id:'a',name:'节点 A',protocol:'vless',server:v.address,port:v.port,uuid:u.id,sni:r.serverName,flow:u.flow,fingerprint:r.fingerprint,public_key:r.publicKey,short_id:r.shortId || '',mldsa65:r.mldsa65Verify || '',native_outbound:o}]});
}
function public_node(n,store) {
 if(n.protocol=='chain'){let by=chain_model.map_nodes(store),ready=available(n,store);return {id:n.id,name:n.name,protocol:'chain',front:n.front,rear:n.rear,udp:n.udp,udp_expected_ip:n.udp_expected_ip||'',udp_test_valid:udp.stamp_valid(n,store),udp_capable:udp.ready(by[n.front],by[n.rear]),role:'chain',model_version:minimum_version(n),extended_model:false,combo:n.udp?'chain-udp':'chain-tcp',capability_status:ready?(trial(n,store)?'trial':'verified'):'pending',single_allowed:false,default_allowed:false,route_allowed:ready,test_allowed:ready,chain_front_allowed:false,chain_rear_allowed:false,composition:{front:{id:n.front,name:display_name(by[n.front]?.name||'')},rear:{id:n.rear,name:display_name(by[n.rear]?.name||''),protocol:by[n.rear]?.protocol}},notice:n.udp?'承载原规则允许且实际命中此链的 TCP/UDP；原保护保持':'仅命中链的 TCP；匹配链的 UDP 阻断'};}
 let v={};for(let k in fields) if(n[k]!=null) v[k]=k=='source'?{id:n.source.id}:member(secrets,k)?mask(n[k]):cp(n[k]);v.extended_model=extended(n);v.role=role(n);v.combo=combo_id(n);v.model_version=minimum_version(n);v.capability_status=available(n)?(trial(n,store)?'trial':extended(n)?modern.combo(connection_only(n)).status:'legacy_preserved'):'pending';v.single_allowed=role(n)!='rear_only'&&available(n);v.default_allowed=v.single_allowed&&!trial(n,store)&&!member(['socks5','http'],n.protocol);v.route_allowed=v.single_allowed;v.test_allowed=v.single_allowed;v.chain_front_allowed=chains.role_ready(n,'chain_front');v.chain_rear_allowed=chains.role_ready(n,'chain_rear');return v;}
function update_node(input,previous) {
    if(type(input)!='object') bad();let n=previous?cp(previous):{};
    for(let k in keys(input)) {
        if(!member(fields,k)) bad();
        if(k=='source'){if(input[k]!=null)fail('param_invalid','source','来源关联只由缓存导入建立；可明确清除');delete n.source;continue;}
        if(member(['socks5','http'],n.protocol)&&member(['username','password'],k)&&input.username==null&&input.password==null&&member(keys(input),'username')&&member(keys(input),'password')){delete n.username;delete n.password;continue;}
        if(k=='import_hints'&&input[k]==null){delete n.import_hints;continue;}
        if(member(hy2_fields,k)&&(input[k]==null||input[k]=='')){delete n[k];continue;}
        if(k=='spiderX'&&input[k]==''&&(!previous||previous.spiderX==null))continue;
        if(member(secrets,k) && input[k]=='' && previous) continue;n[k]=input[k];
    }
    if(previous && n.protocol!=previous.protocol) bad();
    // Form input is normalized like a share link; validate_store then accepts only canonical text.
    if(n.protocol=='hysteria2'&&!extended(n)){
        if(member(keys(input),'hop_ports')&&n.hop_ports!=null){let v=hop_value(n.hop_ports,'hop_ports',n.port,true);if(v==null)delete n.hop_ports;else n.hop_ports=v;}
        if(member(keys(input),'pin_sha256')&&n.pin_sha256!=null)n.pin_sha256=pin_value(n.pin_sha256,'pin_sha256');
        if(member(keys(input),'hop_interval')&&n.hop_interval!=null){let v=interval_value(n.hop_interval,'hop_interval');if(v==null)delete n.hop_interval;else n.hop_interval=v;}
        for(let k in ['up_mbps','down_mbps'])if(member(keys(input),k)&&n[k]!=null)n[k]=mbps_value(n[k],k);
        // The interval belongs to hopping; clearing the hop ports clears it too.
        if(n.hop_ports==null)delete n.hop_interval;
    }
    if(n.protocol=='chain'){if(!n.udp){delete n.udp_verification;delete n.udp_expected_ip;}chains.shape(n);return n;}
    if(extended(n)&&previous){
        if(previous.native_outbound)fail('combo_unsupported','node','现有原生节点不能隐式转换组合，请新增条目');
        let c=modern.combo(connection_only(n));if(c){for(let key in keys(input))if(!member(c.fields,key)&&key!='import_hints'&&key!='source')fail('param_unsupported',key,'此组合不接受该字段');for(let key in keys(n))if(!member(c.fields,key)&&key!='source')delete n[key];}
    }
    return n;
}
// Byte-aware UTF-8 validation, used only for new input limits.
function utf8_length(s){
    let count=0;
    for(let i=0;i<length(s);i++){
        let b=ord(substr(s,i,1)),extra=0,point=b,min=0;
        if(b<128){}else if(b>=194&&b<=223){extra=1;point=b&31;min=128;}
        else if(b>=224&&b<=239){extra=2;point=b&15;min=2048;}
        else if(b>=240&&b<=244){extra=3;point=b&7;min=65536;}else return -1;
        for(let j=0;j<extra;j++){i++;if(i>=length(s))return -1;let c=ord(substr(s,i,1));if(c<128||c>191)return -1;point=(point<<6)|(c&63);}
        if(point<min||point>1114111||point>=55296&&point<=57343)return -1;count++;
    }
    return count;
}
display_name = function(s){
    let out='',count=0;
    for(let i=0;i<length(s)&&count<24;){let b=ord(substr(s,i,1)),n=b<128?1:b<224?2:b<240?3:4;out+=substr(s,i,n);i+=n;count++;}
    return out;
};
minimum_version = function(n){if(n.protocol=='chain'&&(n.udp==true||n.udp_expected_ip!=null||n.udp_verification!=null))return 6;if(n.protocol=='chain'||member(keys(n),'front')||member(keys(n),'rear')||member(keys(n),'udp'))return 5;if(length(filter(hy2_fields,k=>member(keys(n),k))))return 7;if(member(keys(n),'source'))return 4;if(extended(n))return 3;return member(keys(n),'spiderX')||member(keys(n),'import_hints')?2:1;};
// Format 7 exists only for HY2 hop/pin fields; without them the store returns to 6, so removing
// those nodes is enough to downgrade to 0.2.1 (which reads formats 1-6).
function version_for(store){let v=store.version;if(v==7&&length(filter(store.nodes,n=>minimum_version(n)>=7))==0)v=6;if(v<4&&(length(store.nodes)>21||length(sprintf('%J\n',store))>524288))v=4;for(let n in store.nodes)if(minimum_version(n)>v)v=minimum_version(n);return v;}
validate_new_fields = function(n,allow_pending){
    if(member(keys(n),'spiderX')){
        require_value(n.protocol=='vless','combo_unsupported','spx','此参数仅适用于 REALITY');
        require_value(type(n.spiderX)=='string','param_invalid','spx','路径格式不正确');
        let count=utf8_length(n.spiderX);
        require_value(count>=1&&count<=256,'value_too_long','spx','路径须为 1–256 个字符');
        require_value(substr(n.spiderX,0,1)=='/'&&!match(n.spiderX,/[[:cntrl:]\\]/),'param_invalid','spx','路径须以斜杠开始且不能包含控制字符或反斜杠');
    }
    if(member(keys(n),'import_hints')){
        let h=n.import_hints;
        require_value(n.protocol=='vless'&&type(h)=='object'&&length(keys(h))==1&&type(h.support_x25519mlkem768)=='bool'&&h.support_x25519mlkem768==true,'param_invalid','support-x25519mlkem768','兼容提示格式不正确');
        require_value(caps.hint_source_supported(n.fingerprint),'param_unsupported','fp','此指纹未满足该兼容提示，不会自动改写指纹');
        if(!allow_pending)require_value(caps.hint_allowed(n.fingerprint),'verification_pending','support-x25519mlkem768','此兼容提示已识别，固定版本握手验证尚未完成');
    }
    if(member(keys(n),'hop_ports')){
        require_value(n.protocol=='hysteria2','combo_unsupported','hop_ports','端口跳跃仅适用于 HY2');
        require_value(type(n.hop_ports)=='string'&&hop_value(n.hop_ports,'hop_ports',n.port,false)==n.hop_ports,'param_invalid','hop_ports','端口跳跃未按规范格式保存');
    }
    if(member(keys(n),'pin_sha256')){
        require_value(n.protocol=='hysteria2','combo_unsupported','pin_sha256','证书指纹仅适用于 HY2');
        require_value(type(n.pin_sha256)=='string'&&match(n.pin_sha256,/^[0-9a-f]{64}$/)!=null,'param_invalid','pin_sha256','证书指纹须为 64 位小写十六进制 SHA-256');
    }
    if(member(keys(n),'hop_interval')){
        require_value(n.protocol=='hysteria2','combo_unsupported','hop_interval','跳跃间隔仅适用于 HY2');
        require_value(n.hop_ports!=null,'param_invalid','hop_interval','跳跃间隔需要同时设置端口跳跃');
        require_value(type(n.hop_interval)=='int'&&n.hop_interval>=5&&n.hop_interval<=3600&&n.hop_interval!=30,'param_invalid','hop_interval','跳跃间隔未按规范格式保存');
    }
    for(let k in ['up_mbps','down_mbps'])if(member(keys(n),k)){
        require_value(n.protocol=='hysteria2','combo_unsupported',k,'带宽仅适用于 HY2');
        require_value(type(n[k])=='int'&&n[k]>=1&&n[k]<=10000,'param_invalid',k,'带宽须为 1–10000 的整数，单位 Mbps');
    }
};
function decode(s,param){
    let out='';
    for(let i=0;i<length(s);i++){
        if(substr(s,i,1)!='%'){out+=substr(s,i,1);continue;}
        require_value(match(substr(s,i,3),/^%[0-9a-fA-F]{2}$/)!=null,'param_invalid',param,'百分号编码不正确');
        out+=chr(int(substr(s,i+1,2),16));i+=2;
    }
    require_value(utf8_length(out)>=0&&!match(out,/[[:cntrl:]]/),'param_invalid',param,'字段含无效字符');return out;
}
function parse_legacy(line,number){
    require_value(length(line)<=8192,'link_too_long','link','单条链接超过 8192 字节');
    let at=index(line,'://');require_value(at>0,'scheme_unsupported','scheme','不支持此链接协议');
    let proto=substr(line,0,at);require_value(member(['vless','hysteria2','hy2'],proto),'scheme_unsupported','scheme','当前仅支持 VLESS 与 HY2');
    let protocol=proto=='vless'?'vless':'hysteria2',rest=substr(line,at+3),fragment='',query='';
    at=index(rest,'#');if(at>=0){fragment=substr(rest,at+1);rest=substr(rest,0,at);}
    at=index(rest,'?');if(at>=0){query=substr(rest,at+1);rest=substr(rest,0,at);}rest=replace(rest,/\/$/,'');
    at=index(rest,'@');require_value(at>0,'param_missing','credential','缺少认证字段');
    let credential=substr(rest,0,at),authority=substr(rest,at+1),server='',port='443';
    if(substr(authority,0,1)=='['){
        let close=index(authority,']');require_value(close>1,'param_invalid','server','服务器地址格式不正确');
        server=substr(authority,1,close-1);let tail=substr(authority,close+1);
        if(tail){require_value(substr(tail,0,1)==':','param_invalid','port','端口格式不正确');port=substr(tail,1);}
    }else{
        let parts=split(authority,':');require_value(length(parts)<=2,'param_invalid','server','服务器地址格式不正确');server=parts[0];if(length(parts)==2)port=parts[1];
    }
    // Official HY2 multi-port form host:443,20000-50000; the first listed port is the main port.
    let multi=null;
    if(protocol=='hysteria2'&&match(port,/[,-]/)){multi=port;port=split(split(port,',')[0],'-')[0];}
    require_value(match(port,/^[0-9]{1,5}$/)!=null&&int(port)>=1&&int(port)<=65535,'param_invalid','port','端口须在有效范围内');
    require_value(str(server,253)&&match(server,/^[A-Za-z0-9][A-Za-z0-9.:-]*$/)!=null,'param_invalid','server','服务器地址格式不正确');
    let q={};
    for(let pair in split(query,'&')){
        if(!pair)continue;let eq=index(pair,'=');require_value(eq>0,'param_invalid','query','参数格式不正确');
        let key=decode(substr(pair,0,eq),'query');
        require_value(match(key,/^[A-Za-z][A-Za-z0-9_-]{0,63}$/)!=null,'param_invalid','query','参数名格式不正确');
        require_value(q[key]==null,'param_invalid',key,'参数重复');
        require_value(protocol=='hysteria2'&&member(hy2_params,key)||caps.classify(protocol,key)!='unknown','param_unsupported',key,'不支持此参数');
        q[key]=decode(substr(pair,eq+1),key);
        require_value(length(q[key])<=4096,'value_too_long',key,'参数超过长度上限');
    }
    for(let pair in [['pqv','mldsa65Verify'],['sni','peer'],['insecure','allowInsecure']])require_value(q[pair[0]]==null||q[pair[1]]==null||q[pair[0]]==q[pair[1]],'param_invalid',pair[0],'别名参数发生冲突');
    let n={id:'import_'+number,name:fragment?decode(fragment,'name'):'导入节点 '+number,protocol:protocol,server:server,port:int(port),sni:q.sni||q.peer||server};
    require_value(str(n.name,80)&&length(trim(n.name))>0,'value_too_long','name','节点名称为空或超过长度上限');
    require_value(str(n.sni,253)&&match(n.sni,/^[A-Za-z0-9][A-Za-z0-9.-]*$/)!=null,'param_invalid','sni','SNI 格式不正确');
    if(protocol=='vless'){
        require_value(q.security!=null,'param_missing','security','缺少安全方式');
        require_value(q.security=='reality','combo_unsupported','security','当前 VLESS 组合要求 REALITY');
        require_value(q.type==null||member(['raw','tcp'],q.type),'combo_unsupported','type','当前仅支持 raw/tcp 传输');
        require_value(q.encryption==null||q.encryption=='none','security_rejected','encryption','不支持此加密设置');
        require_value(q.headerType==null||q.headerType=='none','param_unsupported','headerType','不支持此头部类型');
        require_value(q.pbk!=null,'param_missing','pbk','缺少 REALITY 公钥');
        n.uuid=decode(credential,'uuid');n.flow=q.flow||'xtls-rprx-vision';n.fingerprint=q.fp||'chrome';n.public_key=q.pbk;n.short_id=q.sid||'';n.mldsa65=q.pqv||q.mldsa65Verify||'';
        require_value(match(n.uuid,/^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$/)!=null,'param_invalid','uuid','UUID 格式不正确');
        require_value(member(['xtls-rprx-vision','xtls-rprx-vision-udp443'],n.flow),'combo_unsupported','flow','不支持此 Flow');
        require_value(str(n.fingerprint,32)&&match(n.fingerprint,/^[a-zA-Z0-9_-]+$/)!=null,'param_invalid','fp','指纹格式不正确');
        require_value(match(n.public_key,/^[A-Za-z0-9_-]{43}$/)!=null,'param_invalid','pbk','REALITY 公钥格式不正确');
        require_value(match(n.short_id,/^([a-fA-F0-9]{2}){0,8}$/)!=null,'param_invalid','sid','Short ID 格式不正确');
        require_value(!n.mldsa65||match(n.mldsa65,/^[A-Za-z0-9_-]+$/)!=null,'param_invalid','pqv','ML-DSA 验证值格式不正确');
        if(q.spx!=null)n.spiderX=q.spx;
        if(q['support-x25519mlkem768']!=null){
            let value=q['support-x25519mlkem768'];
            require_value(member(['true','false'],value),'param_invalid','support-x25519mlkem768','兼容提示须为布尔字面量');
            require_value(value=='true','param_unsupported','support-x25519mlkem768','此版本没有已验证的独立关闭选项');
            n.import_hints={support_x25519mlkem768:true};
        }
    }else{
        n.password=decode(credential,'password');require_value(length(n.password)>0&&length(n.password)<=4096,'value_too_long','password','认证字段为空或超过长度上限');
        // Empty mport/pinSHA256 values mean "not set", as in the official client and v2rayN.
        let pin=q.pinSHA256?pin_value(q.pinSHA256,'pinSHA256'):null;
        for(let key in ['insecure','allowInsecure']){
            require_value(q[key]==null||member(['0','1'],q[key]),'param_invalid',key,'证书验证参数格式不正确');
            // insecure=1 with a pin means "accept only this certificate", which Xray enforces.
            require_value(q[key]!='1'||pin!=null,'security_rejected',key,'不允许跳过证书验证；同时提供证书指纹 pinSHA256 时按指纹校验');
        }
        require_value(multi==null||!q.mport,'param_invalid','mport','端口跳跃不能同时写在地址和 mport 中');
        let hop=multi!=null?hop_value(multi,'port',n.port,false):q.mport?hop_value(q.mport,'mport',n.port,true):null;
        if(hop!=null)n.hop_ports=hop;
        if(pin!=null)n.pin_sha256=pin;
        require_value(!q.obfs,'param_unsupported','obfs','此版本不支持混淆参数');
        require_value(!q['obfs-password'],'param_unsupported','obfs-password','此版本不支持混淆参数');
        n.insecure=false;n.alpn=q.alpn?split(q.alpn,','):[];
        require_value(length(n.alpn)<=8,'limit_exceeded','alpn','ALPN 条目超过上限');
        for(let a in n.alpn)require_value(str(a,40)&&match(a,/^[a-zA-Z0-9.\/-]+$/)!=null,'param_invalid','alpn','ALPN 格式不正确');
    }
    validate_new_fields(n,true);return n;
}
function parse_one(line,number,quick){
    if(quick)return modern.parse(line,number,quick);
    let scheme=substr(line,0,index(line,'://'));
    if(member(['hy2','hysteria2'],scheme))return parse_legacy(line,number);
    if(scheme=='vless'){
        let body=split(line,'#')[0],pos=index(body,'?'),q={},legacy_keys=['security','type','flow','sni','fp','pbk','sid','pqv','mldsa65Verify','encryption','spx','support-x25519mlkem768','headerType'];
        let only_legacy=true;
        for(let pair in split(pos<0?'':substr(body,pos+1),'&')){if(!pair)continue;let at=index(pair,'=');if(at<1){only_legacy=false;break;}let key=decode(substr(pair,0,at),'query');if(!member(legacy_keys,key))only_legacy=false;q[key]=decode(substr(pair,at+1),key);}
        if(only_legacy&&q.security=='reality'&&(q.type==null||member(['raw','tcp'],q.type))&&(q.flow==null||member(['xtls-rprx-vision','xtls-rprx-vision-udp443'],q.flow)))return parse_legacy(line,number);
    }
    return modern.parse(line,number,null);
}
function parse_preview(content,quick,kind){
    let body_limit=kind=='subscription'?2097152:262144,item_limit=kind=='subscription'?500:64;
    model_error=null;
    require_value(type(content)=='string'&&length(content)>0&&length(content)<=body_limit,'limit_exceeded','content','正文为空或超过入口字节限制');
    let body=trim(content);
    require_value(utf8_length(body)>=0,'param_invalid','content','正文不是有效 UTF-8');
    require_value(!match(body,/^(\{|\[|proxies\s*:|proxy-providers\s*:)/),'scheme_unsupported','content','请使用通用链接订阅，不接受配置 JSON 或 Clash YAML');
    if(!quick&&index(body,'://')<0){
        let encoded=replace(body,/\s/g,'');
        require_value(match(encoded,/^[A-Za-z0-9+\/_-]+={0,2}$/)!=null&&length(encoded)%4!=1,'base64_invalid','content','Base64 订阅编码不正确');
        encoded=replace(replace(encoded,/-/g,'+'),/_/g,'/');while(length(encoded)%4)encoded+='=';
        try{body=b64dec(encoded);}catch(e){fail('base64_invalid','content','Base64 订阅编码不正确');}
        require_value(type(body)=='string'&&utf8_length(body)>=0&&length(body)<=body_limit&&index(body,'://')>=0,'base64_invalid','content','无法解码为支持的链接文本');
    }
    let rows=[],number=0;
    for(let raw in split(body,'\n')){
        number++;let line=trim(raw);if(!length(line))continue;
        require_value(length(rows)<item_limit,'limit_exceeded','content','条目数超过当前入口上限');
        model_error=null;
        try{let n=parse_one(line,number,quick);let pending=!available(n);push(rows,{line:number,status:pending?'pending_verification':'ok',pending_param:n.import_hints?'support-x25519mlkem768':'protocol',node:n});}
        catch(e){let error=take_error()||{code:'param_invalid',param:'link',message:'链接格式不正确'};push(rows,{line:number,status:'error',error:error});}
    }
    require_value(length(rows)>0,'param_missing','content','未找到节点链接');return rows;
}
function parse_links(content){
    let rows=parse_preview(content),out=[];
    for(let row in rows){if(row.status!='ok'){let e=row.error||{code:'verification_pending',param:row.pending_param||'protocol',message:'固定版本握手验证尚未完成'};fail(e.code,e.param,e.message);}push(out,row.node);}
    return out;
}
function only_keys(value,allowed){return type(value)=='object'&&length(filter(keys(value),k=>!member(allowed,k)))==0;}
function connection(n){
    if(n.protocol=='chain')return null;
    if(extended(n))return modern.connection(connection_only(n));
    // Never infer equivalence after dropping unknown native connection settings.
    if(n.native_outbound){
        let o=n.native_outbound,s=o.settings,t=o.streamSettings,r=t?.realitySettings;
        if(!only_keys(o,['protocol','settings','streamSettings','mux','targetStrategy']))return null;
        if(!only_keys(t,['network','security','realitySettings','rawSettings','tcpSettings']))return null;
        if(!only_keys(r,['serverName','fingerprint','publicKey','shortId','mldsa65Verify','spiderX','show']))return null;
        if(s?.vnext){
            if(!only_keys(s,['vnext'])||length(s.vnext)!=1)return null;
            let v=s.vnext[0];if(!only_keys(v,['address','port','users'])||length(v.users||[])!=1||!only_keys(v.users[0],['id','encryption','flow']))return null;
        }else if(!only_keys(s,['address','port','id','encryption','flow']))return null;
        for(let key in ['rawSettings','tcpSettings'])if(t[key]!=null&&canonical(t[key])!='{}')return null;
        if(o.mux!=null&&!only_keys(o.mux,['enabled','concurrency','xudpConcurrency','xudpProxyUDP443']))return null;
    }
    let effective=render(n),r=effective.streamSettings?.realitySettings||{};
    let out={fp_schema:1,protocol:n.protocol,combo:n.protocol=='vless'?'vless-reality-raw':'hysteria2-tls',server:lc(n.server),port:n.port,sni:lc(n.sni),security:n.protocol=='vless'?'reality':'tls',transport:n.protocol=='vless'?'raw':'hysteria'};
    if(n.protocol=='vless'){
        out.auth={uuid:lc(n.uuid),encryption:'none'};out.flow=n.flow;out.fp=n.fingerprint;out.reality={public_key:n.public_key,short_id:lc(n.short_id||''),mldsa65:n.mldsa65||'',spiderX:r.spiderX??null};
        // Unknown nested native behavior returns null above, known options remain in the identity.
        out.native_options={mux:effective.mux??null,targetStrategy:effective.targetStrategy??null,reality_show:r.show??null};
        out.import_hints=n.import_hints||null;
    }else{
        out.auth={password:n.password};out.alpn=n.alpn||[];out.insecure=n.insecure==true;out.obfs=n.obfs||'';out.obfs_password=n.obfs_password||'';
        // Added only when set, so identities of existing HY2 nodes stay byte-identical.
        for(let k in ['hop_ports','pin_sha256','hop_interval','up_mbps','down_mbps'])if(n[k])out[k]=n[k];
    }
    return out;
}
canonical = function(v){
    if(type(v)=='array')return '['+join(',',map(v,canonical))+']';
    if(type(v)=='object')return '{'+join(',',map(sort(keys(v)),k=>sprintf('%J',k)+':'+canonical(v[k])))+'}';
    return sprintf('%J',v);
};
modern=protocols.bind({fail:fail,decode:decode,str:str,utf8_length:utf8_length});
chains=chain_model.bind({fail,valid_id:valid_node_id,str,utf8_length,combo,available,endpoint:(a,p)=>modern.endpoint(a,p),feature:()=>caps.get().features?.chain_tcp,assert_regular:assert_reference,render_rear:n=>modern.render(connection_only(n),'chain_rear'),udp_shape:n=>udp.shape(n),udp_check:(n,s)=>udp.check(n,s),udp_ready:(a,b)=>udp.ready(a,b),udp_stamp_valid:(n,s)=>udp.stamp_valid(n,s)});
udp=udp_model.bind({fail,feature:()=>caps.get().features?.chain_udp,combo,tcp_ready:(a,b)=>chains.pair_ready(a,b),connection,canonical,caps_file:caps.FILE,display_name});
function chain_udp_ready(front,rear){return udp.ready(front,rear);}
function chain_udp_identity(n,store){return udp.identity(n,store);}
function chain_udp_stamp_valid(n,store){return udp.stamp_valid(n,store);}
function invalidate_chain_udp(before,after){return udp.invalidate(before,after);}
function route_tag(id,store){return chains.tag(id,store);}
function chain_references(store,id){return chains.references(store,id);}
function chain_closure(store,roots){return chains.closure(store,roots);}
function chain_outbound(n,store,tag){return chains.outbound(n,store,tag);}
function chain_rules(rule,store){return chains.guards(rule,store);}
function assert_chain_outbounds(config,store,used){return chains.assert_outbounds(config,store,used,canonical);}
function validate_chains(store,published){for(let n in store.nodes)if(n.protocol=='chain')chains.validate(n,store,published);}
function chain_pair_ready(front,rear){return chains.pair_ready(front,rear);}
function chain_impact(before,after){let result=[];for(let n in after.nodes){let old=filter(before.nodes,x=>x.id==n.id)[0];if(!old||canonical(old)==canonical(n))continue;let fields=changed_fields(old,n);if(old.name!=n.name)push(fields,'name');for(let ref in chain_references(after,n.id))push(result,{id:ref.id,name:display_name(ref.name),dependency_id:n.id,role:ref.role,fields});}return result;}


changed_fields = function(before,after){
 if(before.protocol=='chain'||after.protocol=='chain')return filter(['protocol','front','rear','udp','udp_expected_ip'],k=>canonical(before[k])!=canonical(after[k]));
 let a=connection(before),b=connection(after);if(a==null||b==null)return ['无法完整比较'];let out=[];
 function walk(x,y,path){if(canonical(x)==canonical(y))return;if(type(x)=='object'&&type(y)=='object'){let all={};for(let k in keys(x))all[k]=true;for(let k in keys(y))all[k]=true;for(let k in sort(keys(all)))walk(x[k],y[k],path?path+'.'+k:k);}else push(out,path||'connection');}
 walk(a,b,'');return out;
};


function verification_key(n,store){
 if(n.protocol!='chain'){let v=connection(n);if(v==null)fail('param_invalid','node','无法完整绑定测试节点');return hashes.digest(canonical(v));}
 let by=chain_model.map_nodes(store),a=connection(by[n.front]),b=connection(by[n.rear]);if(a==null||b==null)fail('param_invalid','chain','无法完整绑定链');return hashes.digest(canonical({front:a,rear:b,udp:n.udp==true,expected:n.udp_expected_ip||''}));
}
trial = function(n,store){if(!n)return false;if(n.protocol=='chain')return !caps.user_verified(n.udp?'chain_udp':'chain_tcp',combo_id(n),verification_key(n,store));return combo(n)?.status=='trial'||n.import_hints&&!caps.hint_verified(n.fingerprint);};

export { trial, verification_key, chain_udp_ready, chain_udp_identity, chain_udp_stamp_valid, invalidate_chain_udp, route_tag, chain_references, chain_closure, chain_outbound, chain_rules, assert_chain_outbounds, validate_chains, chain_pair_ready, chain_impact, assert_default, combo, changed_fields, extended, role, available, assert_reference, combo_id, valid_node_id, mask, render, validate_store, read_store, migrate, public_node, update_node, parse_links, parse_preview, take_error, minimum_version, version_for, connection, canonical, display_name };
