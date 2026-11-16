#!/usr/bin/env python3
"""Serve demo data and exactly the versioned modules shipped in the APK."""
from pathlib import Path
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
import argparse,sys,shutil,tempfile,json
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/build'))
from materialize import materialize
p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8766);a=p.parse_args()
parent=ROOT/'build';parent.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='preview-',dir=parent) as work:
    work=Path(work);web=work/'www';shutil.copytree(ROOT/'tools/preview/public',web)
    installed=work/'installed';mapping=materialize(installed,(ROOT/'VERSION').read_text().strip(),(ROOT/'RELEASE').read_text().strip())
    shutil.copytree(installed/'www/luci-static/resources',web/'luci-static/resources')
    (web/'module-map.js').write_text('window.LaneKeepModules='+json.dumps(mapping)+';\n')
    class Handler(SimpleHTTPRequestHandler):
        def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(web),**kwargs)
        def do_POST(self):self.send_error(405,'Preview has no network RPC')
        def log_message(self,*args):pass
    server=ThreadingHTTPServer(('127.0.0.1',a.port),Handler)
    print(f'LaneKeep demo preview: http://127.0.0.1:{a.port}',flush=True)
    server.serve_forever()
