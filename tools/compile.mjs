import fs from 'node:fs/promises';
import {compile} from '../vendor/cuda-webshader/compiler/compiler.js';
const root=new URL('../',import.meta.url);
const files=['common','world','assets','cache','trace','materials','learning','shade'];
const groups={world:{initWorld:64,stepCamera:1,selectPages:64,schedulePages:1,commitPages:64,summarise:1},assets:{generatePages:64},cache:{sortPages:256,buildBVH:64},trace:{tracePrimary:[8,8,1]},learning:{initNeural:64,prepareMaterialBatch:64,materialForward:64,scoreMaterial:1,materialGradient:64,materialAdam:64},shade:{shadePixels:[8,8,1],resolveFrame:[8,8,1]}};
const text=Object.fromEntries(await Promise.all(files.map(async f=>[f,await fs.readFile(new URL(`kernels/${f}.cu`,root),'utf8')])));
// Select dependencies explicitly; the bundled compiler emits all declared device helpers.
const dependencies={world:['common','world'],assets:['common','assets'],cache:['common','cache'],trace:['common','trace'],learning:['common','trace','materials','learning'],shade:['common','trace','materials','shade']};
await fs.mkdir(new URL('generated/',root),{recursive:true});const manifest=[];let failed=0;
for(const [file,entries]of Object.entries(groups))for(const [entry,block]of Object.entries(entries)){
 const workgroupSize=Array.isArray(block)?block:[block,1,1];
 try{
  const source=dependencies[file].map(f=>text[f]).join('\n');
  const artifact=compile(source,{entry,workgroupSize});const {ast,kernel,...portable}=artifact;
  await fs.writeFile(new URL(`generated/${entry}.json`,root),JSON.stringify(portable));
  await fs.writeFile(new URL(`generated/${entry}.wgsl`,root),artifact.wgsl);
  manifest.push({entry,file,workgroupSize,dependencies:dependencies[file],bindings:artifact.metadata.bindings.map(x=>x.name),uniformBytes:artifact.metadata.uniformSize});
  console.log(`OK ${entry}: ${artifact.wgsl.length} WGSL bytes, ${artifact.metadata.bindings.length} buffers`);
 }catch(e){console.error(`FAILED ${entry}: ${e.stack||e.message}`);failed++;}
}
await fs.writeFile(new URL('generated/manifest.json',root),JSON.stringify(manifest,null,2));
await fs.writeFile(new URL('Stratum.cu',root),'// Generated combined CUDA source. Rebuild split kernels with npm run build.\n'+files.map(f=>`\n// ===== ${f.toUpperCase()} =====\n${text[f]}`).join('\n'));
if(failed)process.exitCode=1;
