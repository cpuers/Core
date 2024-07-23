

#include <common.hpp>
#include <iostream>
#include <testbench.hpp>
#include <Vtlb_async.h>

#include <map>
#include <random>
#include <ctime>
#include <iostream>

// modify
#define TLBENTRY    16
#define TESTLOOP  10000
#define MASK(x,y,z) 

Vtlb_async *dut;

struct tlb_ctx{
    // 比较部分
    u8 e;
    u8 g;
    u8 ps;
    u16 asid;
    u16 vppn;
    // 物理转换部分
    u8 d0;
    u8 v0;
    u8 mat0;
    u8 plv0;
    u16 ppn0;
    u8 d1;
    u8 v1;
    u8 mat1;
    u8 plv1;
    u16 ppn1;
};

tlb_ctx TLB[TLBENTRY];
bool init_mode[TLBENTRY];

Testbench::Testbench(int argc, char **argv) {
    srand(time(0));
    // TLB don't need to init (accroding to manual)
    for(int i=0; i<TLBENTRY; i++) init_mode[i] = true;
}

u16 genbit(int len) {
    u16 mask = (1 << len) - 1;
    u16 randnum = rand();
    return (randnum & mask);
}


u16 truePercent(int percentage) {
    u16 randnum = rand() % 100;
    if(randnum < percentage) return 1;
    return 0;
}

u8 oneProcAsid = 255;

tlb_ctx *gen_context(bool page4KB = true) {
    
    tlb_ctx *ctx = new tlb_ctx;
    
    // 转换部分
    ctx->asid = genbit(8);
    ctx->e = 1;
    ctx->g = genbit(1);
    if(page4KB) ctx->ps = 12;
    else ctx->ps = rand()%2 ? 12 : 21;
    ctx->vppn = genbit(13);
    
    // 物理部分
    ctx->v0 = truePercent(90);
    ctx->d0 = 1;
    ctx->mat0 = genbit(2) % 2;
    ctx->plv0 = genbit(1);
    ctx->ppn0 = genbit(12);
    
    ctx->v1 = truePercent(90);
    ctx->d1 = 1;
    ctx->mat1 = genbit(2) % 2;
    ctx->plv1 = genbit(1);
    ctx->ppn1 = genbit(12);
    
    return ctx;
}

int cur_write;

u16 ref_write(tlb_ctx *ctx) {

    int idx       = rand() % TLBENTRY;
    cur_write = idx;
    init_mode[idx] = false;
    TLB[idx].vppn = ctx->vppn;
    TLB[idx].ps   = ctx->ps;
    TLB[idx].g    = ctx->g;
    TLB[idx].asid = ctx->asid;
    TLB[idx].e    = ctx->e;
    TLB[idx].v0   = ctx->v0;
    TLB[idx].d0   = ctx->d0;
    TLB[idx].ppn0 = ctx->ppn0;
    TLB[idx].mat0 = ctx->mat0;
    TLB[idx].plv0 = ctx->plv0;
    TLB[idx].v1   = ctx->v1;
    TLB[idx].d1   = ctx->d1;
    TLB[idx].ppn1 = ctx->ppn1;
    TLB[idx].mat1 = ctx->mat1;
    TLB[idx].plv1 = ctx->plv1;

    dut->w_vppn = ctx->vppn;
    //dut->w_g    = ctx->g; // no G
    dut->w_ps   = ctx->ps;
    dut->w_asid = ctx->asid;
    dut->w_e    = ctx->e;
    dut->w_idx  = idx;

    dut->w_tlbelo0 = 0;
    dut->w_tlbelo0 = dut->w_tlbelo0 | ctx->v0;
    dut->w_tlbelo0 = dut->w_tlbelo0 | ctx->d0;
    dut->w_tlbelo0 = dut->w_tlbelo0 | ctx->plv0;
    dut->w_tlbelo0 = dut->w_tlbelo0 | ctx->mat0;
    dut->w_tlbelo0 = dut->w_tlbelo0 | ctx->ppn0;
    
    dut->w_tlbelo1 = 0;
    dut->w_tlbelo1 = dut->w_tlbelo1 | ctx->v1;
    dut->w_tlbelo1 = dut->w_tlbelo1 | ctx->d1;
    dut->w_tlbelo1 = dut->w_tlbelo1 | ctx->plv1;
    dut->w_tlbelo1 = dut->w_tlbelo1 | ctx->mat1;
    dut->w_tlbelo1 = dut->w_tlbelo1 | ctx->ppn1;

    return idx;
}


/*
void read_tlb_read() { // TODO

    tlb_found = 0
    for(int i=0; i<TLBENTRY; i++) {
        if ((TLB[i].e==1) &&
            ((TLB[i].g==1) || (TLB[i].asid==csr->asid)) &&
            (TLB[i].vppn[VALEN-1: TLB[i].PS+1]==va[VALEN-1: TLB[i].PS+1]))
        {
            if (tlb_found==0) {
                tlb_found = 1;
                found_ps = TLB[i].ps;
                if (va[found_ps]==0) {
                    found_v = TLB[i].v0;
                    found_d = TLB[i].d0;
                    found_mat = TLB[i].mat0;
                    found_plv = TLB[i].plv0;
                    found_ppn = TLB[i].ppn0;
                }
                else {
                    found_v = TLB[i].v1;
                    found_d = TLB[i].d1;
                    found_mat = TLB[i].mat1;
                    found_plv = TLB[i].plv1;
                    found_ppn = TLB[i].ppn1;
                }
            }
            else{
                // 多项命中，不稳定
                std::cout << "多项命中！！\n";
                assert(0);
            }
        }
    }
    if (tlb_found==0)
        SignalException(TLBR); // 报 TLB 重填例外
    if (found_v==0)
        switch(mem_type){
            case FETCH : 
                SignalException(PIF); // 报取指操作页无效例外
            break;
            case LOAD : 
                SignalException(PIL); // 报 load 操作页无效例外
            break;
            case STORE : 
                SignalException(PIS);  // 报 store 操作页无效例外
            break;
        }
    else if(plv > found_plv)
        SignalException(PPI);  // 报页特权等级不合规例外
    else if ((mem_type==STORE) && (found_d==0)){
        // 禁止写允许检查功能未开启
        SignalException(PME); //报页修改例外
    }
    else {
        pa = {found_ppn[PALEN-13:found_ps-12], va[found_ps-1:0]};
        mat = found_mat;
    }
}
*/



bool dut_read(int idx, tlb_ctx *ctx) {

    if(TLB[idx].vppn != ctx->vppn) { 
        std::cout << "Err: ref:" << TLB[idx].vppn << " dut: " << ctx->vppn << std::endl;
        return false;
    }
    if(TLB[idx].e    != ctx->e) { 
        std::cout << "Err: ref:" << TLB[idx].e << " dut: " << ctx->e << std::endl;
        return false;
    }
    else if(TLB[idx].e == 0) return true;
    if(TLB[idx].ps   != ctx->ps) { 
        std::cout << "Err: ref:" << TLB[idx].ps << " dut: " << ctx->ps << std::endl;
        return false;
    }
    if(TLB[idx].g    != ctx->g) { 
        std::cout << "Err: ref:" << TLB[idx].g << " dut: " << ctx->g << std::endl;
        return false;
    }
    if(TLB[idx].asid != ctx->asid) { 
        std::cout << "Err: ref:" << TLB[idx].asid << " dut: " << ctx->asid << std::endl;
        return false;
    }
    
    
    if(TLB[idx].v0   != ctx->v0) { 
        std::cout << "Err: ref:" << TLB[idx].v0 << " dut: " << ctx->v0 << std::endl;
        return false;
    }
    else if(TLB[idx].v0 == 0) goto PHY1;
    if(TLB[idx].d0   != ctx->d0) { 
        std::cout << "Err: ref:" << TLB[idx].d0 << " dut: " << ctx->d0 << std::endl;
        return false;
    }
    else if(TLB[idx].d0 == 0) goto PHY1;
    if(TLB[idx].ppn0 != ctx->ppn0) { 
        std::cout << "Err: ref:" << TLB[idx].ppn0 << " dut: " << ctx->ppn0 << std::endl;
        return false;
    }
    if(TLB[idx].mat0 != ctx->mat0) { 
        std::cout << "Err: ref:" << TLB[idx].mat0 << " dut: " << ctx->mat0 << std::endl;
        return false;
    }
    if(TLB[idx].plv0 != ctx->plv0) { 
        std::cout << "Err: ref:" << TLB[idx].plv0 << " dut: " << ctx->plv0 << std::endl;
        return false;
    }

PHY1:
    if(TLB[idx].v1   != ctx->v1) { 
        std::cout << "Err: ref:" << TLB[idx].v1 << " dut: " << ctx->v1 << std::endl;
        return false;
    }
    else if(TLB[idx].v1 == 0) return true;
    if(TLB[idx].d1   != ctx->d1) { 
        std::cout << "Err: ref:" << TLB[idx].d1 << " dut: " << ctx->d1 << std::endl;
        return false;
    }
    else if(TLB[idx].d1 == 0) return true;
    if(TLB[idx].ppn1 != ctx->ppn1) { 
        std::cout << "Err: ref:" << TLB[idx].ppn1 << " dut: " << ctx->ppn1 << std::endl;
        return false;
    }
    if(TLB[idx].mat1 != ctx->mat1) { 
        std::cout << "Err: ref:" << TLB[idx].mat1 << " dut: " << ctx->mat1 << std::endl;
        return false;
    }
    if(TLB[idx].plv1 != ctx->plv1) { 
        std::cout << "Err: ref:" << TLB[idx].plv1 << " dut: " << ctx->plv1 << std::endl;
        return false;
    }
    
    
    return true;
}

void step() {

    dut->clock = ~dut->clock;
    dut->eval();
}


int main() {

    dut = new Vtlb_async;
    for(int i=0; i<TLBENTRY; i++) init_mode[i] = true;

    for(int i=0; i<TESTLOOP; i++) {
        tlb_ctx *cur = gen_context();
        ref_write(cur);
        int read_idx;
        do {
            read_idx = rand() % TLBENTRY;
        } while(read_idx == cur_write);
        bool chk = dut_read(read_idx, cur);
        if(chk == false) {
            std::cout << "FAULT!" << std::endl;
            break;
        }
        step();
        delete cur;
    }

    std::cout << "PASS!" << std::endl;

    return 0;
}