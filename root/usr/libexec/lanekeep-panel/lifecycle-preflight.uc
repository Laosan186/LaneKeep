// SPDX-License-Identifier: GPL-3.0-only
import * as fs from 'fs';
import * as lan from './network.uc';
import * as nodes from './nodes.uc';
let store=nodes.read_store('/etc/lanekeep-proxy/nodes.json');
if(!store.default_node)die('add_and_select_default_node_first');
nodes.assert_default(filter(store.nodes,n=>n.id==store.default_node)[0]);
let ctx=lan.context();
// IPv4-only policy. Require the administrator to disable LAN IPv6 explicitly.
if(length(ctx.ipv6)||length(ctx.ipv6_prefix)||trim(fs.readfile('/proc/sys/net/ipv6/conf/'+ctx.device+'/disable_ipv6')||'')!='1')die('disable_lan_ipv6_before_enabling');
print(sprintf('%J\n',{ok:true,interface:ctx.name,device:ctx.device}));
