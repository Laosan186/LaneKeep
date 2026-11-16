"""Offline release invariants. Run: python -m unittest discover -s tests -v"""
from pathlib import Path
import hashlib,json,re,sys,tempfile,unittest
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

if __name__=='__main__':unittest.main()
