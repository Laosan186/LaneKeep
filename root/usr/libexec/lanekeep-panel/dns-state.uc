// SPDX-License-Identifier: GPL-3.0-only
// Preserve the complete original for byte-exact restoration if it was not edited.
// If other software edited DHCP meanwhile, restore only our still-owned fields.
import * as fs from 'fs';
import * as uci from 'uci';
let dir='/etc/lanekeep-state',path='/etc/config/dhcp',mode=ARGV[0];
function save(name,value){if(fs.writefile(dir+'/'+name,value)==null)die('dns_snapshot_write');fs.chmod(dir+'/'+name,384);}
if(mode=='enable') {
 if(fs.lstat(dir+'/dns-before'))exit(0);
 let original=fs.readfile(path);if(original==null)die('dns_config_missing');
 let c=uci.cursor(),fields=[];c.foreach('dhcp','dnsmasq',s=>push(fields,{id:s['.name'],server:s.server,noresolv:s.noresolv}));
 if(length(fields)!=1)die('exactly_one_dnsmasq_required');
 save('dns-before',original);save('dns-fields.json',sprintf('%J',fields));
 for(let s in fields){c.set('dhcp',s.id,'server',['127.0.0.1#5053']);c.set('dhcp',s.id,'noresolv','1');}
 if(!c.commit('dhcp'))die('dns_commit_failed');save('dns-installed',fs.readfile(path));
} else if(mode=='restore') {
 if(!fs.lstat(dir+'/dns-before'))exit(0);
 let before=fs.readfile(dir+'/dns-before'),installed=fs.readfile(dir+'/dns-installed'),now=fs.readfile(path);
 if(installed!=null&&now==installed){if(fs.writefile(path,before)==null)die('dns_restore_failed');}
 else {
  let c=uci.cursor(),fields=json(fs.readfile(dir+'/dns-fields.json'));
  for(let s in fields){
   let current=c.get('dhcp',s.id);if(current!='dnsmasq')continue;
   if(sprintf('%J',c.get('dhcp',s.id,'server'))==sprintf('%J',['127.0.0.1#5053'])){if(s.server==null)c.delete('dhcp',s.id,'server');else c.set('dhcp',s.id,'server',s.server);}
   if(c.get('dhcp',s.id,'noresolv')=='1'){if(s.noresolv==null)c.delete('dhcp',s.id,'noresolv');else c.set('dhcp',s.id,'noresolv',s.noresolv);}
  }
  if(!c.commit('dhcp'))die('dns_restore_commit_failed');
 }
 for(let name in ['dns-before','dns-installed','dns-fields.json'])fs.unlink(dir+'/'+name);
} else die('invalid_mode');
