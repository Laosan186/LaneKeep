#!/usr/bin/env python3
"""Create the installed tree with versioned LaneKeep module URLs."""
from pathlib import Path
import argparse,json,re,shutil,os,hashlib
ROOT=Path(__file__).resolve().parents[2]
def materialize(output,version,release):
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',version) or not re.fullmatch(r'[0-9]+',release):raise ValueError('invalid version')
    if output.exists() and any(output.iterdir()):raise ValueError('output must be empty')
    source=ROOT/'root';resources=Path('www/luci-static/resources');namespace='v'+version.replace('.','_')+'_r'+release
    modules={};paths={}
    for p in (source/resources).rglob('*'):
        if not p.is_file():continue
        rel=p.relative_to(source/resources).as_posix()
        if rel.startswith('view/lanekeep/'):new='view/lanekeep/'+namespace+'/'+rel.split('/')[-1]
        elif rel.startswith('lanekeep/'):new='lanekeep/'+namespace+'/'+rel.split('/')[-1]
        elif rel.startswith('lanekeep'):
            new='lanekeep/'+namespace+'/'+('core.js' if rel=='lanekeep.js' else rel[len('lanekeep-'):])
        else:raise ValueError('unexpected frontend file: '+rel)
        paths[rel]=new
        if rel.endswith('.js'):modules[rel[:-3].replace('/','.')]=new[:-3].replace('/','.')
    for p in sorted(source.rglob('*')):
        if not p.is_file():continue
        rel=p.relative_to(source);target=output/rel
        if rel.is_relative_to(resources):target=output/resources/paths[rel.relative_to(resources).as_posix()]
        target.parent.mkdir(parents=True,exist_ok=True)
        if p.suffix=='.dat':target.write_bytes(p.read_bytes())
        else:
            text=p.read_text(encoding='utf-8')
            if p.suffix=='.js':
                for old,new in sorted(modules.items(),key=lambda x:-len(x[0])):
                    text=re.sub(r"(?<=require )"+re.escape(old)+r"(?= as |['\"])",new,text)
                text=text.replace("var version='20261116-style-r2'",f"var version='{version}-r{release}'")
                text=text.replace('lanekeep/panel.css',paths['lanekeep/panel.css'])
            if rel.as_posix()=='usr/share/luci/menu.d/luci-app-lanekeep.json':
                menu=json.loads(text)
                for item in menu.values():
                    a=item.get('action',{})
                    if a.get('type')=='view':a['path']='lanekeep/'+namespace+'/'+a['path'].split('/')[-1]
                text=json.dumps(menu,ensure_ascii=False,indent=2)+'\n'
            target.write_text(text,encoding='utf-8',newline='\n')
        name=rel.as_posix()
        target.chmod(0o755 if name.startswith('etc/init.d/') or name.startswith('usr/libexec/') and p.suffix!='.uc' else 0o600 if name.startswith('etc/config/') or name.startswith('etc/lanekeep-proxy/') else 0o644)
    return modules
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',required=True,type=Path);p.add_argument('--version',default=(ROOT/'VERSION').read_text().strip());p.add_argument('--release',default=(ROOT/'RELEASE').read_text().strip());p.add_argument('--map',type=Path);a=p.parse_args()
    mapping=materialize(a.output,a.version,a.release)
    if a.map:a.map.write_text(json.dumps(mapping,indent=2)+'\n')
    print('Materialized LaneKeep '+a.version+'-r'+a.release)
