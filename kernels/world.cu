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
