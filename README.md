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

### Minimal Overhead, Maximum Safety

This mathematical rigor comes with **< 5% runtime overhead**. GHC's optimizer eliminates abstraction costs through inlining, while `Vector`-based storage improves cache locality over traditional lists.

Type-level naturals (`Vector n`, `Finite n`) give us:
- Compile-time dimensional checking
- O(1) indexing with bounds guarantees
- No out-of-bounds errors at runtime

## Quick Start

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

## Learn More

- **[Theory Blog](https://overshiki.github.io/symplectic-blog-intuitive/)** — Why the Pauli group is symplectic
- **[Implementation Guide](doc/implement.md)** — The complete mathematical hierarchy
- **[Performance Analysis](doc/overhead.md)** — Why the abstractions are free

## Testing

```bash
cabal test
```

All 58 tests pass, verifying symplectic form properties, tableau validity, gate composition, and measurement correctness.

## References

- Aaronson & Gottesman, "Improved Simulation of Stabilizer Circuits," *Phys. Rev. A* 70, 052328 (2004)
- Artin, *Geometric Algebra* (symplectic groups)
- Gosson, *Symplectic Geometry and Quantum Mechanics*

## License

MIT License
