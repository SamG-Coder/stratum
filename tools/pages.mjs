import fs from 'node:fs/promises';
const root=new URL('../',import.meta.url),out=new URL('../dist/',import.meta.url);
await fs.rm(out,{recursive:true,force:true});await fs.mkdir(out,{recursive:true});
for(const name of ['index.html','style.css','src','generated','kernels','vendor','tests/browser.html','tests/browser.js'])await fs.cp(new URL(name,root),new URL(name,out),{recursive:true});
console.log('Static WebGPU application copied to dist/. Serve over HTTPS.');
