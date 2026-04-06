{-# LANGUAGE DataKinds #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE AllowAmbiguousTypes #-}

module SymplecticCHP where

import Data.Bits
import Data.Word
import Data.Proxy (Proxy(..))
import Data.Kind (Type)
import System.Random (randomRIO)
import Data.List (sortOn, groupBy)
import Data.Function (on)
import Data.Maybe (fromJust, isJust)

-- vector-sized imports
import qualified Data.Vector.Sized as VS
import Data.Vector.Sized (Vector)
import qualified GHC.TypeNats
import GHC.TypeNats (Nat, KnownNat, natVal)

-- For type-safe finite indices
import Data.Finite (Finite)
import qualified Data.Finite as Finite

-- ============================================================================
-- PART I: GROUP STRUCTURE
-- ============================================================================

-- | A group (G, ·, e, ⁻¹) 
-- 
-- Mathematically, a group consists of:
-- 1. A set G
-- 2. A binary operation ·: G × G → G (multiplication)
-- 3. An identity element e ∈ G
-- 4. Inverses: for all g ∈ G, exists g⁻¹ ∈ G such that g·g⁻¹ = e
--
-- Satisfying: associativity, identity, inverse laws
class Group g where
  -- | Group multiplication
  mulG :: g -> g -> g
  
  -- | Identity element
  identityG :: g
  
  -- | Inverse
  invG :: g -> g
  
  -- | Commutator [a,b] = a·b·a⁻¹·b⁻¹
  commutatorG :: g -> g -> g
  commutatorG a b = mulG (mulG (mulG a b) (invG a)) (invG b)

-- | A group where every pair of elements either commutes or anticommutes
-- 
-- This is a special property. For such groups, there exists a central
-- element z (of order 2) such that:
-- - Either [a,b] = e (commute)
-- - Or [a,b] = z (anticommute)
class Group g => BinaryCommutationGroup g where
  -- | The central element representing "anticommutation"
  -- For Pauli group, this is -I (phase 2)
  anticommutationMarker :: g
  
  -- | Check if two elements commute: [a,b] = e
  commuteG :: g -> g -> Bool
  
  -- | Check if two elements anticommute: [a,b] = z
  anticommuteG :: g -> g -> Bool
  anticommuteG a b = not (commuteG a b)

-- ============================================================================
-- PART II: SYMPLECTIC VECTOR SPACE STRUCTURE
-- ============================================================================

-- | A symplectic vector space (V, ω) over a field k.
-- 
-- Mathematically, a symplectic vector space consists of:
-- 1. A vector space V over a field k
-- 2. A symplectic form ω: V × V → k that is:
--    - Bilinear
--    - Alternating: ω(v, v) = 0 for all v
--    - Non-degenerate: if ω(v, w) = 0 for all w, then v = 0
--
-- Note: "Commute" and "anticommute" are NOT part of this abstraction.
-- They are specific to the Pauli group interpretation where:
-- - ω(v1, v2) = 0 is interpreted as "commute"
-- - ω(v1, v2) = 1 is interpreted as "anticommute"
class Eq (Field v) => SymplecticVectorSpace v where
  type Field v :: Type
  
  -- | The zero element of the field (needed for isotropy checks)
  fieldZero :: proxy v -> Field v
  
  -- | The symplectic form ω(v1, v2)
  -- This is a bilinear, alternating, non-degenerate form
  omega :: v -> v -> Field v
  
  -- | Vector addition (abelian group operation)
  addV :: v -> v -> v
  
  -- | Zero vector (identity for addV)
  zeroV :: v
  
  -- | Negation (additive inverse)
  negateV :: v -> v

-- | Check if a vector is isotropic: ω(v, v) = fieldZero
-- In a symplectic vector space, ALL vectors are isotropic (alternating property)
isIsotropicElement :: (SymplecticVectorSpace v, Eq (Field v)) => proxy v -> v -> Bool
isIsotropicElement p v = omega v v == fieldZero p

-- | Check if two vectors are symplectically orthogonal: ω(v1, v2) = fieldZero
symplecticOrthogonal :: (SymplecticVectorSpace v, Eq (Field v)) => proxy v -> v -> v -> Bool
symplecticOrthogonal p v1 v2 = omega v1 v2 == fieldZero p

-- | For Pauli group specifically: two operators commute iff ω = 0
-- This is an interpretation specific to F_2
commuteV :: (SymplecticVectorSpace v, Field v ~ Bool) => v -> v -> Bool
commuteV v1 v2 = not (omega v1 v2)

-- | For Pauli group specifically: two operators anticommute iff ω = 1
-- This is an interpretation specific to F_2
anticommuteV :: (SymplecticVectorSpace v, Field v ~ Bool) => v -> v -> Bool
anticommuteV v1 v2 = omega v1 v2

-- ============================================================================
-- PART III: THE CRUCIAL CONNECTION - SYMPLECTIC GROUP
-- ============================================================================

-- | A group that is also a symplectic vector space via quotient by center.
--
-- The Pauli group is a central extension:
-- 1 → Z(G) → G → V → 1
-- where:
-- - Z(G) is the center (phases for Pauli: {±I, ±iI})
-- - V = G/Z(G) is the symplectic vector space (F_2)^(2n)
-- - The commutator [a,b] corresponds to the symplectic form ω(ā, b̄)
--
-- Key theorem: [a,b] = e ⟺ ω(ā, b̄) = 0
--              [a,b] = z ⟺ ω(ā, b̄) ≠ 0
-- where ā is the projection of a to V, z = anticommutationMarker
class (BinaryCommutationGroup g, SymplecticVectorSpace v) 
      => SymplecticGroup g v | g -> v where
  -- | Project to the symplectic quotient (strip phases)
  toSymplectic :: g -> v
  
  -- | Lift from symplectic quotient (add phase, if possible)
  fromSymplectic :: v -> Maybe g
  
  -- | The fundamental theorem: commutator is determined by symplectic form
  -- [a,b] = e  ⟺  ω(ā, b̄) = 0
  symplecticCommutation :: g -> g -> Bool
  symplecticCommutation a b = 
    let va = toSymplectic a
        vb = toSymplectic b
        p = Proxy :: Proxy v
    in omega va vb == fieldZero p

-- ============================================================================
-- PART IV: ISOTROPIC AND LAGRANGIAN SUBSPACES
-- ============================================================================

-- | An isotropic subspace: ω vanishes on all pairs
-- 
-- Mathematically: W ⊂ V such that ω|_{W×W} = 0
-- Dimension bound: dim(W) ≤ n in a 2n-dimensional symplectic space
class (KnownNat n, SymplecticVectorSpace v) => IsotropicSubSpace s n v where
  -- | Get the underlying basis vectors
  toBasis :: s n v -> Vector n v
  
  -- | Check isotropy: ω(v_i, v_j) = fieldZero for all i, j
  verifyIsotropy :: s n v -> Bool
  verifyIsotropy s = 
    let vs = toBasis s
        p = Proxy :: Proxy v
    in VS.all (\v_i -> VS.all (\v_j -> symplecticOrthogonal p v_i v_j) vs) vs
  
  -- | Get the dimension (always n for this representation)
  dimSubspace :: s n v -> Int
  dimSubspace _ = fromIntegral $ natVal (Proxy @n)

-- | Lagrangian subspace: maximal isotropic (dim = n in 2n-dim space)
-- 
-- A Lagrangian subspace is isotropic and maximal with respect to inclusion.
-- These correspond to maximal abelian subgroups of the Pauli group.
class IsotropicSubSpace s n v => LagrangianSubSpace s n v

-- ============================================================================
-- PART V: THE ABELIAN-LAGRANGIAN CORRESPONDENCE
-- ============================================================================

-- | The fundamental correspondence:
-- Abelian subgroups of a SymplecticGroup ⟷ Isotropic subspaces of V
--
-- Key insight: 
-- - Pauli operators P₁, P₂ commute  ⟺  ω(v₁, v₂) = 0
-- - A set of commuting Paulis forms an Abelian subgroup  ⟺  
--   The corresponding vectors form an Isotropic subspace
-- - A MAXIMAL commuting set  ⟺  A LAGRANGIAN subspace (dimension = n)
class SymplecticGroup g v => AbelianLagrangianCorrespondence g n v | g -> v where
  -- | The type representing abelian subgroups of g
  -- These correspond to isotropic subspaces of the quotient
  type IsotropicSubgroup g :: Nat -> Type
  
  -- | Convert an abelian subgroup to an isotropic subspace
  -- This strips phases and takes the span in V
  subgroupToIsotropic :: IsotropicSubgroup g n -> Lagrangian n v
  
  -- | Lift an isotropic subspace to an abelian subgroup
  -- This adds canonical phases (usually 0) to each generator
  isotropicToSubgroup :: Lagrangian n v -> IsotropicSubgroup g n
  
  -- | Verify the fundamental invariant: abelian ⟺ isotropic
  -- For all a, b in subgroup: [a,b] = e  ⟺  ω(ā, b̄) = 0
  abelianIffIsotropic :: IsotropicSubgroup g n -> Bool

-- | Maximal abelian subgroups correspond to Lagrangian subspaces
class AbelianLagrangianCorrespondence g n v => MaximalAbelianCorrespondence g n v where
  -- | Check if abelian subgroup is maximal (dimension = n)
  isMaximalAbelian :: IsotropicSubgroup g n -> Bool
  
  -- | The correspondence: maximal abelian ⟺ Lagrangian
  maximalAbelianIffLagrangian :: IsotropicSubgroup g n -> Bool

-- ============================================================================
-- PART VI: THE SYMPLECTIC BASIS THEOREM (The Crown Jewel)
-- ============================================================================

-- | The Symplectic Basis Theorem: Every symplectic vector space admits
-- a canonical basis (Darboux basis) that puts ω in standard form.
--
-- Mathematical Statement:
-- Let (V, ω) be a symplectic vector space over field k, dim(V) = 2n.
-- Then there exists a basis {e₁,...,eₙ, f₁,...,fₙ} such that:
--   ω(eᵢ, eⱼ) = 0         (e's span a Lagrangian)
--   ω(fᵢ, fⱼ) = 0         (f's span a Lagrangian)  
--   ω(eᵢ, fⱼ) = δᵢⱼ       (duality)
--
-- This is equivalent to saying V decomposes as L ⊕ L* where L is Lagrangian.
class (KnownNat n, SymplecticVectorSpace v) => SymplecticBasisTheorem s n v where
  -- | Get the first Lagrangian (traditionally "position" or stabilizers)
  firstLagrangian :: s n v -> Lagrangian n v
  
  -- | Get the second Lagrangian (traditionally "momentum" or destabilizers)
  secondLagrangian :: s n v -> Lagrangian n v
  
  -- | Verify the duality condition: ω(secondᵢ, firstⱼ) = δᵢⱼ
  verifyDuality :: s n v -> Bool

-- ============================================================================
-- PART VII: CONCRETE IMPLEMENTATION - PAULI GROUP
-- ============================================================================

-- | Pauli operator P = i^phase · X^x Z^z as symplectic vector (x|z) ∈ F_2^(2n)
-- The symplectic form ω((x1|z1), (x2|z2)) = x1·z2 + z1·x2 (mod 2)
-- ω = 0 ⟺ commute, ω = 1 ⟺ anti-commute
data Pauli = Pauli 
  { xVec :: !Word64      -- ^ X-support bitmask
  , zVec :: !Word64      -- ^ Z-support bitmask  
  , phase :: !Int        -- ^ i^phase overall phase (0,1,2,3)
  } 
  deriving (Eq, Show)

-- | Group instance: Pauli operators form a group under multiplication
instance Group Pauli where
  mulG = multiplyPauli
  identityG = Pauli 0 0 0
  invG (Pauli x z r) = Pauli x z ((4 - r) `mod` 4)

-- | Binary commutation: Pauli operators either commute or anticommute
instance BinaryCommutationGroup Pauli where
  -- The anticommutation marker is -I (phase 2)
  anticommutationMarker = Pauli 0 0 2
  
  -- Two Paulis commute iff ω = 0 (symplectic form vanishes)
  commuteG p1 p2 = not (omegaPauli p1 p2)

-- | Helper: compute omega for Pauli (ignoring phase)
omegaPauli :: Pauli -> Pauli -> Bool
omegaPauli (Pauli x1 z1 _) (Pauli x2 z2 _) = 
  odd (popCount ((x1 .&. z2) `xor` (z1 .&. x2)))

-- | Pauli group multiplication with phase tracking
multiplyPauli :: Pauli -> Pauli -> Pauli
multiplyPauli (Pauli x1 z1 r1) (Pauli x2 z2 r2) =
  let x = x1 `xor` x2
      z = z1 `xor` z2
      -- Symplectic phase: i^{x1·z2} (-i)^{z1·x2} = i^{x1·z2 - z1·x2}
      symPhase = popCount (x1 .&. z2) - popCount (z1 .&. x2)
      r = (r1 + r2 + symPhase) `mod` 4
  in Pauli x z r

-- | Symplectic vector space structure on Pauli (modulo phases)
-- The quotient Pauli / {phases} ≅ (F_2)^(2n)
instance SymplecticVectorSpace Pauli where
  type Field Pauli = Bool  -- ^ F_2, represented as Bool
  
  -- | Zero element of F_2 (False = 0)
  fieldZero _ = False
  
  -- | Symplectic inner product ω: Pauli × Pauli → F_2
  -- ω(P₁, P₂) = x₁·z₂ + z₁·x₂ (mod 2)
  -- This is bilinear, alternating, and non-degenerate
  omega = omegaPauli
  
  -- | Pauli group multiplication is vector addition in (F_2)^(2n)
  -- (ignoring phase)
  addV = multiplyPauli
  
  -- | Identity element (zero vector)
  zeroV = Pauli 0 0 0
  
  -- | Inverse (negation) - conjugate by changing phase
  negateV (Pauli x z r) = Pauli x z ((4 - r) `mod` 4)

-- | The symplectic group connection: Pauli → (F_2)^(2n)
instance SymplecticGroup Pauli Pauli where
  -- The projection strips the phase, keeping only (x|z)
  toSymplectic (Pauli x z _) = Pauli x z 0
  
  -- Lift adds zero phase
  fromSymplectic (Pauli x z r) = Just (Pauli x z ((r `mod` 4 + 4) `mod` 4))
  
  -- The fundamental theorem: [P,Q] = I ⟺ ω(P,Q) = 0
  symplecticCommutation = commuteG

-- ============================================================================
-- PART VIII: LAGRANGIAN SUBSPACE DATA TYPE
-- ============================================================================

-- | A Lagrangian subspace is a maximal isotropic subspace of dimension n
-- in a 2n-dimensional symplectic vector space.
-- It is represented by n basis vectors.
newtype Lagrangian (n :: Nat) v = Lagrangian
  { lagrangianBasis :: Vector n v  -- ^ n basis vectors spanning the subspace
  }
  deriving (Show)

-- | Isotropic subspace instance
instance (KnownNat n, SymplecticVectorSpace v) => IsotropicSubSpace Lagrangian n v where
  toBasis = lagrangianBasis

-- | Lagrangian subspace instance
instance (KnownNat n, SymplecticVectorSpace v) => LagrangianSubSpace Lagrangian n v

-- | Map over a Lagrangian (apply symplectic transformation)
mapLagrangian :: (v -> v) -> Lagrangian n v -> Lagrangian n v
mapLagrangian f (Lagrangian vs) = Lagrangian (VS.map f vs)

-- | Index into a Lagrangian
indexLagrangian :: Lagrangian n v -> Finite n -> v
indexLagrangian (Lagrangian vs) i = VS.index vs i

-- | Convert Lagrangian to list
toListLagrangian :: Lagrangian n v -> [v]
toListLagrangian (Lagrangian vs) = VS.toList vs

-- ============================================================================
-- PART IX: TABLEAU AS SYMPLECTIC BASIS
-- ============================================================================

-- | The CHP Tableau is the computational realization of the 
-- Symplectic Basis Theorem for the Pauli group.
--
-- Tableau n v = (Lagrangian n v, Lagrangian n v) with duality
-- where:
-- - First Lagrangian = Stabilizers S (isotropic)
-- - Second Lagrangian = Destabilizers D (isotropic)
-- - Duality: ω(Dᵢ, Sⱼ) = δᵢⱼ
data Tableau (n :: Nat) v where
  Tableau :: (SymplecticVectorSpace v, Field v ~ Bool) =>
    { stabLagrangian :: Lagrangian n v      -- ^ S: first Lagrangian (stabilizers)
    , destabLagrangian :: Lagrangian n v    -- ^ D: second Lagrangian (destabilizers)
    } -> Tableau n v

-- | Tableau implements the Symplectic Basis Theorem!
instance (KnownNat n, SymplecticVectorSpace v, Field v ~ Bool) 
         => SymplecticBasisTheorem Tableau n v where
  firstLagrangian = stabLagrangian
  secondLagrangian = destabLagrangian
  
  -- Verify: ω(Dᵢ, Sⱼ) = δᵢⱼ
  verifyDuality tab =
    let s = stabLagrangian tab
        d = destabLagrangian tab
        vs = lagrangianBasis s
        vd = lagrangianBasis d
    in VS.and $ VS.imap (\i d_i ->
         VS.and $ VS.imap (\j s_j ->
           if i == j 
           then omega d_i s_j == True   -- ω(Dᵢ, Sᵢ) = 1
           else omega d_i s_j == False  -- ω(Dᵢ, Sⱼ) = 0 for i≠j
         ) vs
       ) vd

-- ============================================================================
-- PART X: TABLEAU OPERATIONS
-- ============================================================================

-- | Get the number of qubits (dimension of each Lagrangian)
nQubits :: forall n v. KnownNat n => Tableau n v -> Int
nQubits _ = fromIntegral $ natVal (Proxy @n)

-- | Get a stabilizer by index
getStabilizer :: Tableau n v -> Finite n -> v
getStabilizer tab i = indexLagrangian (stabLagrangian tab) i

-- | Get a destabilizer by index  
getDestabilizer :: Tableau n v -> Finite n -> v
getDestabilizer tab i = indexLagrangian (destabLagrangian tab) i

-- | Get stabilizer by Int index (for backward compatibility)
stabilizer :: forall n v. (KnownNat n, SymplecticVectorSpace v, Field v ~ Bool) => Tableau n v -> Int -> Maybe v
stabilizer tab i = do
  fin <- intToFinite i
  return $ getStabilizer tab fin

-- | Get destabilizer by Int index (for backward compatibility)
destabilizer :: forall n v. (KnownNat n, SymplecticVectorSpace v, Field v ~ Bool) => Tableau n v -> Int -> Maybe v
destabilizer tab i = do
  fin <- intToFinite i
  return $ getDestabilizer tab fin

-- | Convert Int to Finite safely
intToFinite :: forall n. KnownNat n => Int -> Maybe (Finite n)
intToFinite i 
  | i >= 0 = Finite.packFinite (fromIntegral i)
  | otherwise = Nothing

-- | Get all rows as a list [S_0..S_{n-1}, D_0..D_{n-1}] (for backward compatibility)
rows :: (KnownNat n, SymplecticVectorSpace v) => Tableau n v -> [v]
rows tab = toListLagrangian (stabLagrangian tab) ++ toListLagrangian (destabLagrangian tab)

-- | Initial state |0...0⟩: S_i = Z_i, D_i = X_i
-- This is the standard symplectic basis for the initial state
emptyTableau :: forall n. KnownNat n => Tableau n Pauli
emptyTableau = Tableau stabs destabs
  where
    stabs = Lagrangian $ VS.generate $ \i ->
      let idx = fromIntegral (Finite.getFinite i)
      in Pauli 0 (bit idx) 0        -- Z_i stabilizer
    destabs = Lagrangian $ VS.generate $ \i ->
      let idx = fromIntegral (Finite.getFinite i)
      in Pauli (bit idx) 0 0        -- X_i destabilizer

-- | Verify tableau validity (symplectic basis conditions)
-- This checks the three conditions from the Symplectic Basis Theorem:
-- 1. Stabilizers are isotropic: ω(Sᵢ, Sⱼ) = 0
-- 2. Destabilizers are isotropic: ω(Dᵢ, Dⱼ) = 0
-- 3. Duality: ω(Dᵢ, Sⱼ) = δᵢⱼ
isValid :: forall n v. (KnownNat n, SymplecticVectorSpace v, Field v ~ Bool, SymplecticBasisTheorem Tableau n v) 
        => Tableau n v -> Bool
isValid tab = 
  let s = stabLagrangian tab
      d = destabLagrangian tab
      vs = lagrangianBasis s
      vd = lagrangianBasis d
      p = Proxy :: Proxy v
      -- Check stabilizers are isotropic: ω(Sᵢ, Sⱼ) = 0
      stabIsotropic = VS.all (\s_i -> VS.all (\s_j -> symplecticOrthogonal p s_i s_j) vs) vs
      -- Check destabilizers are isotropic: ω(Dᵢ, Dⱼ) = 0
      destIsotropic = VS.all (\d_i -> VS.all (\d_j -> symplecticOrthogonal p d_i d_j) vd) vd
      -- Check dual pairing: ω(Dᵢ, Sⱼ) = δᵢⱼ (via SymplecticBasisTheorem)
      dualPairing = verifyDuality tab
  in stabIsotropic && destIsotropic && dualPairing

-- ============================================================================
-- PART XI: CLIFFORD GATES AS SYMPLECTIC TRANSFORMATIONS
-- ============================================================================

-- | Symplectic transformation on single qubit i
data LocalSymplectic 
  = Hadamard !Int      -- ^ H: (x_i, z_i) ↦ (z_i, x_i)
  | Phase !Int         -- ^ S: (x_i, z_i) ↦ (x_i, x_i + z_i)
  deriving (Show)

-- | Two-qubit symplectic
data SymplecticGate
  = Local !LocalSymplectic
  | CNOT !Int !Int     -- ^ (x_c, z_c, x_t, z_t) ↦ (x_c, z_c+z_t, x_t+x_c, z_t)
  deriving (Show)

-- | Apply symplectic gate to Pauli operator (conjugation P ↦ U P U†)
-- This is a symplectic transformation on the vector space
applyGate :: SymplecticGate -> Pauli -> Pauli
applyGate (Local (Hadamard i)) (Pauli x z r) =
  let xi = testBit x i
      zi = testBit z i
      mask = complement (bit i)
      x' = (x .&. mask) .|. (if zi then bit i else 0)
      z' = (z .&. mask) .|. (if xi then bit i else 0)
      r' = (r + if xi && zi then 2 else 0) `mod` 4
  in Pauli x' z' r'

applyGate (Local (Phase i)) (Pauli x z r) =
  let xi = testBit x i
      z' = if xi then z `xor` bit i else z
      -- Phase update: X->Y (+1), Y->-X (+1), Z->Z (0)
      r' = (r + if xi then 1 else 0) `mod` 4
  in Pauli x z' r'

applyGate (CNOT c t) (Pauli x z r) =
  let xc = testBit x c; zc = testBit z c
      xt = testBit x t; zt = testBit z t
      x' = if xc then x `xor` bit t else x
      z' = if zt then z `xor` bit c else z
      phaseTerm = if xc && zt then (if xt `xor` zc then 2 else 0) + 1 else 0
      r' = (r + phaseTerm) `mod` 4
  in Pauli x' z' r'

-- | Apply gate to entire tableau (conjugate both Lagrangians)
-- Since Clifford gates preserve the symplectic form, they map
-- symplectic bases to symplectic bases (per Symplectic Basis Theorem).
evolveTableau :: KnownNat n => Tableau n Pauli -> SymplecticGate -> Tableau n Pauli
evolveTableau (Tableau s d) g = 
  let s' = mapLagrangian (applyGate g) s
      d' = mapLagrangian (applyGate g) d
  in Tableau s' d'

-- ============================================================================
-- PART XII: MEASUREMENT VIA SYMPLECTIC DECOMPOSITION
-- ============================================================================

data MeasurementResult = Determinate Bool | Random Bool
  deriving (Show)

-- | Test if measurement is deterministic: P must commute with stabilizer subspace
isDeterminate :: KnownNat n => Tableau n Pauli -> Pauli -> Bool
isDeterminate tab p = 
  VS.all (\s_i -> commuteG p s_i) (lagrangianBasis $ stabLagrangian tab)

-- | Find stabilizer index j such that P anti-commutes with S_j
findAntiCommutingStab :: forall n. KnownNat n => Tableau n Pauli -> Pauli -> Maybe Int
findAntiCommutingStab tab p =
  let s = stabLagrangian tab
  in VS.ifoldl' (\acc (i :: Finite n) s_i ->
    case acc of
      Just _ -> acc
      Nothing -> if anticommuteG p s_i then Just (fromIntegral $ Finite.getFinite i) else Nothing) Nothing (lagrangianBasis s)

-- | Update a vector at a specific index
updateVector :: KnownNat n => Int -> a -> Vector n a -> Vector n a
updateVector i v vec = VS.unsafeUpd vec [(i, v)]

-- | Update a Lagrangian at a specific index
updateLagrangian :: KnownNat n => Finite n -> v -> Lagrangian n v -> Lagrangian n v
updateLagrangian i v (Lagrangian vs) = Lagrangian (VS.unsafeUpd vs [(fromIntegral $ Finite.getFinite i, v)])

-- | Measurement as state update (symplectic transvection)
measure :: forall n. KnownNat n => Tableau n Pauli -> Pauli -> IO (Tableau n Pauli, MeasurementResult)
measure tab@(Tableau s d) p
  | isDeterminate tab p = do
      let outcome = computePhase tab p
      return (tab, Determinate outcome)
  
  | otherwise = do
      let Just j = findAntiCommutingStab tab p
          Just jFin = intToFinite j
          s_j = indexLagrangian s jFin
          
          newStabBasis = VS.imap (\(k :: Finite n) s_k ->
            if k == jFin 
              then p
              else if anticommuteG p (indexLagrangian s k)
                   then multiplyPauli s_k s_j
                   else s_k) (lagrangianBasis s)
          
          newDestabBasis = updateVector j s_j (lagrangianBasis d)
      
      outcome <- randomRIO (0, 1) :: IO Int
      
      let Pauli x z r = p
          p' = Pauli x z ((r + if outcome == 0 then 2 else 0) `mod` 4)
          finalStabBasis = updateVector j p' newStabBasis
          finalStabs = Lagrangian finalStabBasis
          newDestabs = Lagrangian newDestabBasis
      
      return (Tableau finalStabs newDestabs, Random (outcome == 1))

-- | Compute deterministic measurement outcome via symplectic decomposition
computePhase :: forall n. KnownNat n => Tableau n Pauli -> Pauli -> Bool
computePhase (Tableau s d) p = 
  let scratch = VS.ifoldl' (\acc (j :: Finite n) d_j ->
        if anticommuteG p d_j
          then multiplyPauli acc (indexLagrangian s j)
          else acc) (Pauli 0 0 0) (lagrangianBasis d)
      totalPhase = (phase p - phase scratch) `mod` 4
  in totalPhase == 0

-- ============================================================================
-- PART XIII: MONADIC INTERFACE
-- ============================================================================

data SomeTableau where
  SomeTableau :: KnownNat n => Tableau n Pauli -> SomeTableau

newtype Clifford a = Clifford { runClifford :: SomeTableau -> IO (SomeTableau, a) }

instance Functor Clifford where
  fmap f (Clifford g) = Clifford $ \t -> do (t', x) <- g t; return (t', f x)

instance Applicative Clifford where
  pure x = Clifford $ \t -> return (t, x)
  Clifford f <*> Clifford x = Clifford $ \t -> do
    (t', f') <- f t; (t'', x') <- x t'; return (t'', f' x')

instance Monad Clifford where
  return = pure
  Clifford x >>= f = Clifford $ \t -> do (t', x') <- x t; runClifford (f x') t'

gate :: SymplecticGate -> Clifford ()
gate g = Clifford $ \t -> case t of
  SomeTableau tab -> return (SomeTableau (evolveTableau tab g), ())

measurePauli :: Pauli -> Clifford Bool
measurePauli p = Clifford $ \t -> case t of
  SomeTableau tab -> do
    (t', res) <- measure tab p
    case res of
      Determinate b -> return (SomeTableau t', b)
      Random b      -> return (SomeTableau t', b)

getTableau :: Clifford SomeTableau
getTableau = Clifford $ \t -> return (t, t)

withNatProxy :: KnownNat n => Proxy n -> (KnownNat n => Tableau n Pauli) -> Tableau n Pauli
withNatProxy _ t = t

emptyTableauN :: Int -> SomeTableau
emptyTableauN n
  | n < 0 = error $ "Invalid qubit count: " ++ show n
  | otherwise = case GHC.TypeNats.someNatVal (fromIntegral n) of
      GHC.TypeNats.SomeNat (proxy :: Proxy n) -> 
        SomeTableau (emptyTableau :: Tableau n Pauli)

runWith :: Int -> Clifford a -> IO (SomeTableau, a)
runWith n (Clifford f) = f (emptyTableauN n)

-- ============================================================================
-- PART XIV: BACKWARD COMPATIBILITY HELPERS
-- ============================================================================

rowsSome :: SomeTableau -> [Pauli]
rowsSome (SomeTableau tab) = rows tab

nQubitsSome :: SomeTableau -> Int
nQubitsSome (SomeTableau tab) = nQubits tab

stabilizerSome :: SomeTableau -> Int -> Maybe Pauli
stabilizerSome (SomeTableau tab) i = stabilizer tab i

destabilizerSome :: SomeTableau -> Int -> Maybe Pauli
destabilizerSome (SomeTableau tab) i = destabilizer tab i

isValidSome :: SomeTableau -> Bool
isValidSome (SomeTableau tab) = isValid tab

evolveTableauSome :: SomeTableau -> SymplecticGate -> SomeTableau
evolveTableauSome (SomeTableau tab) g = SomeTableau (evolveTableau tab g)

measureSome :: SomeTableau -> Pauli -> IO (SomeTableau, MeasurementResult)
measureSome (SomeTableau tab) p = do
  (tab', res) <- measure tab p
  return (SomeTableau tab', res)

isDeterminateSome :: SomeTableau -> Pauli -> Bool
isDeterminateSome (SomeTableau tab) p = isDeterminate tab p

findAntiCommutingStabSome :: SomeTableau -> Pauli -> Maybe Int
findAntiCommutingStabSome (SomeTableau tab) p = findAntiCommutingStab tab p

computePhaseSome :: SomeTableau -> Pauli -> Bool
computePhaseSome (SomeTableau tab) p = computePhase tab p

-- ============================================================================
-- PART XV: EXAMPLES AND HELPERS
-- ============================================================================

bellCircuit :: Clifford Bool
bellCircuit = do
  gate (Local (Hadamard 0))
  gate (CNOT 0 1)
  measurePauli (Pauli (bit 0) (bit 0) 0)

pauliX :: Int -> Pauli
pauliX i = Pauli (bit i) 0 0

pauliZ :: Int -> Pauli
pauliZ i = Pauli 0 (bit i) 0

pauliY :: Int -> Pauli
pauliY i = Pauli (bit i) (bit i) 1

-- | Backward compatibility: symplectic form
symplecticForm :: Pauli -> Pauli -> Bool
symplecticForm p1 p2 = not (omegaPauli p1 p2)

-- | Backward compatibility: commute
commute :: Pauli -> Pauli -> Bool
commute = commuteG

-- | Backward compatibility: anticommute
anticommute :: Pauli -> Pauli -> Bool
anticommute = anticommuteG

-- | Backward compatibility: multiply
multiply :: Pauli -> Pauli -> Pauli
multiply = multiplyPauli

-- ============================================================================
-- PART XVI: UTILITIES
-- ============================================================================

(//) :: [a] -> [(Int, a)] -> [a]
xs // [] = xs
xs // updates = 
  let sorted = sortOn fst updates
      grouped = groupBy ((==) `on` fst) sorted
      finalUpdates = [(i, v) | grp@((i,_):_) <- grouped, let (_,v) = last grp]
      go _ [] [] = []
      go i (x:xs) ups@((ui,uv):us)
        | i == ui   = uv : go (i+1) xs us
        | i < ui    = x  : go (i+1) xs ups
        | otherwise = go i (x:xs) us
      go i xs [] = xs
      go _ [] _ = []
  in go 0 xs finalUpdates
