// SPDX-License-Identifier: GPL-3.0-only
// Body of the identity script used by hy2-check.sh, which prepends
//   import * as nodes from '<tree>/root/usr/libexec/lanekeep-panel/nodes.uc';
// for the tree under test. Prints parse, render and identity results for links without the new
// HY2 parameters, so two releases can be compared byte for byte. Synthetic values only.
let links=[
 'hysteria2://PASSWORD@203.0.113.20:443/?sni=example.com#a',
 'hy2://PASSWORD@203.0.113.20:8443?sni=example.com&alpn=h3#b',
 'hysteria2://PASSWORD@[2001:db8::1]:443/?sni=example.com&insecure=0',
 'hysteria2://PASSWORD@203.0.113.21:443/?sni=example.net&alpn=h3,h2',
 'vless://00000000-0000-4000-8000-000000000001@203.0.113.30:443?security=reality&pbk=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&sni=example.com&fp=chrome&flow=xtls-rprx-vision&sid=abcd',
 'vless://00000000-0000-4000-8000-000000000002@203.0.113.31:8443?security=reality&pbk=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&sni=example.org',
 // Rejected before and after: only the error code and parameter are compared.
 'hysteria2://PASSWORD@203.0.113.20:443/?sni=example.com&insecure=1',
 'hysteria2://PASSWORD@203.0.113.20:443/?sni=example.com&obfs=salamander&obfs-password=x',
 'hysteria2://PASSWORD@203.0.113.20:443/?sni=example.com&upmbps=100',
 'hysteria2://PASSWORD@203.0.113.20:0/?sni=example.com'
];
let out=[],list=[],i=0;
for(let l in links){
 let r=nodes.parse_preview(l)[0];i++;
 if(r.status=='error'){push(out,{line:i,status:'error',code:r.error.code,param:r.error.param});continue;}
 let n=r.node;n.id='node_'+i;n.name='Node '+i;push(list,n);
 let c=nodes.connection(n);
 push(out,{line:i,status:r.status,node:n,public:nodes.public_node(n),render:nodes.render(n),connection:c,canonical:nodes.canonical(c),
  key:nodes.verification_key(n,{version:6,default_node:'',nodes:[n]}),minimum:nodes.minimum_version(n),combo:nodes.combo_id(n),trial:nodes.trial(n)});
}
let store={version:6,default_node:list[0].id,nodes:list},result='ok';
try{nodes.validate_store(store);}catch(e){let m=nodes.take_error();result=m?m.code+':'+m.param:'die';}
push(out,{store:result,version_for:nodes.version_for(store)});
print(sprintf('%J\n',out));
