// Bounded fixed-slot RAM rings, with generation sentinels against torn reads.
import * as fs from 'fs';
let ROOT='/tmp/lanekeep-telemetry';
let SLOT=1280;
function initialize(root){
 if(root!=ROOT&&!match(root,/^\/tmp\/lanekeep-proxy-stage\/status-history-[0-9TZ]+\/test-data(-[a-z0-9]+)?$/))die('ram_path');
 if(!match(fs.readfile('/proc/mounts')||'',/(^|\n)tmpfs \/tmp tmpfs /))die('tmp_not_ram');
 let s=fs.lstat(root);if(s!=null&&(s.type!='directory'||s.uid!=0))die('unsafe_directory');if(!s&&!fs.mkdir(root,0700))die('mkdir');fs.chmod(root,0700);ROOT=root;
}
function safe(name){if(!match(name,/^[a-z0-9_-]+(\.json|\.ring)?(-next)?$/))die('filename');let p=ROOT+'/'+name,s=fs.lstat(p);if(s!=null&&(s.type!='file'||s.uid!=0))die('unsafe_file');return p;}
function request(value){let p=safe('mark-request.json'),f=fs.open(p,'wx',0600);if(!f)return false;let ok=f.write(sprintf('%J\n',value))!=null;f.close();return ok;}
function read(name){let p=safe(name);try{return json(fs.readfile(p));}catch(e){return null;}}
function write(name,value){let p=safe(name),next=safe(name+'-next'),f=fs.open(next,'w',0600);if(!f)die('open');if(f.write(sprintf('%J\n',value))==null)die('write');f.close();if(!fs.rename(next,p))die('rename');}
function put(name,count,index,value,size){size=size||SLOT;let p=safe(name),s=sprintf('%d\n%J\n%d\n',index,value,index);if(length(s)>size)die('slot_limit');let f=fs.open(p,fs.lstat(p)?'r+':'w+',0600);if(!f)die('open_ring');f.seek((index%count)*size,0);let n=f.write(sprintf('%-'+size+'s',s));f.close();if(n!=size)die('short_write');}
function rows(name,count,size){size=size||SLOT;let p=safe(name),f=fs.open(p,'r');if(!f)return [];let out=[];
 for(let i=0;i<count;i++){let s=f.read(size);if(!s||length(s)!=size)break;let a=split(trim(s),'\n');if(length(a)!=3||!match(a[0],/^[0-9]+$/)||a[0]!=a[2])continue;try{let r=json(a[1]);if(type(r)=='object')push(out,r);}catch(e){}}
 f.close();return sort(out,(a,b)=>a.mono-b.mono);
}
function clear(name){let p=safe(name),f=fs.open(p,'w',0600);if(!f)die('clear');f.close();}
function remove_request(){let p=safe('mark-request.json');if(fs.lstat(p))fs.unlink(p);}

export { ROOT, SLOT, initialize, request, read, write, put, rows, clear, remove_request };
