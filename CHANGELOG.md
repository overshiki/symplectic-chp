# Revision history for symplectic-chp

## 0.1.0.0 -- 2026-04-06

### Major Features

* **Symplectic Geometry Foundation**: Complete implementation of CHP simulator through the lens of symplectic geometry, revealing that Aaronson & Gottesman's CHP algorithm is a computational realization of the Symplectic Basis Theorem.

* **Mathematical Hierarchy**: Type class hierarchy encoding the geometric structure:
  - `Group` → `SymplecticGroup` → `AbelianLagrangianCorrespondence`
  - `SymplecticVectorSpace` → `IsotropicSubSpace` → `LagrangianSubSpace` → `SymplecticBasisTheorem`

* **Type-Safe Tableau**: Compile-time guarantees via GADTs and type-level naturals:
  - Dimensional checking with `Vector n` and `Finite n`
  - O(1) indexing with bounds guarantees
  - Zero-cost abstractions (< 5% runtime overhead)

### STIM Circuit Support

* **Parser Integration**: Full STIM circuit file parsing via `stim-parser` library
* **Supported Gates**: H, S, CNOT, X, Y, Z, CZ, SWAP, SQRT_Z, S_DAG, XCZ, ZCX, ZCZ, H_XZ
* **Gate Decomposition**: Automatic decomposition of non-native gates:
  - X = H·S·S·H
  - Y = S·X·S³
  - Z = S·S
  - CZ = H(t)·CNOT(c,t)·H(t)
  - SWAP = CNOT(a,b)·CNOT(b,a)·CNOT(a,b)
* **Measurements**: Z-basis (M/MZ), X-basis (MX), Y-basis (MY)
* **Multi-target Gates**: Support for `H 0 1 2`, `CNOT 0 1 2 3` syntax
* **Command-line Tool**: `symplectic-chp` executable with options:
  - `--seed N` for reproducible measurements
  - `--no-tableau` to hide tableau output
  - `-v` for verbose mode

### Bug Fixes

* **S Gate Phase Fix**: Corrected phase update in S gate to properly handle Y→-X transformation (was adding 0 phase, should add +1)
* **Phase Convention**: Stabilizer phases now correctly reflect canonical form (-Z instead of +iZ)

### Test Suite

* **68 Total Tests**:
  - 58 Haskell unit tests (symplectic properties, gate composition, measurement correctness)
  - 10 STIM circuit integration tests
* **Test Circuits**: bell-state, ghz-state, single-hadamard, stabilizer-cycle, cz-gate, swap-gate, multi-target, y-measurement, phase-gate, unsupported-rx
* **Mathematical Derivations**: Each test circuit includes `.derive.md` with step-by-step tableau evolution

### Documentation

* **Implementation Guide** (`doc/implement.md`): Complete mathematical hierarchy documentation
* **STIM Parser Implementation** (`doc/stim-parse-impl.md`): Real implementation documentation
* **Performance Analysis** (`doc/overhead.md`): Abstraction cost analysis
* **Theory Blog** (`doc/symplectic-blog-intuitive.md`): Intuitive explanation of symplectic geometry

### Formal Verification

* **Agda Formalization**: All test expectations derived from [symplectic-pauli](https://github.com/overshiki/symplectic-pauli) Agda proofs
* Machine-checked proofs of:
  - Symplectic Basis Theorem
  - Fundamental Correspondence (Pauli commutation ⟺ symplectic form)
  - All 10 circuit examples verified in Agda

---

## Pre-release History

### 2026-03 - Initial Development

* Core CHP simulator implementation with symplectic geometry foundation
* Type-safe vector implementation using `vector-sized`
* Basic gate support: H, S, CNOT
* Tableau operations: evolution, measurement

### 2026-03 - Mathematical Abstraction

* Refactored to use geometric hierarchy (Group, SymplecticGroup, etc.)
* Added `Clifford` monad for circuit composition
* Property-based testing with QuickCheck

### 2026-04 - STIM Integration

* Added STIM circuit file support
* Gate decomposition for X, Y, Z, CZ, SWAP
* Multi-target gate syntax
* Comprehensive test suite with derivations
* Bug fix for S gate phase calculation
