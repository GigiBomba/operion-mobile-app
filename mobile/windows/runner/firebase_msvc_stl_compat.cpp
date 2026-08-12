// MSVC STL vectorization-helper ABI shim for the prebuilt Firebase C++ SDK.
//
// WHY THIS FILE EXISTS
// --------------------
// The prebuilt `firebase_app.lib` shipped by the firebase_cpp_sdk
// (downloaded by the firebase_core Windows plugin) is compiled with an older
// MSVC STL that still exported its internal <algorithm>/<string>
// vectorization helpers:
//
//   __std_find_last_trivial_1        (backing std::_Find_last_vectorized)
//   __std_find_first_of_trivial_1    (backing std::_Find_first_of_vectorized)
//   __std_remove_8                   (backing std::_Remove_vectorized)
//   __std_find_last_of_trivial_pos_1 (backing std::_Find_last_of_pos_vectorized)
//
// MSVC 17.14 removed these helpers from the STL (they are no longer declared
// in any current STL header), so linking that prebuilt lib against the current
// toolchain fails with:
//
//   LNK2019: unresolved external symbol __std_find_last_trivial_1
//   (plus __std_find_first_of_trivial_1 / __std_remove_8 /
//    __std_find_last_of_trivial_pos_1) referenced in firebase_app.lib(...)
//
// These symbols are ONLY referenced by the prebuilt .obj files — no current
// STL header emits them — so all the linker needs is a definition with the
// exact symbol names and the ABI the prebuilt caller uses. Each function below
// implements the scalar (non-vectorized) fallback of the algorithm it backs,
// which is behaviourally equivalent. All are `extern "C"`; on x64 there is a
// single calling convention so the exact `__cdecl`/`__stdcall` decoration the
// old STL used is irrelevant to symbol resolution.

#include <cstddef>
#include <cstring>

extern "C" {

// std::find_last: returns a pointer to the LAST element equal to _Val in
// [_First, _Last), or _Last when there is no match.
__declspec(noinline) const char* __std_find_last_trivial_1(
    const char* const _First,
    const char* const _Last,
    const char _Val) noexcept {
    for (const char* p = _Last; p != _First;) {
        --p;
        if (*p == _Val) {
            return p;
        }
    }
    return _Last;
}

// std::find_first_of: returns a pointer to the FIRST element in
// [_First, _Last) equal to any element of [_PFirst, _PLast), or _Last.
__declspec(noinline) const char* __std_find_first_of_trivial_1(
    const char* const _First,
    const char* const _Last,
    const char* const _PFirst,
    const char* const _PLast) noexcept {
    for (const char* p = _First; p != _Last; ++p) {
        for (const char* q = _PFirst; q != _PLast; ++q) {
            if (*p == *q) {
                return p;
            }
        }
    }
    return _Last;
}

// std::remove over 8-byte elements (e.g. pointers): removes every element
// whose 8 bytes are equal to the value at *_Val and returns the new logical
// end of the range.
__declspec(noinline) void* __std_remove_8(
    void* const _First,
    void* const _Last,
    void* const _Val) noexcept {
    auto* first = static_cast<unsigned char*>(_First);
    const auto* const last = static_cast<const unsigned char*>(_Last);
    const auto* const val = static_cast<const unsigned char*>(_Val);
    unsigned char* result = first;
    while (first != last) {
        if (std::memcmp(first, val, 8) != 0) {
            if (result != first) {
                std::memcpy(result, first, 8);
            }
            result += 8;
        }
        first += 8;
    }
    return result;
}

// std::basic_string::find_last_of position helper: returns the index (relative
// to _First) of the LAST element among the first _Count elements that equals
// any of the first _PCount elements of _PFirst, or npos when there is no match.
__declspec(noinline) std::size_t __std_find_last_of_trivial_pos_1(
    const char* const _First,
    const std::size_t _Count,
    const char* const _PFirst,
    const std::size_t _PCount) noexcept {
    if (_Count == 0 || _PCount == 0) {
        return static_cast<std::size_t>(-1);
    }
    for (std::size_t i = _Count; i > 0; --i) {
        const char c = _First[i - 1];
        for (std::size_t j = 0; j < _PCount; ++j) {
            if (c == _PFirst[j]) {
                return i - 1;
            }
        }
    }
    return static_cast<std::size_t>(-1);
}

} // extern "C"
