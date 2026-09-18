// Generated combined CUDA source. Rebuild split kernels with npm run build.

// ===== COMMON =====
// STRATUM — compute-streamed geometry. Distances are metres.
// Supported CUDA C subset; this file is also compiled by the native test harness.
#define CITY 64
#define CELL 36.0f
#define HALF_CITY 1152.0f
#define CACHE_SIDE 16
#define PAGES 256
#define CLUSTERS 64
#define PER_CLUSTER 32
#define PRIMS 2048
#define NODES 4096
#define PS 16
#define MS 12
#define REQUESTS 8
#define GENERATE_BUDGET 6
#define NN_INPUTS 8
#define NN_HIDDEN 24
#define NN_PARAMS 291
#define NN_BATCH 64
#define NN_WS 64
#define PI 3.141592653589793f
#define FAR 30000.0f
__device__ float clampf(float x,float a,float b){return fminf(b,fmaxf(a,x));}
__device__ float sat(float x){return clampf(x,0.0f,1.0f);}
__device__ float lerpf(float a,float b,float t){return a+(b-a)*t;}
__device__ float fractf(float x){return x-floorf(x);}
__device__ float smoothf(float a,float b,float x){float t=sat((x-a)/(b-a));return t*t*(3.0f-2.0f*t);}
__device__ int imod(int x,int n){int r=x%n;return r<0?r+n:r;}
__device__ float dot3(float3 a,float3 b){return a.x*b.x+a.y*b.y+a.z*b.z;}
__device__ float length3(float3 a){return sqrtf(dot3(a,a));}
__device__ float3 norm3(float3 a){return a/fmaxf(0.000001f,length3(a));}
__device__ float3 cross3(float3 a,float3 b){return make_float3(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x);}
__device__ float3 mix3(float3 a,float3 b,float t){return a+(b-a)*t;}
__device__ float3 min3(float3 a,float3 b){return make_float3(fminf(a.x,b.x),fminf(a.y,b.y),fminf(a.z,b.z));}
__device__ float3 max3(float3 a,float3 b){return make_float3(fmaxf(a.x,b.x),fmaxf(a.y,b.y),fmaxf(a.z,b.z));}
__device__ float3 abs3(float3 a){return make_float3(fabsf(a.x),fabsf(a.y),fabsf(a.z));}
// Integer hashing controls topology. It does not depend on vendor-specific sin precision.
__device__ unsigned int hashU(unsigned int x){x^=x>>16;x*=2146121005u;x^=x>>15;x*=2221713035u;x^=x>>16;return x;}
__device__ float hash1(int x){return (float)(hashU((unsigned int)x)&16777215u)/16777216.0f;}
__device__ float hash2(int x,int y,int seed){return (float)(hashU((unsigned int)x*1973u+(unsigned int)y*9277u+(unsigned int)seed*26699u)&16777215u)/16777216.0f;}
__device__ float noise2(float x,float y){
 int ix=(int)floorf(x);int iy=(int)floorf(y);float fx=fractf(x);float fy=fractf(y);
 fx=fx*fx*(3.0f-2.0f*fx);fy=fy*fy*(3.0f-2.0f*fy);
 return lerpf(lerpf(hash2(ix,iy,13),hash2(ix+1,iy,13),fx),lerpf(hash2(ix,iy+1,13),hash2(ix+1,iy+1,13),fx),fy);
}
__device__ float fbm2(float x,float y){
 float v=0.0f;float a=0.5f;for(int i=0;i<5;i++){v+=noise2(x,y)*a;x=x*2.07f+11.7f;y=y*2.03f-8.3f;a*=0.5f;}return v;
}
__device__ float frequencyWeight(float footprint,float freq){return 1.0f-smoothf(0.35f,1.1f,footprint*freq);}
__device__ float3 cameraForward(const float* C){return make_float3(sinf(C[3])*cosf(C[4]),sinf(C[4]),cosf(C[3])*cosf(C[4]));}
__device__ float3 cameraRight(const float* C){return make_float3(cosf(C[3]),0.0f,-sinf(C[3]));}
__device__ float3 cameraPosition(const float* C){return make_float3(C[0],C[1],C[2]);}
__device__ float3 sunDirection(const float* C){return norm3(make_float3(cosf(C[7])*cosf(C[8]),sinf(C[8]),sinf(C[7])*cosf(C[8])));}
__device__ float3 rayDirection(const float* C,int x,int y,int width,int height){
 float jitterX=0.0f;float jitterY=0.0f;
 if(C[15]<0.5f){jitterX=fractf(C[6]*0.754877666f)-0.5f;jitterY=fractf(C[6]*0.569840296f)-0.5f;}
 float sx=((float)x+0.5f+jitterX-(float)width*0.5f)/(float)height*1.08f;
 float sy=-((float)y+0.5f+jitterY-(float)height*0.5f)/(float)height*1.08f;
 float3 f=cameraForward(C);float3 r=cameraRight(C);float3 u=cross3(f,r);
 return norm3(f+r*sx+u*sy);
}
__device__ float safeInv(float d){return 1.0f/(fabsf(d)>0.0000001f?d:(d<0.0f?-0.0000001f:0.0000001f));}
__device__ float2 boxRange(float3 ro,float3 rd,float3 lo,float3 hi){
 float3 a=make_float3((lo.x-ro.x)*safeInv(rd.x),(lo.y-ro.y)*safeInv(rd.y),(lo.z-ro.z)*safeInv(rd.z));
 float3 b=make_float3((hi.x-ro.x)*safeInv(rd.x),(hi.y-ro.y)*safeInv(rd.y),(hi.z-ro.z)*safeInv(rd.z));
 float3 mn=min3(a,b);float3 mx=max3(a,b);
 return make_float2(fmaxf(fmaxf(mn.x,mn.y),mn.z),fminf(fminf(mx.x,mx.y),mx.z));
}
__device__ int worldIndex(int cx,int cz){return (cz+CITY/2)*CITY+cx+CITY/2;}
__device__ int pageIndex(int cx,int cz){return imod(cz,CACHE_SIDE)*CACHE_SIDE+imod(cx,CACHE_SIDE);}
__device__ bool inCity(int cx,int cz){return cx>=-CITY/2&&cx<CITY/2&&cz>=-CITY/2&&cz<CITY/2;}
__device__ float2 masonryUV(float3 p,float3 n){return fabsf(n.y)>0.5f?make_float2(p.x,p.z):(fabsf(n.x)>0.5f?make_float2(p.z,p.y):make_float2(p.x,p.y));}
// Bounded geometric relief. Fine pores are shading detail; masonry joints are actual relief.
__device__ float masonryHeight(float u,float v,int material){
 float bw=material==1?0.46f:0.92f;float bh=material==1?0.215f:0.46f;
 int row=(int)floorf(v/bh);float x=fractf(u/bw+(float)imod(row,2)*0.5f);float y=fractf(v/bh);
 float edge=fminf(fminf(x,1.0f-x)*bw,fminf(y,1.0f-y)*bh);
 float grain=noise2(u*24.0f,v*24.0f);
 float chippedEdge=edge-0.006f*smoothf(0.34f,0.73f,noise2(u*117.0f,v*117.0f));
 return -0.018f*(1.0f-smoothf(0.008f,0.023f,chippedEdge))+0.0025f*grain;
}
__device__ unsigned int spread10(unsigned int x){x&=1023u;x=(x|(x<<16))&0x030000FFu;x=(x|(x<<8))&0x0300F00Fu;x=(x|(x<<4))&0x030C30C3u;x=(x|(x<<2))&0x09249249u;return x;}
__device__ unsigned int morton3(float x,float y,float z){
 unsigned int a=(unsigned int)(sat(x)*1023.0f);unsigned int b=(unsigned int)(sat(y)*1023.0f);unsigned int c=(unsigned int)(sat(z)*1023.0f);
 return spread10(a)|(spread10(b)<<1)|(spread10(c)<<2);
}
__device__ unsigned int packRGBA(float3 c){unsigned int r=(unsigned int)(sat(c.x)*255.0f);unsigned int g=(unsigned int)(sat(c.y)*255.0f);unsigned int b=(unsigned int)(sat(c.z)*255.0f);return r|(g<<8)|(b<<16)|4278190080u;}


// ===== WORLD =====
// World descriptors and camera are authored here. No mesh/texture upload is involved.
__global__ void initWorld(float* World,float* Meta,float* C,int seed){
 int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);
 if(i<CITY*CITY){
  int cx=i%CITY-CITY/2;int cz=i/CITY-CITY/2;int b=i*8;
  float r=hash2(cx,cz,seed);int type=r>0.95f?1:0;
  if(r<0.105f)type=3;
  if(cx==-4)type=4;
  if(cx==0&&cz==0)type=2;
  if(cx==0&&(cz==1||cz==2))type=3;
  int floors=3+(int)(hash2(cx+19,cz,seed)*4.0f);
  float h=4.2f+(float)floors*3.8f;
  if(type==2)h=30.8f;
  World[b]=11.0f+hash2(cx+31,cz,seed)*3.0f;
  World[b+1]=10.5f+hash2(cx,cz+81,seed)*3.5f;
  World[b+2]=h;World[b+3]=(float)type;
  World[b+4]=r>0.52f?1.0f:0.0f;World[b+5]=(float)floors;
  World[b+6]=(float)(hashU((unsigned int)(cx*1973+cz*9277+seed))&65535u);World[b+7]=r;
 }
 if(i<PAGES){for(int j=0;j<MS;j++)Meta[i*MS+j]=0.0f;Meta[i*MS+3]=0.0f;}
 if(i==0){
  for(int j=0;j<64;j++)C[j]=0.0f;
  C[0]=112.0f;C[1]=76.0f;C[2]=155.0f;C[3]=-2.53f;C[4]=-0.30f;
  C[7]=-0.55f;C[8]=0.35f;C[9]=0.93f;C[10]=0.28f;C[12]=38.0f;C[14]=(float)seed;C[15]=1.0f;
 }
}
__global__ void stepCamera(float* C,const float* I,const float* World,float dt,int width,int height){
 if(blockIdx.x!=0||threadIdx.x!=0)return;
 C[5]+=dt;C[6]+=1.0f;C[13]=(float)height;C[20]=(float)width/(float)height;C[15]=0.0f;
 int bookmark=(int)I[8];
 if(bookmark>0){
  if(bookmark==1){C[0]=112.0f;C[1]=76.0f;C[2]=155.0f;C[3]=-2.53f;C[4]=-0.30f;C[12]=38.0f;}
  if(bookmark==2){C[0]=19.0f;C[1]=1.75f;C[2]=49.0f;C[3]=-2.80f;C[4]=0.17f;C[12]=6.0f;}
  if(bookmark==3){C[0]=World[worldIndex(0,0)*8]+1.1f;C[1]=6.9f;C[2]=1.2f;C[3]=-PI*0.5f;C[4]=0.015f;C[12]=0.8f;}
  if(bookmark==4){C[0]=540.0f;C[1]=810.0f;C[2]=910.0f;C[3]=-2.61f;C[4]=-0.66f;C[12]=220.0f;}
  if(bookmark==5){C[0]=-122.0f;C[1]=4.5f;C[2]=70.0f;C[3]=-2.65f;C[4]=0.08f;C[12]=12.0f;}
  if(bookmark==6){C[0]=World[worldIndex(0,0)*8]+0.18f;C[1]=6.18f;C[2]=1.2f;C[3]=-PI*0.5f;C[4]=0.0f;C[12]=0.12f;}
  C[15]=1.0f;
 }
 if(I[3]!=0.0f||I[4]!=0.0f){C[3]+=I[3]*0.0022f;C[4]=clampf(C[4]-I[4]*0.0022f,-1.53f,1.53f);C[15]=1.0f;}
 if(I[7]!=0.0f)C[12]=clampf(C[12]*expf(-I[7]*0.0015f),0.03f,1600.0f);
 float speed=C[12]*(I[5]>0.5f?5.0f:1.0f)*(I[6]>0.5f?0.15f:1.0f);
 float3 f=cameraForward(C);float3 r=cameraRight(C);float3 move=f*I[0]+r*I[1]+make_float3(0.0f,I[2],0.0f);
 if(dot3(move,move)>0.0f){move=norm3(move)*speed*dt;C[0]+=move.x;C[1]=fmaxf(0.08f,C[1]+move.y);C[2]+=move.z;C[15]=1.0f;}
 if(I[9]!=0.0f){C[7]+=I[9]*dt*0.35f;C[15]=1.0f;}
 if(I[10]>0.0f){C[11]=(float)((int)C[11]+1);if(C[11]>3.0f)C[11]=0.0f;C[15]=1.0f;}
 if(I[11]>0.0f){C[16]=1.0f-C[16];C[15]=1.0f;}
 if(I[12]>0.0f){C[17]=1.0f-C[17];C[15]=1.0f;}
 if(I[13]!=0.0f){C[9]=clampf(C[9]+I[13]*dt,0.25f,3.0f);C[15]=1.0f;}
 if(I[14]>0.0f){C[18]=1.0f-C[18];C[15]=1.0f;}
 if(I[15]>0.0f)C[21]=1.0f-C[21];
 if(I[16]>0.0f)C[22]=1.0f-C[22];
 if(C[22]>0.5f){float a=C[5]*0.025f;C[0]=cosf(a)*150.0f;C[2]=sinf(a)*150.0f;C[1]=58.0f+15.0f*sinf(a*0.7f);C[3]=-PI*0.5f-a;C[4]=-0.24f;C[15]=1.0f;}
 C[19]=C[15]>0.5f?1.0f:fminf(32.0f,C[19]+1.0f);
}
// Visibility and screen-space detail requests, one GPU thread per physical cache slot.
__global__ void selectPages(const float* C,const float* World,const float* Meta,float* Req){
 int s=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(s>=PAGES)return;int b=s*REQUESTS;
 int ax=(int)floorf((C[0]+CELL*0.5f)/CELL)-CACHE_SIDE/2;
 int az=(int)floorf((C[2]+CELL*0.5f)/CELL)-CACHE_SIDE/2;
 int cx=ax+imod(s%CACHE_SIDE-imod(ax,CACHE_SIDE),CACHE_SIDE);
 int cz=az+imod(s/CACHE_SIDE-imod(az,CACHE_SIDE),CACHE_SIDE);
 Req[b]=(float)cx;Req[b+1]=(float)cz;Req[b+2]=0.0f;Req[b+3]=0.0f;
 if(!inCity(cx,cz))return;
 int w=worldIndex(cx,cz)*8;float h=World[w+2];float3 delta=make_float3((float)cx*CELL-C[0],h*0.5f-C[1],(float)cz*CELL-C[2]);
 float dist=fmaxf(1.0f,length3(delta)-23.0f);float z=dot3(delta,cameraForward(C));
 float xx=fabsf(dot3(delta,cameraRight(C)));float yy=fabsf(dot3(delta,cross3(cameraForward(C),cameraRight(C))));
 float aspect=C[20]>0.1f?C[20]:1.7778f;
 bool visible=(z+45.0f>0.0f&&xx<(z*0.54f*aspect+65.0f)&&yy<z*0.54f+65.0f)||dist<55.0f;
 if(!visible||C[17]>0.5f)return;
 float ppm=C[13]/(1.08f*dist);int lod=ppm>6.5f?3:(ppm>1.5f?2:1);
 int m=s*MS;bool same=Meta[m+3]>0.5f&&(int)Meta[m]==cx&&(int)Meta[m+1]==cz;
 int old=(int)Meta[m+2];
 if(same&&old==3&&ppm>5.3f)lod=3;
 if(same&&old==2&&ppm>1.2f&&ppm<7.2f)lod=2;
 Req[b+2]=(float)lod;Req[b+4]=ppm;
 if(!same||old!=lod){Req[b+3]=10000.0f/(dist+5.0f)+(same?0.0f:80.0f);}
}
__global__ void schedulePages(const float* Req,int* Queue,float* Stats){
 if(blockIdx.x!=0||threadIdx.x!=0)return;
 int n=0;int pending=0;
 for(int s=0;s<PAGES;s++)if(Req[s*REQUESTS+3]>0.0f)pending++;
 for(int k=0;k<GENERATE_BUDGET;k++){
  float best=0.0f;int chosen=-1;
  for(int s=0;s<PAGES;s++){
   bool used=false;for(int j=0;j<GENERATE_BUDGET;j++)if(j<n&&Queue[j+1]==s)used=true;
   float score=Req[s*REQUESTS+3];if(!used&&score>best){best=score;chosen=s;}
  }
  if(chosen>=0){Queue[n+1]=chosen;n++;}
 }
 Queue[0]=n;Stats[1]=(float)n;Stats[2]=(float)pending;
}
__global__ void commitPages(const float* Req,const int* Queue,const float* P,float* Meta,const float* C){
 int q=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(q>=Queue[0])return;
 int s=Queue[q+1];int m=s*MS;Meta[m]=Req[s*REQUESTS];Meta[m+1]=Req[s*REQUESTS+1];Meta[m+2]=Req[s*REQUESTS+2];Meta[m+3]=1.0f;
 int n=0;for(int i=0;i<PRIMS;i++)if(P[(s*PRIMS+i)*PS+3]>=0.0f)n++;
 Meta[m+4]=(float)n;Meta[m+5]=C[6];Meta[m+6]+=1.0f;
}
__global__ void summarise(const float* Meta,const float* Req,const float* C,float* Stats){
 if(blockIdx.x!=0||threadIdx.x!=0)return;
 int resident=0;int prims=0;int visible=0;int reused=0;int wanted=0;int clusters=0;
 for(int s=0;s<PAGES;s++){
  int b=s*MS;if(Meta[b+3]>0.5f){resident++;prims+=(int)Meta[b+4];}
  if(Req[s*REQUESTS+2]>0.0f){wanted++;bool same=(int)Meta[b]==(int)Req[s*REQUESTS]&&(int)Meta[b+1]==(int)Req[s*REQUESTS+1]&&Meta[b+3]>0.5f;
   if(same){visible++;if(Meta[b+5]!=C[6])reused++;clusters+=CLUSTERS;}}
 }
 Stats[0]=(float)resident;Stats[3]=(float)prims;Stats[4]=(float)visible;Stats[5]=(float)reused;Stats[6]=(float)wanted;Stats[7]=(float)clusters;Stats[8]+=Stats[1];
}


// ===== ASSETS =====
// Procedural asset compiler: each thread creates one spatial cluster of analytic geometry.
// Primitive ABI: centre.xyz, shape, half-size.xyz, material, quarter-turn, seed,
// reserved[2], then debug information. Empty slots have shape = -1.
__device__ int emit(float* P,int base,int n,float3 p,float3 size,int shape,int material,int turn,float seed){
 if(n>=PER_CLUSTER)return n;
 int b=(base+n)*PS;P[b]=p.x;P[b+1]=p.y;P[b+2]=p.z;P[b+3]=(float)shape;
 P[b+4]=size.x;P[b+5]=size.y;P[b+6]=size.z;P[b+7]=(float)material;P[b+8]=(float)turn;P[b+9]=seed;P[b+10]=1.0f;P[b+11]=0.0f;return n+1;
}
__device__ int wallBox(float* P,int base,int n,int face,float cx,float cz,float w,float d,float u,float y,float out,float hw,float hy,float hd,int material,float seed){
 float3 p=make_float3(cx+u,y,cz+d+out);float3 h=make_float3(hw,hy,hd);
 if(face==1){p=make_float3(cx+w+out,y,cz+u);h=make_float3(hd,hy,hw);}
 if(face==2)p=make_float3(cx+u,y,cz-d-out);
 if(face==3){p=make_float3(cx-w-out,y,cz+u);h=make_float3(hd,hy,hw);}
 return emit(P,base,n,p,h,0,material,0,seed);
}
__global__ void generatePages(const float* World,const float* Req,const int* Queue,float* P){
 int q=(int)blockIdx.x;int group=(int)threadIdx.x;
 if(q>=Queue[0]||group>=CLUSTERS)return;
 int s=Queue[q+1];int base=s*PRIMS+group*PER_CLUSTER;
 for(int j=0;j<PER_CLUSTER;j++){for(int k=0;k<PS;k++)P[(base+j)*PS+k]=0.0f;P[(base+j)*PS+3]=-1.0f;P[(base+j)*PS+14]=(float)group;P[(base+j)*PS+15]=(float)s;}
 int cx=(int)Req[s*REQUESTS];int cz=(int)Req[s*REQUESTS+1];int lod=(int)Req[s*REQUESTS+2];int wi=worldIndex(cx,cz)*8;
 float x=(float)cx*CELL;float z=(float)cz*CELL;float w=World[wi];float d=World[wi+1];float h=World[wi+2];int type=(int)World[wi+3];int mat=(int)World[wi+4];int floors=(int)World[wi+5];float seed=World[wi+6];int n=0;
 if(type==4){
  if(imod(cz,4)==0&&group==0){
   n=emit(P,base,n,make_float3(x,0.25f,z),make_float3(18.0f,0.5f,5.0f),0,0,0,seed);
   n=emit(P,base,n,make_float3(x,1.25f,z-5.0f),make_float3(18.0f,0.2f,0.23f),0,0,0,seed);
   n=emit(P,base,n,make_float3(x,1.25f,z+5.0f),make_float3(18.0f,0.2f,0.23f),0,0,0,seed);
   for(int k=0;k<12;k++){float u=-16.5f+(float)k*3.0f;n=emit(P,base,n,make_float3(x+u,0.8f,z-5.0f),make_float3(0.12f,0.6f,0.12f),2,6,0,seed);n=emit(P,base,n,make_float3(x+u,0.8f,z+5.0f),make_float3(0.12f,0.6f,0.12f),2,6,0,seed);}
  }
  return;
 }
 if(type==3){
  if(group==0)n=emit(P,base,n,make_float3(x,-0.12f,z),make_float3(15.5f,0.22f,15.5f),0,11,0,seed);
  if(group>=1&&group<=8){
   int k=group-1;float tx=x+(k<4?-10.0f:10.0f);float tz=z+((float)(k%4)-1.5f)*6.7f;
   float th=5.0f+hash1((int)seed+k)*3.0f;
   n=emit(P,base,n,make_float3(tx,th*0.4f,tz),make_float3(0.19f,th*0.4f,0.19f),2,15,0,seed);
   for(int j=0;j<28;j++){
    float a=(float)j*2.4f;float yy=hash1((int)seed+j+991)*3.3f-0.5f;float rr=sqrtf(hash1((int)seed+j+330))*2.1f*(1.0f-yy*0.12f);
    float size=0.48f+hash1((int)seed+j+62)*0.30f;
    n=emit(P,base,n,make_float3(tx+cosf(a)*rr,th+yy,tz+sinf(a)*rr),make_float3(size,size*1.25f,size),1,7,0,seed+(float)j);
   }
  }
  if(group==9){
   n=emit(P,base,n,make_float3(x,0.8f,z),make_float3(3.6f,0.45f,3.6f),2,0,0,seed);
   n=emit(P,base,n,make_float3(x,1.24f,z),make_float3(3.3f,0.04f,3.3f),2,9,0,seed);
   n=emit(P,base,n,make_float3(x,2.0f,z),make_float3(0.65f,1.0f,0.65f),2,0,0,seed);
   n=emit(P,base,n,make_float3(x,2.85f,z),make_float3(1.4f,0.18f,1.4f),2,13,0,seed);
   n=emit(P,base,n,make_float3(x,3.15f,z),make_float3(0.5f,0.5f,0.5f),1,3,0,seed);
  }
  return;
 }
 if(group==0){
  n=emit(P,base,n,make_float3(x,0.15f,z),make_float3(w+1.1f,0.25f,d+1.1f),0,0,0,seed);
  n=emit(P,base,n,make_float3(x,(h+4.0f)*0.5f,z),make_float3(w,(h-4.0f)*0.5f,d),0,mat,0,seed);
  n=emit(P,base,n,make_float3(x,4.0f,z),make_float3(w+0.24f,0.24f,d+0.24f),0,13,0,seed);
  // Open arcades are geometry, not dark rectangles painted on a solid ground floor.
  n=emit(P,base,n,make_float3(x,1.9f,z),make_float3(w-3.5f,1.9f,d-3.5f),0,5,0,seed);
  for(int f=0;f<4;f++)for(int k=0;k<3;k++){
   float ext=(f%2==0?w:d)-0.65f;float u=((float)k-1.0f)*ext;
   float px=f%2==0?x+u:x+(f==1?w-0.5f:-w+0.5f);float pz=f%2==0?z+(f==0?d-0.5f:-d+0.5f):z+u;
   n=emit(P,base,n,make_float3(px,2.0f,pz),make_float3(0.38f,1.75f,0.38f),2,0,0,seed+(float)k);
   n=emit(P,base,n,make_float3(px,3.66f,pz),make_float3(0.64f,0.18f,0.64f),0,13,0,seed);
  }
 }
 if(group==1){
  n=emit(P,base,n,make_float3(x,h+0.25f,z),make_float3(w+0.6f,0.24f,d+0.6f),0,13,0,seed);
  if(type==0){
   int roofmat=hash1((int)seed)>0.5f?14:2;
   n=emit(P,base,n,make_float3(x,h+0.35f,z),make_float3(w+0.45f,4.4f,d+0.45f),3,roofmat,0,seed);
   n=emit(P,base,n,make_float3(x,h+4.8f,z),make_float3(0.12f,0.14f,d+0.7f),0,3,0,seed);
   for(int k=0;k<4;k++){
    float xx=x+(k%2==0?-w*0.52f:w*0.52f);float zz=z+((float)(k/2)-0.5f)*d;
    n=emit(P,base,n,make_float3(xx,h+3.8f,zz),make_float3(0.48f,2.2f,0.55f),0,1,0,seed);
    n=emit(P,base,n,make_float3(xx,h+6.0f,zz),make_float3(0.66f,0.17f,0.72f),0,0,0,seed);
    if(lod>=2)n=emit(P,base,n,make_float3(xx,h+6.32f,zz),make_float3(0.2f,0.25f,0.2f),2,14,0,seed);
   }
  }else if(type==1){
   n=emit(P,base,n,make_float3(x,h+2.2f,z),make_float3(w*0.72f,2.0f,w*0.72f),2,0,0,seed);
   n=emit(P,base,n,make_float3(x,h+3.1f,z),make_float3(w*0.79f,8.4f,w*0.79f),1,3,0,seed);
   n=emit(P,base,n,make_float3(x,h+12.2f,z),make_float3(0.24f,1.45f,0.24f),2,6,0,seed);
   n=emit(P,base,n,make_float3(x,h+13.8f,z),make_float3(0.6f,0.6f,0.6f),1,8,0,seed);
  }else{
   n=emit(P,base,n,make_float3(x,h+0.4f,z),make_float3(w*0.72f,5.2f,d+0.2f),3,2,0,seed);
   for(int k=0;k<2;k++){
    float xx=x+(k==0?-w*0.75f:w*0.75f);float zz=z+d*0.60f;
    n=emit(P,base,n,make_float3(xx,h+3.5f,zz),make_float3(2.3f,7.2f,2.3f),0,0,0,seed);
    n=emit(P,base,n,make_float3(xx,h+10.9f,zz),make_float3(2.65f,0.35f,2.65f),0,13,0,seed);
    n=emit(P,base,n,make_float3(xx,h+11.2f,zz),make_float3(2.55f,4.4f,2.55f),3,3,0,seed);
    n=emit(P,base,n,make_float3(xx,h+16.0f,zz),make_float3(0.17f,1.2f,0.17f),2,8,0,seed);
    for(int j=0;j<4;j++){float a=(float)j*PI*0.5f;n=emit(P,base,n,make_float3(xx+cosf(a)*2.2f,h+12.0f,zz+sinf(a)*2.2f),make_float3(0.17f,1.1f,0.17f),2,0,0,seed);}
   }
  }
 }
 if(group>=2&&group<=5){
  int face=group-2;float ext=face%2==0?w:d;
  for(int j=0;j<=floors;j++){float y=4.2f+(float)j*3.8f;n=wallBox(P,base,n,face,x,z,w,d,0.0f,y,0.17f,ext+0.15f,0.11f,0.22f,13,seed);if(lod>=2)n=wallBox(P,base,n,face,x,z,w,d,0.0f,y+0.21f,0.1f,ext+0.10f,0.052f,0.16f,0,seed);}
  for(int j=0;j<5;j++){
   float u=((float)j/4.0f*2.0f-1.0f)*(ext-0.3f);
   if(lod>=2)n=wallBox(P,base,n,face,x,z,w,d,u,(h+4.0f)*0.5f,0.16f,0.19f,(h-4.0f)*0.5f,0.22f,13,seed);
  }
  // Dentil mouldings at the roofline, selected only when their screen footprint warrants it.
  if(lod>=3)for(int j=0;j<8;j++){float u=((float)j-3.5f)*(ext/4.0f);n=wallBox(P,base,n,face,x,z,w,d,u,h-0.24f,0.4f,0.15f,0.12f,0.19f,13,seed);}
 }
 if(group>=6&&group<30){
  int face=(group-6)/6;int row=(group-6)%6;if(row>=floors)return;
  float ext=face%2==0?w:d;float y=6.1f+(float)row*3.8f;
  for(int j=0;j<4;j++){
   float u=((float)j-1.5f)*(ext*0.48f);float wy=1.2f;
   // Glass is an opaque, analytically shaded surface, not a transparent backing quad.
   n=wallBox(P,base,n,face,x,z,w,d,u,y,0.032f,0.91f,wy,0.045f,4,seed+(float)(row*17+j*9+face*59));
   n=wallBox(P,base,n,face,x,z,w,d,u,y-wy-0.13f,0.22f,1.13f,0.14f,0.29f,13,seed);
   if(lod>=2){
    n=wallBox(P,base,n,face,x,z,w,d,u,y+wy+0.12f,0.18f,1.11f,0.14f,0.23f,13,seed);
    n=wallBox(P,base,n,face,x,z,w,d,u-1.02f,y,0.12f,0.11f,wy,0.17f,13,seed);
    n=wallBox(P,base,n,face,x,z,w,d,u+1.02f,y,0.12f,0.11f,wy,0.17f,13,seed);
    n=wallBox(P,base,n,face,x,z,w,d,u,y,0.12f,0.044f,wy,0.08f,5,seed);
   }
   if(lod>=3){
    n=wallBox(P,base,n,face,x,z,w,d,u,y+0.3f,0.12f,0.94f,0.035f,0.08f,5,seed);
    n=wallBox(P,base,n,face,x,z,w,d,u,y-wy+0.46f,0.56f,1.10f,0.035f,0.035f,6,seed);
   }
  }
 }
 if(group==30&&lod>=2){
  for(int k=0;k<2;k++){
   float px=x+(k==0?-16.0f:16.0f);float pz=z+15.9f;
   n=emit(P,base,n,make_float3(px,2.0f,pz),make_float3(0.068f,2.0f,0.068f),2,6,0,seed);
   n=emit(P,base,n,make_float3(px,4.0f,pz),make_float3(0.29f,0.38f,0.29f),0,8,0,seed);
   n=emit(P,base,n,make_float3(px,4.44f,pz),make_float3(0.37f,0.1f,0.37f),3,6,0,seed);
   n=emit(P,base,n,make_float3(px,0.15f,pz),make_float3(0.27f,0.18f,0.27f),2,0,0,seed);
  }
  for(int k=0;k<8;k++)n=emit(P,base,n,make_float3(x-14.9f,0.43f,z-12.0f+(float)k*3.3f),make_float3(0.10f,0.43f,0.10f),2,6,0,seed);
  for(int face=0;face<4;face++)for(int k=0;k<2;k++){
   float ext=(face%2==0?w:d)-0.65f;float u=(k==0?-0.5f:0.5f)*ext;
   float3 centre=make_float3(x+u,3.16f,z+(face==0?d-0.5f:-d+0.5f));
   if(face%2==1)centre=make_float3(x+(face==1?w-0.5f:-w+0.5f),3.16f,z+u);
   n=emit(P,base,n,centre,make_float3(ext*0.5f,0.88f,0.49f),4,13,face%2,seed);
  }

 }
 if(group==31&&lod>=2){
  // Rooftop dormers and copper service details.
  if(type==0)for(int k=0;k<4;k++){
   float xx=x+(k%2==0?-w*0.68f:w*0.68f);float zz=z+((float)(k/2)-0.5f)*d*0.96f;
   n=emit(P,base,n,make_float3(xx,h+2.5f,zz),make_float3(1.35f,1.05f,1.05f),0,0,0,seed);
   n=emit(P,base,n,make_float3(xx,h+3.55f,zz),make_float3(1.45f,1.0f,1.2f),3,2,1,seed);
   n=emit(P,base,n,make_float3(xx+(k%2==0?-1.36f:1.36f),h+2.5f,zz),make_float3(0.035f,0.70f,0.65f),0,4,0,seed);
  }
  for(int face=0;face<4;face++){
   n=wallBox(P,base,n,face,x,z,w-3.5f,d-3.5f,0.0f,1.6f,0.045f,1.05f,1.4f,0.055f,4,seed);
   n=wallBox(P,base,n,face,x,z,w-3.5f,d-3.5f,0.0f,3.13f,0.09f,1.25f,0.15f,0.12f,13,seed);
   n=wallBox(P,base,n,face,x,z,w-3.5f,d-3.5f,0.0f,0.18f,0.18f,1.25f,0.10f,0.35f,0,seed);
  }
  // Planters on the front arcade edge: leaves grow from code too.
  for(int k=0;k<3;k++){
   float xx=x+((float)k-1.0f)*7.0f;
   n=emit(P,base,n,make_float3(xx,0.48f,z+d+1.5f),make_float3(0.52f,0.42f,0.52f),2,14,0,seed);
   n=emit(P,base,n,make_float3(xx,1.13f,z+d+1.5f),make_float3(0.7f,0.8f,0.7f),1,7,0,seed+(float)k);
  }
 }

 if(group>=32&&group<56&&lod>=2){
  int face=(group-32)/6;int row=(group-32)%6;if(row>=floors)return;
  float ext=face%2==0?w:d;float y=6.1f+(float)row*3.8f;
  for(int j=0;j<4;j++){
   float u=((float)j-1.5f)*(ext*0.48f);
   n=wallBox(P,base,n,face,x,z,w,d,u,y-1.18f,0.56f,1.16f,0.085f,0.65f,13,seed);
   n=wallBox(P,base,n,face,x,z,w,d,u,y-0.28f,1.12f,1.15f,0.035f,0.035f,6,seed);
   if(lod>=3){
    n=wallBox(P,base,n,face,x,z,w,d,u,y-1.00f,1.12f,1.15f,0.026f,0.026f,6,seed);
    for(int k=0;k<5;k++)n=wallBox(P,base,n,face,x,z,w,d,u+((float)k-2.0f)*0.53f,y-0.64f,1.12f,0.025f,0.37f,0.026f,6,seed);
   }
  }
 }
 if(group>=56&&group<60&&lod>=2){
  int face=group-56;float ext=face%2==0?w:d;
  // Quoin blocks: real alternating corner stones, not a diffuse decal.
  for(int k=0;k<14;k++){
   float yy=4.45f+(float)k*(h-4.0f)/14.0f;float width=k%2==0?0.52f:0.30f;
   n=wallBox(P,base,n,face,x,z,w,d,-ext+width,yy,0.12f,width,0.16f,0.16f,0,seed);
   n=wallBox(P,base,n,face,x,z,w,d,ext-width,yy,0.12f,width,0.16f,0.16f,0,seed);
  }
  if(type==2){
   float3 centre=make_float3(x,h-2.3f,z+(face==0?d+0.21f:-d-0.21f));
   if(face%2==1)centre=make_float3(x+(face==1?w+0.21f:-w-0.21f),h-2.3f,z);
   n=emit(P,base,n,centre,make_float3(2.35f,2.35f,0.26f),7,13,face%2,seed);
   n=emit(P,base,n,centre,make_float3(1.85f,1.85f,0.032f),1,17,face%2,seed);
  }
 }
 if((group==60||group==61)&&lod>=3&&type==0){
  int side=group-60;int roofmat=hash1((int)seed)>0.5f?14:2;
  for(int j=0;j<32;j++){
   float zz=z-d+((float)(j+side*32)+0.5f)*d/32.0f;
   n=emit(P,base,n,make_float3(x,h+0.395f,zz),make_float3(w+0.46f,4.42f,0.023f),3,roofmat,0,seed);
  }
 }
 if(group==62&&lod>=2){
  for(int side=0;side<2;side++)for(int k=0;k<16;k++){
   float u=-15.5f+(float)k*2.0f;
   n=emit(P,base,n,make_float3(x+u,0.16f,z+(side==0?-16.3f:16.3f)),make_float3(0.98f,0.19f,0.19f),0,0,0,seed);
  }
 }
 if(group==63&&lod>=3){
  for(int face=0;face<4;face++)for(int k=0;k<8;k++){
   float ext=face%2==0?w:d;float u=((float)k-3.5f)*ext*0.25f;
   n=wallBox(P,base,n,face,x,z,w,d,u,h-0.36f,0.48f,0.12f,0.24f,0.24f,13,seed);
  }
 }
}


// ===== CACHE =====
// A page is a cached procedural asset, not a downloaded mesh. Morton-ordered BVH leaves
// refer to analytic primitives generated by assets.cu. All accesses stay on the GPU.
__global__ void sortPages(const int* Queue,const float* P,int* Order,float* Nodes){
 __shared__ unsigned int keys[PRIMS];
 __shared__ unsigned int ids[PRIMS];
 int q=(int)blockIdx.x;int lane=(int)threadIdx.x;bool valid=q<Queue[0];int slot=0;
 if(valid)slot=Queue[q+1];
 for(int r=0;r<PRIMS/256;r++){
  int i=lane+r*256;unsigned int key=4294967295u;
  if(valid){int b=(slot*PRIMS+i)*PS;if(P[b+3]>=0.0f){float cx=floorf((P[b]+CELL*0.5f)/CELL)*CELL;float cz=floorf((P[b+2]+CELL*0.5f)/CELL)*CELL;key=morton3((P[b]-cx+18.0f)/36.0f,P[b+1]/70.0f,(P[b+2]-cz+18.0f)/36.0f);}}
  keys[i]=key;ids[i]=(unsigned int)i;
 }
 __syncthreads();
 for(int size=2;size<=PRIMS;size*=2){
  for(int stride=size/2;stride>0;stride/=2){
   for(int r=0;r<PRIMS/256;r++){
    int i=lane+r*256;int other=i^stride;
    if(other>i){bool ascending=(i&size)==0;unsigned int a=keys[i];unsigned int b=keys[other];unsigned int ia=ids[i];unsigned int ib=ids[other];
     bool greater=a>b||(a==b&&ia>ib);
     if((ascending&&greater)||(!ascending&&!greater)){keys[i]=b;keys[other]=a;ids[i]=ib;ids[other]=ia;}
    }
   }
   __syncthreads();
  }
 }
 if(valid)for(int r=0;r<PRIMS/256;r++){
  int i=lane+r*256;int id=slot*PRIMS+(int)ids[i];Order[slot*PRIMS+i]=id;int b=id*PS;int n=(slot*NODES+PRIMS+i)*8;
  float3 lo=make_float3(1000000.0f,1000000.0f,1000000.0f);float3 hi=make_float3(-1000000.0f,-1000000.0f,-1000000.0f);
  if(P[b+3]>=0.0f){
   float3 p=make_float3(P[b],P[b+1],P[b+2]);float3 h=make_float3(P[b+4],P[b+5],P[b+6]);
   if(((int)P[b+8])%2==1){float tmp=h.x;h.x=h.z;h.z=tmp;}
   lo=p-h;hi=p+h;if((int)P[b+3]==3||(int)P[b+3]==4)lo.y=p.y;
   lo=lo-make_float3(0.008f,0.008f,0.008f);hi=hi+make_float3(0.008f,0.008f,0.008f);
  }
  Nodes[n]=lo.x;Nodes[n+1]=lo.y;Nodes[n+2]=lo.z;Nodes[n+3]=P[b+3]>=0.0f?1.0f:0.0f;
  Nodes[n+4]=hi.x;Nodes[n+5]=hi.y;Nodes[n+6]=hi.z;Nodes[n+7]=0.0f;
 }
}
__global__ void buildBVH(const int* Queue,float* Nodes,int first){
 int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);int q=i/first;int j=i%first+first;if(q>=Queue[0])return;
 int slot=Queue[q+1];int n=(slot*NODES+j)*8;int a=(slot*NODES+j*2)*8;int b=a+8;
 for(int k=0;k<3;k++){Nodes[n+k]=fminf(Nodes[a+k],Nodes[b+k]);Nodes[n+4+k]=fmaxf(Nodes[a+4+k],Nodes[b+4+k]);}
 Nodes[n+3]=Nodes[a+3]+Nodes[b+3];Nodes[n+7]=0.0f;
}


// ===== TRACE =====
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


// ===== MATERIALS =====
// Procedural material signals are evaluated in world metres and filtered by ray footprint.
// No material image, mesh asset, normal map or downloaded atlas exists.
__device__ float3 substrateMean(int material){return material==1?make_float3(0.37f,0.185f,0.105f):make_float3(0.55f,0.485f,0.365f);}
__device__ float3 substrate(float u,float v,float seed,int material){
 float large=fbm2(u*0.31f+seed*0.013f,v*0.31f);
 float run=fbm2(u*0.42f+seed*0.01f,v*0.038f+1.7f);
 float3 base=substrateMean(material);
 float age=0.61f+0.52f*large;float damp=smoothf(0.49f,0.76f,run)*0.31f;
 return base*(age-damp)+make_float3(0.017f,0.024f,0.014f)*damp;
}
__device__ float feature(int i,float u,float v,float seed,int mat){
 if(i==0)return sinf(u*0.13f);
 if(i==1)return cosf(u*0.13f);
 if(i==2)return sinf(v*0.13f);
 if(i==3)return cosf(v*0.13f);
 if(i==4)return noise2(u*0.31f+seed*0.013f,v*0.31f)*2.0f-1.0f;
 if(i==5)return noise2(u*0.42f+seed*0.01f,v*0.038f+1.7f)*2.0f-1.0f;
 if(i==6)return (float)mat*2.0f-1.0f;
 return sinf(seed*0.03f);
}
__device__ float activate(float x){x=clampf(x,-8.0f,8.0f);return 2.0f/(1.0f+expf(-2.0f*x))-1.0f;}
__device__ float3 predictSubstrate(const float* W,float u,float v,float seed,int mat){
 float hidden[24];for(int h=0;h<NN_HIDDEN;h++){float z=W[192+h];for(int j=0;j<NN_INPUTS;j++)z+=W[h*8+j]*feature(j,u,v,seed,mat);hidden[h]=activate(z);}
 float3 out=make_float3(W[288],W[289],W[290]);
 for(int h=0;h<24;h++){out.x+=W[216+h]*hidden[h];out.y+=W[240+h]*hidden[h];out.z+=W[264+h]*hidden[h];}
 return make_float3(sat(out.x),sat(out.y),sat(out.z));
}
__device__ float3 sky(float3 rd,float3 sun){
 float elev=sat(rd.y);float3 c=mix3(make_float3(0.62f,0.69f,0.72f),make_float3(0.13f,0.30f,0.52f),powf(elev,0.45f));
 float sd=fmaxf(0.0f,dot3(rd,sun));c=c+make_float3(1.1f,0.62f,0.22f)*powf(sd,18.0f)+make_float3(9.0f,6.0f,3.2f)*powf(sd,2600.0f);
 if(rd.y>0.025f){float cloud=fbm2(rd.x/(rd.y+0.20f)*1.8f+16.0f,rd.z/(rd.y+0.20f)*1.8f);float veil=smoothf(0.46f,0.70f,cloud)*smoothf(0.02f,0.2f,rd.y)*0.55f;c=mix3(c,make_float3(0.86f,0.85f,0.80f),veil);}
 return c;
}
// Cellular pores and mineral inclusions are evaluated in metres, not a zoomed bitmap.
__device__ float3 mineralCell(float u,float v,int seed){
 int ix=(int)floorf(u);int iy=(int)floorf(v);float x=fractf(u);float y=fractf(v);
 float nearest=10.0f;float second=10.0f;float value=0.0f;
 for(int j=-1;j<=1;j++)for(int i=-1;i<=1;i++){
  float dx=(float)i+0.18f+0.64f*hash2(ix+i,iy+j,seed)-x;
  float dy=(float)j+0.18f+0.64f*hash2(ix+i,iy+j,seed+47)-y;
  float d=dx*dx+dy*dy;if(d<nearest){second=nearest;nearest=d;value=hash2(ix+i,iy+j,seed+83);}else second=fminf(second,d);
 }
 return make_float3(sqrtf(nearest),value,sqrtf(second)-sqrtf(nearest));
}
__device__ float microRelief(float u,float v,float footprint){
 float value=(noise2(u*83.0f,v*83.0f)-0.5f)*0.0016f*frequencyWeight(footprint,83.0f);
 value+=(noise2(u*277.0f+8.7f,v*277.0f)-0.5f)*0.00048f*frequencyWeight(footprint,277.0f);
 value+=(noise2(u*911.0f,v*911.0f-13.9f)-0.5f)*0.00013f*frequencyWeight(footprint,911.0f);
 return value;
}
__device__ float3 surfaceColor(float3 p,float3 n,int mat,float seed,float footprint,float3 foundation){
 float2 uv=masonryUV(p,n);float u=uv.x;float v=uv.y;float fine=frequencyWeight(footprint,34.0f);
 float3 c=foundation;
 if(mat==0||mat==1){
  float bw=mat==1?0.46f:0.92f;float bh=mat==1?0.215f:0.46f;int row=(int)floorf(v/bh);int brick=(int)floorf(u/bw+(float)imod(row,2)*0.5f);
  float xx=fractf(u/bw+(float)imod(row,2)*0.5f);float yy=fractf(v/bh);float edge=fminf(fminf(xx,1.0f-xx)*bw,fminf(yy,1.0f-yy)*bh);
  float joint=(1.0f-smoothf(0.005f,0.021f+footprint*0.4f,edge))*frequencyWeight(footprint,1.0f/bh);
  float variation=(hash2(brick,row,(int)seed)-0.5f)*0.19f*frequencyWeight(footprint,1.0f/bh);
  c=c*(1.0f+variation);c=mix3(c,make_float3(0.25f,0.245f,0.21f),joint*0.84f);
  float pores=fbm2(u*52.0f+seed,v*52.0f);c=c*(1.0f+(pores-0.5f)*0.38f*fine);
  float deposits=smoothf(0.45f,0.76f,fbm2(u*5.1f+seed*0.3f,v*6.2f));
  c=mix3(c,make_float3(0.52f,0.49f,0.39f),deposits*0.23f*(1.0f-joint));
  if(footprint<0.007f){
   float3 mineral=mineralCell(u*190.0f,v*190.0f,(int)seed);float detail=frequencyWeight(footprint,190.0f);
   float pit=(1.0f-smoothf(0.075f,0.23f,mineral.x))*smoothf(0.52f,0.76f,mineral.y)*detail;
   float grit=(1.0f-smoothf(0.018f,0.072f,mineral.z))*detail;
   c=c*(1.0f-pit*0.66f-grit*0.075f);
   float fleck=(1.0f-smoothf(0.04f,0.17f,mineral.x))*(1.0f-smoothf(0.07f,0.18f,mineral.y))*detail;
   c=mix3(c,make_float3(0.62f,0.56f,0.44f),fleck*0.78f);
   float powder=(noise2(u*740.0f,v*740.0f)-0.5f)*frequencyWeight(footprint,740.0f);
   c=c*(1.0f+powder*(joint>0.5f?0.50f:0.24f));
  }
  // Multi-scale branching fractures: thin shading features, filtered before they alias.
  float crack=fabsf(sinf(u*8.4f+fbm2(u*2.4f,v*2.4f)*5.0f+v*1.3f));
  float fracture=(1.0f-smoothf(0.012f,0.042f+footprint*4.0f,crack))*smoothf(0.48f,0.72f,noise2(u*1.4f,v*1.4f));
  c=c*(1.0f-fracture*0.45f*frequencyWeight(footprint,15.0f));
  float moss=(1.0f-smoothf(0.1f,3.1f,p.y))*smoothf(0.44f,0.69f,noise2(u*1.3f,v*0.3f));c=mix3(c,make_float3(0.095f,0.125f,0.046f),moss*0.7f);
 }
 else if(mat==2||mat==14){
  c=mat==2?make_float3(0.14f,0.19f,0.22f):make_float3(0.38f,0.125f,0.048f);
  float tile=fractf(u*3.7f);float row=fractf(v*4.4f);float seam=(1.0f-smoothf(0.01f,0.07f,tile))+(1.0f-smoothf(0.02f,0.11f,row));
  c=c*(0.78f+0.26f*noise2(u*7.2f,v*7.2f)-sat(seam)*0.25f*frequencyWeight(footprint,4.4f));
 }
 else if(mat==3){float patina=smoothf(0.28f,0.64f,fbm2(u*2.1f,v*2.1f));c=mix3(make_float3(0.27f,0.145f,0.072f),make_float3(0.085f,0.24f,0.18f),patina);float seam=1.0f-smoothf(0.015f,0.07f,fractf(u*1.8f));c=c*(1.0f-seam*0.4f*frequencyWeight(footprint,1.8f));}
 else if(mat==4)c=make_float3(0.045f,0.084f,0.093f);
 else if(mat==5){float grain=sinf(u*49.0f+fbm2(u*2.0f,v*0.5f)*8.0f);c=make_float3(0.12f,0.07f,0.039f)*(1.0f+grain*0.12f*fine);}
 else if(mat==6)c=make_float3(0.075f,0.091f,0.087f)*(0.8f+noise2(u*30.0f,v*30.0f)*0.3f);
 else if(mat==7){float leaves=fbm2(p.x*8.0f+p.y*6.0f,p.z*8.0f);c=mix3(make_float3(0.055f,0.095f,0.020f),make_float3(0.18f,0.25f,0.055f),leaves);}
 else if(mat==8)c=make_float3(0.70f,0.43f,0.13f);
 else if(mat==9)c=make_float3(0.035f,0.115f,0.12f);
 else if(mat==10){float grit=fbm2(u*45.0f,v*45.0f);c=make_float3(0.16f,0.17f,0.16f)*(0.72f+grit*0.4f);}
 else if(mat==11){int row=(int)floorf(v/0.45f);float a=fractf(u/0.9f+(float)imod(row,2)*0.5f);float b=fractf(v/0.45f);float joint=(1.0f-smoothf(0.02f,0.07f+footprint, fminf(fminf(a,1.0f-a),fminf(b,1.0f-b))));c=make_float3(0.43f,0.415f,0.36f)*(0.78f+fbm2(u*18.0f,v*18.0f)*0.3f);c=c*(1.0f-joint*0.30f*frequencyWeight(footprint,2.0f));}
 else if(mat==13)c=make_float3(0.54f,0.475f,0.35f)*(0.82f+fbm2(u*1.6f,v*1.6f)*0.24f);
 else if(mat==15)c=make_float3(0.17f,0.12f,0.065f)*(0.65f+0.6f*fbm2(u*31.0f,v*3.0f));
 if(mat==18){float panel=fractf(u/1.6f);float frame=(1.0f-smoothf(0.02f,0.06f,panel))+(1.0f-smoothf(0.02f,0.06f,1.0f-panel));float band=1.0f-smoothf(0.03f,0.07f,fabsf(v-2.65f));c=mix3(make_float3(0.058f,0.092f,0.105f),make_float3(0.10f,0.059f,0.027f),sat(frame+band));}
 if(mat==17){float a=atan2f(v-floorf(v/30.0f)*30.0f-28.5f,u);float glass=0.5f+0.5f*sinf(a*12.0f+seed);c=mix3(make_float3(0.08f,0.18f,0.32f),make_float3(0.50f,0.12f,0.04f),glass);}
 return c;
}


// ===== LEARNING =====
// Optional online material surrogate, not an AI-generated world or a claimed speed-up.
// 8 -> 24 tanh -> 3 linear = 291 parameters. The exact seam/grain geometry remains procedural.
// Eight held-out samples are scored before an update; they are excluded from its gradient.
__device__ bool materialTrainNow(const float* C){return ((int)C[6])%4==0&&C[21]<0.5f;}
__global__ void initNeural(float* W,float* M,float* V,float* Brain,int seed){
 int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);
 if(i<NN_PARAMS){W[i]=(hash1(i+seed)-0.5f)*0.08f;M[i]=0.0f;V[i]=0.0f;if(i>=216)W[i]=0.0f;}
 if(i<32)Brain[i]=0.0f;
 if(i==288)W[i]=0.36f;if(i==289)W[i]=0.29f;if(i==290)W[i]=0.20f;
}
__global__ void prepareMaterialBatch(const float* P,const float* Hit,const float* C,float* Work,int width,int height){
 int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=NN_BATCH||!materialTrainNow(C))return;int b=i*NN_WS;int chosen=-1;
 for(int trial=0;trial<6;trial++){
  int px=(int)(hash1(i*1877+trial*331+(int)C[6]*59)*(float)(width*height));int id=(int)Hit[px*4+1];
  if(id>=0){int mat=(int)P[id*PS+7];if(mat==0||mat==1)chosen=px;}
 }
 Work[b+62]=0.0f;for(int j=0;j<11;j++)Work[b+j]=0.0f;
 if(chosen<0)return;
 int id=(int)Hit[chosen*4+1];int mat=(int)P[id*PS+7];float seed=P[id*PS+9];float3 rd=rayDirection(C,chosen%width,chosen/width,width,height);float3 p=cameraPosition(C)+rd*Hit[chosen*4];float3 n=primitiveNormal(P,id,p);float2 uv=masonryUV(p,n);
 for(int j=0;j<NN_INPUTS;j++)Work[b+j]=feature(j,uv.x,uv.y,seed,mat);
 float3 target=substrate(uv.x,uv.y,seed,mat);Work[b+8]=target.x;Work[b+9]=target.y;Work[b+10]=target.z;Work[b+62]=1.0f;Work[b+63]=(float)mat;
}
__global__ void materialForward(const float* C,const float* W,float* Work){
 int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=NN_BATCH||!materialTrainNow(C))return;int b=i*NN_WS;
 for(int h=0;h<NN_HIDDEN;h++){float z=W[192+h];for(int j=0;j<NN_INPUTS;j++)z+=W[h*8+j]*Work[b+j];Work[b+14+h]=activate(z);}
 for(int o=0;o<3;o++){float z=W[288+o];for(int h=0;h<NN_HIDDEN;h++)z+=W[216+o*24+h]*Work[b+14+h];Work[b+11+o]=z;}
}
__global__ void scoreMaterial(const float* C,const float* Work,float* Brain){
 if(blockIdx.x!=0||threadIdx.x!=0||!materialTrainNow(C))return;
 float err=0.0f;float baseline=0.0f;float n=0.0f;
 for(int i=56;i<64;i++){
  int b=i*NN_WS;if(Work[b+62]>0.5f){n+=1.0f;float3 mean=substrateMean((int)Work[b+63]);
   for(int o=0;o<3;o++){float d=Work[b+11+o]-Work[b+8+o];err+=d*d;float v=o==0?mean.x:(o==1?mean.y:mean.z);float e=v-Work[b+8+o];baseline+=e*e;}
  }
 }
 if(n>0.0f){float a=Brain[1]<1.0f?1.0f:0.065f;Brain[2]=lerpf(Brain[2],err/(n*3.0f),a);Brain[3]=lerpf(Brain[3],baseline/(n*3.0f),a);Brain[1]+=n;}
 // A real gate, not a cosmetic AI toggle. No contribution if validation fails.
 Brain[4]=Brain[1]>=256.0f&&Brain[2]<Brain[3]*0.90f&&Brain[2]<0.0012f?1.0f:0.0f;
}
__global__ void materialGradient(const float* C,const float* Work,const float* W,float* Grad,float* Brain){
 int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=NN_PARAMS||!materialTrainNow(C))return;
 float g=0.0f;float count=0.0f;
 for(int n=0;n<56;n++){
  int b=n*NN_WS;if(Work[b+62]>0.5f){count+=1.0f;
   if(i<216){int h=i<192?i/8:i-192;float d=0.0f;for(int o=0;o<3;o++)d+=(Work[b+11+o]-Work[b+8+o])*W[216+o*24+h];float a=Work[b+14+h];d*=1.0f-a*a;g+=i<192?d*Work[b+i%8]:d;}
   else if(i<288){int o=(i-216)/24;int h=(i-216)%24;g+=(Work[b+11+o]-Work[b+8+o])*Work[b+14+h];}
   else{int o=i-288;g+=Work[b+11+o]-Work[b+8+o];}
  }
 }
 Grad[i]=clampf(g/fmaxf(1.0f,count),-0.8f,0.8f);
 if(i==0){if(count>0.0f)Brain[0]+=1.0f;Brain[5]=count;}
}
__global__ void materialAdam(const float* C,const float* Grad,float* W,float* M,float* V,const float* Brain){
 int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=NN_PARAMS||!materialTrainNow(C)||Brain[5]<1.0f)return;
 float g=Grad[i];float m=0.9f*M[i]+0.1f*g;float v=0.999f*V[i]+0.001f*g*g;M[i]=m;V[i]=v;
 float mh=m/(1.0f-powf(0.9f,Brain[0]));float vh=v/(1.0f-powf(0.999f,Brain[0]));
 W[i]-=0.002f*(mh/(sqrtf(vh)+0.00001f)+0.0001f*W[i]);
}


// ===== SHADE =====
// Lighting is explicit and intentionally not described as path tracing.
// Shadows use macro city geometry; fine local ambient occlusion is analytic.
__device__ float macroShadow(const float* World,float3 p,float3 light){
 if(light.y<0.005f)return 0.0f;
 float maxT=(90.0f-p.y)/light.y;if(maxT<0.0f)return 1.0f;maxT=fminf(maxT,800.0f);
 float3 ro=p+light*0.08f;int cx=(int)floorf((ro.x+18.0f)/CELL);int cz=(int)floorf((ro.z+18.0f)/CELL);
 int sx=light.x>0.0f?1:-1;int sz=light.z>0.0f?1:-1;
 float tx=((float)cx*CELL+(sx>0?18.0f:-18.0f)-ro.x)*safeInv(light.x);float tz=((float)cz*CELL+(sz>0?18.0f:-18.0f)-ro.z)*safeInv(light.z);
 float dx=CELL*fabsf(safeInv(light.x));float dz=CELL*fabsf(safeInv(light.z));float t=0.0f;
 for(int step=0;step<40;step++){
  if(!inCity(cx,cz)||t>maxT)break;int b=worldIndex(cx,cz)*8;int type=(int)World[b+3];
  if(type!=3&&type!=4){
   float w=World[b];float d=World[b+1];float h=World[b+2];
   // Contract just inside facade surfaces so fine attached geometry does not self-shadow as a solid building.
   float3 lo=make_float3((float)cx*CELL-w+0.05f,4.1f,(float)cz*CELL-d+0.05f);float3 hi=make_float3((float)cx*CELL+w-0.05f,h,(float)cz*CELL+d-0.05f);
   float2 span=boxRange(ro,light,lo,hi);
   if(span.y>fmaxf(0.06f,span.x)&&span.x<maxT)return 0.04f;
  }
  if(type==3)for(int k=0;k<8;k++){
   float th=5.0f+hash1((int)World[b+6]+k)*3.0f;float txc=(float)cx*CELL+(k<4?-10.0f:10.0f);float tzc=(float)cz*CELL+((float)(k%4)-1.5f)*6.7f;
   float3 a=make_float3((ro.x-txc)/2.5f,(ro.y-th-1.0f)/2.7f,(ro.z-tzc)/2.5f);float3 v=make_float3(light.x/2.5f,light.y/2.7f,light.z/2.5f);float aa=dot3(v,v);float bb=dot3(a,v);float disc=bb*bb-aa*(dot3(a,a)-1.0f);
   if(disc>0.0f){float u=(-bb-sqrtf(disc))/aa;if(u>0.05f&&u<maxT)return 0.22f+0.42f*noise2(p.x*8.2f,p.z*8.2f);}
  }
  if(tx<tz){t=tx;tx+=dx;cx+=sx;}else{t=tz;tz+=dz;cz+=sz;}
 }
 return 1.0f;
}
__device__ float ambientVisibility(const float* World,float3 p,float3 n){
 int cx=(int)floorf((p.x+18.0f)/CELL);int cz=(int)floorf((p.z+18.0f)/CELL);float occ=0.0f;
 for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)if(inCity(cx+x,cz+z)){
  int b=worldIndex(cx+x,cz+z)*8;int type=(int)World[b+3];if(type!=3&&type!=4){
   float xx=fabsf(p.x-(float)(cx+x)*CELL)-World[b];float zz=fabsf(p.z-(float)(cz+z)*CELL)-World[b+1];
   float dist=sqrtf(fmaxf(0.0f,xx)*fmaxf(0.0f,xx)+fmaxf(0.0f,zz)*fmaxf(0.0f,zz));
   if(dist>0.06f)occ+=sat((World[b+2]-p.y)/(dist+World[b+2]+1.0f))*expf(-dist*0.12f)*0.48f;
  }
 }
 return clampf(1.0f-occ,0.35f,1.0f);
}
__global__ void shadePixels(const float* World,const float* P,const float* C,const float* Hit,const float* W,const float* Brain,float* Linear,int width,int height){
 int x=(int)(blockIdx.x*blockDim.x+threadIdx.x);int y=(int)(blockIdx.y*blockDim.y+threadIdx.y);if(x>=width||y>=height)return;int b=(y*width+x)*4;
 float t=Hit[b];int id=(int)Hit[b+1];float3 rd=rayDirection(C,x,y,width,height);float3 ro=cameraPosition(C);float3 sun=sunDirection(C);float3 result=sky(rd,sun);
 if(id!=-10000){
  float3 p=ro+rd*t;float3 n=make_float3(0.0f,1.0f,0.0f);int mat=10;float seed=0.0f;
  if(id>=0){n=primitiveNormal(P,id,p);mat=(int)P[id*PS+7];seed=P[id*PS+9];}
  else if(id<=-2){int wi=-id-2;int wi8=wi*8;float3 c=make_float3((float)(wi%CITY-CITY/2)*CELL,(World[wi8+2]+4.5f)*0.5f,(float)(wi/CITY-CITY/2)*CELL);float3 h=make_float3(World[wi8],c.y,World[wi8+1]);float3 q=abs3(p-c);float3 e=make_float3(fabsf(q.x-h.x),fabsf(q.y-h.y),fabsf(q.z-h.z));n=e.y<e.x&&e.y<e.z?make_float3(0.0f,1.0f,0.0f):(e.x<e.z?make_float3(p.x<c.x?-1.0f:1.0f,0.0f,0.0f):make_float3(0.0f,0.0f,p.z<c.z?-1.0f:1.0f));mat=n.y>0.5f?2:(int)World[wi8+4];seed=World[wi8+6];}
  else{
   int cx=(int)floorf((p.x+18.0f)/CELL);int cz=(int)floorf((p.z+18.0f)/CELL);float xx=fabsf(p.x-(float)cx*CELL);float zz=fabsf(p.z-(float)cz*CELL);
   if(xx<16.5f&&zz<16.5f)mat=11;
   if(cx==-4&&inCity(cx,cz)&&imod(cz,4)!=0)mat=9;
   if(!inCity(cx,cz))mat=7;
  }
  if(id>=0&&mat==5&&P[id*PS+4]>4.0f&&P[id*PS+5]>1.0f)mat=18;
  if(mat==7&&dot3(n,rd)>0.0f)n=n*-1.0f;
  float footprint=fmaxf(0.00005f,t*1.08f/(float)height);float2 uv=masonryUV(p,n);float3 base=substrateMean(mat);
  if(mat==0||mat==1){if(C[16]>0.5f&&Brain[4]>0.5f)base=predictSubstrate(W,uv.x,uv.y,seed,mat);else base=substrate(uv.x,uv.y,seed,mat);}
  float3 albedo=surfaceColor(p,n,mat,seed,footprint,base);
  float3 originalN=n;
  if((mat==0||mat==1)&&fabsf(n.y)<0.5f){
   float eps=fmaxf(0.002f,footprint*0.6f);float du=(masonryHeight(uv.x+eps,uv.y,mat)-masonryHeight(uv.x-eps,uv.y,mat))/(2.0f*eps);float dv=(masonryHeight(uv.x,uv.y+eps,mat)-masonryHeight(uv.x,uv.y-eps,mat))/(2.0f*eps);
   if(footprint<0.005f){float me=fmaxf(0.00016f,footprint*0.8f);du+=(microRelief(uv.x+me,uv.y,footprint)-microRelief(uv.x-me,uv.y,footprint))/(2.0f*me);dv+=(microRelief(uv.x,uv.y+me,footprint)-microRelief(uv.x,uv.y-me,footprint))/(2.0f*me);}
   float3 tangent=fabsf(n.x)>0.5f?make_float3(0.0f,0.0f,1.0f):make_float3(1.0f,0.0f,0.0f);float fade=frequencyWeight(footprint,5.0f);
   n=norm3(n-tangent*(du*fade)-make_float3(0.0f,dv*fade,0.0f));
  }
  if(mat==9){float wave=cosf(p.x*3.7f+p.z*1.1f)*0.06f;float wave2=sinf(p.z*4.4f-p.x*0.9f)*0.08f;n=norm3(n+make_float3(wave,0.0f,wave2));}
  float nl=fmaxf(0.0f,dot3(n,sun));float nv=fmaxf(0.03f,-dot3(n,rd));
  float shadow=C[18]>0.5f?1.0f:macroShadow(World,p+originalN*0.035f,sun);
  float ao=ambientVisibility(World,p,originalN);float rough=0.75f;
  if(mat==3||mat==6)rough=0.38f;if(mat==4||mat==18)rough=0.15f;if(mat==9)rough=0.12f;if(mat==8)rough=0.3f;
  if(id==-1&&mat!=9)rough=lerpf(rough,0.33f,C[10]*smoothf(0.43f,0.68f,fbm2(p.x*0.19f,p.z*0.19f)));
  float3 halfv=norm3(sun-rd);float nh=fmaxf(0.0f,dot3(n,halfv));float vh=fmaxf(0.0f,-dot3(rd,halfv));
  float a=rough*rough;float denom=nh*nh*(a*a-1.0f)+1.0f;float distribution=a*a/(PI*denom*denom+0.000001f);
  float k=(rough+1.0f)*(rough+1.0f)/8.0f;float geometry=nv/(nv*(1.0f-k)+k)*nl/(nl*(1.0f-k)+k+0.00001f);
  float f0=mat==3||mat==6||mat==8?0.35f:0.045f;float fresnel=f0+(1.0f-f0)*powf(1.0f-vh,5.0f);
  float spec=distribution*geometry*fresnel/(4.0f*nv*nl+0.0001f);
  float3 direct=make_float3(2.25f,1.63f,0.99f)*(nl*shadow);
  float skyWeight=0.22f+0.29f*sat(n.y*0.5f+0.5f);float3 ambient=make_float3(0.25f,0.34f,0.44f)*(skyWeight*ao);
  float bounce=(1.0f-sat(n.y))*0.10f;ambient=ambient+make_float3(0.65f,0.43f,0.25f)*bounce*ao;
  result=albedo*(direct+ambient)+make_float3(1.0f,0.87f,0.63f)*(spec*nl*shadow*2.1f);
  if(mat==4||mat==9||mat==18){
   float3 reflection=rd-n*(2.0f*dot3(rd,n));float fr=0.10f+0.72f*powf(1.0f-nv,4.0f);
   result=mix3(result,sky(reflection,sun)*0.60f,fr);
   if(mat==4||mat==18){float room=hash1((int)seed);float shade=0.2f+noise2(uv.x*3.0f,uv.y*2.0f)*0.15f;result=result*0.73f+make_float3(0.13f,0.075f,0.028f)*(room>0.78f?shade:0.03f);}
  }
  if(mat==8)result=result+make_float3(1.1f,0.62f,0.19f)*0.8f;
  if(mat==7)result=result+albedo*(powf(fmaxf(0.0f,dot3(rd,sun)),4.0f)*0.35f);
  // Procedural distant facade windows remain visible without retaining their geometry pages.
  if(id<=-2&&fabsf(originalN.y)<0.5f){float uu=fractf(uv.x/5.6f);float vv=fractf((p.y-4.2f)/3.8f);float pane=smoothf(0.20f,0.26f,uu)*(1.0f-smoothf(0.65f,0.71f,uu))*smoothf(0.20f,0.26f,vv)*(1.0f-smoothf(0.75f,0.81f,vv));result=mix3(result,make_float3(0.095f,0.135f,0.15f),pane*0.8f);}
  float fog=1.0f-expf(-t*0.00062f);float3 haze=sky(norm3(make_float3(rd.x,0.004f,rd.z)),sun);result=mix3(result,haze,fog);
  if(C[11]==1.0f){if(id>=0){int slot=id/PRIMS;float h=hash1(slot);result=make_float3(0.2f+0.7f*h,0.2f+0.7f*hash1(slot+31),0.2f+0.7f*hash1(slot+78));}else result=make_float3(0.10f,0.13f,0.16f);}
  if(C[11]==2.0f){if(id>=0){int cluster=id/PER_CLUSTER;result=make_float3(0.15f+0.75f*hash1(cluster),0.15f+0.75f*hash1(cluster+31),0.15f+0.75f*hash1(cluster+98));}else result=make_float3(0.09f,0.12f,0.14f);}
  if(C[11]==3.0f)result=(n+make_float3(1.0f,1.0f,1.0f))*0.5f;
 }
 Linear[b]=result.x;Linear[b+1]=result.y;Linear[b+2]=result.z;Linear[b+3]=1.0f;
}
__device__ float aces(float x){return sat(x*(2.51f*x+0.03f)/(x*(2.43f*x+0.59f)+0.14f));}
__global__ void resolveFrame(const float* Linear,float* History,unsigned int* Pixels,const float* C,const float* Stats,const float* Hit,const float* P,int width,int height){
 int x=(int)(blockIdx.x*blockDim.x+threadIdx.x);int y=(int)(blockIdx.y*blockDim.y+threadIdx.y);if(x>=width||y>=height)return;int b=(y*width+x)*4;
 float3 c=make_float3(Linear[b],Linear[b+1],Linear[b+2]);
 // Depth-derived local contact occlusion; finite thickness avoids dark halo silhouettes.
 if(C[11]<0.5f&&(int)Hit[b+1]!=-10000&&Hit[b]<250.0f){
  float3 ro=cameraPosition(C);float3 point=ro+rayDirection(C,x,y,width,height)*Hit[b];int id=(int)Hit[b+1];
  float3 n=id>=0?primitiveNormal(P,id,point):make_float3(0.0f,1.0f,0.0f);float occlusion=0.0f;
  float radius=clampf((float)height/(fmaxf(Hit[b],0.5f)*1.08f)*0.8f,3.0f,28.0f);
  for(int k=0;k<8;k++){
   float a=(float)k*PI*0.25f+0.2f;int xx=(int)clampf((float)x+cosf(a)*radius,0.0f,(float)(width-1));int yy=(int)clampf((float)y+sinf(a)*radius,0.0f,(float)(height-1));int j=(yy*width+xx)*4;
   if((int)Hit[j+1]!=-10000){float3 other=ro+rayDirection(C,xx,yy,width,height)*Hit[j];float3 delta=other-point;float len=length3(delta);if(len>0.04f&&len<2.0f){float elevated=dot3(n,delta/len)-0.12f;occlusion+=fmaxf(0.0f,elevated)*expf(-len*1.4f)*0.28f;}}
  }
  c=c*clampf(1.0f-occlusion,0.55f,1.0f);
 }

 float3 bloom=make_float3(0.0f,0.0f,0.0f);
 if(C[11]<0.5f)for(int k=0;k<8;k++){
  float a=(float)k*PI/4.0f;int xx=(int)clampf((float)x+cosf(a)*4.0f,0.0f,(float)(width-1));int yy=(int)clampf((float)y+sinf(a)*4.0f,0.0f,(float)(height-1));int j=(yy*width+xx)*4;
  bloom=bloom+make_float3(fmaxf(0.0f,Linear[j]-1.0f),fmaxf(0.0f,Linear[j+1]-1.0f),fmaxf(0.0f,Linear[j+2]-1.0f))*0.022f;
 }
 c=c+bloom;
 float count=C[15]>0.5f||Stats[1]>0.0f?1.0f:fminf(32.0f,History[b+3]+1.0f);
 float3 old=make_float3(History[b],History[b+1],History[b+2]);c=mix3(old,c,1.0f/count);
 History[b]=c.x;History[b+1]=c.y;History[b+2]=c.z;History[b+3]=count;
 float sx=((float)x/(float)width-0.5f)*1.3f;float sy=((float)y/(float)height-0.5f)*1.3f;float vignette=1.0f-(sx*sx+sy*sy)*0.18f;
 c=c*(C[9]*vignette);c=make_float3(powf(aces(c.x),1.0f/2.2f),powf(aces(c.y),1.0f/2.2f),powf(aces(c.z),1.0f/2.2f));
 Pixels[y*width+x]=packRGBA(c);
}
