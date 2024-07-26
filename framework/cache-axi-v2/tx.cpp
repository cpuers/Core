#include <cassert>
#include <tx.hpp>

Tx::Tx() : st_(0), ed_(0), state_(State::PENDING) {}

ICacheTx::ICacheTx() {
  araddr = 0;
  uncached = false;
  rdata = {0, 0, 0, 0};
  rhit = false;
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
  if (!hit()) {
    ram->iflush(araddr);
  }
  if (values.find(rdata) == values.end()) {
    printf("ICache Read: %08x, [%lu -- %lu]\n", araddr, st(), ed());
    r_t &r = rdata;
    printf("Result  : [%08x %08x %08x %08x]\n", r[3], r[2], r[1], r[0]);
    auto it = values.begin();
    const r_t &e = *it;
    printf("Expected: [%08x %08x %08x %08x]\n", e[3], e[2], e[1], e[0]);
    for (it ++; it != values.end(); it ++) {
      const r_t &e = *it;
      printf("  or    : [%08x %08x %08x %08x]\n", e[3], e[2], e[1], e[0]);
    }
    return false;
  }
  return true;
}
bool ICacheTxR::hit() {
  CacheTx::hit();
  return this->rhit;
}
bool DCacheTxR::check(Ram *ram) {
  CacheTx::check(ram);
  if (values.find(rdata) == values.end()) {
    printf("DCache Read: %08x, [%lu -- %lu]\n", addr, st(), ed());
    printf("Result  : %08x\n", rdata);
    auto it = values.begin();
    printf("Expected: %08x\n", *it);
    for (it ++; it != values.end(); it ++) {
      printf("  or    : %08x\n", *it);
    }
    return false;
  }
  return true;
}
bool DCacheTxR::hit() {
  CacheTx::hit();
  return this->rhit;
}
bool DCacheTxW::check(Ram *ram) {
  CacheTx::check(ram);
  ram->dwrite(addr, wdata, awstrb);
  return true;
}
bool DCacheTxW::hit() { return this->whit; }
Tx::State Tx::state() { return state_; };
void CacheTx::watch(Ram *ram) {}
void DCacheTxR::watch(Ram *ram) {
  values.insert(ram->dread(addr, false));
  values.insert(ram->dread(addr, true));
}
void ICacheTxR::watch(Ram *ram) {
  auto a = ram->iread(araddr, false);
  auto b = ram->iread(araddr, true);
  u32 addr = araddr / 16 * 16;
  r_t c = {};
  for (auto i = 0; i < 4; i++) {
    c[i] = ram->dread(addr + 4 * i, false);
  }
  values.insert(a);
  values.insert(b);
  values.insert(c);
}
ICacheTxRH::ICacheTxRH(u32 addr) : ICacheTxR(addr) {}
bool ICacheTxRH::check(Ram *ram) {
  ICacheTxR::check(ram);
  if (!hit()) {
    printf("ICache Read: %08x should hit but not.\n", araddr);
    return false;
  }
  return true;
}
