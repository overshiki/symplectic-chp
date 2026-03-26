module Test.MeasurementSpec where

import Test.Hspec
import Test.QuickCheck
import SymplecticCHP
import Data.Bits (bit, (.|.))
import Control.Monad (replicateM)

spec :: Spec
spec = describe "SymplecticCHP.Measurement" $ do
  describe "isDeterminate" $ do
    it "Z measurement on |0> is determinate" $ do
      let tab = emptyTableau 1
      isDeterminate tab (pauliZ 0) `shouldBe` True
    
    it "X measurement on |0> is random" $ do
      let tab = emptyTableau 1
      isDeterminate tab (pauliX 0) `shouldBe` False
    
    it "I measurement is always determinate" $ do
      property $ \(n :: Int) ->
        n > 0 && n <= 10 ==>
          let tab = emptyTableau n
              identity = Pauli 0 0 0
          in isDeterminate tab identity === True
    
    it "stabilizer measurement is determinate" $ do
      let n = 3
          tab = emptyTableau n
          stab0 = rows tab !! 0  -- Z_0
      isDeterminate tab stab0 `shouldBe` True
    
    it "product of stabilizers is determinate" $ do
      let n = 3
          tab = emptyTableau n
          stab0 = rows tab !! 0
          stab1 = rows tab !! 1
          product = multiply stab0 stab1
      isDeterminate tab product `shouldBe` True

  describe "findAntiCommutingStab" $ do
    it "finds stabilizer for X on |0>" $ do
      let tab = emptyTableau 1
          result = findAntiCommutingStab tab (pauliX 0)
      result `shouldBe` Just 0  -- S_0 = Z_0 anti-commutes with X_0
    
    it "returns Nothing for Z on |0>" $ do
      let tab = emptyTableau 1
          result = findAntiCommutingStab tab (pauliZ 0)
      result `shouldBe` Nothing  -- Z_0 = S_0 commutes with itself
    
    it "returns Nothing for identity" $ do
      let tab = emptyTableau 2
          result = findAntiCommutingStab tab (Pauli 0 0 0)
      result `shouldBe` Nothing

  describe "Measurement outcomes" $ do
    it "deterministic Z measurement gives +1 on |0>" $ do
      let tab = emptyTableau 1
      (tab', result) <- measure tab (pauliZ 0)
      case result of
        Determinate True -> return ()  -- Expected +1
        _ -> expectationFailure "Expected determinate +1"
    
    it "deterministic outcome is reproducible" $ do
      let n = 3
          tab = emptyTableau n
          p = pauliZ 0  -- determinate
      results <- replicateM 10 (measure tab p)
      all (\(_, res) -> case res of Determinate _ -> True; _ -> False) results
        `shouldBe` True
    
    it "random measurement changes tableau" $ do
      let tab0 = emptyTableau 1
      (tab1, res1) <- measure tab0 (pauliX 0)  -- random
      (tab2, res2) <- measure tab1 (pauliX 0)  -- now determinate (should be)
      case (res1, res2) of
        (Random _, Determinate _) -> return ()  -- First random, second determinate
        _ -> expectationFailure "Expected random then determinate"

  describe "Measurement state update" $ do
    it "random measurement updates stabilizer" $ do
      let tab0 = emptyTableau 2
      (tab1, _) <- measure tab0 (pauliX 0)
      -- Tableau should still be valid
      isValid tab1 `shouldBe` True
    
    it "measurement preserves number of qubits" $ do
      property $ \(Positive n') ->
        let n = n' `mod` 5 + 1  -- Ensure 1-5 range
        in ioProperty $ do
          let tab0 = emptyTableau n
          (tab1, _) <- measure tab0 (pauliX 0)
          return $ nQubits tab1 === n

    it "measurement preserves tableau validity" $ do
      property $ \(Positive n') ->
        let n = n' `mod` 5 + 1  -- Ensure 1-5 range
        in ioProperty $ do
            let tab0 = emptyTableau n
                p = Pauli (bit 0) 0 0  -- X_0
            (tab1, _) <- measure tab0 p
            return $ isValid tab1 === True

  describe "computePhase" $ do
    it "gives +1 for Z on |0>" $ do
      let tab = emptyTableau 1
          outcome = computePhase tab (pauliZ 0)
      outcome `shouldBe` True  -- +1
    
    it "gives -1 for -Z on |0>" $ do
      let tab = emptyTableau 1
          minusZ = Pauli 0 (bit 0) 2  -- phase 2 = -1
          outcome = computePhase tab minusZ
      outcome `shouldBe` False  -- -1

  describe "Bell state measurement" $ do
    it "XX stabilizer gives determinate +1 after Bell prep" $ do
      let tab0 = emptyTableau 2
          tab1 = evolveTableau tab0 (Local (Hadamard 0))
          tab2 = evolveTableau tab1 (CNOT 0 1)
          xx = Pauli (bit 0 .|. bit 1) 0 0  -- X⊗X
      isDeterminate tab2 xx `shouldBe` True
      computePhase tab2 xx `shouldBe` True  -- +1 eigenvalue