{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ViewPatterns #-}

module SymplecticCHP where

import Data.Bits
import Data.Word
-- import qualified Data.Vector.Unboxed as V
import qualified Data.List as V
import Control.Monad (foldM, when)
import System.Random (randomRIO)
import Data.List (sortOn, groupBy)
import Data.Function (on)

-- helper function for Data.List
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

-- | ω(v1, v2) ∈ {0,1} as integer
omega :: Pauli -> Pauli -> Int
omega (Pauli x1 z1 _) (Pauli x2 z2 _) = 
  popCount ((x1 .&. z2) `xor` (z1 .&. x2)) `mod` 2

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
-- Tableau as Lagrangian Subspace
-- ============================================================================

-- | The tableau represents a maximal isotropic subspace (Lagrangian) of the 
-- symplectic vector space. It consists of:
--   - Stabilizers S_i (rows 0..n-1): isotropic generators, ω(S_i, S_j) = 0
--   - Destabilizers D_i (rows n..2n-1): dual basis, ω(D_i, S_j) = δ_ij

data Tableau = Tableau
  { nQubits :: !Int
  , rows :: [Pauli]  -- ^ 2n rows: [S_0..S_{n-1}, D_0..D_{n-1}]
  } 
  deriving (Show)

generate :: Int -> (Int -> a) -> [a]
generate n f = map f [0 .. n - 1]

-- | Initial state |0...0⟩: S_i = Z_i, D_i = X_i
emptyTableau :: Int -> Tableau
emptyTableau n = Tableau n $ generate (2*n) $ \i ->
  if i < n 
    then Pauli 0 (bit i) 0        -- Z_i stabilizer
    else Pauli (bit (i-n)) 0 0    -- X_{i-n} destabilizer

-- | Verify isotropic condition: all stabilizers commute
isValid :: Tableau -> Bool
isValid (Tableau n rs) = 
  all (\i -> all (\j -> symplecticForm (rs V.!! i) (rs V.!! j)) [0..n-1]) [0..n-1]
  && all (\i -> omega (rs V.!! (i+n)) (rs V.!! i) == 1) [0..n-1]  -- Dual pairing

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
  let xi = testBit x i; zi = testBit z i
      x' = if xi then clearBit z i else if zi then setBit z i else z
      z' = if zi then clearBit x i else if xi then setBit x i else x
      -- Phase: H X H† = Z, H Z H† = X, H Y H† = -Y
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
evolveTableau :: Tableau -> SymplecticGate -> Tableau
evolveTableau (Tableau n rs) g = Tableau n (V.map (applyGate g) rs)

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
isDeterminate :: Tableau -> Pauli -> Bool
isDeterminate (Tableau n rs) p = 
  all (\i -> symplecticForm p (rs V.!! i)) [0..n-1]

-- | Find which destabilizer anti-commutes with P (for random case)
findAntiCommutingDestab :: Tableau -> Pauli -> Maybe Int
findAntiCommutingDestab (Tableau n rs) p =
  case filter (\i -> not (symplecticForm p (rs V.!! (i+n)))) [0..n-1] of
    []    -> Nothing
    (i:_) -> Just i

-- | Measurement as state update
measure :: Tableau -> Pauli -> IO (Tableau, MeasurementResult)
measure tab@(Tableau n rs) p
  | isDeterminate tab p = do
      -- Deterministic: decompose P in stabilizer basis
      -- P = (-1)^b ∏_i S_i^{a_i}, outcome = (-1)^b
      let outcome = computePhase tab p  -- True = +1, False = -1
      return (tab, Determinate outcome)
  
  | otherwise = do
      -- Random: find anti-commuting destabilizer D_j
      let Just j = findAntiCommutingDestab tab p
          d_j = rs V.!! (j+n)  -- destabilizer D_j
          s_j = rs V.!! j      -- old stabilizer S_j
          
          imap :: (Int -> a -> b) -> [a] -> [b]
          imap f xs = map (\(i, x) -> f i x) (zip [0 .. length xs - 1] xs)

          -- Update: make other stabilizers commute with new P
          rs' = imap (\i row ->
            if i < n && i /= j && not (symplecticForm p (rs V.!! i))
              then multiply row d_j  -- S_i ↦ S_i · D_j to restore [S_i, P] = 0
              else if i == j then p else row) rs
          
      -- Random outcome ±1
      outcome <- (== 1) <$> (randomRIO (0, 1) :: IO Int) 
      let -- Update phase of new stabilizer based on outcome
          Pauli x z r = p
          p' = Pauli x z ((r + if outcome then 0 else 2) `mod` 4)
          rs'' = rs' // [(j, p')]
      
      return (Tableau n rs'', Random outcome)

-- | Compute deterministic measurement outcome via symplectic decomposition
computePhase :: Tableau -> Pauli -> Bool
computePhase (Tableau n rs) p = 
  -- Use destabilizer basis to find coefficients
  -- P = ∏_j D_j^{c_j} · (phase factor), extract phase from product
  let scratch = foldl (\acc j -> 
        if omega p (rs V.!! (j+n)) == 1  -- if [P, D_j] ≠ 0, then P contains S_j
          then multiply acc (rs V.!! j)
          else acc) (Pauli 0 0 0) [0..n-1]
  in phase scratch `mod` 4 == 0  -- +1 if phase ≡ 0 (mod 4)

-- ============================================================================
-- Monadic Interface
-- ============================================================================

newtype Clifford a = Clifford { runClifford :: Tableau -> IO (Tableau, a) }

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
gate g = Clifford $ \t -> return (evolveTableau t g, ())

-- | Measure Pauli operator
measurePauli :: Pauli -> Clifford Bool
measurePauli p = Clifford $ \t -> do
  (t', res) <- measure t p
  case res of
    Determinate b -> return (t', b)
    Random b      -> return (t', b)

-- | Get current tableau state
getTableau :: Clifford Tableau
getTableau = Clifford $ \t -> return (t, t)

-- | Run with n qubits
runWith :: Int -> Clifford a -> IO (Tableau, a)
runWith n (Clifford f) = f (emptyTableau n)

-- ============================================================================
-- Examples
-- ============================================================================

-- | Bell state preparation: |00⟩ + |11⟩
bellCircuit :: Clifford Bool
bellCircuit = do
  gate (Local (Hadamard 0))    -- H on qubit 0
  gate (CNOT 0 1)               -- CNOT 0→1
  measurePauli (Pauli (bit 0) (bit 0) 0)  -- measure X⊗X (should be +1)

-- -- | Steane code stabilizer measurement (simplified)
-- steaneMeasure :: Clifford [Bool]
-- steaneMeasure = do
--   -- X-type stabilizers of Steane [[7,1,3]] code
--   let xStabs = map (\mask -> Pauli mask 0 0) 
--                [0b0001011, 0b0010110, 0b0101100]
--   mapM measurePauli xStabs

-- | some helper definitions
pauliX :: Int -> Pauli
pauliX i = Pauli (bit i) 0 0

pauliZ :: Int -> Pauli
pauliZ i = Pauli 0 (bit i) 0

pauliY :: Int -> Pauli
pauliY i = Pauli (bit i) (bit i) 1