// Bounds both UTF-8 JSON and the ubus blob representation.
let MAX=65536,PAGE=50;
function pad(n){return (n+3)&~3;}
function wire(k,v){let t=type(v),n=0;if(t=='array'){for(let a in v)n+=wire('',a);}else if(t=='object'){for(let key,a in v)n+=wire(key,a);}else if(t=='string')n=length(v)+1;else if(t=='bool')n=1;else if(t=='double')n=8;else if(t=='int')n=v>=-2147483648&&v<=2147483647?4:8;return pad(4+pad(2+length(k)+1)+n);}
function fits(v){return length(sprintf('%J',v))+1<=MAX&&wire('',v)+64<=MAX;}
function page(items,offset,base,key){
 key=key||'items';if(type(offset)!='int'||offset<0||offset>length(items))die('page_invalid');let out={...base,offset,total:length(items),next:null};out[key]=[];
 for(let i=offset;i<length(items)&&length(out[key])<PAGE;i++){push(out[key],items[i]);out.next=i+1<length(items)?i+1:null;if(!fits(out)){pop(out[key]);out.next=i;break;}}
 if((offset<length(items)&&!length(out[key]))||!fits(out))die('limit_exceeded');return out;
}
export {MAX,PAGE,wire,fits,page};
