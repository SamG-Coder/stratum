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
