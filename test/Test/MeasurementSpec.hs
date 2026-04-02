module Test.MeasurementSpec where

import Test.Hspec
import Test.QuickCheck
import SymplecticCHP
import Data.Bits (bit, (.|.))
import Control.Monad (replicateM)
import Data.Maybe (fromJust)

spec :: Spec
spec = describe "SymplecticCHP.Measurement" $ do
  describe "isDeterminateSome" $ do
    it "Z measurement on |0> is determinate" $ do
      let tab = emptyTableauN 1
      isDeterminateSome tab (pauliZ 0) `shouldBe` True
    
    it "X measurement on |0> is random" $ do
      let tab = emptyTableauN 1
      isDeterminateSome tab (pauliX 0) `shouldBe` False
    
    it "I measurement is always determinate" $ do
      property $ \(Positive n') ->
        let n = (n' `mod` 10) + 1  -- Ensure 1-10 range
            tab = emptyTableauN n
            identity = Pauli 0 0 0
        in isDeterminateSome tab identity === True
    
    it "stabilizer measurement is determinate" $ do
      let n = 3
          tab = emptyTableauN n
          stab0 = rowsSome tab !! 0  -- Z_0
      isDeterminateSome tab stab0 `shouldBe` True
    
    it "product of stabilizers is determinate" $ do
      let n = 3
          tab = emptyTableauN n
          stab0 = rowsSome tab !! 0
          stab1 = rowsSome tab !! 1
          product = multiply stab0 stab1
      isDeterminateSome tab product `shouldBe` True

  describe "findAntiCommutingStabSome" $ do
    it "finds stabilizer for X on |0>" $ do
      let tab = emptyTableauN 1
          result = findAntiCommutingStabSome tab (pauliX 0)
      result `shouldBe` Just 0  -- S_0 = Z_0 anti-commutes with X_0
    
    it "returns Nothing for Z on |0>" $ do
      let tab = emptyTableauN 1
          result = findAntiCommutingStabSome tab (pauliZ 0)
      result `shouldBe` Nothing  -- Z_0 = S_0 commutes with itself
    
    it "returns Nothing for identity" $ do
      let tab = emptyTableauN 2
          result = findAntiCommutingStabSome tab (Pauli 0 0 0)
      result `shouldBe` Nothing

  describe "Measurement outcomes" $ do
    it "deterministic Z measurement gives +1 on |0>" $ do
      let tab = emptyTableauN 1
      (tab', result) <- measureSome tab (pauliZ 0)
      case result of
        Determinate True -> return ()  -- Expected +1
        _ -> expectationFailure "Expected determinate +1"
    
    it "deterministic outcome is reproducible" $ do
      let n = 3
          tab = emptyTableauN n
          p = pauliZ 0  -- determinate
      results <- replicateM 10 (measureSome tab p)
      all (\(_, res) -> case res of Determinate _ -> True; _ -> False) results
        `shouldBe` True
    
    it "random measurement changes tableau" $ do
      let tab0 = emptyTableauN 1
      (tab1, res1) <- measureSome tab0 (pauliX 0)  -- random
      (tab2, res2) <- measureSome tab1 (pauliX 0)  -- now determinate (should be)
      case (res1, res2) of
        (Random _, Determinate _) -> return ()  -- First random, second determinate
        _ -> expectationFailure "Expected random then determinate"

  describe "Measurement state update" $ do
    it "random measurement updates stabilizer" $ do
      let tab0 = emptyTableauN 2
      (tab1, _) <- measureSome tab0 (pauliX 0)
      -- Tableau should still be valid
      isValidSome tab1 `shouldBe` True
    
    it "measurement preserves number of qubits" $ do
      property $ \(Positive n') ->
        let n = n' `mod` 5 + 1  -- Ensure 1-5 range
        in ioProperty $ do
          let tab0 = emptyTableauN n
          (tab1, _) <- measureSome tab0 (pauliX 0)
          return $ nQubitsSome tab1 === n

    it "measurement preserves tableau validity" $ do
      property $ \(Positive n') ->
        let n = n' `mod` 5 + 1  -- Ensure 1-5 range
        in ioProperty $ do
            let tab0 = emptyTableauN n
                p = Pauli (bit 0) 0 0  -- X_0
            (tab1, _) <- measureSome tab0 p
            return $ isValidSome tab1 === True

  describe "computePhaseSome" $ do
    it "gives +1 for Z on |0>" $ do
      let tab = emptyTableauN 1
          outcome = computePhaseSome tab (pauliZ 0)
      outcome `shouldBe` True  -- +1
    
    it "gives -1 for -Z on |0>" $ do
      let tab = emptyTableauN 1
          minusZ = Pauli 0 (bit 0) 2  -- phase 2 = -1
          outcome = computePhaseSome tab minusZ
      outcome `shouldBe` False  -- -1

  describe "Bell state measurement" $ do
    it "XX stabilizer gives determinate +1 after Bell prep" $ do
      let tab0 = emptyTableauN 2
          tab1 = evolveTableauSome tab0 (Local (Hadamard 0))
          tab2 = evolveTableauSome tab1 (CNOT 0 1)
          xx = Pauli (bit 0 .|. bit 1) 0 0  -- X⊗X
      isDeterminateSome tab2 xx `shouldBe` True
      computePhaseSome tab2 xx `shouldBe` True  -- +1 eigenvalue
