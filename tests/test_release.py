"""Offline release invariants. Run: python -m unittest discover -s tests -v"""
from pathlib import Path
import hashlib,ipaddress,json,re,sys,tempfile,unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/build'))
from materialize import materialize

class ReleaseInvariants(unittest.TestCase):
    def test_factory_has_no_user_state(self):
        state=json.loads((ROOT/'root/etc/lanekeep-proxy/nodes.json').read_text())
        self.assertEqual(state['nodes'],[])
        self.assertEqual(state['default_node'],'')
        config=(ROOT/'root/etc/config/lanekeep').read_text(encoding='utf-8')
        self.assertNotRegex(config,r'config rule\b|list member\b|list domain\b')
        self.assertIn("option enabled '0'",(ROOT/'root/etc/config/lanekeep_runtime').read_text())

    def test_version_changes_all_custom_resource_namespaces(self):
        with tempfile.TemporaryDirectory() as tmp:
            for release in ['1','2']:
                stage=Path(tmp)/release;materialize(stage,'0.1.0',release)
                menu=json.loads((stage/'usr/share/luci/menu.d/luci-app-lanekeep.json').read_text())
                views=[v['action']['path'] for v in menu.values() if v['action']['type']=='view']
                self.assertEqual(len(views),6)
                self.assertTrue(all('/v0_1_0_r'+release+'/' in v for v in views))
                resources=stage/'www/luci-static/resources'
                for file in resources.rglob('*.js'):
                    for module in re.findall(r"['\"]require (lanekeep[^'\"; ]*)",file.read_text(encoding='utf-8')):
                        self.assertIn('v0_1_0_r'+release,module)
                self.assertTrue((resources/f'lanekeep/v0_1_0_r{release}/panel.css').exists())

    def test_dns_logs_and_modes(self):
        template=json.loads((ROOT/'root/etc/lanekeep-proxy/template.json').read_text())
        self.assertEqual(template['log'],{'access':'none','error':'none','loglevel':'none','dnsLog':False})
        tags={i['tag'] for i in template['inbounds']}
        self.assertTrue({'standard-transparent','global-transparent','enhanced-transparent','ondemand-transparent'}<=tags)
        self.assertEqual(json.loads((ROOT/'root/etc/lanekeep-proxy/domestic-dns.json').read_text())['inbounds'][0]['listen'],'127.0.0.1')

    def test_public_geodata_matches_record(self):
        record=json.loads((ROOT/'docs/audit/geodata.json').read_text())
        self.assertEqual(hashlib.sha256((ROOT/'root/usr/share/v2ray/lanekeep-services.dat').read_bytes()).hexdigest(),record['output_sha256'])

    def test_generator_hash_lock_matches_generator(self):
        # The panel refuses every rule commit when this lock and the shipped generator differ.
        panel=(ROOT/'root/usr/libexec/lanekeep-panel/panel.uc').read_text(encoding='utf-8')
        locked=re.search(r"let GENERATOR_SHA = '([0-9a-f]{64})';",panel).group(1)
        self.assertEqual(hashlib.sha256((ROOT/'root/usr/libexec/lanekeep-xray/lanekeep-gen.uc').read_bytes()).hexdigest(),locked)

    def test_style_version_follows_package_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            stage=Path(tmp)/'s';materialize(stage,'0.1.0','7')
            foundation=(stage/'www/luci-static/resources/lanekeep/v0_1_0_r7/foundation.js').read_text(encoding='utf-8')
            self.assertIn("var version='0.1.0-r7'",foundation)

    def test_ip_rules_reject_reserved_ranges_and_are_wired(self):
        lib=ROOT/'root/usr/libexec'
        helper=(lib/'lanekeep-panel/ip-rule.uc').read_text(encoding='utf-8')
        reserved={ipaddress.ip_network(f'{a}/{p}') for a,p in re.findall(r"\['([0-9.]+)',([0-9]+)\]",helper)}
        for net in ['0.0.0.0/8','10.0.0.0/8','100.64.0.0/10','127.0.0.0/8','169.254.0.0/16','172.16.0.0/12','192.0.2.0/24','192.168.0.0/16','198.18.0.0/15','198.51.100.0/24','203.0.113.0/24','224.0.0.0/4','240.0.0.0/4']:
            self.assertIn(ipaddress.ip_network(net),reserved)
        template=json.loads((ROOT/'root/etc/lanekeep-proxy/template.json').read_text())
        for pool in template['fakedns']:
            self.assertTrue(any(ipaddress.ip_network(pool['ipPool']).subnet_of(r) for r in reserved))
        gen=(lib/'lanekeep-xray/lanekeep-gen.uc').read_text(encoding='utf-8')
        panel=(lib/'lanekeep-panel/panel.uc').read_text(encoding='utf-8')
        self.assertIn("'keyword', 'ip', 'regexp'",gen)
        self.assertIn('ip_rule.normalize(value, lan.context().subnet)',gen)
        self.assertIn("rule_types:['domain','full','keyword','ip','dedicated','geosite']",panel)

    def test_frontend_reads_lan_address_from_router(self):
        for file in (ROOT/'root/www').rglob('*.js'):
            text=file.read_text(encoding='utf-8')
            self.assertNotRegex(text,r'socks5://\d',file.name)
            self.assertNotRegex(text,r'\b(?:10|172\.(?:1[6-9]|2\d|3[01])|192\.168)\.\d{1,3}\.\d{1,3}\b',file.name)

    def test_latency_measurement_v3_is_consistent(self):
        lib=ROOT/'root/usr/libexec/lanekeep-panel'
        wire=(lib/'node-wire.uc').read_text(encoding='utf-8')
        self.assertIn("mode!='probe'",wire)
        self.assertIn("address:'127.0.0.1'",wire)
        self.assertIn('measurement_version:3',wire)
        for runner in ['node-test','chain-test']:
            text=(lib/runner).read_text(encoding='utf-8')
            self.assertIn('node-wire.uc" probe "$1" "$3"',text)
            self.assertNotIn(' nc ',text)
        self.assertIn('measurement_version !== 3',(ROOT/'root/www/luci-static/resources/lanekeep.js').read_text(encoding='utf-8'))

    def test_nodes_page_reads_the_same_gate_snapshot_as_status(self):
        # The Nodes page shows "Unknown" whenever the nodes RPC omits gate, so both RPCs share one reader.
        panel=(ROOT/'root/usr/libexec/lanekeep-panel/panel.uc').read_text(encoding='utf-8')
        def body(name):return re.search(r'\nfunction '+name+r'\(.*?\n\}\n',panel,re.S).group(0)
        self.assertEqual(panel.count("fs.readfile('/tmp/lanekeep-dns-gate/status')"),1)
        self.assertEqual(panel.count("'nft -j list set inet lanekeep_dns_gate healthy_data'"),1)
        snapshot=body('gate_snapshot')
        self.assertIn("'/tmp/lanekeep-dns-gate/status'",snapshot)
        self.assertRegex(snapshot,r"return \{state:[^\n]*\?'OPEN':'CLOSED',fresh:fresh,lease_valid:leased\};")
        status=body('status')
        self.assertIn('let gate=gate_snapshot(service,uptime);',status)
        self.assertIn("if(!gate.fresh) push(warnings,'门控状态过期或不可读，按CLOSED显示');",status)
        self.assertIn('core:core,gate:gate,',status)
        nodes=body('node_list')
        self.assertRegex(nodes,r"try \{[^\n]*gate=gate_snapshot\([^\n]*\}\n\s*catch\(e\) \{ gate=\{state:'CLOSED',fresh:false,lease_valid:false\}; \}")
        self.assertRegex(nodes,r'return sizes\.page\(result,[^\n]*,gate:gate,')
        # fresh:false is what the Nodes page renders as "Unknown".
        self.assertIn('known=g.fresh!==false',(ROOT/'root/www/luci-static/resources/lanekeep/nodes-ui.js').read_text(encoding='utf-8'))

    def test_direct_group_is_isolated_and_upgrades_keep_standard(self):
        template=json.loads((ROOT/'root/etc/lanekeep-proxy/template.json').read_text(encoding='utf-8'))
        inbound=[i for i in template['inbounds'] if i['tag']=='direct-transparent']
        self.assertEqual(len(inbound),1)
        self.assertEqual((inbound[0]['port'],inbound[0]['sniffing'],inbound[0]['streamSettings']['sockopt']),(12349,{'enabled':False},{'tproxy':'tproxy'}))
        # Direct rules come last, so every earlier rule must be tagged for other inbounds;
        # only the user slots are untagged, and the generator replaces them with tagged rows.
        for r in template['routing']['rules']:
            self.assertTrue('__lanekeep_user_slot' in r or r.get('inboundTag'),r)
        rules=[r for r in template['routing']['rules'] if 'direct-transparent' in r.get('inboundTag',[])]
        # Only its own rules: router DNS to dnsmasq, block router services and FakeIP, then everything else direct.
        self.assertTrue(all(r['inboundTag']==['direct-transparent'] for r in rules))
        self.assertEqual([r['outboundTag'] for r in rules],['direct-router-dns','block','block','direct'])
        self.assertEqual({k:v for k,v in rules[0].items() if k not in ('type','inboundTag','outboundTag')},{'ip':['__LAN_ADDRESS__/32'],'port':'53','network':'tcp,udp'})
        self.assertEqual({k:v for k,v in rules[-1].items() if k not in ('type','inboundTag','outboundTag')},{'network':'tcp,udp'})
        self.assertIn('198.18.0.0/15',rules[2]['ip'])
        self.assertEqual([o['tag'] for o in template['outbounds'] if o['protocol']=='freedom'],['direct'])
        # Router DNS goes through the core (TPROXY picks the socket, so the core's own UDP reply
        # sockets on LAN:53 cannot take it) and is forwarded unchanged to dnsmasq on loopback.
        # userLevel 53 is the short idle level dns-idle.uc adds for the other groups' UDP DNS.
        router_dns=[o for o in template['outbounds'] if o['tag']=='direct-router-dns']
        self.assertEqual(router_dns,[{'protocol':'dns','settings':{'rewriteAddress':'127.0.0.1','rewritePort':53,'rules':[{'action':'direct'}],'userLevel':53},'tag':'direct-router-dns'}])
        self.assertNotIn('policy',template)
        self.assertIn("next.policy.levels['53']={connIdle:15};",(ROOT/'root/usr/libexec/lanekeep-panel/dns-idle.uc').read_text(encoding='utf-8'))
        gen=(ROOT/'root/usr/libexec/lanekeep-xray/lanekeep-gen.uc').read_text(encoding='utf-8')
        self.assertNotIn('7612',gen)
        # When the core is down a group's TPROXY finds no socket and the packet falls through
        # dispatch_device into later chains, ending in the unassigned one. Every capture chain must
        # therefore accept only through TPROXY, so no group can reach a router service without the core.
        nft=json.loads(re.search(r'^let nft_template = (".*");$',gen,re.M).group(1))
        chains=re.findall(r'^    chain (capture_\w+) \{\n(.*?)^    \}$',nft,re.M|re.S)
        self.assertEqual(sorted(c for c,_ in chains),['capture_direct','capture_enhanced','capture_global','capture_ondemand','capture_phone'])
        for name,body in chains:
            for line in body.splitlines():
                if 'accept' in line or '0x7610' in line: self.assertIn(' tproxy to :1234',line,name)
                for verb in ('return','jump','goto'): self.assertNotIn(verb,line,name)
        # The direct inbound may already or still listen while another group's has no socket, so a
        # fallen-through member of another group must be dropped before it, and what the direct
        # inbound cannot take is dropped rather than passed on to a later chain (a proxy node).
        direct=[l.strip() for l in dict(chains)['capture_direct'].splitlines() if l.strip() and not l.strip().startswith('#')]
        self.assertEqual(direct[:4],['ip saddr @lanekeep_grp_%s counter drop'%g for g in ('global','enhanced','ondemand','standard')])
        self.assertEqual(direct[-2:],['meta l4proto { tcp, udp } tproxy to :12349 meta mark set 0x7610 counter name captured accept','meta l4proto { tcp, udp } counter drop'])
        # Global, Enhanced and On-demand members reach their own chain first. What their TPROXY cannot
        # take (no socket: core start, stop or failure) is dropped there, so it never reaches the
        # unassigned chain and the Standard or Direct inbound.
        for name,port in (('capture_global',12346),('capture_enhanced',12347),('capture_ondemand',12348)):
            body=[l.strip() for l in dict(chains)[name].splitlines() if l.strip() and not l.strip().startswith('#')]
            self.assertEqual(body,['meta l4proto { tcp, udp } counter name selected ct mark set 0x7611','meta l4proto { tcp, udp } tproxy to :%d meta mark set 0x7610 counter name captured accept'%port,'meta l4proto { tcp, udp } counter drop'],name)
        dispatch=re.search(r'^    chain dispatch_device \{\n(.*?)^    \}$',nft,re.M|re.S).group(1)
        self.assertEqual(re.findall(r'@lanekeep_grp_(\w+) jump',dispatch),['global','enhanced','ondemand','standard','direct'])
        # A shipped unassigned section could replace an unmodified conffile on upgrade; only a
        # first install, before lifecycle has created its state directory, writes direct.
        self.assertNotIn('unassigned',(ROOT/'root/etc/config/lanekeep').read_text(encoding='utf-8'))
        install=(ROOT/'root/usr/libexec/lanekeep-panel/package-install').read_text(encoding='utf-8')
        guard=install.index("if [ ! -e /etc/lanekeep-state ] && ! uci -q get lanekeep.unassigned >/dev/null && shipped_defaults; then")
        self.assertLess(guard,install.index('lifecycle prepare'))
        # sysupgrade keeps the conffiles but not the state directory: a first install also needs
        # every conffile to be the shipped default, so the pinned hashes must match the package.
        makefile=(ROOT/'Makefile').read_text(encoding='utf-8')
        conffiles=makefile.split('define Package/luci-app-lanekeep/conffiles\n',1)[1].split('endef',1)[0].split()
        pinned=dict(reversed(line.split()) for line in install.split("<<'EOF'\n",1)[1].split('\nEOF\n',1)[0].splitlines())
        self.assertEqual(sorted(pinned),sorted(conffiles))
        for path,digest in pinned.items():
            self.assertEqual(hashlib.sha256((ROOT/'root'/path.lstrip('/')).read_bytes()).hexdigest(),digest,path)
        self.assertIn("unassigned:'standard'",(ROOT/'root/usr/libexec/lanekeep-panel/settings.uc').read_text(encoding='utf-8'))

if __name__=='__main__':unittest.main()
