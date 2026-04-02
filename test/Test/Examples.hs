module Test.Examples where

import Test.Hspec
import SymplecticCHP
import Data.Maybe (fromJust)

spec :: Spec
spec = describe "SymplecticCHP Examples" $ do
  describe "Bell state" $ do
    it "prepares entangled state" $ do
      (tab, outcome) <- runWith 2 bellCircuit
      outcome `shouldBe` True  -- X⊗X should measure +1
      -- Check stabilizers using SomeTableau helper
      let s0 = fromJust $ stabilizerSome tab 0
          s1 = fromJust $ stabilizerSome tab 1
      -- Bell state has stabilizers XX and ZZ
      commute s0 s1 `shouldBe` True
