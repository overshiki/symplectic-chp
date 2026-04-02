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

module SymplecticCHP where

import Data.Bits
import Data.Word
import Data.Proxy (Proxy(..))
import Data.Kind (Type)
import System.Random (randomRIO)
import Data.List (sortOn, groupBy)
import Data.Function (on)

-- vector-sized imports
import qualified Data.Vector.Sized as VS
import Data.Vector.Sized (Vector)
import qualified GHC.TypeNats
import GHC.TypeNats (Nat, KnownNat, natVal)

-- For type-safe finite indices
import Data.Finite (Finite)
import qualified Data.Finite as Finite

-- ============================================================================
-- Symplectic Vector Space Type Class Hierarchy
-- ============================================================================

-- | A symplectic vector space over a field k.
-- The symplectic form ω is a bilinear, alternating, non-degenerate form.
class Eq (Field v) => SymplecticVectorSpace v where
  type Field v :: Type
  
  -- | Zero element of the field
  fieldZero :: proxy v -> Field v
  
  -- | The symplectic form ω(v1, v2)
  omega :: v -> v -> Field v
  
  -- | Vector addition (abelian group)
  addV :: v -> v -> v
  
  -- | Zero vector
  zeroV :: v
  
  -- | Negation (additive inverse)
  negateV :: v -> v
  
  -- | Check if a vector is isotropic (ω(v,v) = 0)
  isIsotropicElement :: v -> Bool
  
  -- | Two vectors commute iff ω(v1, v2) = 0
  commuteV :: v -> v -> Bool
  
  -- | Two vectors anti-commute iff ω(v1, v2) ≠ 0
  anticommuteV :: v -> v -> Bool
  anticommuteV v1 v2 = not (commuteV v1 v2)

-- ============================================================================
-- Pauli Group as Symplectic Vector Space over F_2
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

instance SymplecticVectorSpace Pauli where
  type Field Pauli = Bool  -- ^ F_2, represented as Bool
  
  -- | Zero element of the field (False = 0 ∈ F_2)
  fieldZero _ = False
  
  -- | Symplectic inner product (commutator)
  omega (Pauli x1 z1 _) (Pauli x2 z2 _) = 
    odd (popCount ((x1 .&. z2) `xor` (z1 .&. x2)))
  
  -- | Pauli group multiplication is vector addition in (F_2)^(2n)
  addV = multiplyPauli
  
  -- | Identity element
  zeroV = Pauli 0 0 0
  
  -- | Inverse (negation) - conjugate by changing phase
  negateV (Pauli x z r) = Pauli x z ((4 - r) `mod` 4)
  
  -- | In F_2, ω(v,v) = 0 always (alternating property)
  isIsotropicElement _ = True
  
  -- | Commute if ω = False (0 ∈ F_2)
  commuteV v1 v2 = not (omega v1 v2)

-- | Pauli group multiplication with phase tracking
multiplyPauli :: Pauli -> Pauli -> Pauli
multiplyPauli (Pauli x1 z1 r1) (Pauli x2 z2 r2) =
  let x = x1 `xor` x2
      z = z1 `xor` z2
      -- Symplectic phase: i^{x1·z2} (-i)^{z1·x2} = i^{x1·z2 - z1·x2}
      symPhase = popCount (x1 .&. z2) - popCount (z1 .&. x2)
      r = (r1 + r2 + symPhase) `mod` 4
  in Pauli x z r

-- | Symplectic inner product (commutator) - backward compatible
-- Returns True if they commute (ω=0), False if anti-commute (ω=1)
symplecticForm :: Pauli -> Pauli -> Bool
symplecticForm p1 p2 = not (omega p1 p2)

-- | Check if two Paulis commute (wrapper for clarity)
commute :: Pauli -> Pauli -> Bool
commute = commuteV

anticommute :: Pauli -> Pauli -> Bool
anticommute = anticommuteV

-- | Pauli group multiplication (exported)
multiply :: Pauli -> Pauli -> Pauli
multiply = multiplyPauli

-- ============================================================================
-- Lagrangian Subspace (Maximal Isotropic)
-- ============================================================================

-- | A Lagrangian subspace is a maximal isotropic subspace of dimension n
-- in a 2n-dimensional symplectic vector space.
-- It is represented by n basis vectors.
newtype Lagrangian (n :: Nat) v = Lagrangian
  { lagrangianBasis :: Vector n v  -- ^ n basis vectors spanning the subspace
  }
  deriving (Show)

-- | Class for isotropic subspaces (subspaces where ω vanishes)
class (KnownNat n, SymplecticVectorSpace v) => IsotropicSubSpace s n v where
  -- | Get the underlying basis vectors
  toBasis :: s n v -> Vector n v
  
  -- | Check isotropy: ω(v_i, v_j) = 0 for all i, j
  verifyIsotropy :: s n v -> Bool
  verifyIsotropy s = 
    let vs = toBasis s
    in VS.all (\v_i -> VS.all (\v_j -> commuteV v_i v_j) vs) vs
  
  -- | Get the dimension (always n for this representation)
  dimSubspace :: s n v -> Int
  dimSubspace _ = fromIntegral $ natVal (Proxy @n)

-- | Lagrangian subspaces are maximal isotropic
class IsotropicSubSpace Lagrangian n v => LagrangianSubSpace n v where
  -- | Empty Lagrangian for construction
  emptyLagrangian :: Vector n v -> Lagrangian n v
  emptyLagrangian = Lagrangian

instance (KnownNat n, SymplecticVectorSpace v) => IsotropicSubSpace Lagrangian n v where
  toBasis = lagrangianBasis

instance (KnownNat n, SymplecticVectorSpace v) => LagrangianSubSpace n v

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
-- Tableau as Symplectic Basis (Two Transverse Lagrangians)
-- ============================================================================

-- | Duality proof: ω(D_i, S_j) = δ_ij
-- Represented as a matrix where diagonal should be True (anti-commute)
-- and off-diagonal should be False (commute)
type DualityProof n = Vector n (Vector n Bool)

-- | The tableau represents a symplectic basis consisting of:
--   - Stabilizers S: a Lagrangian subspace (isotropic, dimension n)
--   - Destabilizers D: another Lagrangian subspace, transverse to S
-- The duality condition ω(D_i, S_j) = δ_ij makes (S, D) a symplectic basis.
data Tableau (n :: Nat) v where
  Tableau :: (SymplecticVectorSpace v, Field v ~ Bool) =>
    { stabLagrangian :: Lagrangian n v      -- ^ S: stabilizer subspace
    , destabLagrangian :: Lagrangian n v    -- ^ D: destabilizer subspace
    } -> Tableau n v

-- | Class for symplectic bases (two transverse Lagrangians)
class (KnownNat n, SymplecticVectorSpace v) => SymplecticBasis s n v where
  -- | Get the stabilizer Lagrangian (first Lagrangian)
  getStabLagrangian :: s n v -> Lagrangian n v
  
  -- | Get the destabilizer Lagrangian (second Lagrangian)
  getDestabLagrangian :: s n v -> Lagrangian n v
  
  -- | Verify duality: ω(D_i, S_j) = δ_ij
  verifyDuality :: s n v -> Bool
  verifyDuality s =
    let d = getDestabLagrangian s
        st = getStabLagrangian s
    in VS.and $ VS.imap (\i d_i ->
         VS.and $ VS.imap (\j s_j ->
           if Finite.equals i j
           then anticommuteV d_i s_j  -- ω(D_i, S_i) = 1 (anti-commute)
           else commuteV d_i s_j       -- ω(D_i, S_j) = 0 (commute for i≠j)
         ) (lagrangianBasis st)
       ) (lagrangianBasis d)
  
  -- | Verify both subspaces are isotropic
  verifyIsotropic :: s n v -> Bool
  verifyIsotropic s = verifyIsotropy (getStabLagrangian s) && 
                      verifyIsotropy (getDestabLagrangian s)

instance (KnownNat n, SymplecticVectorSpace v, Field v ~ Bool) => 
         SymplecticBasis Tableau n v where
  getStabLagrangian = stabLagrangian
  getDestabLagrangian = destabLagrangian

-- ============================================================================
-- Tableau Operations
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
isValid :: forall n v. (KnownNat n, SymplecticVectorSpace v, Field v ~ Bool, SymplecticBasis Tableau n v) => Tableau n v -> Bool
isValid tab = 
  let s = stabLagrangian tab
      d = destabLagrangian tab
      vs = lagrangianBasis s
      vd = lagrangianBasis d
      -- Check stabilizers are isotropic
      stabIsotropic = VS.all (\s_i -> VS.all (\s_j -> commuteV s_i s_j) vs) vs
      -- Check destabilizers are isotropic
      destIsotropic = VS.all (\d_i -> VS.all (\d_j -> commuteV d_i d_j) vd) vd
      -- Check dual pairing: ω(D_i, S_j) = δ_ij (via SymplecticBasis type class)
      dualPairing = verifyDuality tab
  in stabIsotropic && destIsotropic && dualPairing

-- ============================================================================
-- Clifford Gates as Symplectic Transformations
-- ============================================================================

-- | Clifford gates are symplectic transformations preserving ω.
-- They act on the symplectic vector space by conjugation.

-- Symplectic transformation on single qubit i
data LocalSymplectic 
  = Hadamard !Int      -- ^ H: (x_i, z_i) ↦ (z_i, x_i)
  | Phase !Int         -- ^ S: (x_i, z_i) ↦ (x_i, x_i + z_i)
  deriving (Show)

-- Two-qubit symplectic
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
      -- CORRECT bit swap using mask
      mask = complement (bit i)
      x' = (x .&. mask) .|. (if zi then bit i else 0)
      z' = (z .&. mask) .|. (if xi then bit i else 0)
      -- Phase: flip by 2 (add -1) if Y operator
      r' = (r + if xi && zi then 2 else 0) `mod` 4
  in Pauli x' z' r'

applyGate (Local (Phase i)) (Pauli x z r) =
  let xi = testBit x i
      z' = if xi then z `xor` bit i else z
      -- Phase: S X S† = Y (phase i), S Y S† = -X (phase -i = 3)
      r' = (r + if xi && not (testBit z i) then 1 else 0) `mod` 4
  in Pauli x z' r'

applyGate (CNOT c t) (Pauli x z r) =
  let xc = testBit x c; zc = testBit z c
      xt = testBit x t; zt = testBit z t
      -- x_t += x_c, z_c += z_t
      x' = if xc then x `xor` bit t else x
      z' = if zt then z `xor` bit c else z
      -- Phase from commutation: i^{x_c z_t (1 + x_t + z_c)}
      phaseTerm = if xc && zt then (if xt `xor` zc then 2 else 0) + 1 else 0
      r' = (r + phaseTerm) `mod` 4
  in Pauli x' z' r'

-- | Apply gate to entire tableau (conjugate both Lagrangians)
-- Since Clifford gates preserve the symplectic form, they map
-- symplectic bases to symplectic bases.
evolveTableau :: KnownNat n => Tableau n Pauli -> SymplecticGate -> Tableau n Pauli
evolveTableau (Tableau s d) g = 
  let -- Apply the symplectic transformation to both Lagrangians
      s' = mapLagrangian (applyGate g) s
      d' = mapLagrangian (applyGate g) d
  in Tableau s' d'

-- ============================================================================
-- Measurement via Symplectic Decomposition
-- ============================================================================

-- | Measurement of Pauli P:
--   1. Check if P ∈ S^⊥ (commutes with stabilizer subspace)
--      - If yes: deterministic outcome, phase from decomposition
--      - If no: random outcome, update isotropic subspace via symplectic transvection
data MeasurementResult = Determinate Bool | Random Bool
  deriving (Show)

-- | Test if measurement is deterministic: P must commute with stabilizer subspace
isDeterminate :: (KnownNat n, SymplecticVectorSpace v, Field v ~ Bool) => Tableau n v -> v -> Bool
isDeterminate tab p = 
  VS.all (\s_i -> commuteV p s_i) (lagrangianBasis $ stabLagrangian tab)

-- | Find stabilizer index j such that P anti-commutes with S_j
-- Returns Nothing if P commutes with all stabilizers (determinate measurement)
findAntiCommutingStab :: forall n v. (KnownNat n, SymplecticVectorSpace v, Field v ~ Bool) 
                      => Tableau n v -> v -> Maybe Int
findAntiCommutingStab tab p =
  let s = stabLagrangian tab
  in VS.ifoldl' (\acc (i :: Finite n) s_i ->
    case acc of
      Just _ -> acc
      Nothing -> if anticommuteV p s_i then Just (fromIntegral $ Finite.getFinite i) else Nothing) Nothing (lagrangianBasis s)

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
          s_j = indexLagrangian s jFin  -- SAVE old stabilizer S_j before updates
          
          -- Update stabilizers via symplectic transvection:
          -- 1. S_j → p' (new stabilizer with phase from random outcome)
          -- 2. S_k → S_k · s_j for k≠j where P anti-commutes with S_k
          newStabBasis = VS.imap (\(k :: Finite n) s_k ->
            if k == jFin 
              then p  -- Will fix phase below
              else if anticommuteV p (indexLagrangian s k)
                   then multiplyPauli s_k s_j  -- S_k = S_k · S_j
                   else s_k) (lagrangianBasis s)
          newStabs = Lagrangian newStabBasis
          
          -- Update destabilizers: D_j → s_j (old stabilizer becomes new destabilizer)
          newDestabBasis = updateVector j s_j (lagrangianBasis d)
          newDestabs = Lagrangian newDestabBasis
      
      -- Random outcome
      outcome <- randomRIO (0, 1) :: IO Int
      
      -- Phase: -1 outcome adds 2 to phase
      let Pauli x z r = p
          p' = Pauli x z ((r + if outcome == 0 then 2 else 0) `mod` 4)
          finalStabBasis = updateVector j p' newStabBasis
          finalStabs = Lagrangian finalStabBasis
      
      return (Tableau finalStabs newDestabs, Random (outcome == 1))

-- | Compute deterministic measurement outcome via symplectic decomposition
computePhase :: forall n. KnownNat n => Tableau n Pauli -> Pauli -> Bool
computePhase (Tableau s d) p = 
  -- Accumulate product of stabilizers S_j where P anti-commutes with D_j
  let scratch = VS.ifoldl' (\acc (j :: Finite n) d_j ->
        if anticommuteV p d_j  -- [P, D_j] ≠ 0 means S_j is in decomposition
          then multiplyPauli acc (indexLagrangian s j)
          else acc) (Pauli 0 0 0) (lagrangianBasis d)
      -- Total phase: P = ±(stabilizer product), so compare phases
      totalPhase = (phase p - phase scratch) `mod` 4
  in totalPhase == 0  -- +1 if phases match, -1 if differ by 2

-- ============================================================================
-- Monadic Interface
-- ============================================================================

-- Existential wrapper to hide the type parameter
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

-- | Apply symplectic gate
gate :: SymplecticGate -> Clifford ()
gate g = Clifford $ \t -> case t of
  SomeTableau tab -> return (SomeTableau (evolveTableau tab g), ())

-- | Measure Pauli operator
measurePauli :: Pauli -> Clifford Bool
measurePauli p = Clifford $ \t -> case t of
  SomeTableau tab -> do
    (t', res) <- measure tab p
    case res of
      Determinate b -> return (SomeTableau t', b)
      Random b      -> return (SomeTableau t', b)

-- | Get current tableau state (as SomeTableau existential)
getTableau :: Clifford SomeTableau
getTableau = Clifford $ \t -> return (t, t)

-- | Helper to bring KnownNat instance into scope from a Proxy
withNatProxy :: KnownNat n => Proxy n -> (KnownNat n => Tableau n Pauli) -> Tableau n Pauli
withNatProxy _ t = t

-- | Create an empty tableau with a runtime-specified number of qubits
emptyTableauN :: Int -> SomeTableau
emptyTableauN n
  | n < 0 = error $ "Invalid qubit count: " ++ show n
  | otherwise = case GHC.TypeNats.someNatVal (fromIntegral n) of
      GHC.TypeNats.SomeNat (proxy :: Proxy n) -> 
        SomeTableau (emptyTableau :: Tableau n Pauli)

-- | Run with n qubits
runWith :: Int -> Clifford a -> IO (SomeTableau, a)
runWith n (Clifford f) = f (emptyTableauN n)

-- ============================================================================
-- Backward Compatibility Helpers for SomeTableau
-- ============================================================================

-- | Get rows from SomeTableau (for backward compatibility in tests)
rowsSome :: SomeTableau -> [Pauli]
rowsSome (SomeTableau tab) = rows tab

-- | Get nQubits from SomeTableau
nQubitsSome :: SomeTableau -> Int
nQubitsSome (SomeTableau tab) = nQubits tab

-- | Get stabilizer from SomeTableau by index
stabilizerSome :: SomeTableau -> Int -> Maybe Pauli
stabilizerSome (SomeTableau tab) i = stabilizer tab i

-- | Get destabilizer from SomeTableau by index
destabilizerSome :: SomeTableau -> Int -> Maybe Pauli
destabilizerSome (SomeTableau tab) i = destabilizer tab i

-- | Check validity of SomeTableau
isValidSome :: SomeTableau -> Bool
isValidSome (SomeTableau tab) = isValid tab

-- | Evolve SomeTableau
evolveTableauSome :: SomeTableau -> SymplecticGate -> SomeTableau
evolveTableauSome (SomeTableau tab) g = SomeTableau (evolveTableau tab g)

-- | Measure SomeTableau
measureSome :: SomeTableau -> Pauli -> IO (SomeTableau, MeasurementResult)
measureSome (SomeTableau tab) p = do
  (tab', res) <- measure tab p
  return (SomeTableau tab', res)

-- | Is determinate for SomeTableau
isDeterminateSome :: SomeTableau -> Pauli -> Bool
isDeterminateSome (SomeTableau tab) p = isDeterminate tab p

-- | Find anti-commuting stabilizer for SomeTableau
findAntiCommutingStabSome :: SomeTableau -> Pauli -> Maybe Int
findAntiCommutingStabSome (SomeTableau tab) p = findAntiCommutingStab tab p

-- | Compute phase for SomeTableau
computePhaseSome :: SomeTableau -> Pauli -> Bool
computePhaseSome (SomeTableau tab) p = computePhase tab p

-- ============================================================================
-- Examples and Helpers
-- ============================================================================

-- | Bell state preparation: |00⟩ + |11⟩
bellCircuit :: Clifford Bool
bellCircuit = do
  gate (Local (Hadamard 0))    -- H on qubit 0
  gate (CNOT 0 1)               -- CNOT 0→1
  measurePauli (Pauli (bit 0) (bit 0) 0)  -- measure X⊗X (should be +1)

-- | Helper definitions
pauliX :: Int -> Pauli
pauliX i = Pauli (bit i) 0 0

pauliZ :: Int -> Pauli
pauliZ i = Pauli 0 (bit i) 0

pauliY :: Int -> Pauli
pauliY i = Pauli (bit i) (bit i) 1

-- ============================================================================
-- Backward compatibility: List update operator
-- ============================================================================

-- | Helper for list update operator (for backward compatibility in tests)
(//) :: [a] -> [(Int, a)] -> [a]
xs // [] = xs
xs // updates = 
  let -- Sort by index, group, take last of each group (latest update wins)
      sorted = sortOn fst updates
      grouped = groupBy ((==) `on` fst) sorted
      finalUpdates = [(i, v) | grp@((i,_):_) <- grouped, let (_,v) = last grp]
      -- Build result
      go _ [] [] = []
      go i (x:xs) ups@((ui,uv):us)
        | i == ui   = uv : go (i+1) xs us
        | i < ui    = x  : go (i+1) xs ups
        | otherwise = go i (x:xs) us  -- skip invalid index
      go i xs [] = xs  -- remaining unchanged
      go _ [] _ = []   -- updates beyond list length ignored
  in go 0 xs finalUpdates
