{-# OPTIONS_GHC -fno-warn-orphans #-}

module Test.Arbitrary where

import Test.QuickCheck
import SymplecticCHP
import Data.Bits ((.&.), bit)
import Data.Word (Word64)

instance Arbitrary Pauli where
  arbitrary = do
    x <- chooseInt (0, 0xFFFF) :: Gen Int
    z <- chooseInt (0, 0xFFFF) :: Gen Int
    p <- chooseInt (0, 3)
    return $ Pauli (fromIntegral x) (fromIntegral z) p
  
  shrink (Pauli x z p) = 
    [Pauli x' z' p' | x' <- shrink x, x' >= 0, z' <- shrink z, z' >= 0, p' <- [0..p]]

instance Arbitrary LocalSymplectic where
  arbitrary = oneof 
    [ Hadamard <$> chooseInt (0, 10)
    , Phase <$> chooseInt (0, 10)
    ]

instance Arbitrary SymplecticGate where
  arbitrary = frequency
    [ (3, Local <$> arbitrary)
    , (1, do c <- chooseInt (0, 10)
             t <- chooseInt (0, 10)
             return $ if c /= t then CNOT c t else Local (Hadamard 0))
    ]

newtype SmallN = SmallN { unSmallN :: Int }
  deriving (Show, Eq)

instance Arbitrary SmallN where
  arbitrary = SmallN <$> chooseInt (1, 10)
  shrink (SmallN n) = SmallN <$> [n' | n' <- shrink n, n' > 0]