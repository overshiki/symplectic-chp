module Test.UtilsSpec where

import Test.Hspec
import Test.QuickCheck
import SymplecticCHP ((//))
import qualified Data.List as L

spec :: Spec
spec = describe "SymplecticCHP.Utils" $ do
  describe "(//) list update operator" $ do
    it "basic example from Vector semantics" $ do
      let xs = [5,9,2,7 :: Int]
          updates = [(2,1),(0,3),(2,8)]
      xs // updates `shouldBe` [3,9,8,7]
    
    it "handles empty update list" $ do
      let xs = [1,2,3 :: Int]
      xs // [] `shouldBe` xs
    
    it "ignores out-of-bounds indices (too large)" $ do
      let xs = [1,2,3 :: Int]
      xs // [(5,99)] `shouldBe` xs
    
    it "ignores negative indices" $ do
      let xs = [1,2,3 :: Int]
      xs // [(-1,99)] `shouldBe` xs
    
    it "later update wins for same index" $ do
      let xs = [1,2,3 :: Int]
      xs // [(0,10),(0,20)] `shouldBe` [20,2,3]
      xs // [(1,5),(1,6),(1,7)] `shouldBe` [1,7,3]
    
    it "handles updates in any order" $ do
      let xs = [0,0,0,0 :: Int]
          updates1 = [(0,1),(2,3)]
          updates2 = [(2,3),(0,1)]  -- reversed
      xs // updates1 `shouldBe` xs // updates2
    
    it "handles single element list" $ do
      let xs = [42 :: Int]
      xs // [(0,100)] `shouldBe` [100]
      xs // [(1,100)] `shouldBe` [42]  -- out of bounds
    
    it "handles all indices updated" $ do
      let xs = [1,2,3 :: Int]
      xs // [(0,10),(1,20),(2,30)] `shouldBe` [10,20,30]

  describe "(//) property tests" $ do
    it "preserves list length" $ do
      property $ \xs updates -> 
        let xs' :: [Int]
            xs' = take 50 xs
            updates' :: [(Int, Int)]
            updates' = take 20 updates
            result = xs' // updates'
        in length result === length xs'
    
    it "is idempotent when applying same updates twice" $ do
      property $ \xs updates -> 
        let xs' :: [Int]
            xs' = take 30 xs
            updates' :: [(Int, Int)]
            updates' = [(i `mod` 40, v) | (i, v) <- take 10 updates, let ii = i `mod` 40, ii >= 0]
            xs'' = xs' // updates'
        in xs'' // updates' === xs''
    
    it "lookup finds updated values correctly" $ do
      property $ \xs updates (idx :: Int) -> 
        let xs' :: [Int]
            xs' = take 20 xs
            len = length xs'
            updates' :: [(Int, Int)]
            updates' = [(i `mod` max 1 len, v) | (i, v) <- take 10 updates, let ii = i `mod` max 1 len, ii >= 0]
            result = xs' // updates'
            i = idx `mod` max 1 (length xs')
        in case lookup i updates' of
             Just v  -> result L.!! i === v
             Nothing -> result L.!! i === (xs' L.!! i)
    
    it "later updates override earlier ones" $ do
      property $ \xs -> 
        let xs' :: [Int]
            xs' = take 10 xs
            updates :: [(Int, Int)]
            updates = [(0, 1), (0, 2), (0, 3)]
        in xs' // updates === (xs' // [(0, 3)] :: [Int])
    
    it "empty updates is identity" $ do
      property $ \xs -> 
        let xs' :: [Int] = take 100 xs
        in xs' // [] === xs'