#!/usr/bin/env python3
"""Build with a full apk-tools 3.x mkpkg, on Linux (no SDK C compilation needed)."""
from pathlib import Path
import argparse,subprocess,tempfile,hashlib,json,os
from materialize import materialize,ROOT
DEPENDS=['luci-base','rpcd','rpcd-mod-ucode','uhttpd-mod-ubus','xray-core','v2ray-geoip','v2ray-geosite','firewall4','nftables-json','kmod-nft-tproxy','kmod-nft-socket','ip-full','ucode','ucode-mod-fs','ucode-mod-uci','ucode-mod-ubus','ucode-mod-math','ucode-mod-socket','ucode-mod-struct','ucode-mod-digest','ca-bundle','curl','flock','coreutils-timeout']
p=argparse.ArgumentParser();p.add_argument('--apk',default='apk');p.add_argument('--output',type=Path,default=ROOT/'dist');p.add_argument('--release',default=(ROOT/'RELEASE').read_text().strip());a=p.parse_args()
version=(ROOT/'VERSION').read_text().strip();a.output.mkdir(parents=True,exist_ok=True);dest=a.output/f'luci-app-lanekeep-{version}-r{a.release}.apk'
if dest.exists():raise SystemExit('Refusing to overwrite an existing artifact')
with tempfile.TemporaryDirectory(prefix='lanekeep-build-') as tmp:
    stage=Path(tmp)/'root';materialize(stage,version,a.release)
    metadata=stage/'lib/apk/packages';metadata.mkdir(parents=True)
    configs=['/etc/config/lanekeep','/etc/config/lanekeep_runtime','/etc/lanekeep-proxy/nodes.json']
    (metadata/'luci-app-lanekeep.conffiles').write_text('\n'.join(configs)+'\n')
    (metadata/'luci-app-lanekeep.conffiles_static').write_text(''.join(f'{name} {hashlib.sha256((stage/name.lstrip("/")).read_bytes()).hexdigest()}\n' for name in configs))
    (metadata/'luci-app-lanekeep.list').write_text('\n'.join('/'+p.relative_to(stage).as_posix() for p in sorted(stage.rglob('*')) if p.is_file())+'\n')
    command=[a.apk,'mkpkg','--info','name:luci-app-lanekeep','--info',f'version:{version}-r{a.release}','--info','arch:noarch','--info','license:GPL-3.0-only','--info','description:Per-device split routing with protected DNS and explicit activation','--info','origin:luci-app-lanekeep','--info','maintainer:LaneKeep contributors','--info','depends:'+' '.join(DEPENDS)]
    for phase in ['post-install','pre-upgrade','post-upgrade','pre-deinstall','post-deinstall']:command+=['--script',phase+':'+str(ROOT/'packaging'/phase)]
    epoch=int(os.environ.get('SOURCE_DATE_EPOCH','1794787200'))
    for p in stage.rglob('*'):os.utime(p,(epoch,epoch))
    command+=['--files',str(stage),'--output',str(dest)]
    subprocess.run(command,check=True,env={**os.environ,'SOURCE_DATE_EPOCH':str(epoch)})
digest=hashlib.sha256(dest.read_bytes()).hexdigest();(dest.with_suffix('.apk.sha256')).write_text(digest+'  '+dest.name+'\n');print(dest.name,digest)
