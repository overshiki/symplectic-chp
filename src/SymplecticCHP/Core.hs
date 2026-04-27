{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Core CHP simulator with type-family-based storage abstraction.
-- Supports arbitrary qubit counts with automatic storage selection.
module SymplecticCHP.Core
  ( -- * Pauli operators
    Pauli(..)
  , pattern PauliW
  , pauliX
  , pauliZ
  , pauliY
  , pauliI
    -- * Symplectic form
  , omegaPauli
    -- * Clifford gates
  , LocalSymplectic(..)
  , SymplecticGate(..)
  , applyGate
    -- * Tableau
  , Tableau(..)
  , Lagrangian
  , emptyTableau
  , nQubits
  , getStabilizer
  , getDestabilizer
  , isValid
    -- * Measurement
  , MeasurementResult(..)
  , measure
  , isDeterminate
  , findAntiCommutingStab
    -- * Dynamic interface (runtime-sized)
  , DynamicTableau(..)
  , dynamicEmpty
  , dynamicApplyGate
  , dynamicMeasure
  , dynamicNQubits
  , dynamicIsValid
    -- * SomeTableau (backward compatible)
  , SomeTableau(..)
  ) where

import Data.Bits
import Data.Word
import Data.Proxy (Proxy(..))
import Data.Kind (Type)
import System.Random (randomRIO)
import Control.Monad (foldM)

import GHC.TypeNats
import qualified Data.Vector.Sized as VS
import Data.Vector.Sized (Vector)
import qualified Data.Finite as Finite
import Data.Finite (Finite)

import SymplecticCHP.Storage

-- ============================================================================
-- Pauli Operators with Type-Family Storage
-- ============================================================================

-- | Pauli operator P = i^phase · X^x Z^z
-- The storage type is determined by n at compile time.
data Pauli (n :: Nat) = Pauli
  { xVec :: !(Storage n)  -- ^ X-support (type depends on n)
  , zVec :: !(Storage n)  -- ^ Z-support (type depends on n)
  , phase :: !Int         -- ^ i^phase overall phase (0,1,2,3)
  }

-- | Pattern synonym for backward compatibility when n <= 64
pattern PauliW :: Word64 -> Word64 -> Int -> Pauli n
pattern PauliW x z r <- Pauli x z r
  where
    PauliW x z r = Pauli x z r

{-# COMPLETE PauliW #-}

-- | Smart constructors for common Pauli operators
pauliX :: forall n. TableauSize n => Pauli n
pauliX = Pauli (storageSetBit (storageEmpty @n) 0) (storageEmpty @n) 0

pauliZ :: forall n. TableauSize n => Pauli n
pauliZ = Pauli (storageEmpty @n) (storageSetBit (storageEmpty @n) 0) 0

pauliY :: forall n. TableauSize n => Pauli n
pauliY = Pauli (storageSetBit (storageEmpty @n) 0) (storageSetBit (storageEmpty @n) 0) 1

pauliI :: forall n. TableauSize n => Pauli n
pauliI = Pauli (storageEmpty @n) (storageEmpty @n) 0

-- ============================================================================
-- Symplectic Form
-- ============================================================================

-- | Symplectic inner product ω(P₁, P₂) = x₁·z₂ + z₁·x₂ (mod 2)
-- This determines commutation: ω = 0 means commute, ω = 1 means anticommute.
omegaPauli :: forall n. TableauSize n => Pauli n -> Pauli n -> Bool
omegaPauli (Pauli x1 z1 _) (Pauli x2 z2 _) =
  odd (storagePopCount @n (storageAnd @n x1 z2) + 
       storagePopCount @n (storageAnd @n z1 x2))
{-# INLINE omegaPauli #-}

-- ============================================================================
-- Clifford Gates
-- ============================================================================

-- | Symplectic transformation on single qubit i
data LocalSymplectic 
  = Hadamard !Int      -- ^ H: (x_i, z_i) ↦ (z_i, x_i)
  | Phase !Int         -- ^ S: (x_i, z_i) ↦ (x_i, x_i + z_i)
  deriving (Show, Eq)

-- | Two-qubit symplectic
data SymplecticGate
  = Local !LocalSymplectic
  | CNOT !Int !Int     -- ^ (x_c, z_c, x_t, z_t) ↦ (x_c, z_c+z_t, x_t+x_c, z_t)
  deriving (Show, Eq)

-- | Apply symplectic gate to Pauli operator (conjugation P ↦ U P U†)
applyGate :: forall n. TableauSize n => SymplecticGate -> Pauli n -> Pauli n
applyGate (Local (Hadamard i)) (Pauli x z r) =
  let xi = storageTestBit @n x i
      zi = storageTestBit @n z i
      -- Swap x and z bits
      x' = if zi then storageSetBit @n (storageClearBit @n x i) i 
                 else storageClearBit @n x i
      z' = if xi then storageSetBit @n (storageClearBit @n z i) i
                 else storageClearBit @n z i
      -- Phase correction: Y = iXZ gets -1 phase
      r' = (r + if xi && zi then 2 else 0) `mod` 4
  in Pauli x' z' r'
{-# INLINE applyGate #-}

applyGate (Local (Phase i)) (Pauli x z r) =
  let xi = storageTestBit @n x i
      zi = storageTestBit @n z i
      -- Z' = Z XOR X (add X to Z)
      z' = if xi then storageXor @n z (if storageTestBit @n x i 
                                         then storageSetBit @n (storageEmpty @n) i
                                         else storageEmpty @n)
                 else z
      -- Phase correction: X -> Y adds +1 phase
      r' = (r + if xi && not zi then 1 else 0) `mod` 4
  in Pauli x z' r'
{-# INLINE applyGate #-}

applyGate (CNOT c t) (Pauli x z r) =
  let xc = storageTestBit @n x c
      zc = storageTestBit @n z c
      xt = storageTestBit @n x t
      zt = storageTestBit @n z t
      -- X'[t] = X[t] XOR X[c]
      x' = if xc then storageXor @n x (storageSetBit @n (storageEmpty @n) t) else x
      -- Z'[c] = Z[c] XOR Z[t]
      z' = if zt then storageXor @n z (storageSetBit @n (storageEmpty @n) c) else z
      -- Phase correction
      phaseTerm = if xc && zt then (if xt /= zc then 2 else 0) + 1 else 0
      r' = (r + phaseTerm) `mod` 4
  in Pauli x' z' r'
{-# INLINE applyGate #-}

-- ============================================================================
-- Tableau Structure
-- ============================================================================

-- | Lagrangian subspace: n basis vectors (stabilizers or destabilizers)
type Lagrangian (n :: Nat) = Vector n (Pauli n)

-- | CHP Tableau with n qubits
-- Storage type is determined by n at compile time
data Tableau (n :: Nat) where
  Tableau :: (KnownNat n, TableauSize n) =>
    { stabLagrangian :: Lagrangian n    -- ^ Stabilizers S
    , destabLagrangian :: Lagrangian n  -- ^ Destabilizers D
    } -> Tableau n

-- | Get number of qubits
nQubits :: forall n. KnownNat n => Tableau n -> Int
nQubits _ = fromIntegral (natVal (Proxy @n))

-- | Get stabilizer by index
getStabilizer :: forall n. KnownNat n => Tableau n -> Finite n -> Pauli n
getStabilizer tab i = VS.index (stabLagrangian tab) i

-- | Get destabilizer by index
getDestabilizer :: forall n. KnownNat n => Tableau n -> Finite n -> Pauli n
getDestabilizer tab i = VS.index (destabLagrangian tab) i

-- | Check if tableau is valid (duality condition)
isValid :: forall n. (KnownNat n, TableauSize n) => Tableau n -> Bool
isValid tab =
  let s = stabLagrangian tab
      d = destabLagrangian tab
      -- Check ω(Dᵢ, Sⱼ) = δᵢⱼ
      checkDuality i j =
        let di = VS.index d i
            sj = VS.index s j
            omega = if omegaPauli di sj then 1 else 0
        in if i == j then omega == 1 else omega == 0
  in VS.and $ VS.imap (\i _ ->
       VS.and $ VS.imap (\j _ -> checkDuality i j) s) d

-- | Initial state |0...0⟩: S_i = Z_i, D_i = X_i
emptyTableau :: forall n. (KnownNat n, TableauSize n) => Tableau n
emptyTableau = Tableau stabs destabs
  where
    stabs = VS.generate $ \i ->
      let idx = fromIntegral (Finite.getFinite i)
      in Pauli (storageEmpty @n) (storageSetBit @n (storageEmpty @n) idx) 0
    destabs = VS.generate $ \i ->
      let idx = fromIntegral (Finite.getFinite i)
      in Pauli (storageSetBit @n (storageEmpty @n) idx) (storageEmpty @n) 0

-- ============================================================================
-- Measurement
-- ============================================================================

data MeasurementResult = Determinate Bool | Random Bool
  deriving (Show, Eq)

-- | Test if measurement is deterministic: P must commute with all stabilizers
isDeterminate :: forall n. (KnownNat n, TableauSize n) => Tableau n -> Pauli n -> Bool
isDeterminate tab p =
  VS.all (\s -> not (omegaPauli p s)) (stabLagrangian tab)

-- | Find stabilizer index that anticommutes with P
findAntiCommutingStab :: forall n. (KnownNat n, TableauSize n) => Tableau n -> Pauli n -> Maybe Int
findAntiCommutingStab tab p =
  VS.ifoldl' (\acc i s ->
    case acc of
      Just _ -> acc
      Nothing -> if omegaPauli p s then Just (fromIntegral i) else Nothing) Nothing (stabLagrangian tab)

-- | Measurement as state update
measure :: forall n. (KnownNat n, TableauSize n) => Tableau n -> Pauli n -> IO (Tableau n, MeasurementResult)
measure tab@(Tableau s d) p
  | isDeterminate tab p = do
      let outcome = computePhase tab p
      return (tab, Determinate outcome)
  | otherwise = do
      case findAntiCommutingStab tab p of
        Nothing -> error "Internal error: non-determinate but no anticommuting stabilizer"
        Just j -> do
          let jFin = fromIntegral j
              s_j = VS.index s jFin
              
              -- Update other stabilizers
              newStabBasis = VS.imap (\(k :: Finite n) s_k ->
                if k == jFin 
                  then p
                  else if omegaPauli p s_k
                       then multiplyPauli s_k s_j
                       else s_k) s
              
              -- New destabilizer is the old stabilizer
              newDestabBasis = VS.unsafeUpd (VS.toVector d) [(j, s_j)]
          
          -- Random outcome
          outcome <- randomRIO (0, 1) :: IO Int
          
          -- Update stabilizer with phase
          let p' = p { phase = (phase p + if outcome == 0 then 2 else 0) `mod` 4 }
              finalStabBasis = VS.unsafeUpd (VS.toVector newStabBasis) [(j, p')]
          
          return (Tableau (VS.fromVector finalStabBasis) (VS.fromVector newDestabBasis), 
                  Random (outcome == 1))

-- | Compute deterministic measurement outcome
computePhase :: forall n. (KnownNat n, TableauSize n) => Tableau n -> Pauli n -> Bool
computePhase (Tableau s d) p =
  let scratch = VS.ifoldl' (\acc (j :: Finite n) d_j ->
        if omegaPauli p d_j
          then multiplyPauli acc (VS.index s j)
          else acc) (Pauli (storageEmpty @n) (storageEmpty @n) 0) d
      totalPhase = (phase p - phase scratch) `mod` 4
  in totalPhase == 0

-- | Pauli multiplication with phase tracking
multiplyPauli :: forall n. TableauSize n => Pauli n -> Pauli n -> Pauli n
multiplyPauli (Pauli x1 z1 r1) (Pauli x2 z2 r2) =
  let x = storageXor @n x1 x2
      z = storageXor @n z1 z2
      -- Symplectic phase: i^{x1·z2} (-i)^{z1·x2}
      symPhase = storagePopCount @n (storageAnd @n x1 z2) - 
                 storagePopCount @n (storageAnd @n z1 x2)
      r = (r1 + r2 + symPhase) `mod` 4
  in Pauli x z r

-- ============================================================================
-- Dynamic Tableau (Runtime-sized)
-- ============================================================================

-- | Existential wrapper for runtime-sized tableaux
data DynamicTableau where
  DT :: (KnownNat n, TableauSize n) => Tableau n -> DynamicTableau

-- | Create empty tableau with n qubits (runtime-known)
dynamicEmpty :: Int -> DynamicTableau
dynamicEmpty n
  | n <= 0 = error "Invalid qubit count: must be positive"
  | n <= 64 = case someNatVal (fromIntegral n) of
      Just (SomeNat (proxy :: Proxy n)) -> 
        withKnownNat proxy $ withTableauSize64 @n $ DT (emptyTableau @n)
      Nothing -> error "Failed to create natural"
  | otherwise = case someNatVal (fromIntegral n) of
      Just (SomeNat (proxy :: Proxy n)) ->
        withKnownNat proxy $ withTableauSizeLarge @n $ DT (emptyTableau @n)
      Nothing -> error "Failed to create natural"

-- Helper for dispatching to correct instance
data Dict (c :: Constraint) where
  Dict :: c => Dict c

withTableauSize64 :: forall n r. (KnownNat n, n <= 64) => (TableauSize n => r) -> r
withTableauSize64 f = case (leqProof @n @64) of
  Just _ -> f
  Nothing -> error "Type-level bound check failed"

withTableauSizeLarge :: forall n r. (KnownNat n, n > 64) => (TableauSize n => r) -> r
withTableauSizeLarge f = f

leqProof :: forall n m. (KnownNat n, KnownNat m) => Maybe (Dict (n <= m))
leqProof = 
  let n = natVal (Proxy @n)
      m = natVal (Proxy @m)
  in if n <= m then Just (unsafeCoerce Dict) else Nothing

-- | Apply gate to dynamic tableau
dynamicApplyGate :: SymplecticGate -> DynamicTableau -> DynamicTableau
dynamicApplyGate g (DT tab) = DT (mapTableau (applyGate g) tab)

-- | Measure in dynamic tableau
dynamicMeasure :: DynamicTableau -> DynamicTableau -> IO (DynamicTableau, MeasurementResult)
dynamicMeasure (DT tab) (DT p) = case sameNat (Proxy @(QubitCount tab)) (Proxy @(QubitCount p)) of
  Just Refl -> do (tab', res) <- measure tab p; return (DT tab', res)
  Nothing -> error "Qubit count mismatch"

type family QubitCount (a :: Type) :: Nat
type instance QubitCount (Tableau n) = n
type instance QubitCount (Pauli n) = n

-- | Get qubit count from dynamic tableau
dynamicNQubits :: DynamicTableau -> Int
dynamicNQubits (DT (tab :: Tableau n)) = fromIntegral (natVal (Proxy @n))

-- | Check validity of dynamic tableau
dynamicIsValid :: DynamicTableau -> Bool
dynamicIsValid (DT tab) = isValid tab

-- | Map over tableau (apply function to all Pauli operators)
mapTableau :: (forall n. TableauSize n => Pauli n -> Pauli n) -> Tableau n -> Tableau n
mapTableau f (Tableau s d) = Tableau (VS.map f s) (VS.map f d)

-- | SomeTableau for backward compatibility
data SomeTableau where
  SomeTableau :: (KnownNat n, TableauSize n) => Tableau n -> SomeTableau

-- Helper imports
import Unsafe.Coerce (unsafeCoerce)
import Data.Type.Equality (sameNat, (:~:)(Refl))
