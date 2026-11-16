// SPDX-License-Identifier: GPL-3.0-only
// Called before first activation, after generating the exact inbound list.
import * as fs from 'fs';
let config=json(fs.readfile('/etc/lanekeep-proxy/config.json'));
let ports={ '5053':true };
for(let inbound in config.inbounds || []) ports[sprintf('%d',inbound.port)]=true;
for(let file in ['tcp','tcp6','udp','udp6']) {
 for(let line in split(fs.readfile('/proc/net/'+file)||'', '\n')) {
  let fields=split(trim(line), /\s+/);
  if(length(fields)<4 || fields[0]=='sl')continue;
  if(index(file,'tcp')==0 && fields[3]!='0A')continue;
  let address=split(fields[1],':'),port=int(address[-1],16);
  if(ports[sprintf('%d',port)])die('reserved_listen_port_in_use');
 }
}
