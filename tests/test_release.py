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

if __name__=='__main__':unittest.main()
