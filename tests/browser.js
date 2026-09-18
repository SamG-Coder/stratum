import {Engine,ABI} from '../src/engine.js';
const log=document.querySelector('#log');const say=t=>log.textContent+=t+'\n';
let previousEngine=null;
function check(ok,name){if(!ok)throw Error(name);say('PASS '+name);}
document.querySelector('#run').onclick=async()=>{
 document.querySelector('#run').disabled=true;log.textContent='';let engine;
 try{
  if(previousEngine){await previousEngine.dispose();previousEngine=null;}
  const errors=[];engine=await new Engine(document.querySelector('canvas')).init({width:320,height:192,onProgress:n=>say('Compile '+n),onError:e=>errors.push(e.message??String(e))});
  previousEngine=engine;
  say('Adapter: '+JSON.stringify(engine.info));
  engine.input[8]=2;engine.frame(1/60,{draw:false});await engine.runtime.idle();engine.input.fill(0);
  for(let i=0;i<40;i++){engine.frame(1/60,{draw:false});await engine.runtime.idle();}
  let info=await engine.inspect();check(info.stats[0]>20,'procedural pages exist');check(info.stats[3]>2000,'primitive count is nonzero');
  engine.frame();await engine.runtime.idle();info=await engine.inspect();check(info.stats[1]===0,'stationary camera reuses its pages');
  const pixels=await engine.screenshotPixels();let nonzero=0;for(let i=0;i<pixels.length;i+=4)if(pixels[i]+pixels[i+1]+pixels[i+2]>20)nonzero++;check(nonzero>320*192*.8,'render output is not blank');
  const meta=await engine.runtime.read(engine.buffers.Meta);const slot=Array.from({length:ABI.PAGES},(_,i)=>i).find(i=>meta[i*ABI.PAGE_FLOATS+3]>.5);
  const prim=await engine.runtime.read(engine.buffers.P,Float32Array,ABI.PRIMS*16*4,slot*ABI.PRIMS*16*4);
  const order=await engine.runtime.read(engine.buffers.Order,Int32Array,ABI.PRIMS*4,slot*ABI.PRIMS*4);
  check(new Set(order).size===ABI.PRIMS&&Array.from(order).every(v=>v>=slot*ABI.PRIMS&&v<(slot+1)*ABI.PRIMS),'cooperative sort produces a page-local permutation');
  const root=await engine.runtime.read(engine.buffers.Nodes,Float32Array,32,(slot*ABI.NODES+1)*32);let count=0;for(let i=0;i<ABI.PRIMS;i++)if(prim[i*16+3]>=0)count++;
  check(root[3]===count,'BVH root matches actual primitive count');
  engine.input[8]=3;engine.frame(1/60,{draw:false});engine.input.fill(0);for(let i=0;i<30;i++){engine.frame(1/60,{draw:false});await engine.runtime.idle();}
  const before=await engine.runtime.read(engine.buffers.W);for(let i=0;i<24;i++){engine.frame();await engine.runtime.idle();}
  const after=await engine.runtime.read(engine.buffers.W);info=await engine.inspect();check(info.brain[0]>0,'online optimizer runs');check(after.some((v,i)=>v!==before[i]),'neural weights change');check(after.every(Number.isFinite),'neural weights remain finite');
  engine.input[15]=1;engine.frame();await engine.runtime.idle();engine.input.fill(0);const frozen=await engine.runtime.read(engine.buffers.W);
  for(let i=0;i<5;i++){engine.frame();await engine.runtime.idle();}const frozenAfter=await engine.runtime.read(engine.buffers.W);check(frozen.every((v,i)=>v===frozenAfter[i]),'training freezes without freezing the renderer');
  check(errors.length===0,'no uncaptured GPU validation errors');say('\nActual measurements:\n'+JSON.stringify(await engine.inspect(),null,2));say('\nAll requested GPU checks completed.');
 }catch(e){say('FAIL '+(e.stack??e));console.error(e);}finally{document.querySelector('#run').disabled=false;}
};
