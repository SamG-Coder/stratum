// Analytic geometry ray visibility. Nearest hit wins; no alpha-painted billboards.
__device__ float3 localPoint(float3 p,int turn){if(turn%2==1)return make_float3(p.z,p.y,-p.x);return p;}
__device__ float3 worldNormal(float3 p,int turn){if(turn%2==1)return make_float3(-p.z,p.y,p.x);return p;}
// A foliage envelope contains stable, leaf-sized discs, generated at ray time.
// The envelope itself is never painted as an opaque sphere.
__device__ float3 leafNormal(int x,int y,int z,int seed){
 return norm3(make_float3(hash2(x+y*19,z,seed)-0.5f,0.25f+hash2(x-y,z+91,seed)*0.7f,hash2(z+y*31,x,seed+17)-0.5f));
}
__device__ float foliageHit(float3 ro,float3 rd,float3 centre,float3 radius,int seed,float begin,float end){
 const float step=0.18f;
 float t=fmaxf(0.001f,begin)+0.0001f;float3 pos=ro+rd*t;
 int ix=(int)floorf(pos.x/step);int iy=(int)floorf(pos.y/step);int iz=(int)floorf(pos.z/step);
 int sx=rd.x>0.0f?1:-1;int sy=rd.y>0.0f?1:-1;int sz=rd.z>0.0f?1:-1;
 float tx=((float)(ix+(sx>0?1:0))*step-ro.x)*safeInv(rd.x);
 float ty=((float)(iy+(sy>0?1:0))*step-ro.y)*safeInv(rd.y);
 float tz=((float)(iz+(sz>0?1:0))*step-ro.z)*safeInv(rd.z);
 float dx=step*fabsf(safeInv(rd.x));float dy=step*fabsf(safeInv(rd.y));float dz=step*fabsf(safeInv(rd.z));
 for(int k=0;k<48;k++){
  if(t>end)break;float exit=fminf(tx,fminf(ty,tz));
  float3 c=make_float3(((float)ix+0.5f)*step,((float)iy+0.5f)*step,((float)iz+0.5f)*step);
  float3 q=c-centre;float ell=q.x*q.x/(radius.x*radius.x)+q.y*q.y/(radius.y*radius.y)+q.z*q.z/(radius.z*radius.z);
  if(ell<1.0f&&hash2(ix+iy*113,iz,seed)>0.20f){
   float3 n=leafNormal(ix,iy,iz,seed);float den=dot3(rd,n);
   if(fabsf(den)>0.00001f){float u=dot3(c-ro,n)/den;
    if(u>=t&&u<=exit){float3 pp=ro+rd*u-c;float3 tangent=norm3(cross3(n,make_float3(0.0f,0.0f,1.0f)));float3 bitangent=cross3(n,tangent);float a=dot3(pp,tangent)/0.125f;float b=dot3(pp,bitangent)/0.062f;if(a*a+b*b<1.0f)return u;}
   }
  }
  if(tx<ty&&tx<tz){t=tx;tx+=dx;ix+=sx;}else if(ty<tz){t=ty;ty+=dy;iy+=sy;}else{t=tz;tz+=dz;iz+=sz;}
 }
 return FAR;
}

__device__ float primitiveHit(const float* P,int id,float3 ro,float3 rd){
 int b=id*PS;int shape=(int)P[b+3];if(shape<0)return FAR;
 float3 cp=make_float3(P[b],P[b+1],P[b+2]);float3 h=make_float3(P[b+4],P[b+5],P[b+6]);int turn=(int)P[b+8];
 float3 p=localPoint(ro-cp,turn);float3 d=localPoint(rd,turn);
 float2 range=boxRange(p,d,h*-1.0f,h);
 if(shape==3||shape==4)range=boxRange(p,d,make_float3(-h.x,0.0f,-h.z),h);
 if(range.y<fmaxf(0.001f,range.x))return FAR;
 float t=range.x>0.001f?range.x:range.y;
 if(shape==1){
  float3 a=make_float3(p.x/h.x,p.y/h.y,p.z/h.z);float3 v=make_float3(d.x/h.x,d.y/h.y,d.z/h.z);
  float aa=dot3(v,v);float bb=dot3(a,v);float cc=dot3(a,a)-1.0f;float disc=bb*bb-aa*cc;if(disc<0.0f)return FAR;
  t=(-bb-sqrtf(disc))/aa;if(t<=0.001f)t=(-bb+sqrtf(disc))/aa;
 }
 if(shape==2){
  float a=d.x*d.x/(h.x*h.x)+d.z*d.z/(h.z*h.z);
  float bb=p.x*d.x/(h.x*h.x)+p.z*d.z/(h.z*h.z);float cc=p.x*p.x/(h.x*h.x)+p.z*p.z/(h.z*h.z)-1.0f;
  float best=FAR;float disc=bb*bb-a*cc;
  if(disc>=0.0f&&a>0.0000001f){float u=(-bb-sqrtf(disc))/a;float v=(-bb+sqrtf(disc))/a;
   if(u>0.001f&&fabsf(p.y+d.y*u)<=h.y)best=u;
   if(v>0.001f&&fabsf(p.y+d.y*v)<=h.y)best=fminf(best,v);
  }
  for(int k=0;k<2;k++)if(fabsf(d.y)>0.000001f){float cy=k==0?-h.y:h.y;float u=(cy-p.y)/d.y;float xx=(p.x+d.x*u)/h.x;float zz=(p.z+d.z*u)/h.z;if(u>0.001f&&xx*xx+zz*zz<=1.0f)best=fminf(best,u);}
  t=best;
 }
 if(shape==3){
  float near=fmaxf(0.001f,range.x);float far=range.y;
  // Clip the AABB interval by the two sloping half-spaces of a triangular prism.
  for(int k=0;k<2;k++){
   float sign=k==0?1.0f:-1.0f;float numer=h.y-(p.y+sign*p.x*h.y/h.x);float denom=d.y+sign*d.x*h.y/h.x;
   if(fabsf(denom)<0.000001f){if(numer<0.0f)return FAR;}
   else {float u=numer/denom;if(denom>0.0f)far=fminf(far,u);else near=fmaxf(near,u);}
  }
  if(far<near)return FAR;t=near;
 }
 if(shape==4||shape==7){
  float best=FAR;float a=d.x*d.x/(h.x*h.x)+d.y*d.y/(h.y*h.y);
  float bb=p.x*d.x/(h.x*h.x)+p.y*d.y/(h.y*h.y);
  for(int ring=0;ring<2;ring++){
   float rad=ring==0?1.0f:0.77f;float cc=p.x*p.x/(h.x*h.x)+p.y*p.y/(h.y*h.y)-rad*rad;float disc=bb*bb-a*cc;
   if(disc>=0.0f&&a>0.000001f)for(int k=0;k<2;k++){float u=(-bb+(k==0?-sqrtf(disc):sqrtf(disc)))/a;if(u>0.001f&&fabsf(p.z+d.z*u)<=h.z&&(shape==7||p.y+d.y*u>=0.0f))best=fminf(best,u);}
  }
  if(fabsf(d.z)>0.000001f)for(int k=0;k<2;k++){float u=((k==0?-h.z:h.z)-p.z)/d.z;float xx=(p.x+d.x*u)/h.x;float yy=(p.y+d.y*u)/h.y;float rr=xx*xx+yy*yy;if(u>0.001f&&rr<=1.0f&&rr>=0.77f*0.77f&&(shape==7||yy>=0.0f))best=fminf(best,u);}
  t=best;
 }
 if(shape==1&&(int)P[b+7]==7&&t<FAR){
  t=foliageHit(ro,rd,cp,h,(int)P[b+9],range.x,range.y);
 }
 if(t<=0.001f)return FAR;
 // Close-range mortar relief is ray-evaluated, not claimed as millions of polygons.
 if(shape==0&&t<18.0f&&((int)P[b+7]==0||(int)P[b+7]==1)&&h.y>1.0f){
  float3 hit=p+d*t;float ex=fabsf(fabsf(hit.x)-h.x);float ez=fabsf(fabsf(hit.z)-h.z);
  if(fabsf(fabsf(hit.y)-h.y)>0.01f){
   float3 n=ex<ez?make_float3(hit.x<0.0f?-1.0f:1.0f,0.0f,0.0f):make_float3(0.0f,0.0f,hit.z<0.0f?-1.0f:1.0f);
   float denom=dot3(n,d);
   if(denom<-0.08f){float initial=t;for(int k=0;k<4;k++){float3 wp=ro+rd*t;float3 wn=worldNormal(n,turn);float2 uv=masonryUV(wp,wn);float displacement=masonryHeight(uv.x,uv.y,(int)P[b+7]);t=initial+displacement/denom;}}
  }
 }
 return t;
}
__device__ float3 primitiveNormal(const float* P,int id,float3 point){
 int b=id*PS;int shape=(int)P[b+3];int turn=(int)P[b+8];float3 p=localPoint(point-make_float3(P[b],P[b+1],P[b+2]),turn);float3 h=make_float3(P[b+4],P[b+5],P[b+6]);float3 n=make_float3(0.0f,1.0f,0.0f);
 if(shape==1)n=norm3(make_float3(p.x/(h.x*h.x),p.y/(h.y*h.y),p.z/(h.z*h.z)));
 else if(shape==2){if(fabsf(fabsf(p.y)-h.y)<0.01f)n=make_float3(0.0f,p.y<0.0f?-1.0f:1.0f,0.0f);else n=norm3(make_float3(p.x/(h.x*h.x),0.0f,p.z/(h.z*h.z)));}
 else if(shape==4||shape==7){
  if(fabsf(fabsf(p.z)-h.z)<0.008f)n=make_float3(0.0f,0.0f,p.z<0.0f?-1.0f:1.0f);
  else {float rr=p.x*p.x/(h.x*h.x)+p.y*p.y/(h.y*h.y);n=norm3(make_float3(p.x/(h.x*h.x),p.y/(h.y*h.y),0.0f))*(rr<0.8f?-1.0f:1.0f);}
 }
 else if(shape==3){
  if(fabsf(fabsf(p.z)-h.z)<0.006f)n=make_float3(0.0f,0.0f,p.z<0.0f?-1.0f:1.0f);
  else if(p.y<0.003f)n=make_float3(0.0f,-1.0f,0.0f);
  else n=norm3(make_float3(p.x<0.0f?-h.y/h.x:h.y/h.x,1.0f,0.0f));
 }else{
  float3 a=make_float3(fabsf(fabsf(p.x)-h.x),fabsf(fabsf(p.y)-h.y),fabsf(fabsf(p.z)-h.z));
  n=a.x<a.y&&a.x<a.z?make_float3(p.x<0.0f?-1.0f:1.0f,0.0f,0.0f):(a.y<a.z?make_float3(0.0f,p.y<0.0f?-1.0f:1.0f,0.0f):make_float3(0.0f,0.0f,p.z<0.0f?-1.0f:1.0f));
  // Small bevel normals make stone edges catch light without changing gross visibility.
  float bevel=fminf(0.035f,fminf(fminf(h.x,h.y),h.z)*0.18f);
  float3 q=make_float3(fmaxf(fabsf(p.x)-h.x+bevel,0.0f)*(p.x<0.0f?-1.0f:1.0f),fmaxf(fabsf(p.y)-h.y+bevel,0.0f)*(p.y<0.0f?-1.0f:1.0f),fmaxf(fabsf(p.z)-h.z+bevel,0.0f)*(p.z<0.0f?-1.0f:1.0f));
  if(dot3(q,q)>0.000001f)n=norm3(q);
 }
 if(shape==1&&(int)P[b+7]==7){return leafNormal((int)floorf(point.x/0.18f),(int)floorf(point.y/0.18f),(int)floorf(point.z/0.18f),(int)P[b+9]);}
 return worldNormal(n,turn);
}
__device__ float2 pageHit(const float* P,const float* Nodes,const int* Order,int slot,float3 ro,float3 rd,float best){
 int stack[24];int top=0;int node=1;int found=-10000;int visits=0;
 while(node>0&&visits<NODES){
  visits++;int b=(slot*NODES+node)*8;
  float2 span=boxRange(ro,rd,make_float3(Nodes[b],Nodes[b+1],Nodes[b+2]),make_float3(Nodes[b+4],Nodes[b+5],Nodes[b+6]));
  bool hit=Nodes[b+3]>0.0f&&span.y>=fmaxf(0.001f,span.x)&&span.x<best;
  if(hit&&node<PRIMS){
   int left=node*2;int right=left+1;int lb=(slot*NODES+left)*8;int rb=lb+8;
   float2 ls=boxRange(ro,rd,make_float3(Nodes[lb],Nodes[lb+1],Nodes[lb+2]),make_float3(Nodes[lb+4],Nodes[lb+5],Nodes[lb+6]));
   float2 rs=boxRange(ro,rd,make_float3(Nodes[rb],Nodes[rb+1],Nodes[rb+2]),make_float3(Nodes[rb+4],Nodes[rb+5],Nodes[rb+6]));
   bool lh=Nodes[lb+3]>0.0f&&ls.y>=fmaxf(0.001f,ls.x)&&ls.x<best;
   bool rh=Nodes[rb+3]>0.0f&&rs.y>=fmaxf(0.001f,rs.x)&&rs.x<best;
   if(lh&&rh){int near=ls.x<rs.x?left:right;int far=ls.x<rs.x?right:left;if(top<24){stack[top]=far;top++;}node=near;}
   else if(lh)node=left;else if(rh)node=right;
   else{node=0;if(top>0){top--;node=stack[top];}}
  }
  else{
   if(hit){int id=Order[slot*PRIMS+node-PRIMS];float t=primitiveHit(P,id,ro,rd);if(t<best){best=t;found=id;}}
   node=0;if(top>0){top--;node=stack[top];}
  }
 }
 return make_float2(best,(float)found);
}
__device__ float2 macroHit(const float* World,int wi,float3 ro,float3 rd,float best){
 int b=wi*8;int type=(int)World[b+3];if(type==3||type==4)return make_float2(best,-10000.0f);
 int cx=wi%CITY-CITY/2;int cz=wi/CITY-CITY/2;float x=(float)cx*CELL;float z=(float)cz*CELL;float h=World[b+2];
 float2 span=boxRange(ro,rd,make_float3(x-World[b],0.0f,z-World[b+1]),make_float3(x+World[b],h+4.5f,z+World[b+1]));
 if(span.y>=fmaxf(0.001f,span.x)){float t=span.x>0.001f?span.x:span.y;if(t<best)return make_float2(t,(float)(-wi-2));}
 return make_float2(best,-10000.0f);
}
__device__ float2 traceScene(const float* World,const float* Meta,const float* P,const float* Nodes,const int* Order,float3 ro,float3 rd){
 float best=FAR;int found=-10000;
 if(rd.y<-0.000001f){best=-ro.y/rd.y;found=-1;if(best>FAR){best=FAR;found=-10000;}}
 float2 bounds=boxRange(ro,rd,make_float3(-HALF_CITY-18.0f,-0.01f,-HALF_CITY-18.0f),make_float3(HALF_CITY-18.0f,90.0f,HALF_CITY-18.0f));
 if(bounds.y<fmaxf(bounds.x,0.0f)||bounds.x>best)return make_float2(best,(float)found);
 float t=fmaxf(bounds.x,0.001f)+0.001f;float3 start=ro+rd*t;
 int cx=(int)floorf((start.x+CELL*0.5f)/CELL);int cz=(int)floorf((start.z+CELL*0.5f)/CELL);
 int sx=rd.x>0.0f?1:-1;int sz=rd.z>0.0f?1:-1;
 float tx=((float)cx*CELL+(sx>0?CELL*0.5f:-CELL*0.5f)-ro.x)*safeInv(rd.x);
 float tz=((float)cz*CELL+(sz>0?CELL*0.5f:-CELL*0.5f)-ro.z)*safeInv(rd.z);
 float dx=CELL*fabsf(safeInv(rd.x));float dz=CELL*fabsf(safeInv(rd.z));
 for(int step=0;step<140;step++){
  if(!inCity(cx,cz)||t>best||t>bounds.y)break;
  int wi=worldIndex(cx,cz);int slot=pageIndex(cx,cz);int m=slot*MS;
  bool cached=Meta[m+3]>0.5f&&(int)Meta[m]==cx&&(int)Meta[m+1]==cz;
  float2 hit=cached?pageHit(P,Nodes,Order,slot,ro,rd,best):macroHit(World,wi,ro,rd,best);
  if(hit.x<best){best=hit.x;found=(int)hit.y;}
  if(tx<tz){t=tx;tx+=dx;cx+=sx;}else{t=tz;tz+=dz;cz+=sz;}
 }
 return make_float2(best,(float)found);
}
__global__ void tracePrimary(const float* World,const float* Meta,const float* P,const float* Nodes,const int* Order,const float* C,float* Hit,int width,int height){
 int x=(int)(blockIdx.x*blockDim.x+threadIdx.x);int y=(int)(blockIdx.y*blockDim.y+threadIdx.y);if(x>=width||y>=height)return;
 float3 ro=cameraPosition(C);float3 rd=rayDirection(C,x,y,width,height);float2 result=traceScene(World,Meta,P,Nodes,Order,ro,rd);int b=(y*width+x)*4;
 Hit[b]=result.x;Hit[b+1]=result.y;Hit[b+2]=0.0f;Hit[b+3]=1.0f;
}
