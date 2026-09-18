// Executes the authored CUDA math/generation/visibility/shading on CPU.
// The cooperative GPU sort has a clearly separate scalar CPU reference below.
// This harness is NOT the shipped renderer and does not certify hardware GPU performance.
#include <algorithm>
#include <cassert>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#define __device__
#define __global__
#define __shared__
#define __syncthreads() ((void)0)
struct Index {unsigned int x=0,y=0,z=0;};
thread_local Index threadIdx,blockIdx,blockDim,gridDim;
struct float2 {float x,y;};
struct float3 {float x,y,z;};
struct float4 {float x,y,z,w;};
float2 make_float2(float x,float y){return{x,y};}
float3 make_float3(float x,float y,float z){return{x,y,z};}
float4 make_float4(float x,float y,float z,float w){return{x,y,z,w};}
float3 operator+(float3 a,float3 b){return{a.x+b.x,a.y+b.y,a.z+b.z};}
float3 operator-(float3 a,float3 b){return{a.x-b.x,a.y-b.y,a.z-b.z};}
float3 operator*(float3 a,float b){return{a.x*b,a.y*b,a.z*b};}
float3 operator*(float a,float3 b){return b*a;}
float3 operator*(float3 a,float3 b){return{a.x*b.x,a.y*b.y,a.z*b.z};}
float3 operator/(float3 a,float b){return{a.x/b,a.y/b,a.z/b};}
#include "../Stratum.cu"
void scalar(){threadIdx={0,0,0};blockIdx={0,0,0};blockDim={1,1,1};}
template<class F>void dispatch1(int n,F f){for(int i=0;i<n;i++){blockDim={64,1,1};blockIdx={unsigned(i/64),0,0};threadIdx={unsigned(i%64),0,0};f();}}
template<class F>void dispatch2(int w,int h,F f){
 #pragma omp parallel for schedule(dynamic,4)
 for(int y=0;y<h;y++)for(int x=0;x<w;x++){blockDim={8,8,1};blockIdx={unsigned(x/8),unsigned(y/8),0};threadIdx={unsigned(x%8),unsigned(y%8),0};f();}
}
void require(bool ok,const char*label){if(!ok)throw std::runtime_error(label);std::cout<<"PASS "<<label<<"\n";}
struct Renderer {
 std::vector<float>world=std::vector<float>(CITY*CITY*8),meta=std::vector<float>(PAGES*MS),c=std::vector<float>(64),input=std::vector<float>(32),req=std::vector<float>(PAGES*REQUESTS),p=std::vector<float>(PAGES*PRIMS*PS),nodes=std::vector<float>(PAGES*NODES*8),stats=std::vector<float>(32),weights=std::vector<float>(NN_PARAMS),mom=std::vector<float>(NN_PARAMS),variance=std::vector<float>(NN_PARAMS),brain=std::vector<float>(32),work=std::vector<float>(NN_BATCH*NN_WS),grad=std::vector<float>(NN_PARAMS);
 std::vector<int>queue=std::vector<int>(GENERATE_BUDGET+1),order=std::vector<int>(PAGES*PRIMS);
 std::vector<float>hit,linear,history;std::vector<unsigned int>pixels;int width=960,height=600;
 Renderer(){dispatch1(CITY*CITY,[&]{initWorld(world.data(),meta.data(),c.data(),1788);});dispatch1(320,[&]{initNeural(weights.data(),mom.data(),variance.data(),brain.data(),1788);});resize(width,height);}
 void resize(int w,int h){width=w;height=h;hit.assign(w*h*4,0);linear=hit;history=hit;pixels.assign(w*h,0);}
 void camera(int bookmark){scalar();input[8]=float(bookmark);stepCamera(c.data(),input.data(),world.data(),1.0f/60,width,height);input[8]=0;}
 void cpuSort(){
  for(int q=0;q<queue[0];q++){
   int slot=queue[q+1];std::vector<std::pair<uint32_t,int>>a;
   for(int i=0;i<PRIMS;i++){int b=(slot*PRIMS+i)*PS;uint32_t key=0xffffffffu;if(p[b+3]>=0){float cx=floorf((p[b]+18)/CELL)*CELL;float cz=floorf((p[b+2]+18)/CELL)*CELL;key=morton3((p[b]-cx+18)/36,p[b+1]/70,(p[b+2]-cz+18)/36);}a.push_back({key,i});}
   std::sort(a.begin(),a.end());
   for(int i=0;i<PRIMS;i++){
    int id=slot*PRIMS+a[i].second;order[slot*PRIMS+i]=id;int b=id*PS,n=(slot*NODES+PRIMS+i)*8;float3 lo={1e6,1e6,1e6},hi={-1e6,-1e6,-1e6};
    if(p[b+3]>=0){float3 cp={p[b],p[b+1],p[b+2]},h={p[b+4],p[b+5],p[b+6]};if(int(p[b+8])%2)std::swap(h.x,h.z);lo=cp-h;hi=cp+h;if(int(p[b+3])==3||int(p[b+3])==4)lo.y=cp.y;lo=lo-make_float3(.008,.008,.008);hi=hi+make_float3(.008,.008,.008);}
    nodes[n]=lo.x;nodes[n+1]=lo.y;nodes[n+2]=lo.z;nodes[n+3]=p[b+3]>=0?1:0;nodes[n+4]=hi.x;nodes[n+5]=hi.y;nodes[n+6]=hi.z;
   }
  }
 }
 void cacheFrame(){
  dispatch1(PAGES,[&]{selectPages(c.data(),world.data(),meta.data(),req.data());});scalar();schedulePages(req.data(),queue.data(),stats.data());
  for(int q=0;q<queue[0];q++)for(int g=0;g<CLUSTERS;g++){blockDim={64,1,1};blockIdx={unsigned(q),0,0};threadIdx={unsigned(g),0,0};generatePages(world.data(),req.data(),queue.data(),p.data());}
  cpuSort();for(int first=PRIMS/2;first>=1;first/=2)dispatch1(queue[0]*first,[&]{buildBVH(queue.data(),nodes.data(),first);});
  dispatch1(queue[0],[&]{commitPages(req.data(),queue.data(),p.data(),meta.data(),c.data());});scalar();summarise(meta.data(),req.data(),c.data(),stats.data());
 }
 void settle(){for(int i=0;i<60;i++){camera(0);cacheFrame();if(queue[0]==0)break;}}
 void trace(){dispatch2(width,height,[&]{tracePrimary(world.data(),meta.data(),p.data(),nodes.data(),order.data(),c.data(),hit.data(),width,height);});}
 void train(){dispatch1(NN_BATCH,[&]{prepareMaterialBatch(p.data(),hit.data(),c.data(),work.data(),width,height);});dispatch1(NN_BATCH,[&]{materialForward(c.data(),weights.data(),work.data());});scalar();scoreMaterial(c.data(),work.data(),brain.data());dispatch1(NN_PARAMS,[&]{materialGradient(c.data(),work.data(),weights.data(),grad.data(),brain.data());});dispatch1(NN_PARAMS,[&]{materialAdam(c.data(),grad.data(),weights.data(),mom.data(),variance.data(),brain.data());});}
 void shade(){dispatch2(width,height,[&]{shadePixels(world.data(),p.data(),c.data(),hit.data(),weights.data(),brain.data(),linear.data(),width,height);});dispatch2(width,height,[&]{resolveFrame(linear.data(),history.data(),pixels.data(),c.data(),stats.data(),hit.data(),p.data(),width,height);});}
 void save(const std::string&name){std::ofstream f(name,std::ios::binary);f<<"P6\n"<<width<<" "<<height<<"\n255\n";for(auto p:pixels){char rgb[3]={char(p&255u),char((p>>8)&255u),char((p>>16)&255u)};f.write(rgb,3);}std::cout<<"RENDER "<<name<<" | resident "<<stats[0]<<" | primitives "<<stats[3]<<" | pages needed "<<stats[6]<<"\n";}
};
float nnLoss(Renderer&r){dispatch1(NN_BATCH,[&]{materialForward(r.c.data(),r.weights.data(),r.work.data());});float l=0,n=0;for(int i=0;i<56;i++)if(r.work[i*NN_WS+62]>.5f){n++;for(int o=0;o<3;o++){float d=r.work[i*NN_WS+11+o]-r.work[i*NN_WS+8+o];l+=.5f*d*d;}}return l/std::max(1.0f,n);}
int main(int argc,char**argv){try{
 Renderer r;
 if(argc>1&&std::string(argv[1])=="render"){
  int bm=argc>3?std::stoi(argv[3]):1;int w=argc>4?std::stoi(argv[4]):960;int h=argc>5?std::stoi(argv[5]):600;int samples=argc>6?std::stoi(argv[6]):8;
  if(w<64||h<64||w>4096||h>4096||samples<1||samples>64)throw std::runtime_error("Render arguments out of bounds");
  r.resize(w,h);r.camera(bm);r.settle();
  for(int sample=0;sample<samples;sample++){r.camera(0);r.c[15]=sample==0?1.0f:0.0f;r.trace();r.shade();}
  r.save(argc>2?argv[2]:"stratum.ppm");return 0;
 }
 require(spread10(1023u)==0x09249249u,"Morton interleaving preserves ten bits");
 r.camera(1);r.settle();require(r.stats[0]>10&&r.stats[3]>1000,"GPU-style procedural page requests create real geometry");
 auto p=r.p;r.cacheFrame();require(r.queue[0]==0&&p==r.p,"stationary scene reuses cached geometry without regeneration");
 int s=pageIndex(0,0);r.camera(2);r.settle();require(r.meta[s*MS+3]>.5f,"landmark page is resident");
 int actual=0;for(int i=0;i<PRIMS;i++)if(r.p[(s*PRIMS+i)*PS+3]>=0)actual++;
 require(int(r.nodes[(s*NODES+1)*8+3])==actual,"BVH root count matches generated primitives");
 // Hierarchical visibility is compared with exhaustive analytic primitive intersection.
 float worst=0;int rays=0;
 for(int i=0;i<200;i++){
  float3 ro={hash1(i)*40-20,hash1(i+8)*45,42};float3 rd=norm3(make_float3(hash1(i+41)*20-10,hash1(i+68)*35,0)-ro);
  float brute=FAR;for(int j=0;j<PRIMS;j++)brute=std::min(brute,primitiveHit(r.p.data(),s*PRIMS+j,ro,rd));
  auto hit=pageHit(r.p.data(),r.nodes.data(),r.order.data(),s,ro,rd,FAR);worst=std::max(worst,std::fabs(brute-hit.x));rays++;
 }
 require(worst<.001f,"BVH intersections match exhaustive visibility (200 rays)");
 r.resize(256,160);r.camera(3);r.settle();r.trace();r.shade();require(std::all_of(r.linear.begin(),r.linear.end(),[](float v){return std::isfinite(v);}),"finite procedural lighting output");
 // Deterministic independent finite-difference test for every trainable parameter.
 r.c[6]=4;r.c[21]=0;
 for(int i=0;i<NN_PARAMS;i++)r.weights[i]=sinf(float(i)*1.27f)*.06f;
 for(int b=0;b<NN_BATCH;b++){for(int j=0;j<8;j++)r.work[b*NN_WS+j]=sinf(float(b*8+j))*.3f;for(int o=0;o<3;o++)r.work[b*NN_WS+8+o]=.15f+.05f*o;r.work[b*NN_WS+62]=1;}
 nnLoss(r);dispatch1(NN_PARAMS,[&]{materialGradient(r.c.data(),r.work.data(),r.weights.data(),r.grad.data(),r.brain.data());});
 worst=0;for(int i=0;i<NN_PARAMS;i++){float v=r.weights[i],eps=.001f;r.weights[i]=v+eps;float plus=nnLoss(r);r.weights[i]=v-eps;float minus=nnLoss(r);r.weights[i]=v;worst=std::max(worst,std::fabs((plus-minus)/(2*eps)-r.grad[i]));}
 std::cout<<"Maximum gradient error "<<worst<<"\n";require(worst<.00015f,"all 291 neural gradients match finite differences");
 // Real online training on the rendered inspection surface, with pre-update held-out scoring.
 dispatch1(320,[&]{initNeural(r.weights.data(),r.mom.data(),r.variance.data(),r.brain.data(),1788);});
 for(int i=0;i<500;i++){r.c[6]=float((i+1)*4);r.train();}
 require(r.brain[0]>=500&&r.brain[1]>200,"live neural material updates and held-out observations");
 require(r.brain[2]<r.brain[3],"trained substrate improves on material-mean baseline in deterministic inspection test");
 std::cout<<"LEARNING {\"steps\":"<<r.brain[0]<<",\"heldOut\":"<<r.brain[1]<<",\"neuralMSE\":"<<r.brain[2]<<",\"baselineMSE\":"<<r.brain[3]<<",\"gate\":"<<r.brain[4]<<"}\n";
 auto frozen=r.weights;r.c[21]=1;r.train();require(frozen==r.weights,"training freeze preserves weights");
 r.camera(4);r.settle();require(r.stats[0]<=PAGES,"cache residency remains bounded during camera travel");
 r.camera(2);r.settle();require(std::all_of(r.p.begin(),r.p.end(),[](float v){return std::isfinite(v);}),"regenerated geometry is finite");
 return 0;
 }catch(const std::exception&e){std::cerr<<"FAIL "<<e.what()<<"\n";return 1;}}
