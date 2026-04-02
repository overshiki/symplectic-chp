# Symplectic-CHP

A Haskell implementation of the CHP clifford simulator, **through the lens of symplectic geometry** with **type-safe, fixed-length vectors**.

## Overview

This package interprets Aaronson & Gottesman's CHP algorithm through the lens of **symplectic linear algebra over 𝔽₂**, revealing the underlying geometric structure that makes the algorithm work. Rather than treating the tableau as an opaque data structure, we expose it as a **Lagrangian subspace** of a symplectic vector space, with Clifford gates acting as **Sp(2n, 𝔽₂)** transformations.

For more details about the theory, please refer to [theory](https://overshiki.github.io/symplectic-blog-intuitive/)

## Features

### Type-Safe Tableau Representation

The `Tableau n` type uses **dependent types** (via `vector-sized`) to encode the 2n-row invariant at the type level:

```haskell
data Tableau (n :: Nat) = Tableau
  { stabilizers   :: !(Vector n Pauli)    -- S₀..Sₙ₋₁
  , destabilizers :: !(Vector n Pauli)    -- D₀..Dₙ₋₁
  }
```

**Benefits:**
- **Compile-time guarantees**: The type system ensures `stabilizers` and `destabilizers` always have exactly `n` elements
- **No out-of-bounds access**: Indexing uses `Finite n` types, making invalid indices unrepresentable
- **Performance**: O(1) vector indexing instead of O(n) list traversal
- **Clarity**: Explicit separation of stabilizers and destabilizers eliminates `i < n` checks and `i + n` arithmetic

### Runtime Flexibility with Existentials

For scenarios requiring runtime-determined qubit counts:

```haskell
data SomeTableau where
  SomeTableau :: KnownNat n => Tableau n -> SomeTableau

emptyTableauN :: Int -> SomeTableau  -- Create from runtime value
```

This provides type safety where possible (static circuits) while preserving flexibility where needed (dynamic simulations). 

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
├── Tableau       -- Lagrangian subspaces with type-safe symplectic bases
├── Gates         -- Sp(2n,𝔽₂) matrix action
├── Measurement   -- Isotropic/anti-isotropic decomposition
└── Monad         -- Stateful evolution with existential types
```

### Methodology: Type-Driven Design

Our implementation follows **type-driven development** principles:

1. **Make illegal states unrepresentable**: The 2n-row invariant is encoded in the type (`Tableau n`), preventing malformed tableaus at compile time.

2. **Leverage dependent types**: Using `vector-sized` and `finite-typelits`, we obtain:
   - Length-indexed vectors: `Vector n a` guarantees exactly `n` elements
   - Bounded indices: `Finite n` ensures indices are always `0 ≤ i < n`

3. **Separate static and dynamic interfaces**:
   - **Static** (`Tableau n`): For known qubit counts, full type safety
   - **Dynamic** (`SomeTableau`): For runtime-determined counts, existential wrapper

### The `isValid` Invariant

Derived from the Symplectic Basis Theorem, our validity checker enforces three conditions that characterize a proper tableau:

```haskell
isValid :: KnownNat n => Tableau n -> Bool
isValid (Tableau stabs destabs) = 
  -- Isotropic: stabilizers mutually commute
  VS.and $ VS.imap (\i sᵢ ->
    VS.and $ VS.imap (\j sⱼ ->
      i == j || commute sᵢ sⱼ) stabs) stabs &&
  -- Dual pairing: ω(Dᵢ,Sⱼ)=δᵢⱼ
  VS.and $ VS.imap (\i dᵢ ->
    VS.and $ VS.imap (\j sⱼ ->
      if i == j then anticommute dᵢ sⱼ else commute dᵢ sⱼ) stabs) destabs &&
  -- Derived: destabilizers mutually commute
  VS.and $ VS.imap (\i dᵢ ->
    VS.and $ VS.imap (\j dⱼ ->
      i == j || commute dᵢ dⱼ) destabs) destabs
```

The third condition, while not explicit in the original CHP paper, follows necessarily from the symplectic structure and serves as our primary correctness invariant.

**Note**: The type `Tableau n` already guarantees the structural invariant (exactly `n` stabilizers and `n` destabilizers). The `isValid` function checks the *geometric* invariants (commutation relations) that the type system cannot enforce.

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
