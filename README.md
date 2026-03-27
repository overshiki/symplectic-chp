# Symplectic-CHP

A Haskell implementation of the CHP clifford simulator, **reconstructed through symplectic geometry**.

## Overview

This package interprets Aaronson & Gottesman's CHP algorithm through the lens of **symplectic linear algebra over 𝔽₂**, revealing the underlying geometric structure that makes the algorithm work. Rather than treating the tableau as an opaque data structure, we expose it as a **Lagrangian subspace** of a symplectic vector space, with Clifford gates acting as **Sp(2n, 𝔽₂)** transformations.

For more details about the theory, please refer to [theory](doc/symplectic-blog.md) 

## Symplectic Framework

### Pauli Group as Symplectic Vector Space

The n-qubit Pauli group forms a vector space (𝔽₂)^(2n) equipped with a canonical symplectic form. Each Pauli operator P = iʳ Xˣ Zᶻ corresponds to a vector (x|z):

| Component | Meaning |
|-----------|---------|
| x ∈ 𝔽₂ⁿ | X-support (bitmask) |
| z ∈ 𝔽₂ⁿ | Z-support (bitmask) |
| r ∈ ℤ₄ | Phase (overall) |

The **symplectic inner product** captures commutation:

```
ω(P₁, P₂) = x₁·z₂ + z₁·x₂  (mod 2)

ω = 0 ⟺ [P₁, P₂] = 0  (commute)
ω = 1 ⟺ {P₁, P₂} = 0  (anti-commute)
```

This ω is bilinear, alternating, and non-degenerate—the defining structure of symplectic geometry.

### Symplectic Basis Theorem

A stabilizer state is a **maximal isotropic subspace**: an n-dimensional subspace where ω vanishes identically. The CHP tableau encodes such a subspace via a **symplectic basis**:

- **Stabilizers** S₀,...,Sₙ₋₁: isotropic generators (ω(Sᵢ,Sⱼ)=0)
- **Destabilizers** D₀,...,Dₙ₋₁: dual basis with ω(Dᵢ,Sⱼ)=δᵢⱼ

This basis is unique up to symplectic transformation, providing the coordinate-free foundation for the algorithm.

### Clifford = Symplectic

Every Clifford gate induces a symplectic transformation on (𝔽₂)^(2n):

| Gate | Action on (x\|z) | Matrix in Sp(2n,𝔽₂) |
|------|-----------------|---------------------|
| Hᵢ | swaps xᵢ ↔ zᵢ | off-diagonal swap |
| Sᵢ | (xᵢ,zᵢ) ↦ (xᵢ,xᵢ+zᵢ) | shear transformation |
| CNOT c→t | xₜ += x_c, z_c += z_t | controlled-shear |

**Key insight**: The CHP algorithm's update rules are simply the matrix-vector product in this symplectic representation.

### Measurement via Orthogonal Complement

Measuring Pauli P distinguishes two cases geometrically:

| Case | Geometric Condition | Algorithm |
|------|---------------------|-----------|
| **Determinate** | P ∈ S^⊥ (commutes with stabilizer subspace) | Decompose P in basis, read phase |
| **Random** | P ∉ S^⊥ (anti-commutes with some Sⱼ) | Update isotropic subspace via symplectic transvection |

The measurement outcome is determined by the **symplectic inner product structure**, not by quantum mechanical postulates alone.

## Implementation

### Core Abstractions

```
SymplecticCHP
├── Core          -- ω(·,·), Pauli group law, phase arithmetic
├── Tableau       -- Lagrangian subspaces with symplectic bases
├── Gates         -- Sp(2n,𝔽₂) matrix action
├── Measurement   -- Isotropic/anti-isotropic decomposition
└── Monad         -- Stateful evolution in Sp(2n,𝔽₂)
```

### The `isValid` Invariant

Derived from the Symplectic Basis Theorem, our validity checker enforces three conditions that characterize a proper tableau:

```haskell
isValid :: Tableau -> Bool
isValid (Tableau n rs) = 
  -- Isotropic: stabilizers mutually commute
  and [ω(Sᵢ,Sⱼ)=0 | i≠j] &&
  -- Dual pairing: ω(Dᵢ,Sⱼ)=δᵢⱼ
  and [ω(Dᵢ,Sᵢ)=1] && and [ω(Dᵢ,Sⱼ)=0 | i≠j] &&
  -- Derived: destabilizers mutually commute
  and [ω(Dᵢ,Dⱼ)=0 | i<j]
```

The third condition, while not explicit in the original CHP paper, follows necessarily from the symplectic structure and serves as our primary correctness invariant.

## Testing

We verify the symplectic abstraction through property-based tests:

| Test Category | Property Verified |
|---------------|-----------------|
| **Symplectic form** | ω is bilinear, alternating, preserved under Clifford action |
| **Tableau validity** | Lagrangian structure preserved by all gates |
| **Gate composition** | Sp(2n,𝔽₂) multiplication matches circuit composition |
| **Measurement** | Random outcomes update isotropic subspace correctly; determinate outcomes match phase formula |
| **Row operations** | List-based `(//)` matches Vector semantics |

to test, run
```bash
cabal test
```

All tests use QuickCheck to generate random symplectic transformations and verify algebraic identities.

## Example: Bell State

```haskell
bellCircuit :: Clifford Bool
bellCircuit = do
  -- H ⊗ I: symplectic shear on qubit 0
  gate (Local (Hadamard 0))
  -- CNOT: controlled-symplectic transformation
  gate (CNOT 0 1)
  -- Measure X⊗X: check if result is in isotropic subspace
  measurePauli (Pauli (bit 0 .|. bit 1) 0 0)
```

The resulting state has stabilizers XX and ZZ, forming a maximal isotropic subspace with ω(XX,ZZ)=0.

## References

- Aaronson & Gottesman, "Improved Simulation of Stabilizer Circuits," *Phys. Rev. A* 70, 052328 (2004)
- Artin, *Geometric Algebra* (symplectic groups)
- Gosson, *Symplectic Geometry and Quantum Mechanics*

## License

MIT License
