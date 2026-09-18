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
