import {Engine} from './engine.js';
const $=id=>document.getElementById(id);
const canvas=$('world'),engine=new Engine(canvas),params=new URLSearchParams(location.search);
const keys=new Set(),pulse=new Float32Array(32);let ready=false,faulted=false,busy=false,hidden=false,dragging=false;
let width=[768,1024,1600,1920].includes(Number(params.get('width')))?Number(params.get('width')):(matchMedia('(pointer:coarse)').matches?768:1600);
let seed=Number(params.get('seed')??1788);if(!Number.isInteger(seed)||seed<0||seed>9999)seed=1788;
let last=0,mouseX=0,mouseY=0,wheel=0,resizeTimer,noticeTimer,polling=false,resizePending=false;
let frameStart=0,completed=0,displayFPS=0,frameWindow=performance.now(),lastPoll=0,lastInfo=null;
const testing=params.has('test');
const views={1:['An entire district.<br>Not a single mesh file.','Fly from the skyline to individual mortar joints.'],2:['Stone, shade<br>and open arcades.','Columns, vaults and railings are generated geometry.'],3:['The wall is a program.','Joints, fractures, weathering and grain — no texture maps.'],4:['4,096 plots.<br>One compact description.','Coarse silhouettes persist while nearby geometry is generated.'],5:['A different kind<br>of streaming.','No mesh downloads. GPU computation fills the geometry cache.'],6:['Closer is not<br>a bigger texture.','World-space materials and bounded ray-evaluated mortar relief.']};
function notice(text){$('notice').textContent=text;$('notice').classList.add('show');clearTimeout(noticeTimer);noticeTimer=setTimeout(()=>$('notice').classList.remove('show'),3800);}
function fatal(error){if(faulted)return;faulted=true;console.error(error);$('boot').hidden=false;$('status').textContent='The renderer could not start.';$('detail').textContent=String(error?.message??error);$('retry').hidden=false;document.body.classList.remove('ready');}
$('retry').onclick=()=>location.reload();
function chooseView(id){if(!ready)return;pulse[8]=id;document.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('active',Number(b.dataset.view)===id));const v=views[id];if(v){$('place-title').innerHTML=v[0];$('place-sub').textContent=v[1];}}
function toggleNotes(){const p=$('notes');p.classList.toggle('closed');}
function action(slot,text){if(!ready)return;pulse[slot]=1;if(text)notice(text);}
$('quality').value=String(width);$('seed-label').textContent=String(seed);
$('quality').onchange=e=>{width=Number(e.target.value);queueResize();};
$('info-button').onclick=toggleNotes;$('close-notes').onclick=toggleNotes;
$('fullscreen').onclick=()=>document.fullscreenElement?document.exitFullscreen():document.documentElement.requestFullscreen().catch(()=>notice('Fullscreen is not available.'));
$('neural-toggle').onclick=()=>action(11,'Neural substrate toggled. Replacement remains quality-gated.');
$('training-toggle').onclick=()=>action(15,'Training state toggled.');$('cache-toggle').onclick=()=>action(12,'Geometry generation freeze toggled. Existing pages remain visible.');
$('debug-button').onclick=()=>action(10);$('shadow-toggle').onclick=()=>action(14);$('tour').onclick=()=>action(16);
for(const b of document.querySelectorAll('[data-view]'))b.onclick=()=>chooseView(Number(b.dataset.view));
$('export-stats').onclick=()=>{if(lastInfo)downloadBlob(new Blob([JSON.stringify({...lastInfo,seed,capturedAt:new Date().toISOString()},null,2)],{type:'application/json'}),'stratum-measurements.json');};
function downloadBlob(blob,name){const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
async function screenshot(){if(!ready)return;try{const pixels=await engine.screenshotPixels();const c=document.createElement('canvas');c.width=engine.width;c.height=engine.height;c.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(pixels),c.width,c.height),0,0);c.toBlob(blob=>{if(blob)downloadBlob(blob,'stratum-frame.png');});}catch(e){notice(e.message);}}
addEventListener('keydown',e=>{
 if(e.target instanceof HTMLSelectElement)return;
 if(['Space','ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Tab'].includes(e.code))e.preventDefault();
 if(!ready||faulted)return;
 keys.add(e.code);if(e.repeat)return;
 const digits={Digit1:1,Digit2:2,Digit3:3,Digit4:4,Digit5:5,Digit6:6};if(digits[e.code])chooseView(digits[e.code]);
 const actions={KeyN:11,KeyG:12,KeyJ:14,KeyT:15,KeyP:16,KeyV:10};if(actions[e.code])action(actions[e.code]);
 if(e.code==='KeyH'||e.code==='Tab')toggleNotes();
 if(e.code==='KeyF')$('fullscreen').click();
 if(e.code==='KeyC'){hidden=!hidden;document.body.classList.toggle('clean',hidden);}
 if(e.code==='KeyK')screenshot();
 if(e.code==='Escape'){dragging=false;keys.clear();$('notes').classList.add('closed');}
});
addEventListener('keyup',e=>keys.delete(e.code));
function clearControls(){keys.clear();mouseX=0;mouseY=0;wheel=0;pulse.fill(0);dragging=false;}
addEventListener('blur',clearControls);addEventListener('visibilitychange',()=>{clearControls();last=0;});
canvas.addEventListener('contextmenu',e=>e.preventDefault());
canvas.addEventListener('pointerdown',e=>{e.preventDefault();canvas.focus();dragging=true;canvas.setPointerCapture(e.pointerId);});
canvas.addEventListener('pointermove',e=>{if(dragging){mouseX+=e.movementX;mouseY+=e.movementY;}});
canvas.addEventListener('pointerup',()=>dragging=false);canvas.addEventListener('pointercancel',clearControls);
canvas.addEventListener('wheel',e=>{e.preventDefault();wheel+=e.deltaY;},{passive:false});
function fillInput(){
 const i=engine.input;i.fill(0);
 i[0]=Number(keys.has('KeyW')||keys.has('ArrowUp'))-Number(keys.has('KeyS')||keys.has('ArrowDown'));
 i[1]=Number(keys.has('KeyD')||keys.has('ArrowRight'))-Number(keys.has('KeyA')||keys.has('ArrowLeft'));
 i[2]=Number(keys.has('KeyE')||keys.has('Space'))-Number(keys.has('KeyQ'));
 i[3]=mouseX;i[4]=mouseY;i[5]=Number(keys.has('ShiftLeft')||keys.has('ShiftRight'));i[6]=Number(keys.has('ControlLeft')||keys.has('ControlRight'));i[7]=wheel;
 i[9]=Number(keys.has('BracketRight'))-Number(keys.has('BracketLeft'));
 i[13]=Number(keys.has('Equal'))-Number(keys.has('Minus'));
 for(let k=0;k<pulse.length;k++)if(pulse[k])i[k]=pulse[k];pulse.fill(0);mouseX=0;mouseY=0;wheel=0;
}
function dimensions(){return [width,Math.round(width*innerHeight/innerWidth)];}
function queueResize(){clearTimeout(resizeTimer);resizeTimer=setTimeout(()=>resizePending=true,150);}
addEventListener('resize',queueResize);
const fmt=n=>Math.round(n).toLocaleString();const mib=n=>(n/1048576).toFixed(1)+' MiB';
async function poll(){
 if(polling)return;polling=true;
 try{
  const v=await engine.inspect();lastInfo=v;const s=v.stats,b=v.brain,c=v.camera;
  $('primitive-count').textContent=fmt(s[3]);$('pages-count').textContent=`${fmt(s[0])} / 256`;
  $('generated-count').textContent=fmt(s[1]);$('pending-count').textContent=fmt(s[2]);
  $('reuse-count').textContent=`${fmt(s[5])} / ${fmt(s[4])}`;$('cache-memory').textContent=mib(v.cacheBytes);$('total-memory').textContent=mib(v.allocatedBytes);
  $('nn-steps').textContent=fmt(b[0]);$('nn-error').textContent=b[1]>0?`${b[2].toExponential(2)} / ${b[3].toExponential(2)}`:'Waiting for samples';
  $('nn-state').textContent=c[16]>.5?(b[4]>.5?'VALIDATED · ACTIVE':'WAITING FOR QUALITY GATE'):'OFF';
  $('neural-toggle').textContent=c[16]>.5?'N · Disable neural substrate':'N · Enable neural substrate';
  $('training-toggle').textContent=c[21]>.5?'T · Resume training':'T · Freeze training';
  $('cache-toggle').textContent=c[17]>.5?'G · Resume generation':'G · Freeze generation';
  $('camera-height').textContent=`${c[1]<10?c[1].toFixed(2):fmt(c[1])} m`;
  $('render-size').textContent=`${v.width} × ${v.height}`;
  if(v.timings){$('timings').replaceChildren(...v.timings.map(({label,ms})=>{const row=document.createElement('div');row.className='timing-row';const a=document.createElement('span'),b=document.createElement('strong');a.textContent=label;b.textContent=ms.toFixed(2)+' ms';row.append(a,b);return row;}));}
  $('tour').classList.toggle('active',c[22]>.5);
 }catch(e){fatal(e);}finally{polling=false;}
}
async function frame(now){
 requestAnimationFrame(frame);
 if(!ready||faulted||testing||document.hidden)return;
 if(busy)return;
 if(resizePending){resizePending=false;busy=true;try{await engine.resize(...dimensions());}catch(e){fatal(e);}finally{busy=false;last=0;}return;}
 const dt=last?Math.min(.1,(now-last)/1000):1/60;last=now;fillInput();busy=true;frameStart=performance.now();
 try{engine.frame(dt);await engine.device.queue.onSubmittedWorkDone();completed++;}catch(e){fatal(e);}finally{busy=false;}
 if(now-frameWindow>=1000){displayFPS=completed*1000/(now-frameWindow);completed=0;frameWindow=now;$('frame-time').textContent=`${displayFPS.toFixed(1)} FPS`;}
 if(now-lastPoll>650){lastPoll=now;poll();}
}
async function start(){try{
 const [w,h]=dimensions();await engine.init({width:w,height:h,seed,recompile:params.has('compile'),onProgress:(name,f)=>{$('status').textContent=`Compiling ${name}`;$('progress').style.width=`${Math.round(f*100)}%`;},onError:fatal});
 // Warm the bounded cache while the first views are built. No world image is substituted.
 for(let i=0;i<12;i++){engine.frame(1/60,{draw:false});await engine.runtime.idle();$('status').textContent=`Generating the first geometry pages · ${i+1}/12`;}
 if(faulted)return;ready=true;document.body.classList.add('ready');$('boot').hidden=true;canvas.focus();
 window.stratum={engine,ready:true,chooseView,screenshot,inspect:()=>engine.inspect()};
 engine.frame(1/60);await engine.runtime.idle();await poll();requestAnimationFrame(frame);
 if(matchMedia('(pointer:coarse)').matches)notice('This build uses keyboard flight controls. Drag to look; use the view buttons to explore.');
}catch(e){fatal(e);}}
start();
