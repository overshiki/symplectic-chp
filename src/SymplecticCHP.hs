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

module SymplecticCHP where

import Data.Bits
import Data.Word
import Data.Proxy (Proxy(..))
import Control.Monad (foldM, when)
import System.Random (randomRIO)
import Data.List (sortOn, groupBy)
import Data.Function (on)

-- vector-sized imports
import qualified Data.Vector.Sized as VS
import Data.Vector.Sized (Vector)
import qualified GHC.TypeNats
import GHC.TypeNats (Nat, KnownNat, natVal, type (+))

-- For type-safe finite indices
import Data.Finite (Finite)
import qualified Data.Finite as Finite

-- ============================================================================
-- Symplectic Vector Space (F_2)^(2n)
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


-- | Symplectic inner product (commutator)
symplecticForm :: Pauli -> Pauli -> Bool
symplecticForm (Pauli x1 z1 _) (Pauli x2 z2 _) = 
  even (popCount ((x1 .&. z2) `xor` (z1 .&. x2)))

-- | Check if two Paulis commute (wrapper for clarity)
commute :: Pauli -> Pauli -> Bool
commute = symplecticForm

anticommute :: Pauli -> Pauli -> Bool
anticommute p1 p2 = not $ symplecticForm p1 p2

-- | Pauli group multiplication with phase tracking
multiply :: Pauli -> Pauli -> Pauli
multiply (Pauli x1 z1 r1) (Pauli x2 z2 r2) =
  let x = x1 `xor` x2
      z = z1 `xor` z2
      -- Symplectic phase: i^{x1·z2} (-i)^{z1·x2} = i^{x1·z2 - z1·x2}
      symPhase = popCount (x1 .&. z2) - popCount (z1 .&. x2)
      r = (r1 + r2 + symPhase) `mod` 4
  in Pauli x z r

-- ============================================================================
-- Tableau as Lagrangian Subspace with Type-Safe Indices
-- ============================================================================

-- | The tableau represents a maximal isotropic subspace (Lagrangian) of the 
-- symplectic vector space. It consists of:
--   - Stabilizers S_i (rows 0..n-1): isotropic generators, ω(S_i, S_j) = 0
--   - Destabilizers D_i (rows n..2n-1): dual basis, ω(D_i, S_j) = δ_ij
--
-- Using sized vectors from vector-sized with Finite indices for type safety.

data Tableau (n :: Nat) = Tableau
  { stabilizers :: !(Vector n Pauli)    -- ^ S_0..S_{n-1}
  , destabilizers :: !(Vector n Pauli)  -- ^ D_0..D_{n-1}
  }

-- | Get the number of qubits (type-level nat converted to Int)
nQubits :: forall n. KnownNat n => Tableau n -> Int
nQubits _ = fromIntegral $ natVal (Proxy @n)

-- | Convert Int to Finite safely
intToFinite :: forall n. KnownNat n => Int -> Maybe (Finite n)
intToFinite i 
  | i >= 0 = Finite.packFinite (fromIntegral i)
  | otherwise = Nothing

-- | Get a stabilizer by index (type-safe via KnownNat constraint)
getStabilizer :: forall n. KnownNat n => Tableau n -> Int -> Maybe Pauli
getStabilizer (Tableau s _) i = do
  fin <- intToFinite i
  return $ VS.index s fin

-- | Get a destabilizer by index (type-safe via KnownNat constraint)
getDestabilizer :: forall n. KnownNat n => Tableau n -> Int -> Maybe Pauli
getDestabilizer (Tableau _ d) i = do
  fin <- intToFinite i
  return $ VS.index d fin

-- | Get all rows as a list [S_0..S_{n-1}, D_0..D_{n-1}] (for backward compatibility)
rows :: KnownNat n => Tableau n -> [Pauli]
rows (Tableau s d) = VS.toList s ++ VS.toList d

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

-- | Get stabilizer by index (for backward compatibility in tests)
-- Returns the stabilizer if index is valid, Nothing otherwise
stabilizer :: KnownNat n => Tableau n -> Int -> Maybe Pauli
stabilizer = getStabilizer

-- | Get destabilizer by index (for backward compatibility in tests)
-- Note: In the old representation, destabilizer i was at index (i + n)
-- Here we use the separate vector, so we just access index i directly
destabilizer :: KnownNat n => Tableau n -> Int -> Maybe Pauli
destabilizer = getDestabilizer

-- | Initial state |0...0⟩: S_i = Z_i, D_i = X_i
emptyTableau :: forall n. KnownNat n => Tableau n
emptyTableau = Tableau stabs destabs
  where
    stabs = VS.generate $ \i ->
      let idx = fromIntegral (Finite.getFinite i)
      in Pauli 0 (bit idx) 0        -- Z_i stabilizer
    destabs = VS.generate $ \i ->
      let idx = fromIntegral (Finite.getFinite i)
      in Pauli (bit idx) 0 0        -- X_i destabilizer

-- | Verify isotropic condition: all stabilizers commute
isValid :: forall n. KnownNat n => Tableau n -> Bool
isValid (Tableau stabs destabs) = 
  let -- Check all stabilizers commute with each other
      stabCommute = VS.and $ VS.imap (\i s_i ->
        VS.and $ VS.imap (\j s_j ->
          i == j || commute s_i s_j) stabs) stabs
      
      -- Check dual pairing: ω(D_i, S_j) = δ_ij
      dualPairing = VS.and $ VS.imap (\i d_i ->
        VS.and $ VS.imap (\j s_j ->
          if i == j then anticommute d_i s_j else commute d_i s_j) stabs) destabs
      
      -- Check destabilizers commute with each other
      destCommute = VS.and $ VS.imap (\i d_i ->
        VS.and $ VS.imap (\j d_j ->
          i == j || commute d_i d_j) destabs) destabs
  in stabCommute && dualPairing && destCommute

-- ============================================================================
-- Clifford Group as Sp(2n, F_2)
-- ============================================================================

-- | Clifford gates are symplectic transformations preserving ω.
-- Instead of matrix multiplication, we define action on Pauli vectors.

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

-- | Apply gate to entire tableau (conjugate all rows)
evolveTableau :: KnownNat n => Tableau n -> SymplecticGate -> Tableau n
evolveTableau (Tableau s d) g = 
  Tableau (VS.map (applyGate g) s) (VS.map (applyGate g) d)

-- ============================================================================
-- Measurement via Symplectic Test
-- ============================================================================

-- | Measurement of Pauli P:
--   1. Check if P ∈ S^⊥ (commutes with all stabilizers)
--      - If yes: deterministic outcome, phase from decomposition
--      - If no: random outcome, update stabilizer subgroup

data MeasurementResult = Determinate Bool | Random Bool
  deriving (Show)

-- | Test if measurement is deterministic: P must commute with stabilizer subspace
isDeterminate :: KnownNat n => Tableau n -> Pauli -> Bool
isDeterminate (Tableau s _) p = 
  VS.all (\s_i -> commute p s_i) s

-- | Find stabilizer index j such that P anti-commutes with S_j
-- Returns Nothing if P commutes with all stabilizers (determinate measurement)
findAntiCommutingStab :: forall n. KnownNat n => Tableau n -> Pauli -> Maybe Int
findAntiCommutingStab (Tableau s _) p =
  VS.ifoldl' (\acc (i :: Finite n) s_i ->
    case acc of
      Just _ -> acc
      Nothing -> if not (commute p s_i) then Just (fromIntegral $ Finite.getFinite i) else Nothing) Nothing s

-- | Update a vector at a specific index (unsafe but internal use only)
updateVector :: KnownNat n => Int -> a -> Vector n a -> Vector n a
updateVector i v vec = VS.unsafeUpd vec [(i, v)]

-- | Measurement as state update
measure :: forall n. KnownNat n => Tableau n -> Pauli -> IO (Tableau n, MeasurementResult)
measure tab@(Tableau stabs destabs) p
  | isDeterminate tab p = do
      let outcome = computePhase tab p
      return (tab, Determinate outcome)
  
  | otherwise = do
      let Just j = findAntiCommutingStab tab p
          Just jFin = intToFinite j
          s_j = VS.index stabs jFin  -- SAVE old stabilizer S_j before updates
          
          -- Update stabilizers:
          -- 1. S_j → p' (new stabilizer with phase from random outcome)
          -- 2. S_k → S_k · s_j for k≠j where P anti-commutes with S_k
          newStabs = VS.imap (\(k :: Finite n) s_k ->
            if k == jFin 
              then p  -- Will fix phase below
              else if not (commute p (VS.index stabs k))
                   then multiply s_k s_j  -- S_k = S_k · S_j (OLD stabilizer!)
                   else s_k) stabs
          
          -- Update destabilizers: D_j → s_j (old stabilizer becomes new destabilizer)
          newDestabs = updateVector j s_j destabs
      
      -- Random outcome
      outcome <- randomRIO (0, 1) :: IO Int
      
      -- Phase: -1 outcome adds 2 to phase
      let Pauli x z r = p
          p' = Pauli x z ((r + if outcome == 0 then 2 else 0) `mod` 4)
          finalStabs = updateVector j p' newStabs
      
      return (Tableau finalStabs newDestabs, Random (outcome == 1))

-- | Compute deterministic measurement outcome via symplectic decomposition
computePhase :: forall n. KnownNat n => Tableau n -> Pauli -> Bool
computePhase (Tableau stabs destabs) p = 
  -- Accumulate product of stabilizers S_j where P anti-commutes with D_j
  let scratch = VS.ifoldl' (\acc (j :: Finite n) d_j ->
        if anticommute p d_j  -- [P, D_j] ≠ 0 means S_j is in decomposition
          then multiply acc (VS.index stabs j)
          else acc) (Pauli 0 0 0) destabs
      -- Total phase: P = ±(stabilizer product), so compare phases
      totalPhase = (phase p - phase scratch) `mod` 4
  in totalPhase == 0  -- +1 if phases match, -1 if differ by 2

-- ============================================================================
-- Monadic Interface
-- ============================================================================

-- Existential wrapper to hide the type parameter
-- This allows runtime determination of qubit count
data SomeTableau where
  SomeTableau :: KnownNat n => Tableau n -> SomeTableau

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
withNatProxy :: KnownNat n => Proxy n -> (KnownNat n => Tableau n) -> Tableau n
withNatProxy _ t = t

-- | Create an empty tableau with a runtime-specified number of qubits
-- This is a backward-compatible version that returns an existential
emptyTableauN :: Int -> SomeTableau
emptyTableauN n
  | n < 0 = error $ "Invalid qubit count: " ++ show n
  | otherwise = case GHC.TypeNats.someNatVal (fromIntegral n) of
      GHC.TypeNats.SomeNat (proxy :: Proxy n) -> 
        SomeTableau (emptyTableau :: Tableau n)

-- | Run with n qubits
runWith :: Int -> Clifford a -> IO (SomeTableau, a)
runWith n (Clifford f) = 
  f (emptyTableauN n)

-- ============================================================================
-- Examples
-- ============================================================================

-- | Bell state preparation: |00⟩ + |11⟩
bellCircuit :: Clifford Bool
bellCircuit = do
  gate (Local (Hadamard 0))    -- H on qubit 0
  gate (CNOT 0 1)               -- CNOT 0→1
  measurePauli (Pauli (bit 0) (bit 0) 0)  -- measure X⊗X (should be +1)

-- | some helper definitions
pauliX :: Int -> Pauli
pauliX i = Pauli (bit i) 0 0

pauliZ :: Int -> Pauli
pauliZ i = Pauli 0 (bit i) 0

pauliY :: Int -> Pauli
pauliY i = Pauli (bit i) (bit i) 1

-- ============================================================================
-- Backward compatibility helpers for tests
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
