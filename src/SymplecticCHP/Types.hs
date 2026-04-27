{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE AllowAmbiguousTypes #-}

-- | Type definitions with storage abstraction.
-- This module provides the core types that work with both
-- Word64 (n <= 64) and BitVec (n > 64).
module SymplecticCHP.Types
  ( -- * Storage selection
    Storage
    -- * Pauli operators
  , Pauli(..)
  , omegaPauli
  , multiplyPauli
    -- * Gates
  , LocalSymplectic(..)
  , SymplecticGate(..)
    -- * Tableau
  , Tableau(..)
  , Lagrangian
  , emptyTableau
  , mapLagrangian
  , indexLagrangian
    -- * SomeTableau (existential wrapper)
  , SomeTableau(..)
  , nQubitsSome
    -- * Utilities
  , intToFinite
  ) where

import Data.Bits (Bits(..), popCount, xor)
import Data.Word (Word64)
import Data.Proxy (Proxy(..))
import GHC.TypeNats
import qualified Data.Vector.Sized as VS
import Data.Vector.Sized (Vector)
import qualified Data.Finite as Finite
import Data.Finite (Finite)

-- ============================================================================
-- Storage Type Family
-- ============================================================================

-- | Storage type selected by qubit count.
-- For n <= 64: Word64 (fast, unboxed)
-- For n > 64: BitVec (chunked Vector Word64)
type family Storage (n :: Nat) :: * where
  Storage 0 = Word64
  Storage 1 = Word64
  Storage 2 = Word64
  Storage 3 = Word64
  Storage 4 = Word64
  Storage 5 = Word64
  Storage 6 = Word64
  Storage 7 = Word64
  Storage 8 = Word64
  Storage 9 = Word64
  Storage 10 = Word64
  Storage 11 = Word64
  Storage 12 = Word64
  Storage 13 = Word64
  Storage 14 = Word64
  Storage 15 = Word64
  Storage 16 = Word64
  Storage 17 = Word64
  Storage 18 = Word64
  Storage 19 = Word64
  Storage 20 = Word64
  Storage 21 = Word64
  Storage 22 = Word64
  Storage 23 = Word64
  Storage 24 = Word64
  Storage 25 = Word64
  Storage 26 = Word64
  Storage 27 = Word64
  Storage 28 = Word64
  Storage 29 = Word64
  Storage 30 = Word64
  Storage 31 = Word64
  Storage 32 = Word64
  Storage 33 = Word64
  Storage 34 = Word64
  Storage 35 = Word64
  Storage 36 = Word64
  Storage 37 = Word64
  Storage 38 = Word64
  Storage 39 = Word64
  Storage 40 = Word64
  Storage 41 = Word64
  Storage 42 = Word64
  Storage 43 = Word64
  Storage 44 = Word64
  Storage 45 = Word64
  Storage 46 = Word64
  Storage 47 = Word64
  Storage 48 = Word64
  Storage 49 = Word64
  Storage 50 = Word64
  Storage 51 = Word64
  Storage 52 = Word64
  Storage 53 = Word64
  Storage 54 = Word64
  Storage 55 = Word64
  Storage 56 = Word64
  Storage 57 = Word64
  Storage 58 = Word64
  Storage 59 = Word64
  Storage 60 = Word64
  Storage 61 = Word64
  Storage 62 = Word64
  Storage 63 = Word64
  Storage 64 = Word64
  Storage n = BitVec n

-- | BitVec for large tableaux (n > 64)
newtype BitVec (n :: Nat) = BitVec (VS.Vector (Chunks n) Word64)
  deriving (Eq, Show)

-- | Calculate number of Word64 chunks needed
type family Chunks (n :: Nat) :: Nat where
  Chunks n = Div64 (n + 63)

type family Div64 (n :: Nat) :: Nat where
  Div64 0 = 0
  Div64 1 = 1
  Div64 n = 1 + Div64 (n - 64)

-- ============================================================================
-- Pauli Operators
-- ============================================================================

-- | Pauli operator with storage type determined by qubit count
data Pauli (n :: Nat) = Pauli
  { xVec :: !(Storage n)
  , zVec :: !(Storage n)
  , phase :: !Int
  }
  deriving (Eq, Show)

-- | Symplectic inner product
omegaPauli :: KnownNat n => Pauli n -> Pauli n -> Bool
omegaPauli p1 p2 = odd (omegaSum p1 p2)

-- | Compute omega sum (for internal use)
omegaSum :: KnownNat n => Pauli n -> Pauli n -> Int
omegaSum (Pauli x1 z1 _) (Pauli x2 z2 _) =
  case sameNat (Proxy @n) (Proxy @64) of
    Just Refl ->
      -- Word64 case
      popCount (x1 .&. z2) + popCount (z1 .&. x2)
    Nothing ->
      case cmpNat (Proxy @n) (Proxy @64) of
        LTI -> popCount (x1 .&. z2) + popCount (z1 .&. x2)
        EQI -> popCount (x1 .&. z2) + popCount (z1 .&. x2)
        GTI -> error "BitVec not yet implemented"

-- | Pauli multiplication
multiplyPauli :: KnownNat n => Pauli n -> Pauli n -> Pauli n
multiplyPauli (Pauli x1 z1 r1) (Pauli x2 z2 r2) =
  let x = xorStorage x1 x2
      z = xorStorage z1 z2
      r = (r1 + r2) `mod` 4
  in Pauli x z r

-- | XOR for storage (handles both Word64 and BitVec)
xorStorage :: KnownNat n => Storage n -> Storage n -> Storage n
xorStorage = case sameNat (Proxy @n) (Proxy @64) of
  Just Refl -> xor
  Nothing -> case cmpNat (Proxy @n) (Proxy @64) of
    LTI -> xor
    EQI -> xor
    GTI -> \_ _ -> error "BitVec not yet implemented"

-- ============================================================================
-- Gates
-- ============================================================================

data LocalSymplectic 
  = Hadamard !Int
  | Phase !Int
  deriving (Show, Eq)

data SymplecticGate
  = Local !LocalSymplectic
  | CNOT !Int !Int
  deriving (Show, Eq)

-- ============================================================================
-- Tableau
-- ============================================================================

type Lagrangian (n :: Nat) = Vector n (Pauli n)

data Tableau (n :: Nat) where
  Tableau :: KnownNat n =>
    { stabLagrangian :: Lagrangian n
    , destabLagrangian :: Lagrangian n
    } -> Tableau n

-- | Map over a Lagrangian
mapLagrangian :: (Pauli n -> Pauli n) -> Lagrangian n -> Lagrangian n
mapLagrangian = VS.map

-- | Index into a Lagrangian
indexLagrangian :: Lagrangian n -> Finite n -> Pauli n
indexLagrangian = VS.index

-- | Initial state |0...0⟩
emptyTableau :: forall n. KnownNat n => Tableau n
emptyTableau = Tableau stabs destabs
  where
    n = fromIntegral (natVal (Proxy @n))
    stabs = VS.generate $ \i ->
      let idx = fromIntegral (Finite.getFinite i)
      in Pauli 0 (bit idx) 0
    destabs = VS.generate $ \i ->
      let idx = fromIntegral (Finite.getFinite i)
      in Pauli (bit idx) 0 0

-- | Convert Int to Finite safely
intToFinite :: forall n. KnownNat n => Int -> Maybe (Finite n)
intToFinite i 
  | i >= 0 = Finite.packFinite (fromIntegral i)
  | otherwise = Nothing

-- ============================================================================
-- Existential Wrapper
-- ============================================================================

data SomeTableau where
  SomeTableau :: KnownNat n => Tableau n -> SomeTableau

nQubitsSome :: SomeTableau -> Int
nQubitsSome (SomeTableau (tab :: Tableau n)) = 
  fromIntegral (natVal (Proxy @n))
