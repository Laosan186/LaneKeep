// SPDX-License-Identifier: GPL-3.0-only
// Prints three addresses inside the selected LAN subnet (never the router address).
import * as lan from '../../root/usr/libexec/lanekeep-panel/network.uc';
let c=lan.context(),out=[];
for(let n=c.network+1;n<c.broadcast&&length(out)<3;n++){let a=lan.address(n);if(a!=c.address)push(out,a);}
print(join(' ',out),'\n');
