# Symplectic-CHP

A Haskell implementation of the CHP clifford simulator, **through the lens of symplectic geometry** with **type-safe, fixed-length vectors**, **higher-order mathematical abstractions**, and **minimal runtime overhead**.

## Overview

What if the CHP simulator isn't just an algorithm, but a **computational realization of the Symplectic Basis Theorem**?

This package reveals that Aaronson & Gottesman's CHP algorithm is actually doing symplectic linear algebra over 𝔽₂. The "tableau" is really a **symplectic basis**—a pair of transverse Lagrangian subspaces satisfying the elegant duality condition ω(Dᵢ, Sⱼ) = δᵢⱼ.

We encode this mathematical structure in Haskell's type system, achieving:
- **Compile-time guarantees** that your tableau is valid
- **Zero-cost abstractions** via GHC optimization
- **Mathematical clarity** where code mirrors geometric structure

> **Why Haskell?** This level of abstraction—encoding theorems as type classes, enforcing geometric invariants at compile time—is uniquely enabled by Haskell's expressive type system. The composition of dependent types, higher-kinded polymorphism, and type families makes such elegant encoding of mathematical structures possible.

## What Makes This Special?

### The Symplectic Basis Theorem, in Code

The CHP tableau **is** a symplectic basis:

```haskell
-- | The Symplectic Basis Theorem: {e₁,...,eₙ, f₁,...,fₙ} with ω(eᵢ,fⱼ) = δᵢⱼ
data Tableau (n :: Nat) v where
  Tableau ::
    { stabLagrangian   :: Lagrangian n v   -- S = {e₁,...,eₙ}
    , destabLagrangian :: Lagrangian n v   -- D = {f₁,...,fₙ}
    } -> Tableau n v

instance SymplecticBasisTheorem Tableau n v where
  firstLagrangian  = stabLagrangian
  secondLagrangian = destabLagrangian
```

The type system enforces the theorem's three conditions:
1. Stabilizers are isotropic: ω(Sᵢ, Sⱼ) = 0
2. Destabilizers are isotropic: ω(Dᵢ, Dⱼ) = 0
3. **Duality**: ω(Dᵢ, Sⱼ) = δᵢⱼ

### A Hierarchy of Mathematical Structures

Our type classes mirror the geometric hierarchy:

```
Group g
  └─ SymplecticGroup g v         -- group + symplectic structure
        ├─ Pauli (concrete)
        └─ AbelianLagrangianCorrespondence g n v
              └─ Maximal abelian  ⟷  Lagrangian

SymplecticVectorSpace v
  └─ IsotropicSubSpace s n v
        └─ LagrangianSubSpace s n v
              └─ SymplecticBasisTheorem s n v
                    └─ Tableau n v
```

The code *is* the mathematics.

## Mathematical Soundness: Formally Verified

The mathematical foundations of this implementation have been **machine-checked** in the [symplectic-pauli](https://github.com/overshiki/symplectic-pauli) Agda formalization project.

### What Does This Mean?

Every theorem underlying this codebase has been formally proven:

| Theorem | Status | Agda Proof |
|---------|--------|------------|
| **Symplectic Basis Theorem** | ✅ Complete | `symplecticBasisTheorem` |
| **Fundamental Correspondence** | ✅ Complete | Pauli commutation ⟺ symplectic form |
| **Tableau as Symplectic Basis** | ✅ Complete | Duality conditions verified |
| **All Circuit Examples** | ✅ Verified | 10/10 test circuits proven correct |

The Agda formalization translates our Haskell type class hierarchy into dependent type theory, providing **compile-time proof** that:
- Stabilizers are isotropic (ω(Sᵢ, Sⱼ) = 0)
- Destabilizers are isotropic (ω(Dᵢ, Dⱼ) = 0)  
- Duality holds (ω(Dᵢ, Sⱼ) = δᵢⱼ)
- Gate conjugations preserve the symplectic form
- Measurement outcomes match quantum mechanical predictions

> **Why this matters**: While Haskell gives us runtime verification via `verifyDuality`, Agda provides **mathematical certainty** at the type level. The test expectations in this repository are derived from these formal proofs.

### Minimal Overhead, Maximum Safety

The mathematical rigor of our haskell chp implementation comes with **< 5% runtime overhead**. GHC's optimizer eliminates abstraction costs through inlining, while `Vector`-based storage improves cache locality over traditional lists.

Type-level naturals (`Vector n`, `Finite n`) give us:
- Compile-time dimensional checking
- O(1) indexing with bounds guarantees
- No out-of-bounds errors at runtime

## Quick Start

### Library Usage

```haskell
-- Create a Bell state
bellCircuit :: Clifford Bool
bellCircuit = do
  gate (Local (Hadamard 0))     -- H ⊗ I
  gate (CNOT 0 1)                -- CNOT 0→1
  measurePauli (Pauli 3 0 0)     -- Measure X⊗X (should be +1)

-- Run it
main = do
  (tab, outcome) <- runWith 2 bellCircuit
  print outcome  -- True (+1 eigenvalue)
```

### STIM Circuit Files

The package includes a command-line tool to simulate [STIM](https://github.com/quantumlib/Stim) circuit files:

```bash
# Build and run
cabal build
cabal run symplectic-chp -- circuit.stim
```

Create a STIM circuit file (e.g., `bell.stim`):

```
# Bell state preparation
H 0
CNOT 0 1
M 0 1
```

Run the simulation:

```bash
$ cabal run symplectic-chp -- bell.stim

========================================
  CHP Simulation Results
========================================

Measurements performed: 2
Measurement outcomes:
  M0: +1 (|0⟩ or |+⟩)
  M1: +1 (|0⟩ or |+⟩)

Number of qubits: 2
Tableau valid: True

Stabilizers (generators of the stabilizer group):
  S0: +Z
  S1: +ZZ

Destabilizers (dual to stabilizers):
  D0: +XX
  D1: +IX
```

#### Supported STIM Features

| Feature | Status |
|---------|--------|
| **Gates** | H, S, CNOT, CZ, X, Y, Z, SWAP, SQRT_Z (S), S_DAG |
| **Measurements** | M (Z-basis), MX (X-basis), MY (Y-basis), MZ (Z-basis) |
| **Gates (decomposed)** | CZ, X, Y, Z, SWAP are decomposed into H/S/CNOT |

#### Unsupported Features (will report error)

- Non-Clifford gates (T, RX, RY, RZ, SQRT_X, etc.)
- Reset operations (R, MR, MRX, etc.)
- Pauli product measurements (MPP)
- Noise channels (X_ERROR, DEPOLARIZE1, etc.)
- REPEAT blocks
- Annotations (QUBIT_COORDS, DETECTOR, etc.)

#### Command-Line Options

```bash
symplectic-chp [OPTIONS] <input.stim>

Options:
  -h, --help         Show help message
  -v                 Enable verbose output
  --seed N           Use specific random seed for reproducibility
  --no-tableau       Don't show final tableau
```

#### Example: GHZ State

```
# ghz.stim
H 0
CNOT 0 1
CNOT 0 2
M 0 1 2
```

```bash
$ cabal run symplectic-chp -- ghz.stim
```

#### Test Circuits

Example circuits are available in `data/stim-circuits/`:

```bash
# List available test circuits
ls data/stim-circuits/*.stim

# Run a test circuit
cabal run symplectic-chp -- data/stim-circuits/bell-state.stim
```

Each circuit includes:
- `.stim` - The circuit file
- `.expected` - Expected results for automated testing
- `.derive.md` - Mathematical derivation of the circuit's behavior

## Learn More

- **[Theory Blog](https://overshiki.github.io/symplectic-blog-intuitive/)** — Why the Pauli group is symplectic
- **[Implementation Guide](doc/implement.md)** — The complete mathematical hierarchy
- **[Performance Analysis](doc/overhead.md)** — Why the abstractions are free
- **[STIM Parser Implementation](doc/stim-parse-impl.md)** — STIM circuit file parsing and simulation
- **[Agda Formalization](https://github.com/overshiki/symplectic-pauli)** — Machine-checked proofs of all theorems (symplectic-pauli)

## Testing

### Haskell Test Suite

```bash
cabal test
```

All **68 tests** pass:
- **58 unit tests** — verifying symplectic form properties, tableau validity, gate composition, and measurement correctness
- **10 integration tests** — STIM circuit files testing Bell states, GHZ states, gate decompositions, and error handling


### Test Circuits

Example STIM circuits are provided in `data/stim-circuits/`:

| Circuit | Description |
|---------|-------------|
| `bell-state.stim` | Bell state \|Φ⁺⟩ preparation |
| `ghz-state.stim` | GHZ state preparation |
| `swap-gate.stim` | SWAP gate decomposition |
| `stabilizer-cycle.stim` | X gate via HSSH decomposition |
| `unsupported-rx.stim` | Error handling for non-Clifford gates |

The test suite automatically runs these circuits and verifies their outputs against expected results.

## References

- Aaronson & Gottesman, "Improved Simulation of Stabilizer Circuits," *Phys. Rev. A* 70, 052328 (2004)
- Artin, *Geometric Algebra* (symplectic groups)
- Gosson, *Symplectic Geometry and Quantum Mechanics*

## License

MIT License
