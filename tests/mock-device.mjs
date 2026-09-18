// API-contract test double ONLY. This does not compile WGSL or emulate GPU arithmetic.
export function installConstants(){
 globalThis.GPUBufferUsage={MAP_READ:1,MAP_WRITE:2,COPY_SRC:4,COPY_DST:8,INDEX:16,VERTEX:32,UNIFORM:64,STORAGE:128,INDIRECT:256,QUERY_RESOLVE:512};
 globalThis.GPUTextureUsage={COPY_SRC:1,COPY_DST:2,TEXTURE_BINDING:4,STORAGE_BINDING:8,RENDER_ATTACHMENT:16};
 globalThis.GPUShaderStage={COMPUTE:4};globalThis.GPUMapMode={READ:1,WRITE:2};
}
export function mockDevice(){
 const calls=[];const limits={minUniformBufferOffsetAlignment:256,maxUniformBufferBindingSize:65536,maxStorageBufferBindingSize:134217728,maxBufferSize:268435456,maxComputeWorkgroupSizeX:256,maxComputeWorkgroupSizeY:256,maxComputeWorkgroupSizeZ:64,maxComputeInvocationsPerWorkgroup:256,maxComputeWorkgroupStorageSize:16384,maxStorageBuffersPerShaderStage:8,maxSampledTexturesPerShaderStage:16,maxSamplersPerShaderStage:16,maxComputeWorkgroupsPerDimension:65535,maxTextureDimension2D:8192};
 const device={limits,features:new Set(),lost:new Promise(()=>{}),calls,addEventListener(){},removeEventListener(){},destroy(){},pushErrorScope(){},async popErrorScope(){return null;},
  createBuffer(d){const bytes=new ArrayBuffer(d.size);return{...d,bytes,mapAsync:async()=>{},getMappedRange:(o=0,n=d.size)=>o===0&&n===d.size?bytes:bytes.slice(o,o+n),unmap(){},destroy(){this.destroyed=true;}};},
  createShaderModule(d){return{...d,getCompilationInfo:async()=>({messages:[]})};},
  createBindGroupLayout(d){return d;},createPipelineLayout(d){return d;},async createComputePipelineAsync(d){return d;},
  createBindGroup(d){for(const e of d.entries){if(e.resource.buffer&&e.resource.size>e.resource.buffer.size)throw Error('Binding overflows buffer');}return d;},
  createCommandEncoder(){const commands=[];return{
   beginComputePass(){return{setPipeline(p){calls.push(['pipeline',p.label]);},setBindGroup(){},dispatchWorkgroups(...groups){if(groups.some(v=>!Number.isInteger(v)||v<0||v>65535))throw Error('Invalid dispatch dimensions');calls.push(['dispatch',...groups]);},end(){}};},
   copyBufferToBuffer(a,ao,b,bo,size){commands.push(()=>{if(ao+size>a.size||bo+size>b.size)throw Error('Copy out of bounds');new Uint8Array(b.bytes,bo,size).set(new Uint8Array(a.bytes,ao,size));});},
   copyBufferToTexture(src,dst,size){if(src.bytesPerRow%256)throw Error('Unaligned texture row');if(src.buffer.size<src.bytesPerRow*size[1])throw Error('Texture source too small');calls.push(['present',...size]);},
   clearBuffer(b,o=0,size=b.size){commands.push(()=>new Uint8Array(b.bytes,o,size).fill(0));},finish(){return commands;}
  };}
 };
 device.queue={writeBuffer(b,offset,data,dataOffset=0,size){const source=data instanceof ArrayBuffer?new Uint8Array(data,dataOffset,size??data.byteLength-dataOffset):new Uint8Array(data.buffer,data.byteOffset+dataOffset,size??data.byteLength-dataOffset);new Uint8Array(b.bytes,offset,source.byteLength).set(source);},submit(cmds){for(const commands of cmds)for(const command of commands)command();},onSubmittedWorkDone:async()=>{}};
 return device;
}
export function mockCanvas(){return{width:0,height:0,getContext(){return{configure(d){if(d.format!=='rgba8unorm')throw Error('Wrong presentation format');},getCurrentTexture(){return{};}};}};}
