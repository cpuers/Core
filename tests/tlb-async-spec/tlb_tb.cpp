

#include <common.hpp>
#include <iostream>
#include <testbench.hpp>
#include <Vtlb_async.h>

#include <map>
#include <random>
#include <ctime>
#include <iostream>
#include <cstring>

// modify
#define PALEN       32
#define TLBENTRY    16
#define TESTLOOP  10000
#define EXTRACT_BITS(n, x, y) ((n) >> (x) & ((1 << (y)) - 1))
#define LOWB_SHIFT(n, x, y) (((n) & ((1 << (x)) - 1)) << (y))

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
    
    dut = new Vtlb_async;
}

u64 Testbench::reset(Vtlb_async *cur) {
    delete cur;
    dut = new Vtlb_async;
    for(int i=0; i<TLBENTRY; i++) init_mode[i] = true;
    memset(TLB, 0, sizeof(TLB));
    return 4;
}

Testbench::~Testbench() {
    std::cout << "PASS!" << std::endl;
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
    dut->w_tlbelo0 = dut->w_tlbelo0 | LOWB_SHIFT(ctx->v0, 0, 1);
    dut->w_tlbelo0 = dut->w_tlbelo0 | LOWB_SHIFT(ctx->d0, 1, 1);
    dut->w_tlbelo0 = dut->w_tlbelo0 | LOWB_SHIFT(ctx->plv0, 2, 2);
    dut->w_tlbelo0 = dut->w_tlbelo0 | LOWB_SHIFT(ctx->mat0, 4, 2);
    dut->w_tlbelo0 = dut->w_tlbelo0 | LOWB_SHIFT(ctx->ppn0, 8, PALEN-13);
    
    dut->w_tlbelo1 = 0;
    dut->w_tlbelo1 = dut->w_tlbelo1 | LOWB_SHIFT(ctx->v1,   0, 1);
    dut->w_tlbelo1 = dut->w_tlbelo1 | LOWB_SHIFT(ctx->d1,   1, 1);
    dut->w_tlbelo1 = dut->w_tlbelo1 | LOWB_SHIFT(ctx->plv1, 2, 2);
    dut->w_tlbelo1 = dut->w_tlbelo1 | LOWB_SHIFT(ctx->mat1, 4, 2);
    dut->w_tlbelo1 = dut->w_tlbelo1 | LOWB_SHIFT(ctx->ppn1, 8, PALEN-13);

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

tlb_ctx *dut_read(int read_idx) {

    dut->r_idx = read_idx;
    dut->eval();
    
    tlb_ctx *dut_ctx = new tlb_ctx;

    dut_ctx->vppn = dut->r_vppn;
    dut_ctx->asid = dut->r_asid;
    dut_ctx->ps   = dut->r_ps;

    u32 elo0 = dut->r_tlbelo0;
    u32 elo1 = dut->r_tlbelo1;
    
    dut_ctx->v0   = EXTRACT_BITS(elo0, 0, 1);
    dut_ctx->d0   = EXTRACT_BITS(elo0, 1, 1);
    dut_ctx->plv0 = EXTRACT_BITS(elo0, 2, 2);
    dut_ctx->mat0 = EXTRACT_BITS(elo0, 4, 2);
    dut_ctx->g    = EXTRACT_BITS(elo0, 6, 1);
    dut_ctx->ppn0 = EXTRACT_BITS(elo0, 8, PALEN-13);

    dut_ctx->v1   = EXTRACT_BITS(elo1, 0, 1);
    dut_ctx->d1   = EXTRACT_BITS(elo1, 1, 1);
    dut_ctx->plv1 = EXTRACT_BITS(elo1, 2, 2);
    dut_ctx->mat1 = EXTRACT_BITS(elo1, 4, 2);
    dut_ctx->g    = EXTRACT_BITS(elo1, 6, 1);
    dut_ctx->ppn1 = EXTRACT_BITS(elo1, 8, PALEN-13);

    return dut_ctx;
}


bool dut_check(int idx, tlb_ctx *ctx) {

    dut->eval();

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

void clk_step() {

    dut->clock = ~dut->clock;
    dut->eval();
}

bool chk;

bool Testbench::check(Vtlb_async *dut, u64 time) {
    if(chk == false) {
        std::cout << "FAULT!" << std::endl;
    }
    return chk;
}

bool Testbench::step(Vtlb_async *dut, u64 time) {


    // for(int i=0; i<TESTLOOP; i++) {
    // }
    
    int tlb_idx = rand() % TLBENTRY;
    tlb_ctx *cur_read = dut_read(tlb_idx);
    chk = dut_check(tlb_idx, cur_read);

    tlb_ctx *cur = gen_context();
    ref_write(cur);

    clk_step();

    delete cur;
    return time < TESTLOOP;
}

