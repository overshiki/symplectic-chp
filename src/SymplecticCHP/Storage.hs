{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeFamilyDependencies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Type family-based storage selection for arbitrary-qubit support.
-- Storage type is determined at compile time by qubit count:
-- - n <= 64: Word64 (fast, unboxed)
-- - n > 64: BitVec n (chunked storage)
module SymplecticCHP.Storage
  ( -- * Storage type family
    Storage
  , StorageType
    -- * Storage operations type class
  , TableauSize(..)
    -- * BitVec for large tableaux
  , BitVec(..)
  , bitVecEmpty
  , bitVecXor
  , bitVecAnd
  , bitVecTestBit
  , bitVecSetBit
  , bitVecClearBit
  , bitVecPopCount
  , bitVecCapacity
    -- * Re-exports
  , module Data.Word
  ) where

import Data.Bits (Bits(..), popCount, xor)
import Data.Kind (Type)
import Data.Proxy (Proxy(..))
import Data.Word (Word64)
import GHC.TypeNats
import qualified Data.Vector.Unboxed as V
import qualified Data.Vector.Unboxed.Mutable as VM
import Control.Monad.ST (runST)

-- ============================================================================
-- Type Family for Storage Selection
-- ============================================================================

-- | Closed type family selecting storage based on qubit count.
-- Resolved at compile time with zero runtime cost.
type family Storage (n :: Nat) = r | r -> n where
  Storage n = StorageType n

-- | Helper type family for the actual selection
type family StorageType (n :: Nat) :: Type where
  StorageType 0 = Word64  -- Edge case: empty tableau
  StorageType 1 = Word64
  StorageType 2 = Word64
  StorageType 3 = Word64
  StorageType 4 = Word64
  StorageType 5 = Word64
  StorageType 6 = Word64
  StorageType 7 = Word64
  StorageType 8 = Word64
  StorageType 9 = Word64
  StorageType 10 = Word64
  StorageType 11 = Word64
  StorageType 12 = Word64
  StorageType 13 = Word64
  StorageType 14 = Word64
  StorageType 15 = Word64
  StorageType 16 = Word64
  StorageType 17 = Word64
  StorageType 18 = Word64
  StorageType 19 = Word64
  StorageType 20 = Word64
  StorageType 21 = Word64
  StorageType 22 = Word64
  StorageType 23 = Word64
  StorageType 24 = Word64
  StorageType 25 = Word64
  StorageType 26 = Word64
  StorageType 27 = Word64
  StorageType 28 = Word64
  StorageType 29 = Word64
  StorageType 30 = Word64
  StorageType 31 = Word64
  StorageType 32 = Word64
  StorageType 33 = Word64
  StorageType 34 = Word64
  StorageType 35 = Word64
  StorageType 36 = Word64
  StorageType 37 = Word64
  StorageType 38 = Word64
  StorageType 39 = Word64
  StorageType 40 = Word64
  StorageType 41 = Word64
  StorageType 42 = Word64
  StorageType 43 = Word64
  StorageType 44 = Word64
  StorageType 45 = Word64
  StorageType 46 = Word64
  StorageType 47 = Word64
  StorageType 48 = Word64
  StorageType 49 = Word64
  StorageType 50 = Word64
  StorageType 51 = Word64
  StorageType 52 = Word64
  StorageType 53 = Word64
  StorageType 54 = Word64
  StorageType 55 = Word64
  StorageType 56 = Word64
  StorageType 57 = Word64
  StorageType 58 = Word64
  StorageType 59 = Word64
  StorageType 60 = Word64
  StorageType 61 = Word64
  StorageType 62 = Word64
  StorageType 63 = Word64
  StorageType 64 = Word64
  StorageType n = BitVec n

-- ============================================================================
-- BitVec: Chunked Storage for Large Tableaux
-- ============================================================================

-- | Arbitrary-length bit vector stored in Word64 chunks.
-- The type parameter n tracks the qubit count at the type level.
newtype BitVec (n :: Nat) = BitVec
  { unBitVec :: V.Vector Word64  -- ^ Chunked storage
  }
  deriving (Eq, Show)

-- | Create an empty BitVec for n qubits.
-- The number of chunks is ceil(n/64).
bitVecEmpty :: forall n. KnownNat n => BitVec n
bitVecEmpty = 
  let n = fromIntegral (natVal (Proxy @n))
      chunks = max 1 ((n + 63) `div` 64)
  in BitVec (V.replicate chunks 0)
{-# INLINE bitVecEmpty #-}

-- | Element-wise XOR (requires same capacity).
bitVecXor :: BitVec n -> BitVec n -> BitVec n
bitVecXor (BitVec a) (BitVec b) = BitVec (V.zipWith xor a b)
{-# INLINE bitVecXor #-}

-- | Element-wise AND.
bitVecAnd :: BitVec n -> BitVec n -> BitVec n
bitVecAnd (BitVec a) (BitVec b) = BitVec (V.zipWith (.&.) a b)
{-# INLINE bitVecAnd #-}

-- | Test bit at index.
bitVecTestBit :: BitVec n -> Int -> Bool
bitVecTestBit (BitVec v) i =
  let (word, bit) = i `divMod` 64
  in if word < V.length v
     then (V.unsafeIndex v word) `testBit` bit
     else False  -- Out of bounds returns False
{-# INLINE bitVecTestBit #-}

-- | Set bit at index.
bitVecSetBit :: BitVec n -> Int -> BitVec n
bitVecSetBit (BitVec v) i =
  let (word, bit) = i `divMod` 64
  in if word < V.length v
     then let oldVal = V.unsafeIndex v word
              newVal = oldVal `setBit` bit
          in BitVec (V.unsafeUpd v [(word, newVal)])
     else BitVec v  -- Out of bounds: no change
{-# INLINE bitVecSetBit #-}

-- | Clear bit at index.
bitVecClearBit :: BitVec n -> Int -> BitVec n
bitVecClearBit (BitVec v) i =
  let (word, bit) = i `divMod` 64
  in if word < V.length v
     then let oldVal = V.unsafeIndex v word
              newVal = oldVal `clearBit` bit
          in BitVec (V.unsafeUpd v [(word, newVal)])
     else BitVec v
{-# INLINE bitVecClearBit #-}

-- | Population count across all chunks.
bitVecPopCount :: BitVec n -> Int
bitVecPopCount (BitVec v) = V.sum (V.map popCount v)
{-# INLINE bitVecPopCount #-}

-- | Capacity in bits (64 * chunks).
bitVecCapacity :: BitVec n -> Int
bitVecCapacity (BitVec v) = V.length v * 64
{-# INLINE bitVecCapacity #-}

-- ============================================================================
-- TableauSize: Operations Type Class
-- ============================================================================

-- | Type class providing operations for a given tableau size.
-- Instances are selected at compile time based on n.
class KnownNat n => TableauSize (n :: Nat) where
  -- | Empty storage
  storageEmpty :: Storage n
  
  -- | XOR operation
  storageXor :: Storage n -> Storage n -> Storage n
  
  -- | AND operation
  storageAnd :: Storage n -> Storage n -> Storage n
  
  -- | Test bit
  storageTestBit :: Storage n -> Int -> Bool
  
  -- | Set bit
  storageSetBit :: Storage n -> Int -> Storage n
  
  -- | Clear bit
  storageClearBit :: Storage n -> Int -> Storage n
  
  -- | Population count
  storagePopCount :: Storage n -> Int
  
  -- | Capacity in qubits
  storageCapacity :: proxy n -> Int

-- Instance for n <= 64 (Word64)
-- Using overlappable to allow the catch-all instance below
instance {-# OVERLAPPABLE #-} 
  ( KnownNat n
  , n <= 64
  , Storage n ~ Word64
  ) => TableauSize n where
  
  storageEmpty = 0
  {-# INLINE storageEmpty #-}
  
  storageXor = xor
  {-# INLINE storageXor #-}
  
  storageAnd = (.&.)
  {-# INLINE storageAnd #-}
  
  storageTestBit = testBit
  {-# INLINE storageTestBit #-}
  
  storageSetBit w i = w `setBit` i
  {-# INLINE storageSetBit #-}
  
  storageClearBit w i = w `clearBit` i
  {-# INLINE storageClearBit #-}
  
  storagePopCount = popCount
  {-# INLINE storagePopCount #-}
  
  storageCapacity _ = 64
  {-# INLINE storageCapacity #-}

-- Instance for n > 64 (BitVec)
-- This will be selected when n > 64 due to the type family
instance {-# OVERLAPPING #-}
  ( KnownNat n
  , n > 64
  , Storage n ~ BitVec n
  ) => TableauSize n where
  
  storageEmpty = bitVecEmpty @n
  {-# INLINE storageEmpty #-}
  
  storageXor = bitVecXor
  {-# INLINE storageXor #-}
  
  storageAnd = bitVecAnd
  {-# INLINE storageAnd #-}
  
  storageTestBit = bitVecTestBit
  {-# INLINE storageTestBit #-}
  
  storageSetBit = bitVecSetBit
  {-# INLINE storageSetBit #-}
  
  storageClearBit = bitVecClearBit
  {-# INLINE storageClearBit #-}
  
  storagePopCount = bitVecPopCount
  {-# INLINE storagePopCount #-}
  
  storageCapacity _ = fromIntegral (natVal (Proxy @n))
  {-# INLINE storageCapacity #-}
