{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

-- | Simple BitVec implementation for arbitrary-qubit support.
-- This is a pragmatic alternative to the full type-family approach.
module SymplecticCHP.BitVec
  ( BitVec
  , bvEmpty
  , bvFromWord64
  , bvToWord64
  , bvXor
  , bvAnd
  , bvTestBit
  , bvSetBit
  , bvClearBit
  , bvPopCount
  , bvShow
    -- * Re-export for compatibility
  , Word64
  ) where

import Data.Bits (Bits(..), popCount, xor)
import Data.Word (Word64)
import qualified Data.Vector.Unboxed as V

-- | Arbitrary-length bit vector
data BitVec = BitVec
  { bvBits :: !(V.Vector Word64)  -- ^ Chunked storage
  , bvSize :: !Int                -- ^ Number of bits
  }
  deriving (Eq)

instance Show BitVec where
  show = bvShow

-- | Create empty BitVec for n bits
bvEmpty :: Int -> BitVec
bvEmpty n
  | n <= 0 = error "bvEmpty: size must be positive"
  | otherwise = 
      let chunks = (n + 63) `div` 64
      in BitVec (V.replicate chunks 0) n

-- | Create from Word64 (for n <= 64)
bvFromWord64 :: Word64 -> BitVec
bvFromWord64 w = BitVec (V.singleton w) 64

-- | Convert to Word64 (only valid for n <= 64)
bvToWord64 :: BitVec -> Word64
bvToWord64 (BitVec v n)
  | n <= 64 && V.length v >= 1 = V.head v
  | otherwise = error "bvToWord64: BitVec too large"

-- | XOR operation
bvXor :: BitVec -> BitVec -> BitVec
bvXor (BitVec a sa) (BitVec b sb)
  | sa /= sb = error "bvXor: size mismatch"
  | otherwise = BitVec (V.zipWith xor a b) sa

-- | AND operation  
bvAnd :: BitVec -> BitVec -> BitVec
bvAnd (BitVec a sa) (BitVec b sb)
  | sa /= sb = error "bvAnd: size mismatch"
  | otherwise = BitVec (V.zipWith (.&.) a b) sa

-- | Test bit
bvTestBit :: BitVec -> Int -> Bool
bvTestBit (BitVec v n) i
  | i < 0 || i >= n = False  -- Out of bounds
  | otherwise = 
      let (word, bit) = i `divMod` 64
      in (V.unsafeIndex v word) `testBit` bit

-- | Set bit
bvSetBit :: BitVec -> Int -> BitVec
bvSetBit bv@(BitVec v n) i
  | i < 0 || i >= n = bv  -- Out of bounds: no change
  | otherwise =
      let (word, bit) = i `divMod` 64
          oldVal = V.unsafeIndex v word
          newVal = oldVal `setBit` bit
      in BitVec (V.unsafeUpd v [(word, newVal)]) n

-- | Clear bit
bvClearBit :: BitVec -> Int -> BitVec
bvClearBit bv@(BitVec v n) i
  | i < 0 || i >= n = bv
  | otherwise =
      let (word, bit) = i `divMod` 64
          oldVal = V.unsafeIndex v word
          newVal = oldVal `clearBit` bit
      in BitVec (V.unsafeUpd v [(word, newVal)]) n

-- | Population count
bvPopCount :: BitVec -> Int
bvPopCount (BitVec v _) = V.sum (V.map popCount v)

-- | Show as string of bits
bvShow :: BitVec -> String
bvShow (BitVec v n) = 
  "BitVec[" ++ show n ++ "] " ++ 
  concatMap showChunk (V.toList v)
  where
    showChunk w = [if testBit w i then '1' else '0' | i <- [0..63]]
