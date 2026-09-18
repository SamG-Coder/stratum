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
