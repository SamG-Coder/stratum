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
