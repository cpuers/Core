#ifndef CACHE_HPP
#define CACHE_HPP

#include <common.hpp>
#include <array>
#include <unordered_set>

using ir_t = std::array<u32, 4>;
using dw_t = u32;
using dr_t = u32;
template <typename T>
using set = std::unordered_set<T>;

namespace std {
    template <typename T, size_t N>
    struct hash<array<T, N>> {
        size_t operator()(const array<T, N> &v) const {
            size_t seed = 0;
            for (const auto& e: v) {
                seed ^= hash<T>{}(e) + 0x9e3779b9U + (seed << 6) + (seed >> 2);
            }
            return seed;
        }
    };
}

#endif
