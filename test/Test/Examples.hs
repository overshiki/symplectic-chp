module Test.Examples where

import Test.Hspec
import SymplecticCHP

spec :: Spec
spec = describe "SymplecticCHP Examples" $ do
  describe "Bell state" $ do
    it "prepares entangled state" $ do
      (tab, outcome) <- runWith 2 bellCircuit
      outcome `shouldBe` True  -- X⊗X should measure +1
      -- Check stabilizers
      let s0 = stabilizer tab 0
          s1 = stabilizer tab 1
      -- Bell state has stabilizers XX and ZZ
      commute s0 s1 `shouldBe` True