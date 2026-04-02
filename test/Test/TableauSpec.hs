{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}

module Test.TableauSpec where

import Test.Hspec
import Test.QuickCheck
import SymplecticCHP
import Data.Bits (bit)
import Data.Maybe (fromJust)

-- Local Pauli constructors
pauliX, pauliZ, pauliY :: Int -> Pauli
pauliX i = Pauli (bit i) 0 0
pauliZ i = Pauli 0 (bit i) 0
pauliY i = Pauli (bit i) (bit i) 1

-- Orphan instance (move to Test.Arbitrary if preferred)
instance Arbitrary Pauli where
  arbitrary = do
    x <- chooseInt (0, 255) :: Gen Int
    z <- chooseInt (0, 255) :: Gen Int
    p <- chooseInt (0, 3)
    return $ Pauli (fromIntegral x) (fromIntegral z) p

newtype SmallN = SmallN Int
  deriving (Show, Eq)

instance Arbitrary SmallN where
  arbitrary = SmallN <$> chooseInt (1, 10)
  shrink (SmallN n) = SmallN <$> [n' | n' <- shrink n, n' > 0]

spec :: Spec
spec = describe "SymplecticCHP.Tableau" $ do
  describe "emptyTableauN" $ do
    it "creates valid tableau for |0...0>" $ do
      let tab = emptyTableauN 5
      isValidSome tab `shouldBe` True
    
    it "has correct number of rows" $ do
      property $ \(SmallN n) ->
        let tab = emptyTableauN n
        in length (rowsSome tab) === 2 * n
    
    it "has correct qubit count" $ do
      property $ \(SmallN n) ->
        nQubitsSome (emptyTableauN n) === n

  describe "Stabilizer properties" $ do
    it "stabilizers commute with each other" $ do
      property $ \(SmallN n) ->
        n > 0 ==>
          let tab = emptyTableauN n
              stab i = fromJust $ stabilizerSome tab i
              -- FIX: Use 'and' with list of Bools, not ==>
              allCommute = and [ i == j || commute (stab i) (stab j)
                               | i <- [0..n-1], j <- [0..n-1] ]
          in allCommute === True
    
    it "destabilizers have correct commutation with stabilizers" $ do
      property $ \(SmallN n) ->
        n > 0 ==>
          let tab = emptyTableauN n
              stab i = fromJust $ stabilizerSome tab i
              destab i = fromJust $ destabilizerSome tab i
              -- FIX: Use if-then-else inside list comprehension, not ==>
              correctPairing = and 
                [ if i == j then anticommute (destab i) (stab j)
                            else commute (destab i) (stab j)
                | i <- [0..n-1], j <- [0..n-1] ]
          in correctPairing === True

  describe "Initial state |0...0>" $ do
    it "has Z stabilizers on each qubit" $ do
      let n = 4
          tab = emptyTableauN n
          hasZStab i = xVec (fromJust $ stabilizerSome tab i) == 0 && zVec (fromJust $ stabilizerSome tab i) == bit i
      all hasZStab [0..n-1] `shouldBe` True
    
    it "has X destabilizers on each qubit" $ do
      let n = 4
          tab = emptyTableauN n
          hasXDestab i = xVec (fromJust $ destabilizerSome tab i) == bit i && zVec (fromJust $ destabilizerSome tab i) == 0
      all hasXDestab [0..n-1] `shouldBe` True
    
    it "all stabilizers have zero phase" $ do
      let n = 5
          tab = emptyTableauN n
      all (\i -> phase (fromJust $ stabilizerSome tab i) == 0) [0..n-1] `shouldBe` True

  describe "(//) operator for tableau rows" $ do
    it "updates single row correctly" $ do
      let tab = emptyTableauN 2
          newRow = Pauli 0 0 0
          rows' = rowsSome tab // [(0, newRow)]
      rows' !! 0 `shouldBe` newRow
      rows' !! 1 `shouldBe` (rowsSome tab !! 1)
      rows' !! 2 `shouldBe` (rowsSome tab !! 2)
      rows' !! 3 `shouldBe` (rowsSome tab !! 3)
    
    it "later update wins" $ do
      let tab = emptyTableauN 2
          rowA = Pauli 1 0 0
          rowB = Pauli 0 1 0
          rows' = rowsSome tab // [(0, rowA), (0, rowB)]
      rows' !! 0 `shouldBe` rowB

  describe "Tableau validity preservation" $ do
    it "remains valid after single-qubit gates" $ do
      property $ \(SmallN n) (q :: Int) ->
        let q' = q `mod` max 1 n  -- Ensure 0 <= q' < n
        in n > 0 ==>
            let tab0 = emptyTableauN n
                tabH = evolveTableauSome tab0 (Local (Hadamard q'))
                tabS = evolveTableauSome tabH (Local (Phase q'))
            in isValidSome tabH .&&. isValidSome tabS


    it "remains valid after CNOT" $ do
      property $ \(SmallN n) (cRaw :: Int) (tRaw :: Int) ->
        let n' = max 2 n
            c = cRaw `mod` n'
            t = tRaw `mod` n'
        in c /= t ==>
            let tab0 = emptyTableauN n'
                tab' = evolveTableauSome tab0 (CNOT c t)
            in isValidSome tab'

  -- describe "Generate function" $ do
  --   it "produces list of correct length" $ do
  --     property $ \(n :: Int) ->
  --       n >= 0 && n <= 100 ==>
  --         length (generate n id) === n
  --   
  --   it "applies function correctly" $ do
  --     generate 5 (*2) `shouldBe` [0,2,4,6,8]
