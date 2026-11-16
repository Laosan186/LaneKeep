// Bounded DNS wire codec for A-only resolution; no resolver or network policy here.
function bad(){die('fetch_failed');}
function u16(s,p){if(p+2>length(s))bad();return ord(substr(s,p,1))*256+ord(substr(s,p+1,1));}
function name(s,p){let labels=[],seen={},at=p.i,jumped=false,steps=0;
 while(++steps<=128){if(at>=length(s)||seen[at])bad();seen[at]=true;let n=ord(substr(s,at++,1));
  if((n&192)==192){if(at>=length(s))bad();if(!jumped)p.i=at+1;at=((n&63)<<8)+ord(substr(s,at,1));jumped=true;continue;}
  if(n&192||n>63||at+n>length(s))bad();if(n==0){if(!jumped)p.i=at;let value=lc(join('.',labels));if(length(value)>253)bad();return value;}
  let label=substr(s,at,n);if(!match(label,/^[A-Za-z0-9_-]+$/))bad();push(labels,label);at+=n;
 }bad();
}
function query(host,id){let s=chr(id>>8,id&255,1,0,0,1,0,0,0,0,0,0);for(let l in split(host,'.')){if(!length(l)||length(l)>63)bad();s+=chr(length(l))+l;}return s+chr(0,0,1,0,1);}
function answer(s,host,id){
 if(type(s)!='string'||length(s)<12||length(s)>65535||u16(s,0)!=id||(u16(s,2)&0xfa0f)!=0x8000||u16(s,4)!=1)bad();
 let p={i:12};if(name(s,p)!=lc(host)||u16(s,p.i)!=1||u16(s,p.i+2)!=1)bad();p.i+=4;
 let answers=u16(s,6),count=answers+u16(s,8)+u16(s,10);if(count>128||!answers)bad();let records=[],all=[];
 for(let i=0;i<count;i++){let owner=name(s,p),type=u16(s,p.i),cls=u16(s,p.i+2),n=u16(s,p.i+8);p.i+=10;if(p.i+n>length(s))bad();
  if(type==1&&cls==1){if(n!=4)bad();let ip=join('.',map([0,1,2,3],k=>ord(substr(s,p.i+k,1))));push(all,ip);if(i<answers)push(records,{owner,ip});}
  if(type==5&&cls==1&&i<answers){let q={i:p.i},alias=name(s,q);if(q.i!=p.i+n)bad();push(records,{owner,alias});}
  if(type==28&&cls==1)bad();p.i+=n;
 }
 if(p.i!=length(s))bad();let reached={},next=lc(host),out=[];
 for(let i=0;i<16;i++){if(reached[next])bad();reached[next]=true;let a=filter(records,r=>r.owner==next&&r.ip);if(length(a)){out=map(a,r=>r.ip);break;}let aliases=filter(records,r=>r.owner==next&&r.alias);if(length(aliases)!=1)bad();next=aliases[0].alias;}
 if(!length(out))bad();return {addresses:out,all_addresses:all};
}
export {query,answer};
