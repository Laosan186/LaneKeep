// Private bounded hashing of modeled identities; never puts data in argv/logs.
import * as fs from 'fs';
function file(path){
 if(fs.lstat(path)?.type!='file')die('fingerprint_unavailable');
 let p=fs.popen("sha256sum '"+replace(path,/'/g,"'\\''")+"' 2>/dev/null",'r');
 if(!p)die('fingerprint_unavailable');let raw=p.read('all'),rc=p.close(),v=split(raw||'',' ')[0];
 if(rc!=0||!match(v,/^[a-f0-9]{64}$/))die('fingerprint_unavailable');return v;
}
function digest(raw){
 if(type(raw)!='string'||length(raw)>65536)die('fingerprint_size');
 let id=trim(fs.readfile('/proc/sys/kernel/random/uuid')||'');if(!match(id,/^[a-f0-9-]{36}$/))die('fingerprint_id');
 let dir='/tmp/lanekeep-node-fp.'+id,path=dir+'/identity';
 if(!fs.mkdir(dir,0700))die('fingerprint_storage');let result=null;
 if(fs.writefile(dir+'/.owner','lanekeep-node-fp-v1\n')==null||!fs.chmod(dir+'/.owner',0600))die('fingerprint_storage');
 try{let f=fs.open(path,'wx',0600);if(!f)die('fingerprint_storage');let n=f.write(raw);f.close();if(n!=length(raw))die('fingerprint_storage');result=file(path);}catch(e){}
 if(fs.readfile(dir+'/.owner')=='lanekeep-node-fp-v1\n'){if(fs.lstat(path)?.type=='file')fs.unlink(path);fs.unlink(dir+'/.owner');fs.rmdir(dir);}
 if(result==null)die('fingerprint_unavailable');return result;
}
export {file,digest};
