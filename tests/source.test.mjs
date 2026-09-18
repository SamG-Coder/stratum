import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';
import {compile} from '../vendor/cuda-webshader/compiler/compiler.js';
import {Engine,ABI} from '../src/engine.js';import {installConstants,mockDevice,mockCanvas} from './mock-device.mjs';
const root=new URL('../',import.meta.url);const manifest=JSON.parse(await fs.readFile(new URL('generated/manifest.json',root),'utf8'));
const cache=new Map();async function source(name){if(!cache.has(name))cache.set(name,await fs.readFile(new URL(`kernels/${name}.cu`,root),'utf8'));return cache.get(name);}
test('all 18 CUDA entry points rebuild into the shipped WGSL',async()=>{
 assert.equal(manifest.length,18);
 for(const spec of manifest){const text=(await Promise.all(spec.dependencies.map(source))).join('\n');const artifact=compile(text,{entry:spec.entry,workgroupSize:spec.workgroupSize});assert.equal(artifact.wgsl,await fs.readFile(new URL(`generated/${spec.entry}.wgsl`,root),'utf8'),spec.entry);const saved=JSON.parse(await fs.readFile(new URL(`generated/${spec.entry}.json`,root),'utf8'));assert.equal(saved.wgsl,artifact.wgsl);assert.ok(artifact.metadata.bindings.length<=8);assert.ok(artifact.metadata.workgroupStorageBytes<=16384);}
});
test('host buffer ABI agrees with CUDA dimensions and dispatch widths',async()=>{
 const common=await source('common');for(const [macro,value]of [['CITY',ABI.CITY],['PAGES',ABI.PAGES],['PRIMS',ABI.PRIMS],['NODES',ABI.NODES],['PS',ABI.PRIMITIVE_FLOATS],['NN_PARAMS',ABI.NN_PARAMS]])assert.match(common,new RegExp(`#define ${macro} ${value}(?:\\s|$)`));
 assert.deepEqual(manifest.find(x=>x.entry==='generatePages').workgroupSize,[64,1,1]);assert.deepEqual(manifest.find(x=>x.entry==='sortPages').workgroupSize,[256,1,1]);
});
test('full host/runtime dispatch and presentation contract (device double, not GPU execution)',async()=>{
 installConstants();const device=mockDevice(),canvas=mockCanvas();const original=globalThis.fetch;
 globalThis.fetch=async url=>{const u=new URL(url);if(u.protocol!=='file:')throw Error('Unexpected remote request');const bytes=await fs.readFile(u);return {ok:true,json:async()=>JSON.parse(bytes),text:async()=>bytes.toString()};};
 try{const e=await new Engine(canvas).init({device,adapter:{info:{vendor:'TEST DOUBLE'}},width:512,height:320});e.input[8]=2;e.frame();e.input.fill(0);e.frame();assert.ok(device.calls.some(x=>x[0]==='present'));assert.equal(e.width%64,0);assert.equal(e.height%8,0);assert.equal(e.bvh.length,11);assert.ok((await e.inspect()).allocatedBytes>60*1048576);await e.resize(768,480);e.frame();await e.reset(42);await e.dispose();assert.ok(e.disposed);}finally{globalThis.fetch=original;}
});
test('camera and training remain bounded and quality-gated in the authored source',async()=>{
 const learning=await source('learning'),world=await source('world'),trace=await source('trace');
 assert.match(learning,/for\(int i=56;i<64;i\+\+\)/);assert.match(learning,/for\(int n=0;n<56;n\+\+\)/);assert.match(learning,/Brain\[2\]<Brain\[3\]\*0\.90f/);assert.match(world,/if\(s>=PAGES\)return/);assert.match(trace,/foliageHit/);assert.match(trace,/pageHit/);
});
