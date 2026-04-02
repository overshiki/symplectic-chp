# Symplectic-CHP

A Haskell implementation of the CHP clifford simulator, **through the lens of symplectic geometry** with **type-safe, fixed-length vectors** and **higher-order mathematical abstractions**.

## Overview

This package interprets Aaronson & Gottesman's CHP algorithm through the lens of **symplectic linear algebra over 𝔽₂**, revealing that the CHP simulator is not merely an algorithm but a **computational realization of the Symplectic Basis Theorem**. Rather than treating the tableau as an opaque data structure, we expose it as a **symplectic basis**—a pair of transverse Lagrangian subspaces satisfying the duality condition ω(Dᵢ, Sⱼ) = δᵢⱼ.

Our implementation achieves an exceptional level of mathematical abstraction through **type classes** that mirror the actual geometric hierarchy:

```
Group g
  ↑
  └─ BinaryCommutationGroup g          -- "commute or anticommute" property
        ↑
        └─ SymplecticGroup g v         -- group + symplectic structure
              ↑
              ├─ Pauli (concrete)
              │
              └─ AbelianLagrangianCorrespondence g n v
                    ↑
                    ├─ IsotropicSubgroup g n  ⟷  Lagrangian n v
                    ↑
                    └─ MaximalAbelianCorrespondence g n v
                          ↑
                          └─ Maximal abelian  ⟷  Lagrangian

SymplecticVectorSpace v
  ↑
  └─ IsotropicSubSpace s n v
        ↑
        └─ LagrangianSubSpace s n v    -- maximal isotropic
              ↑
              └─ SymplecticBasisTheorem s n v  -- THE SYMPLECTIC BASIS THEOREM!
                    ↑
                    └─ Tableau n v     -- CHP implementation
```

**The key insight**: The `Tableau` type is an instance of `SymplecticBasisTheorem`, meaning it satisfies the three conditions from the theorem:
1. Stabilizers are isotropic: ω(Sᵢ, Sⱼ) = 0
2. Destabilizers are isotropic: ω(Dᵢ, Dⱼ) = 0  
3. Duality: ω(Dᵢ, Sⱼ) = δᵢⱼ

For the complete theoretical treatment and implementation details, see:
- **[Theory Blog](https://overshiki.github.io/symplectic-blog-intuitive/)** — Mathematical foundations
- **[Implementation Guide](doc/implement.md)** — Comprehensive technical documentation

## Features

### Mathematical Abstraction via Type Classes

Our implementation captures the **intrinsic geometric hierarchy** of symplectic geometry:

```haskell
-- | A symplectic vector space (V, ω) over a field k
-- 
-- Mathematically, this consists of:
-- 1. A vector space V over a field k
-- 2. A symplectic form ω: V × V → k that is:
--    - Bilinear
--    - Alternating: ω(v, v) = 0 for all v
--    - Non-degenerate: if ω(v, w) = 0 for all w, then v = 0
class Eq (Field v) => SymplecticVectorSpace v where
  type Field v :: Type
  fieldZero    :: proxy v -> Field v  -- Zero element of field
  omega        :: v -> v -> Field v   -- The symplectic form ω
  addV         :: v -> v -> v         -- Vector addition
  zeroV        :: v                   -- Zero vector
  negateV      :: v -> v              -- Additive inverse

-- Note: "Commute" is NOT part of this abstraction!
-- It is specific to the Pauli group where ω = 0 means "commute"
```

The key insight is that `SymplecticVectorSpace` captures the **pure mathematical structure** without physical interpretation. The type class has exactly the operations needed:
- `omega` — the symplectic form ω(v₁, v₂)
- `addV`, `zeroV`, `negateV` — vector space operations
- `fieldZero` — zero element of the field (needed for isotropy checks)

The **higher-level classes** build on this foundation:

```haskell
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
  
  -- | Zero element of F_2
  fieldZero _ = False
  
  -- | Symplectic inner product ω: Pauli × Pauli → F_2
  -- ω(P₁, P₂) = x₁·z₂ + z₁·x₂ (mod 2)
  omega (Pauli x1 z1 _) (Pauli x2 z2 _) = 
    odd (popCount ((x1 .&. z2) `xor` (z1 .&. x2)))
  
  -- | Pauli group multiplication is vector addition in (F_2)^(2n)
  addV = multiplyPauli
  
  -- | Identity element (zero vector)
  zeroV = Pauli 0 0 0
  
  -- | Inverse (negation)
  negateV (Pauli x z r) = Pauli x z ((4 - r) `mod` 4)
```

**Physical interpretation (separate from the abstraction):**

The symplectic form ω on Pauli operators has a physical interpretation:
- `ω(P₁, P₂) = 0` ⟺ P₁ and P₂ **commute**
- `ω(P₁, P₂) = 1` ⟺ P₁ and P₂ **anticommute**

But these are **derived concepts**, not part of the `SymplecticVectorSpace` class:

```haskell
-- | For Pauli specifically: commute iff ω = 0
commuteV :: (SymplecticVectorSpace v, Field v ~ Bool) => v -> v -> Bool
commuteV v1 v2 = not (omega v1 v2)

-- | For Pauli specifically: anticommute iff ω = 1  
anticommuteV :: (SymplecticVectorSpace v, Field v ~ Bool) => v -> v -> Bool
anticommuteV v1 v2 = omega v1 v2
```

The **symplectic inner product** captures commutation:

```
ω(P₁, P₂) = x₁·z₂ + z₁·x₂  (mod 2)

ω = 0 ⟺ [P₁, P₂] = 0  (commute)
ω = 1 ⟺ {P₁, P₂} = 0  (anti-commute)
```

### The Symplectic Basis Theorem

**Theorem**: Let $(V, \omega)$ be a symplectic vector space of dimension $2n$. Then there exists a basis $\{e_1, \ldots, e_n, f_1, \ldots, f_n\}$ such that:
- $\omega(e_i, e_j) = 0$ (the $e$'s span a Lagrangian)
- $\omega(f_i, f_j) = 0$ (the $f$'s span a Lagrangian)  
- $\omega(e_i, f_j) = \delta_{ij}$ (**duality**)

**The CHP Tableau IS a Symplectic Basis:**

In our implementation, the `Tableau` type **is** a symplectic basis:
- **Stabilizers** S₀,...,Sₙ₋₁ = {e₁,...,eₙ} (first Lagrangian)
- **Destabilizers** D₀,...,Dₙ₋₁ = {f₁,...,fₙ} (second Lagrangian)
- **Duality condition**: ω(Dᵢ, Sⱼ) = δᵢⱼ

This is encoded in the `SymplecticBasisTheorem` type class:

```haskell
class SymplecticBasisTheorem s n v where
  firstLagrangian  :: s n v -> Lagrangian n v   -- e₁,...,eₙ (stabilizers)
  secondLagrangian :: s n v -> Lagrangian n v   -- f₁,...,fₙ (destabilizers)
  verifyDuality    :: s n v -> Bool             -- ω(eᵢ,fⱼ) = δᵢⱼ

instance SymplecticBasisTheorem Tableau n v where
  firstLagrangian  = stabLagrangian
  secondLagrangian = destabLagrangian
  verifyDuality    = -- checks ω(Dᵢ,Sⱼ) = δᵢⱼ
```

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

For a comprehensive technical treatment of the implementation, see **[Implementation Guide](doc/implement.md)** — which covers the complete mathematical hierarchy, the connection between group theory and symplectic geometry, and how the Symplectic Basis Theorem gives rise to the CHP tableau structure.

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
