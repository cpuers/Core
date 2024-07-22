#include <cassert>
#include <tx.hpp>

Tx::Tx() : st_(0), ed_(0), state_(State::PENDING) {}

ICacheTx::ICacheTx() {
  araddr = 0;
  uncached = false;
  rdata = {0, 0, 0, 0};
  rhit = false;
  cacop_en = false;
  cacop_code = 0;
  cacop_addr = 0;
}
ICacheTxR::ICacheTxR(u32 araddr) { this->araddr = araddr; }
DCacheTx::DCacheTx() {
  op = false;
  addr = 0;
  uncached = false;
  rdata = 0;
  rhit = false;
  awstrb = 0;
  wdata = 0;
  whit = false;
  cacop_en = false;
  cacop_code = 0;
  cacop_addr = 0;
}
DCacheTxR::DCacheTxR(u32 addr) { this->addr = addr; }
DCacheTxW::DCacheTxW(u32 addr, u8 awstrb, u32 wdata) {
  this->op = true;
  this->addr = addr;
  this->awstrb = awstrb;
  this->wdata = wdata;
}
Tx::~Tx() {}
void ICacheTx::push(VTOP *dut) {
  dut->i_araddr = this->araddr;
  dut->i_uncached = this->uncached;
  dut->i_cacop_en = this->cacop_en;
  dut->i_cacop_code = this->cacop_code;
  dut->i_cacop_addr = this->cacop_addr;
}
void ICacheTx::pull(VTOP *dut) {
  for (u32 i = 0; i < 4; i++) {
    this->rdata[i] = dut->i_rdata.at(i);
  }
  this->rhit = dut->i_rhit;
}
void DCacheTx::push(VTOP *dut) {
  dut->d_op = this->op;
  dut->d_addr = this->addr;
  dut->d_uncached = this->uncached;
  dut->d_wdata = this->wdata;
  dut->d_awstrb = this->awstrb;
  dut->d_cacop_en = this->cacop_en;
  dut->d_cacop_code = this->cacop_code;
  dut->d_cacop_addr = this->cacop_addr;
}
void DCacheTx::pull(VTOP *dut) {
  this->rdata = dut->d_rdata;
  this->rhit = dut->d_rhit;
  this->whit = dut->d_whit;
}
void Tx::st(u64 t) {
  assert(state_ == State::PENDING);
  this->st_ = t;
  this->state_ = State::STARTED;
}
void Tx::ed(u64 t) {
  assert(state_ == State::STARTED);
  this->ed_ = t;
  this->state_ = State::ENDED;
}
u64 Tx::st() { return this->st_; }
u64 Tx::ed() { return this->ed_; }
bool CacheTx::check(Ram *ram) {
  assert(state() == State::ENDED);
  return true;
}
bool CacheTx::hit() {
  assert(state() == State::ENDED);
  return ed() - st() <= 4;
}
bool ICacheTxR::check(Ram *ram) {
  CacheTx::check(ram);
  auto e1 = ram->iread(araddr, false);
  auto e2 = ram->iread(araddr, true);

  auto r = rdata;

  bool flag = true;
  for (auto i = 0; i < 4; i++) {
    if (r[i] != e1[i] && r[i] != e2[i]) {
      flag = false;
      break;
    }
  }
  if (!flag) {
    printf("ICache Read: %08x, [%lu -- %lu]\n", araddr, st(), ed());
    printf("Expected: [%08x %08x %08x %08x]\n  or    : [%08x %08x %08x %08x]\n",
           e1[3], e1[2], e1[1], e1[0], e2[3], e2[2], e2[1], e2[0]);
    printf("Result  : [%08x %08x %08x %08x]\n", r[3], r[2], r[1], r[0]);
    return false;
  }
  return true;
}
bool ICacheTxR::hit() {
  CacheTx::hit();
  return this->rhit;
}
ICacheTxUR::ICacheTxUR(u32 araddr) : ICacheTxR(araddr) { uncached = true; }
bool ICacheTxUR::hit() { return false; }
bool DCacheTxR::check(Ram *ram) {
  CacheTx::check(ram);
  u32 e = ram->dread(addr, false);
  u32 r = rdata;
  if (e != r) {
    printf("DCache Read: %08x, [%lu -- %lu]\n", addr, st(), ed());
    printf("Expected: %08x\nResult  : %08x\n", e, r);
    return false;
  }
  return ram->dread(addr, uncached) == rdata;
}
bool DCacheTxR::hit() {
  CacheTx::hit();
  return this->rhit;
}
bool DCacheTxW::check(Ram *ram) {
  CacheTx::check(ram);
  ram->dwrite(addr, wdata, awstrb, false);
  return true;
}
bool DCacheTxW::hit() { return this->whit; }
Tx::State Tx::state() { return state_; };
