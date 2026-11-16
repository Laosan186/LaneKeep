import * as store from './store.uc';
function take(snapshots,now){
 let request=store.read('mark-request.json');if(!request)return {snapshots};store.remove_request();
 if((type(request.mono)!='double'&&type(request.mono)!='int')||request.mono>now+1||request.mono<now-15)return {snapshots};
 if(length(filter(snapshots,s=>!s.complete))>=2)return {snapshots};
 let slot=0;if(length(snapshots)==2){let ready=filter(snapshots,s=>s.complete);slot=ready[0].slot;snapshots=filter(snapshots,s=>s.slot!=slot);}else if(length(snapshots))slot=1-snapshots[0].slot;
 store.clear('snapshot-'+slot+'.ring');let snap={slot,mark:request.mono,until:request.mono+600,complete:false,count:0,first:null,last:null};
 for(let r in store.rows('raw.ring',720))if(r.mono>=request.mono-600&&r.mono<=request.mono){store.put('snapshot-'+slot+'.ring',250,snap.count++,r);if(snap.first==null)snap.first=r.mono;snap.last=r.mono;}
 push(snapshots,snap);return {snapshots,mark:request.mono,slot};
}
function capture(snapshots,row){for(let s in snapshots){if(s.complete)continue;if(row.mono>s.mark&&row.mono<=s.until&&(s.last==null||row.mono>s.last)){store.put('snapshot-'+s.slot+'.ring',250,s.count++,row);if(s.first==null)s.first=row.mono;s.last=row.mono;}if(row.mono>=s.until)s.complete=true;}}
export { take, capture };
