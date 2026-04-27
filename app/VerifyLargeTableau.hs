{-# LANGUAGE TypeApplications #-}

-- | Verification tests for LargeTableau implementation.
-- Validates correctness against known quantum states.
module Main where

import Control.Monad (foldM, when, forM_, forM)
import Data.Time (diffUTCTime, getCurrentTime)
import System.Environment (getArgs)
import System.Exit (exitFailure, exitSuccess)
import System.Random (randomRIO)
import Text.Printf (printf)

import Data.Bits (testBit, setBit, clearBit, xor)
import Data.Word (Word64)
import SymplecticCHP.BitVec
import SymplecticCHP.LargeTableau
import qualified Data.Vector as V

-- ============================================================================
-- Test Configuration
-- ============================================================================

data Config = Config
  { bellPairsQubits :: Int    -- ^ Qubits for Bell pairs test (default 10000)
  , repCodeQubits :: Int      -- ^ Qubits for repetition code test (default 1000)
  , randomCircuits :: Int     -- ^ Number of random circuits (default 100)
  , verbose :: Bool           -- ^ Verbose output
  }

defaultConfig :: Config
defaultConfig = Config
  { bellPairsQubits = 10000
  , repCodeQubits = 1000
  , randomCircuits = 100
  , verbose = False
  }

-- ============================================================================
-- Test 1: Pairwise Bell States
-- ============================================================================

-- | Create N/2 independent Bell pairs: |Φ⁺⟩^⊗N/2
-- Circuit: For each pair (2k, 2k+1): H on 2k, then CNOT(2k, 2k+1)
createBellPairsLarge :: Int -> LargeTableau
createBellPairsLarge n
  | odd n = error "createBellPairsLarge: qubit count must be even"
  | otherwise = 
      let tab0 = largeEmpty n
          -- Apply H to even qubits
          tab1 = foldl (\t i -> largeApplyGate (LargeLocal (LargeHadamard i)) t) 
                       tab0 [0,2..n-2]
          -- Apply CNOT from even to odd
          tab2 = foldl (\t i -> largeApplyGate (LargeCNOT i (i+1)) t) 
                       tab1 [0,2..n-2]
      in tab2

-- | Test 1: Pairwise Bell States
testBellPairs :: Config -> IO Bool
testBellPairs config = do
  let n = bellPairsQubits config
  putStrLn $ "\n=== Test 1: Pairwise Bell States ==="
  putStrLn $ "Creating " ++ show (n `div` 2) ++ " Bell pairs with " ++ show n ++ " qubits..."
  
  start <- getCurrentTime
  let tableau = createBellPairsLarge n
  mid <- getCurrentTime
  
  putStrLn $ "Circuit creation time: " ++ show (diffUTCTime mid start)
  
  -- Verify tableau validity
  let valid = largeIsValid tableau
  putStrLn $ "Tableau valid: " ++ show valid
  
  -- Verify each pair commutes with all others (independent pairs should commute)
  putStrLn "Checking pair-wise commutation..."
  let stabs = ltStabs tableau
      nStabs = V.length stabs
      -- Sample some pairs to check (checking all would be O(n²))
      sampleIndices = take 100 [0..nStabs-1]  -- Check first 100
      checkCommutation = all (\i -> 
        all (\j -> 
          if i == j then True
          else not (lpOmega (stabs V.! i) (stabs V.! j)))
          sampleIndices)
        sampleIndices
  
  putStrLn $ "Sampled stabilizers commute: " ++ show checkCommutation
  putStrLn $ "  (checked " ++ show (length sampleIndices) ++ " stabilizers)"
  
  -- Verify stabilizer count
  putStrLn $ "Stabilizer count: " ++ show nStabs ++ " (expected: " ++ show n ++ ")"
  let countCorrect = nStabs == n
  
  end <- getCurrentTime
  putStrLn $ "Total test time: " ++ show (diffUTCTime end start)
  
  return (valid && checkCommutation && countCorrect)

-- ============================================================================
-- Test 2: Repetition Code State
-- ============================================================================

-- | Create repetition code state: |+⋯+⟩ = (|0⋯0⟩ + |1⋯1⟩)/√2
-- Circuit: H on qubit 0, then CNOT(0, i) for all i > 0
createRepCodeLarge :: Int -> LargeTableau
createRepCodeLarge n
  | n < 2 = error "createRepCodeLarge: need at least 2 qubits"
  | otherwise =
      let tab0 = largeEmpty n
          tab1 = largeApplyGate (LargeLocal (LargeHadamard 0)) tab0
          tab2 = foldl (\t i -> largeApplyGate (LargeCNOT 0 i) t) tab1 [1..n-1]
      in tab2

-- | Test 2: Repetition Code State
testRepCode :: Config -> IO Bool
testRepCode config = do
  let n = repCodeQubits config
  putStrLn $ "\n=== Test 2: Repetition Code State ==="
  putStrLn $ "Creating repetition code with " ++ show n ++ " qubits..."
  
  start <- getCurrentTime
  let tableau = createRepCodeLarge n
  mid <- getCurrentTime
  
  putStrLn $ "Circuit creation time: " ++ show (diffUTCTime mid start)
  
  -- Verify tableau validity
  let valid = largeIsValid tableau
  putStrLn $ "Tableau valid: " ++ show valid
  
  -- For repetition code, check that X_0 X_i are stabilizers for sampled i
  putStrLn "Checking X_0 X_i stabilizers (sampled)..."
  let sampleIndices = take 50 [1..n-1]  -- Check first 50
      checkXX = all (\i ->
        let xVec = bvSetBit (bvSetBit (bvEmpty n) 0) i
            pauli = LargePauli xVec (bvEmpty n) 0 n
        in largeIsDeterminate tableau pauli) sampleIndices
  
  putStrLn $ "Sampled X_0 X_i are stabilizers: " ++ show checkXX
  putStrLn $ "  (checked " ++ show (length sampleIndices) ++ " indices)"
  
  end <- getCurrentTime
  putStrLn $ "Total test time: " ++ show (diffUTCTime end start)
  
  return (valid && checkXX)

-- ============================================================================
-- Test 3: Phase Gate Identity (S² = Z)
-- ============================================================================

-- | Test that S² = Z on a superposition state
-- Start with |+⟩, apply S twice, should get |−⟩ (Z eigenvalue -1)
testPhaseIdentity :: Config -> IO Bool
testPhaseIdentity _config = do
  putStrLn $ "\n=== Test 3: Phase Gate Identity (S² = Z) ==="
  
  let n = 100  -- Use 100 qubits
  putStrLn $ "Testing on " ++ show n ++ " qubits..."
  
  start <- getCurrentTime
  
  -- Create |+⟩ states on all qubits
  let tab0 = largeEmpty n
      tab1 = foldl (\t i -> largeApplyGate (LargeLocal (LargeHadamard i)) t) 
                   tab0 [0..n-1]
  
  -- Apply S to all qubits (first time)
  let tab2 = foldl (\t i -> largeApplyGate (LargeLocal (LargePhase i)) t) 
                   tab1 [0..n-1]
  
  -- Apply S to all qubits (second time)
  let tab3 = foldl (\t i -> largeApplyGate (LargeLocal (LargePhase i)) t) 
                   tab2 [0..n-1]
  
  mid <- getCurrentTime
  putStrLn $ "Circuit time: " ++ show (diffUTCTime mid start)
  
  -- Verify tableau valid
  let valid = largeIsValid tab3
  putStrLn $ "Tableau valid: " ++ show valid
  
  -- After H then S twice, we should have -X stabilizers (|−⟩ state)
  -- Check first few qubits
  let sampleIndices = take 10 [0..n-1]
      checkNegX = all (\i ->
        let xVec = bvSetBit (bvEmpty n) i
            pauli = LargePauli xVec (bvEmpty n) 2 n  -- phase 2 = -1
        in largeIsDeterminate tab3 pauli) sampleIndices
  
  putStrLn $ "Sampled qubits have -X stabilizer: " ++ show checkNegX
  
  end <- getCurrentTime
  putStrLn $ "Total test time: " ++ show (diffUTCTime end start)
  
  return (valid && checkNegX)

-- ============================================================================
-- Test 4: Random Circuit Property Tests
-- ============================================================================

-- | Apply random Clifford gate to large tableau
applyRandomGate :: Int -> LargeTableau -> IO LargeTableau
applyRandomGate n tab = do
  gateType <- randomRIO (0, 2) :: IO Int
  case gateType of
    0 -> do -- Hadamard
      q <- randomRIO (0, n-1)
      return $ largeApplyGate (LargeLocal (LargeHadamard q)) tab
    1 -> do -- Phase
      q <- randomRIO (0, n-1)
      return $ largeApplyGate (LargeLocal (LargePhase q)) tab
    2 -> do -- CNOT
      c <- randomRIO (0, n-1)
      t <- randomRIO (0, n-1)
      if c == t 
        then return tab
        else return $ largeApplyGate (LargeCNOT c t) tab
    _ -> return tab

-- | Test 4: Random circuits preserve validity
testRandomCircuits :: Config -> IO Bool
testRandomCircuits config = do
  let n = 100  -- Use 100 qubits for random tests (fast but large enough)
      numCircuits = randomCircuits config
  putStrLn $ "\n=== Test 4: Random Circuit Properties ==="
  putStrLn $ "Testing " ++ show numCircuits ++ " random circuits on " ++ show n ++ " qubits..."
  
  results <- forM [1..numCircuits] $ \i -> do
    when (i `mod` 10 == 0) $ putStrLn $ "  Circuit " ++ show i ++ "/" ++ show numCircuits
    
    -- Generate random circuit
    let initialTab = largeEmpty n
    numGates <- randomRIO (10, 100) :: IO Int
    finalTab <- foldM (\t _ -> applyRandomGate n t) initialTab [1..numGates]
    
    -- Check invariants
    let valid = largeIsValid finalTab
        stabs = ltStabs finalTab
        destabs = ltDestabs finalTab
        correctSize = V.length stabs == n && V.length destabs == n
    
    return (valid && correctSize)
  
  let allPass = and results
  putStrLn $ "All random circuits valid: " ++ show allPass
  putStrLn $ "Passed: " ++ show (length (filter id results)) ++ "/" ++ show numCircuits
  
  return allPass

-- ============================================================================
-- Test 5: Performance Benchmark
-- ============================================================================

-- | Benchmark gate application performance
benchmarkGates :: IO ()
benchmarkGates = do
  putStrLn $ "\n=== Test 5: Performance Benchmark ==="
  
  let sizes = [100, 500, 1000, 5000, 10000]
  
  forM_ sizes $ \n -> do
    putStrLn $ "\nBenchmarking " ++ show n ++ " qubits:"
    
    -- Create tableau
    start <- getCurrentTime
    let tab0 = largeEmpty n
    mid1 <- getCurrentTime
    putStrLn $ "  Creation: " ++ show (diffUTCTime mid1 start)
    
    -- Apply 100 Hadamards
    let tab1 = foldl (\t i -> largeApplyGate (LargeLocal (LargeHadamard (i `mod` n))) t) 
                     tab0 [0..99]
    mid2 <- getCurrentTime
    putStrLn $ "  100 Hadamards: " ++ show (diffUTCTime mid2 mid1)
    
    -- Apply 100 CNOTs
    let tab2 = foldl (\t i -> largeApplyGate (LargeCNOT (i `mod` n) ((i+1) `mod` n)) t) 
                     tab1 [0..99]
    mid3 <- getCurrentTime
    putStrLn $ "  100 CNOTs: " ++ show (diffUTCTime mid3 mid2)
    
    -- Check validity
    let valid = largeIsValid tab2
    putStrLn $ "  Tableau valid: " ++ show valid
    
    -- Memory estimate: 2 vectors (X and Z) × n qubits × 8 bytes per 64 qubits
    let chunksPerQubit = (n + 63) `div` 64
        bytesPerPauli = 2 * chunksPerQubit * 8  -- X and Z
        totalBytes = 2 * n * bytesPerPauli  -- Stabs and destabs
    putStrLn $ "  Estimated memory: " ++ show (totalBytes `div` 1024) ++ " KB"

-- ============================================================================
-- Main
-- ============================================================================

parseArgs :: [String] -> Config
parseArgs args = foldl parseArg defaultConfig args
  where
    parseArg cfg "--verbose" = cfg { verbose = True }
    parseArg cfg ('-':'-':'b':'e':'l':'l':'-':'p':'a':'i':'r':'s':'=':n) = 
      cfg { bellPairsQubits = read n }
    parseArg cfg ('-':'-':'r':'e':'p':'-':'c':'o':'d':'e':'=':n) = 
      cfg { repCodeQubits = read n }
    parseArg cfg ('-':'-':'r':'a':'n':'d':'o':'m':'=':n) = 
      cfg { randomCircuits = read n }
    parseArg cfg _ = cfg

printUsage :: IO ()
printUsage = do
  putStrLn "Usage: verify-large-tableau [OPTIONS]"
  putStrLn ""
  putStrLn "Options:"
  putStrLn "  --verbose              Enable verbose output"
  putStrLn "  --bell-pairs=N         Qubits for Bell pairs test (default: 10000)"
  putStrLn "  --rep-code=N           Qubits for repetition code test (default: 1000)"
  putStrLn "  --random=N             Number of random circuits (default: 100)"
  putStrLn "  --help                 Show this help"
  putStrLn ""
  putStrLn "Examples:"
  putStrLn "  verify-large-tableau                    # Run all tests with defaults"
  putStrLn "  verify-large-tableau --bell-pairs=5000  # Test with 5000 qubits"
  putStrLn "  verify-large-tableau --verbose          # Verbose output"

main :: IO ()
main = do
  args <- getArgs
  
  when ("--help" `elem` args) $ do
    printUsage
    exitSuccess
  
  let config = parseArgs args
  
  putStrLn "========================================"
  putStrLn "  LargeTableau Verification Suite"
  putStrLn "========================================"
  putStrLn $ "Configuration:"
  putStrLn $ "  Bell pairs test: " ++ show (bellPairsQubits config) ++ " qubits"
  putStrLn $ "  Rep code test: " ++ show (repCodeQubits config) ++ " qubits"
  putStrLn $ "  Random circuits: " ++ show (randomCircuits config)
  
  startTime <- getCurrentTime
  
  -- Run all tests
  results <- sequence
    [ testBellPairs config
    , testRepCode config
    , testPhaseIdentity config
    , testRandomCircuits config
    ]
  
  -- Performance benchmark
  benchmarkGates
  
  endTime <- getCurrentTime
  
  putStrLn "\n========================================"
  putStrLn "  Summary"
  putStrLn "========================================"
  putStrLn $ "Total time: " ++ show (diffUTCTime endTime startTime)
  
  let allPass = and results
  if allPass
    then do
      putStrLn "\n✅ ALL TESTS PASSED"
      exitSuccess
    else do
      putStrLn "\n❌ SOME TESTS FAILED"
      exitFailure
