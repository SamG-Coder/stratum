import {GpuRuntime} from '../vendor/cuda-webshader/runtime/runtime.js';

export const ABI = Object.freeze({
  CITY:64, PAGES:256, PRIMS:2048, NODES:4096, PRIMITIVE_FLOATS:16, PAGE_FLOATS:12,
  GENERATION_BUDGET:6, NN_PARAMS:291, NN_BATCH:64, NN_STRIDE:64,
});
const STAGES=['Generate + BVH','Visibility','Neural training','Materials + light','Resolve'];

/** Browser transport only. Scene generation, visibility, materials and learning are CUDA. */
export class Engine {
  constructor(canvas){
    this.canvas=canvas;this.buffers={};this.kernels={};this.input=new Float32Array(32);
    this.frames=0;this.errors=[];this.timings=null;this.timingBusy=false;this.disposed=false;
  }
  async init({width=1600,height=900,seed=1788,recompile=false,onProgress=()=>{},onError=()=>{},device=null,adapter=null}={}){
    const ownsDevice=!device;
    if(!device){
      if(!globalThis.navigator?.gpu)throw Error('WebGPU is unavailable. Open on localhost or HTTPS in a WebGPU-capable browser.');
      adapter=await navigator.gpu.requestAdapter({powerPreference:'high-performance'});
      if(!adapter)throw Error('No WebGPU adapter was found. Check hardware acceleration and your graphics driver.');
      const requiredFeatures=adapter.features.has('timestamp-query')?['timestamp-query']:[];
      device=await adapter.requestDevice({requiredFeatures});
    }
    this.device=device;this.adapter=adapter;
    this.runtime=new GpuRuntime(device,{adapter,ownsDevice,uniformCapacity:262144,onError:e=>{this.errors.push(String(e?.message||e));onError(e);}});
    this.info=this.runtime.describe();this.context=this.canvas?.getContext('webgpu')??null;
    const response=await fetch(new URL('../generated/manifest.json',import.meta.url));
    if(!response.ok)throw Error('Missing generated shader manifest. Extract the complete ZIP, then start the server.');
    this.manifest=await response.json();let compile;const sources=new Map();
    if(recompile)({compile}=await import('../vendor/cuda-webshader/compiler/compiler.js'));
    for(let i=0;i<this.manifest.length;i++){
      const spec=this.manifest[i];onProgress(spec.entry,i/this.manifest.length);
      let artifact;
      if(compile){
        for(const f of spec.dependencies)if(!sources.has(f))sources.set(f,await(await fetch(new URL(`../kernels/${f}.cu`,import.meta.url))).text());
        artifact=compile(spec.dependencies.map(f=>sources.get(f)).join('\n'),{entry:spec.entry,workgroupSize:spec.workgroupSize});
      }else{
        const res=await fetch(new URL(`../generated/${spec.entry}.json`,import.meta.url));
        if(!res.ok)throw Error(`Missing generated kernel: ${spec.entry}`);artifact=await res.json();
      }
      this.kernels[spec.entry]=await this.runtime.kernel(artifact);
    }
    const a=ABI;
    const sizes={World:a.CITY*a.CITY*8,Meta:a.PAGES*a.PAGE_FLOATS,C:64,I:32,
      Req:a.PAGES*8,Queue:a.GENERATION_BUDGET+1,P:a.PAGES*a.PRIMS*a.PRIMITIVE_FLOATS,
      Order:a.PAGES*a.PRIMS,Nodes:a.PAGES*a.NODES*8,Stats:32,
      W:a.NN_PARAMS,M:a.NN_PARAMS,V:a.NN_PARAMS,Brain:32,Grad:a.NN_PARAMS,Work:a.NN_BATCH*a.NN_STRIDE};
    for(const [name,count]of Object.entries(sizes))this.buffers[name]=this.runtime.createBuffer(count*4,{label:`STRATUM ${name}`});
    if(device.features.has('timestamp-query')){
      this.queries=device.createQuerySet({type:'timestamp',count:10});
      this.queryResolve=device.createBuffer({size:256,usage:GPUBufferUsage.QUERY_RESOLVE|GPUBufferUsage.COPY_SRC});
      this.queryRead=device.createBuffer({size:80,usage:GPUBufferUsage.COPY_DST|GPUBufferUsage.MAP_READ});
    }
    await this.resize(width,height);
    this.runtime.batch().dispatch(this.bind('initWorld',{seed}),[64]).dispatch(this.bind('initNeural',{seed}),[5]).submit();
    await this.runtime.idle();onProgress('Ready',1);return this;
  }
  bind(entry,scalars={}){
    const k=this.kernels[entry];if(!k)throw Error(`Unknown kernel ${entry}`);
    const values=Object.fromEntries(k.artifact.metadata.bindings.map(b=>{
      const resource=this.buffers[b.name];if(!resource)throw Error(`Missing buffer ${entry}.${b.name}`);return [b.name,resource];
    }));
    return k.bind(values,scalars);
  }
  async resize(width,height){
    if(!Number.isFinite(width)||!Number.isFinite(height))throw Error('Invalid render dimensions');
    // RGBA rows are padded to the required 256-byte copy alignment.
    width=Math.max(320,Math.ceil(width/64)*64);height=Math.max(192,Math.ceil(height/8)*8);
    const max=this.device.limits.maxTextureDimension2D;
    if(width>max||height>max||width*height*16>this.device.limits.maxStorageBufferBindingSize)throw Error('Render dimensions exceed this GPU’s limits. Select a lower resolution.');
    if(width===this.width&&height===this.height)return;
    await this.runtime.idle();
    for(const key of ['Hit','Linear','History','Pixels'])if(this.buffers[key])this.runtime.destroyBuffer(this.buffers[key]);
    this.width=width;this.height=height;
    for(const key of ['Hit','Linear','History'])this.buffers[key]=this.runtime.createBuffer(width*height*16,{label:key});
    this.buffers.Pixels=this.runtime.createBuffer(width*height*4,{label:'CUDA final RGBA8'});
    if(this.canvas){this.canvas.width=width;this.canvas.height=height;}
    if(this.context)this.context.configure({device:this.device,format:'rgba8unorm',usage:GPUTextureUsage.COPY_DST|GPUTextureUsage.RENDER_ATTACHMENT,alphaMode:'opaque'});
    this.buildBindings();
  }
  buildBindings(){
    const dimensions={width:this.width,height:this.height};this.calls={};
    for(const name of ['selectPages','schedulePages','generatePages','sortPages','commitPages','summarise','materialForward','scoreMaterial','materialGradient','materialAdam'])this.calls[name]=this.bind(name);
    for(const name of ['tracePrimary','prepareMaterialBatch','shadePixels','resolveFrame'])this.calls[name]=this.bind(name,dimensions);
    this.calls.stepCamera=this.bind('stepCamera',{...dimensions,dt:1/60});
    this.bvh=[];for(let first=ABI.PRIMS/2;first>=1;first/=2)this.bvh.push([this.bind('buildBVH',{first}),Math.ceil(ABI.GENERATION_BUDGET*first/64)]);
  }
  stage(index,timestamp){
    return this.runtime.batch({label:`STRATUM / ${STAGES[index]}`,...(timestamp?{timestampWrites:{querySet:this.queries,beginningOfPassWriteIndex:index*2,endOfPassWriteIndex:index*2+1}}:{})});
  }
  frame(dt=1/60,{draw=true,train=true}={}){
    if(this.disposed)throw Error('Renderer is disposed');
    this.runtime.write(this.buffers.I,this.input);
    const timed=!!this.queries&&!this.timingBusy&&this.frames%12===0;
    const c=this.calls,groups=[Math.ceil(this.width/8),Math.ceil(this.height/8)];
    const gen=this.stage(0,timed);
    c.stepCamera.setScalars({width:this.width,height:this.height,dt:Math.max(0,Math.min(.1,dt))});
    gen.dispatch(c.stepCamera,[1]).dispatch(c.selectPages,[4]).dispatch(c.schedulePages,[1])
      .dispatch(c.generatePages,[ABI.GENERATION_BUDGET]).dispatch(c.sortPages,[ABI.GENERATION_BUDGET]);
    for(const [call,count]of this.bvh)gen.dispatch(call,[count]);
    gen.dispatch(c.commitPages,[1]).dispatch(c.summarise,[1]).submit();
    if(draw){
      this.stage(1,timed).dispatch(c.tracePrimary,groups).submit();
      const learn=this.stage(2,timed);
      // Dispatching the gated kernels produces defined timestamp results, including frozen frames.
      if(train)learn.dispatch(c.prepareMaterialBatch,[1]).dispatch(c.materialForward,[1]).dispatch(c.scoreMaterial,[1]).dispatch(c.materialGradient,[5]).dispatch(c.materialAdam,[5]);
      else learn.beginPass();
      learn.submit();
      this.stage(3,timed).dispatch(c.shadePixels,groups).submit();
      const resolve=this.stage(4,timed);resolve.dispatch(c.resolveFrame,groups);resolve.endPass();
      if(this.context)resolve.encoder.copyBufferToTexture({buffer:this.buffers.Pixels.gpuBuffer,bytesPerRow:this.width*4,rowsPerImage:this.height},{texture:this.context.getCurrentTexture()},[this.width,this.height]);
      if(timed){resolve.encoder.resolveQuerySet(this.queries,0,10,this.queryResolve,0);resolve.encoder.copyBufferToBuffer(this.queryResolve,0,this.queryRead,0,80);}
      resolve.submit();if(timed)this.readTimings();
    }
    this.frames++;
  }
  async readTimings(){
    this.timingBusy=true;
    try{await this.queryRead.mapAsync(GPUMapMode.READ);const times=new BigUint64Array(this.queryRead.getMappedRange());this.timings=STAGES.map((label,i)=>({label,ms:Number(times[i*2+1]-times[i*2])/1e6}));this.queryRead.unmap();}
    catch(e){console.warn('GPU timestamp readback unavailable',e);this.timings=null;}
    finally{this.timingBusy=false;}
  }
  async inspect(){
    const [stats,brain,camera]=await Promise.all(['Stats','Brain','C'].map(k=>this.runtime.read(this.buffers[k])));
    return {stats:Array.from(stats),brain:Array.from(brain),camera:Array.from(camera),timings:this.timings,allocatedBytes:Object.values(this.buffers).reduce((n,b)=>n+b.byteLength,0),cacheBytes:['P','Nodes','Order','Meta'].reduce((n,k)=>n+this.buffers[k].byteLength,0),width:this.width,height:this.height,frames:this.frames,adapter:this.info};
  }
  async screenshotPixels(){return this.runtime.read(this.buffers.Pixels,Uint8Array);}
  async reset(seed=1788){
    await this.runtime.idle();this.input.fill(0);this.runtime.batch().dispatch(this.bind('initWorld',{seed}),[64]).dispatch(this.bind('initNeural',{seed}),[5]).clear(this.buffers.History).clear(this.buffers.Stats).submit();await this.runtime.idle();
  }
  async dispose(){if(this.disposed)return;await this.runtime.idle();this.disposed=true;this.queries?.destroy();this.queryResolve?.destroy();this.queryRead?.destroy();this.runtime.dispose();}
}
