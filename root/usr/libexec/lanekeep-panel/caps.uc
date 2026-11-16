// Read-only catalog plus explicit, authenticated user confirmations. No automatic promotion.
import * as fs from 'fs';
import * as hashes from './node-fingerprint.uc';
let FILE='/usr/share/lanekeep-panel/capabilities.json',VERIFIED='/etc/lanekeep-proxy/trial-verifications.json',RECEIPTS='/tmp/lanekeep-panel/trial-results.json',cached=null;
function id(v){return type(v)=='string'&&match(v,/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/)!=null;}
function safe_read(path,limit){let s=fs.lstat(path);if(!s)return null;if(s.type!='file'||s.uid!=0||(s.mode&0077)!=0||s.size>limit)die('trial_storage');return json(fs.readfile(path));}
function atomic(path,value){
 if(fs.lstat(path)?.type=='link'||fs.lstat(path+'.next')!=null)die('trial_storage');let body=sprintf('%J\n',value);if(length(body)>65536)die('trial_capacity');
 let f=fs.open(path+'.next','wx',0600);if(!f)die('trial_storage');let n=f.write(body);f.close();if(n!=length(body)||!fs.chmod(path+'.next',0600)||!fs.rename(path+'.next',path))die('trial_storage');
}
function catalog_hash(){return hashes.file(FILE);}
function journal(){let v=safe_read(VERIFIED,65536);if(!v)return {schema:1,core:'26.10.21',catalog:catalog_hash(),entries:[]};if(v.schema!=1||type(v.entries)!='array'||length(v.entries)>256)die('trial_verification_shape');if(v.core!='26.10.21'||v.catalog!=catalog_hash())return {schema:1,core:'26.10.21',catalog:catalog_hash(),entries:[]};return v;}
function user_verified(kind,key,signature){return length(filter(journal().entries,e=>e.kind==kind&&e.id==key&&e.status=='verified'&&e.user_confirmed==true&&type(e.confirmed_at)=='int'&&e.signature==signature))>0;}
function get(){
 if(cached!=null)return cached;if(fs.lstat(FILE)?.type!='file'||fs.stat(FILE).size>65536)die('capabilities_unavailable');
 let v=json(fs.readfile(FILE));if(v?.schema!=1||v.core?.target_version!='26.10.21'||type(v.protocols)!='object')die('capabilities_invalid');
 for(let e in journal().entries)if(e.kind=='combo'&&e.status=='verified'&&e.user_confirmed==true&&match(e.signature||'',/^[a-f0-9]{64}$/))for(let protocol in keys(v.protocols))for(let combo in v.protocols[protocol].combos)if(combo.id==e.id&&combo.status=='trial'){combo.status='verified';combo.verification_scope='用户确认：特定真实节点连接测试通过；不代表所有服务端或防泄露场景';}
 cached=v;return cached;
}
function revision(){return hashes.digest(catalog_hash()+':'+(fs.lstat(VERIFIED)?hashes.file(VERIFIED):'none'));}
function classify(protocol,param){let p=get().protocols?.[protocol]?.params;if(index(p?.critical||[],param)>=0)return 'critical';if(index(p?.ignorable||[],param)>=0)return 'ignorable';return 'unknown';}
function hint_source_supported(fp){return index(get().protocols.vless.mlkem.source_supported_fingerprints,fp)>=0;}
function hint_verified(fp){let c=get().protocols.vless.mlkem;return index(c.loopback_fingerprints,fp)>=0||index(c.verified_fingerprints,fp)>=0||length(filter(journal().entries,e=>e.kind=='hint'&&e.id==fp&&e.status=='verified'&&e.user_confirmed==true))>0;}
function hint_allowed(fp){return hint_verified(fp)||(get().release_status=='trial'&&hint_source_supported(fp));}
function issue(owner,binding,records){
 if(!id(owner)||type(records)!='array'||!length(records)||length(records)>5)die('trial_receipt');
 let now=time(),v=safe_read(RECEIPTS,65536)||{schema:1,items:[]};if(v.schema!=1||type(v.items)!='array')die('trial_receipt');
 v.items=filter(v.items,e=>now>=e.at&&now-e.at<1200);if(length(v.items)>=64)die('trial_receipt_capacity');
 let receipt=trim(fs.readfile('/proc/sys/kernel/random/uuid')||'');if(!id(receipt))die('trial_receipt');
 push(v.items,{id:receipt,owner,at:now,binding,records});atomic(RECEIPTS,v);return receipt;
}
function confirm(receipt,owner,binding,ack){
 if(ack!=true||!id(owner)||!id(receipt))die('trial_confirmation_required');let v=safe_read(RECEIPTS,65536),now=time();
 let matches=filter(v?.items||[],e=>e.id==receipt&&e.owner==owner&&now>=e.at&&now-e.at<1200&&sprintf('%J',e.binding)==sprintf('%J',binding));if(length(matches)!=1)die('trial_receipt_expired');
 let out=journal();for(let record in matches[0].records){if(index(['combo','hint','chain_tcp','chain_udp'],record.kind)<0||!match(record.signature||'',/^[a-f0-9]{64}$/)||!match(record.id||'',/^[a-zA-Z0-9_.>-]{1,160}$/))die('trial_record');out.entries=filter(out.entries,e=>!(e.kind==record.kind&&e.id==record.id&&e.signature==record.signature));push(out.entries,{...record,status:'verified',user_confirmed:true,confirmed_at:now,scope:'specific_real_node_connection_test'});}
 if(length(out.entries)>256)die('trial_verification_capacity');atomic(VERIFIED,out);cached=null;
 // A consumed receipt cannot be replayed because the verification revision changed.
 v.items=filter(v.items,e=>e.id!=receipt);atomic(RECEIPTS,v);return {ok:true,message:'已记录你的明确确认；只更新私有验证状态，未修改代码能力表、节点或运行配置'};
}
export {FILE,VERIFIED,get,classify,hint_verified,hint_allowed,hint_source_supported,revision,user_verified,issue,confirm};
