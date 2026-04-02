# Symplectic-CHP

A Haskell implementation of the CHP clifford simulator, **through the lens of symplectic geometry** with **type-safe, fixed-length vectors** and **higher-order mathematical abstractions**.

## Overview

This package interprets Aaronson & Gottesman's CHP algorithm through the lens of **symplectic linear algebra over 𝔽₂**, revealing the underlying geometric structure that makes the algorithm work. Rather than treating the tableau as an opaque data structure, we expose it as a **Lagrangian subspace** of a symplectic vector space, with Clifford gates acting as **Sp(2n, 𝔽₂)** transformations.

Our implementation achieves an exceptional level of mathematical abstraction through **type classes** that mirror the actual geometric hierarchy:

```
SymplecticVectorSpace v          -- The ambient space (e.g., Pauli over F_2)
    ↑
    └─ LagrangianSubSpace n v    -- Maximal isotropic subspaces
        ↑
        └─ SymplecticBasis s n v -- Two transverse Lagrangians (Tableau)
```

For more details about the theory, please refer to [theory](https://overshiki.github.io/symplectic-blog-intuitive/)

## Features

### Mathematical Abstraction via Type Classes

Our implementation captures the **intrinsic geometric hierarchy** of symplectic geometry:

```haskell
-- | A symplectic vector space over a field k
class Eq (Field v) => SymplecticVectorSpace v where
  type Field v :: Type
  omega        :: v -> v -> Field v   -- The symplectic form ω
  addV         :: v -> v -> v         -- Vector addition
  zeroV        :: v                   -- Zero vector
  commuteV     :: v -> v -> Bool      -- ω(v₁,v₂) = 0

-- | Isotropic subspace: ω vanishes on all pairs
class SymplecticVectorSpace v => IsotropicSubSpace s n v where
  toBasis       :: s n v -> Vector n v
  verifyIsotropy :: s n v -> Bool     -- Check ω(vᵢ,vⱼ) = 0

-- | Lagrangian subspace: maximal isotropic (dim = n in 2n-dim space)
class IsotropicSubSpace Lagrangian n v => LagrangianSubSpace n v

-- | Symplectic basis: two transverse Lagrangians with duality
class SymplecticBasis s n v where
  getStabLagrangian   :: s n v -> Lagrangian n v   -- Stabilizers S
  getDestabLagrangian :: s n v -> Lagrangian n v   -- Destabilizers D
  verifyDuality       :: s n v -> Bool             -- ω(Dᵢ,Sⱼ) = δᵢⱼ
```

**Benefits of this abstraction:**

1. **Mathematical Fidelity**: Code structure mirrors geometric structure
2. **Generic Programming**: Algorithms work over *any* symplectic vector space
3. **Extensibility**: Easy to add new symplectic spaces (e.g., qudit Paulis)
4. **Type Safety**: The type system enforces mathematical invariants

### Type-Safe Tableau Representation

The `Tableau n v` type uses **dependent types** and **GADTs** to encode the geometric structure:

```haskell
-- | Lagrangian subspace: n basis vectors in V
newtype Lagrangian (n :: Nat) v = Lagrangian
  { lagrangianBasis :: Vector n v }

-- | Tableau as a symplectic basis: two transverse Lagrangians
data Tableau (n :: Nat) v where
  Tableau :: (SymplecticVectorSpace v, Field v ~ Bool) =>
    { stabLagrangian   :: Lagrangian n v   -- S₀..Sₙ₋₁
    , destabLagrangian :: Lagrangian n v   -- D₀..Dₙ₋₁
    } -> Tableau n v

instance SymplecticBasis Tableau n v where
  getStabLagrangian   = stabLagrangian
  getDestabLagrangian = destabLagrangian
```

**Type-level guarantees:**
- **Exactly `n` stabilizers and `n` destabilizers** (enforced by `Vector n`)
- **No out-of-bounds access** (`Finite n` indices)
- **Symplectic structure preserved** (type class constraints)

### Runtime Flexibility with Existentials

For scenarios requiring runtime-determined qubit counts:

```haskell
data SomeTableau where
  SomeTableau :: KnownNat n => Tableau n Pauli -> SomeTableau

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

**Type class instance:**

```haskell
instance SymplecticVectorSpace Pauli where
  type Field Pauli = Bool  -- F_2
  
  omega (Pauli x1 z1 _) (Pauli x2 z2 _) = 
    odd (popCount ((x1 .&. z2) `xor` (z1 .&. x2)))
  
  addV  = multiplyPauli    -- Group multiplication is vector addition
  zeroV = Pauli 0 0 0      -- Identity
```

The **symplectic inner product** captures commutation:

```
ω(P₁, P₂) = x₁·z₂ + z₁·x₂  (mod 2)

ω = 0 ⟺ [P₁, P₂] = 0  (commute)
ω = 1 ⟺ {P₁, P₂} = 0  (anti-commute)
```

### Symplectic Basis Theorem

A stabilizer state is a **maximal isotropic subspace**: an n-dimensional subspace where ω vanishes identically. The CHP tableau encodes such a subspace via a **symplectic basis**:

- **Stabilizers** S₀,...,Sₙ₋₁: isotropic generators (ω(Sᵢ,Sⱼ)=0)
- **Destabilizers** D₀,...,Dₙ₋₁: dual basis with ω(Dᵢ,Sⱼ)=δᵢⱼ

**Implementation:**

```haskell
-- | Verify the symplectic basis conditions
verifyDuality :: SymplecticBasis s n v => s n v -> Bool
verifyDuality s =
  let d  = getDestabLagrangian s
      st = getStabLagrangian s
  in VS.and $ VS.imap (\i dᵢ ->
       VS.and $ VS.imap (\j sⱼ ->
         if i == j 
         then anticommuteV dᵢ sⱼ  -- ω(Dᵢ,Sᵢ) = 1
         else commuteV dᵢ sⱼ      -- ω(Dᵢ,Sⱼ) = 0 (i≠j)
       ) (lagrangianBasis st)
     ) (lagrangianBasis d)
```

### Clifford = Symplectic

Every Clifford gate induces a symplectic transformation on (𝔽₂)^(2n):

| Gate | Action on (x\|z) | Matrix in Sp(2n,𝔽₂) |
|------|-----------------|---------------------|
| Hᵢ | swaps xᵢ ↔ zᵢ | off-diagonal swap |
| Sᵢ | (xᵢ,zᵢ) ↦ (xᵢ,xᵢ+zᵢ) | shear transformation |
| CNOT c→t | xₜ += x_c, z_c += z_t | controlled-shear |

**Key insight**: The CHP algorithm's update rules are simply the matrix-vector product in this symplectic representation. Since symplectic transformations preserve the symplectic form, they map symplectic bases to symplectic bases:

```haskell
evolveTableau :: KnownNat n => Tableau n Pauli -> SymplecticGate -> Tableau n Pauli
evolveTableau (Tableau s d) g = 
  Tableau (mapLagrangian (applyGate g) s) 
          (mapLagrangian (applyGate g) d)
```

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
├── SymplecticVectorSpace  -- Type class for (V, ω)
├── IsotropicSubSpace      -- Type class for isotropic subspaces
├── LagrangianSubSpace     -- Type class for maximal isotropic
├── SymplecticBasis        -- Type class for (S, D) pairs
├── Lagrangian n v         -- Data type: Lagrangian subspace
├── Tableau n v            -- Data type: Symplectic basis instance
├── Gates                  -- Sp(2n,𝔽₂) transformations
├── Measurement            -- Isotropic/anti-isotropic decomposition
└── Monad                  -- Stateful evolution
```

### Methodology: Type-Driven Design

Our implementation follows **type-driven development** principles:

1. **Encode mathematical structure in types**: The hierarchy `SymplecticVectorSpace` → `IsotropicSubSpace` → `LagrangianSubSpace` → `SymplecticBasis` mirrors the geometric hierarchy.

2. **Make illegal states unrepresentable**: 
   - `Tableau n` ensures exactly `n` stabilizers and `n` destabilizers
   - `Finite n` indices prevent out-of-bounds access
   - Type class constraints ensure symplectic structure

3. **Separate concerns via type classes**:
   - **Geometric operations** (`omega`, `addV`) in `SymplecticVectorSpace`
   - **Subspace operations** (`toBasis`, `verifyIsotropy`) in `IsotropicSubSpace`
   - **Basis operations** (`verifyDuality`) in `SymplecticBasis`

4. **Generic algorithms**: Write functions that work over any `SymplecticVectorSpace`, enabling future extensions.

### The `isValid` Invariant

Derived from the Symplectic Basis Theorem, our validity checker enforces three conditions:

```haskell
isValid :: KnownNat n => Tableau n Pauli -> Bool
isValid tab = 
  let s = stabLagrangian tab
      d = destabLagrangian tab
      -- Isotropic: stabilizers mutually commute
      stabIsotropic = VS.all (\sᵢ -> 
        VS.all (\sⱼ -> commuteV sᵢ sⱼ) (lagrangianBasis s)) (lagrangianBasis s)
      -- Isotropic: destabilizers mutually commute  
      destIsotropic = VS.all (\dᵢ -> 
        VS.all (\dⱼ -> commuteV dᵢ dⱼ) (lagrangianBasis d)) (lagrangianBasis d)
      -- Dual pairing: ω(Dᵢ,Sⱼ)=δᵢⱼ
      dualPairing = verifyDuality tab
  in stabIsotropic && destIsotropic && dualPairing
```

**Note**: The type `Tableau n v` guarantees structural invariants (exactly `n` vectors in each Lagrangian). The `isValid` function checks the *geometric* invariants (commutation relations) that the type system cannot enforce.

## Testing

We verify the symplectic abstraction through property-based tests:

| Test Category | Property Verified |
|---------------|-----------------|
| **Symplectic form** | ω is bilinear, alternating, preserved under Clifford action |
| **Tableau validity** | Lagrangian structure preserved by all gates |
| **Gate composition** | Sp(2n,𝔽₂) multiplication matches circuit composition |
| **Measurement** | Random outcomes update isotropic subspace correctly; determinate outcomes match phase formula |
| **Row operations** | List-based `(//)` matches Vector semantics |

To test, run:
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
