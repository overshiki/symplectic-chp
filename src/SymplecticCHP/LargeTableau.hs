{-# LANGUAGE GADTs #-}
{-# LANGUAGE RankNTypes #-}

-- | Large tableau support using BitVec for arbitrary qubit counts.
-- This module provides a complement to the standard Word64-based tableau.
module SymplecticCHP.LargeTableau
  ( -- * Large Pauli operators
    LargePauli(..)
  , lpPauliX
  , lpPauliZ
  , lpPauliY
  , lpOmega
  , lpMultiply
    -- * Gates (redefined to avoid circular imports)
  , LargeLocalSymplectic(..)
  , LargeSymplecticGate(..)
  , LargeMeasurementResult(..)
    -- * Large Tableau
  , LargeTableau(..)
  , largeEmpty
  , largeNQubits
  , largeApplyGate
  , largeMeasure
    -- * Validation
  , largeIsValid
  , largeIsDeterminate
  ) where

import Data.Bits (Bits(..), popCount, xor)
import Data.Word (Word64)
import SymplecticCHP.BitVec

import System.Random (randomRIO)
import qualified Data.Vector as V

-- ============================================================================
-- Gate Types (local copies to avoid circular imports)
-- ============================================================================

data LargeLocalSymplectic 
  = LargeHadamard !Int
  | LargePhase !Int
  deriving (Show, Eq)

data LargeSymplecticGate
  = LargeLocal !LargeLocalSymplectic
  | LargeCNOT !Int !Int
  deriving (Show, Eq)

data LargeMeasurementResult = LargeDeterminate Bool | LargeRandom Bool
  deriving (Show, Eq)

-- ============================================================================
-- Large Pauli (using BitVec)
-- ============================================================================

-- | Pauli operator for arbitrary qubit count using BitVec
data LargePauli = LargePauli
  { lpX :: !BitVec
  , lpZ :: !BitVec
  , lpPhase :: !Int
  , lpNQubits :: !Int
  }
  deriving (Eq, Show)

-- | Create Pauli X on qubit i
lpPauliX :: Int -> Int -> LargePauli
lpPauliX n i = LargePauli (bvSetBit (bvEmpty n) i) (bvEmpty n) 0 n

-- | Create Pauli Z on qubit i  
lpPauliZ :: Int -> Int -> LargePauli
lpPauliZ n i = LargePauli (bvEmpty n) (bvSetBit (bvEmpty n) i) 0 n

-- | Create Pauli Y on qubit i
lpPauliY :: Int -> Int -> LargePauli
lpPauliY n i = LargePauli (bvSetBit (bvEmpty n) i) (bvSetBit (bvEmpty n) i) 1 n

-- | Symplectic inner product
lpOmega :: LargePauli -> LargePauli -> Bool
lpOmega (LargePauli x1 z1 _ n1) (LargePauli x2 z2 _ n2)
  | n1 /= n2 = error "lpOmega: qubit count mismatch"
  | otherwise = odd (bvPopCount (bvAnd x1 z2) + bvPopCount (bvAnd z1 x2))

-- | Pauli multiplication
lpMultiply :: LargePauli -> LargePauli -> LargePauli
lpMultiply (LargePauli x1 z1 r1 n1) (LargePauli x2 z2 r2 n2)
  | n1 /= n2 = error "lpMultiply: qubit count mismatch"
  | otherwise =
      let x = bvXor x1 x2
          z = bvXor z1 z2
          symPhase = bvPopCount (bvAnd x1 z2) - bvPopCount (bvAnd z1 x2)
          r = (r1 + r2 + symPhase) `mod` 4
      in LargePauli x z r n1

-- ============================================================================
-- Large Tableau
-- ============================================================================

-- | Tableau for arbitrary qubit count
data LargeTableau = LargeTableau
  { ltStabs :: !(V.Vector LargePauli)
  , ltDestabs :: !(V.Vector LargePauli)
  , ltN :: !Int
  }
  deriving (Show)

-- | Create empty tableau (|0...0⟩ state)
largeEmpty :: Int -> LargeTableau
largeEmpty n
  | n <= 0 = error "largeEmpty: n must be positive"
  | otherwise = LargeTableau stabs destabs n
  where
    stabs = V.fromList [lpPauliZ n i | i <- [0..n-1]]
    destabs = V.fromList [lpPauliX n i | i <- [0..n-1]]

-- | Get qubit count
largeNQubits :: LargeTableau -> Int
largeNQubits = ltN

-- | Apply gate to large tableau
largeApplyGate :: LargeSymplecticGate -> LargeTableau -> LargeTableau
largeApplyGate g (LargeTableau s d n) =
  LargeTableau (V.map (lpApplyGate g) s) (V.map (lpApplyGate g) d) n

-- | Apply gate to large Pauli
lpApplyGate :: LargeSymplecticGate -> LargePauli -> LargePauli
lpApplyGate (LargeLocal (LargeHadamard i)) (LargePauli x z r n) =
  let xi = bvTestBit x i
      zi = bvTestBit z i
      x' = if zi then bvSetBit (bvClearBit x i) i else bvClearBit x i
      z' = if xi then bvSetBit (bvClearBit z i) i else bvClearBit z i
      r' = (r + if xi && zi then 2 else 0) `mod` 4
  in LargePauli x' z' r' n

lpApplyGate (LargeLocal (LargePhase i)) (LargePauli x z r n) =
  let xi = bvTestBit x i
      zi = bvTestBit z i
      -- Z' = Z XOR X
      z' = if xi then bvXor z (bvSetBit (bvEmpty n) i) else z
      r' = (r + if xi && not zi then 1 else 0) `mod` 4
  in LargePauli x z' r' n

lpApplyGate (LargeCNOT c t) (LargePauli x z r n) =
  let xc = bvTestBit x c
      zc = bvTestBit z c
      xt = bvTestBit x t
      zt = bvTestBit z t
      -- X'[t] = X[t] XOR X[c]
      x' = if xc then bvXor x (bvSetBit (bvEmpty n) t) else x
      -- Z'[c] = Z[c] XOR Z[t]
      z' = if zt then bvXor z (bvSetBit (bvEmpty n) c) else z
      phaseTerm = if xc && zt then (if xt /= zc then 2 else 0) + 1 else 0
      r' = (r + phaseTerm) `mod` 4
  in LargePauli x' z' r' n

-- | Measurement on large tableau
largeMeasure :: LargeTableau -> LargePauli -> IO (LargeTableau, LargeMeasurementResult)
largeMeasure tab@(LargeTableau s d n) p
  | largeIsDeterminate tab p = do
      let outcome = largeComputePhase tab p
      return (tab, LargeDeterminate outcome)
  | otherwise = do
      case largeFindAntiCommuting tab p of
        Nothing -> error "Internal error in largeMeasure"
        Just j -> do
          let s_j = s V.! j
              -- Update other stabilizers
              newStabs = V.imap (\k s_k ->
                if k == j
                  then p
                  else if lpOmega p s_k
                       then lpMultiply s_k s_j
                       else s_k) s
              -- New destabilizer is old stabilizer
              newDestabs = d V.// [(j, s_j)]
          
          outcome <- randomRIO (0, 1) :: IO Int
          let p' = p { lpPhase = (lpPhase p + if outcome == 0 then 2 else 0) `mod` 4 }
              finalStabs = newStabs V.// [(j, p')]
          
          return (LargeTableau finalStabs newDestabs n, LargeRandom (outcome == 1))

-- | Check if measurement is deterministic
largeIsDeterminate :: LargeTableau -> LargePauli -> Bool
largeIsDeterminate (LargeTableau s _ _) p =
  V.all (\s_i -> not (lpOmega p s_i)) s

-- | Find anticommuting stabilizer
largeFindAntiCommuting :: LargeTableau -> LargePauli -> Maybe Int
largeFindAntiCommuting (LargeTableau s _ _) p =
  V.ifoldl' (\acc i s_i ->
    case acc of
      Just _ -> acc
      Nothing -> if lpOmega p s_i then Just i else Nothing) Nothing s

-- | Compute deterministic measurement outcome
largeComputePhase :: LargeTableau -> LargePauli -> Bool
largeComputePhase (LargeTableau s d _) p =
  let scratch = V.ifoldl' (\acc j d_j ->
        if lpOmega p d_j
          then lpMultiply acc (s V.! j)
          else acc) (LargePauli (bvEmpty (lpNQubits p)) (bvEmpty (lpNQubits p)) 0 (lpNQubits p)) d
      totalPhase = (lpPhase p - lpPhase scratch) `mod` 4
  in totalPhase == 0

-- | Check tableau validity (duality condition)
largeIsValid :: LargeTableau -> Bool
largeIsValid (LargeTableau s d n) =
  -- Check ω(Dᵢ, Sⱼ) = δᵢⱼ
  V.all (\i ->
    V.all (\j ->
      let di = d V.! i
          sj = s V.! j
          omega = if lpOmega di sj then 1 else 0
      in if i == j then omega == 1 else omega == 0
    ) (V.fromList [0..n-1])
  ) (V.fromList [0..n-1])
