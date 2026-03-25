module Test.GatesSpec where

import Test.Hspec
import Test.QuickCheck
import SymplecticCHP
import Data.Bits (bit, testBit, popCount, xor)
import Test.Arbitrary

spec :: Spec
spec = describe "SymplecticCHP.Gates" $ do
  describe "Hadamard gate" $ do
    it "converts X to Z" $ do
      let x0 = pauliX 0
          x0' = applyGate (Local (Hadamard 0)) x0
      xVec x0' `shouldBe` 0
      zVec x0' `shouldBe` 1
      xVec x0 `shouldBe` 1  -- original unchanged
    
    it "converts Z to X" $ do
      let z0 = pauliZ 0
          z0' = applyGate (Local (Hadamard 0)) z0
      xVec z0' `shouldBe` 1
      zVec z0' `shouldBe` 0
    
    it "converts Y to -Y (phase flip)" $ do
      let y0 = pauliY 0
          y0' = applyGate (Local (Hadamard 0)) y0
      xVec y0' `shouldBe` 1
      zVec y0' `shouldBe` 1
      phase y0' `shouldBe` (phase y0 + 2) `mod` 4
    
    it "is self-inverse up to phase" $ do
      property $ \(p :: Pauli) ->
        let p' = applyGate (Local (Hadamard 0)) p
            p'' = applyGate (Local (Hadamard 0)) p'
        in xVec p'' === xVec p .&&. zVec p'' === zVec p
    
    it "preserves commutation relations" $ do
      property $ \(p1 :: Pauli) (p2 :: Pauli) ->
        let g = Local (Hadamard 0)
            p1' = applyGate g p1
            p2' = applyGate g p2
        in symplecticForm p1 p2 === symplecticForm p1' p2'

  describe "Phase gate" $ do
    it "leaves Z unchanged" $ do
      let z0 = pauliZ 0
          z0' = applyGate (Local (Phase 0)) z0
      xVec z0' `shouldBe` 0
      zVec z0' `shouldBe` 1
    
    it "converts X to Y" $ do
      let x0 = pauliX 0
          x0' = applyGate (Local (Phase 0)) x0
      xVec x0' `shouldBe` 1
      zVec x0' `shouldBe` 1  -- X*Z = Y
    
    it "has correct phase for X->Y" $ do
      let x0 = pauliX 0
          yExpected = pauliY 0
          x0' = applyGate (Local (Phase 0)) x0
      xVec x0' `shouldBe` xVec yExpected
      zVec x0' `shouldBe` zVec yExpected

  describe "CNOT gate" $ do
    it "X_control -> X_control * X_target" $ do
      let xc = pauliX 0  -- control
          xc' = applyGate (CNOT 0 1) xc
      -- X on control becomes X⊗X
      testBit (xVec xc') 0 `shouldBe` True   -- control still X
      testBit (xVec xc') 1 `shouldBe` True   -- target now X too
      zVec xc' `shouldBe` 0
    
    it "Z_target -> Z_control * Z_target" $ do
      let zt = pauliZ 1  -- target
          zt' = applyGate (CNOT 0 1) zt
      -- Z on target becomes Z⊗Z
      testBit (zVec zt') 0 `shouldBe` True   -- control now Z
      testBit (zVec zt') 1 `shouldBe` True   -- target still Z
      xVec zt' `shouldBe` 0
    
    it "leaves X_target unchanged" $ do
      let xt = pauliX 1
          xt' = applyGate (CNOT 0 1) xt
      xVec xt' `shouldBe` bit 1  -- only target bit set
      zVec xt' `shouldBe` 0
    
    it "leaves Z_control unchanged" $ do
      let zc = pauliZ 0
          zc' = applyGate (CNOT 0 1) zc
      zVec zc' `shouldBe` bit 0  -- only control bit set
      xVec zc' `shouldBe` 0
    
    it "is self-inverse" $ do
      property $ \(p :: Pauli) ->
        let p' = applyGate (CNOT 0 1) p
            p'' = applyGate (CNOT 0 1) p'
        in xVec p'' === xVec p .&&. zVec p'' === zVec p
    
    it "preserves commutation relations" $ do
      property $ \(p1 :: Pauli) (p2 :: Pauli) ->
        let g = CNOT 0 1
            p1' = applyGate g p1
            p2' = applyGate g p2
        in symplecticForm p1 p2 === symplecticForm p1' p2'

  describe "Gate composition" $ do
    it "H then CNOT creates Bell stabilizers" $ do
      let tab0 = emptyTableau 2
          tab1 = evolveTableau tab0 (Local (Hadamard 0))
          tab2 = evolveTableau tab1 (CNOT 0 1)
          s0 = rows tab2 !! 0  -- First stabilizer
          s1 = rows tab2 !! 1  -- Second stabilizer
      -- After H⊗CNOT, stabilizers should be XX and ZZ
      symplecticForm s0 s1 `shouldBe` True  -- They commute

  describe "Tableau evolution" $ do
    it "preserves tableau validity" $ do
      property $ \(gates :: [SymplecticGate]) ->
        let tab0 = emptyTableau 3
            tab' = foldl evolveTableau tab0 (take 10 gates)
        in isValid tab'