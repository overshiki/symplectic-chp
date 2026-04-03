{-# LANGUAGE GADTs #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Simulation runner for CHP circuits.
-- Executes translated circuits using the symplectic-chp simulator.
module Simulator
  ( runCHPCircuit
  , runCHPCircuitWithSeed
  , SimulationResult(..)
  , printResults
  ) where

import Control.Monad (foldM)
import System.Random (randomIO)

import SymplecticCHP
  ( Clifford
  , SomeTableau(..)
  , SymplecticGate
  , Pauli(..)
  , gate
  , measurePauli
  , runWith
  , getTableau
  , nQubitsSome
  , rowsSome
  , stabilizerSome
  , destabilizerSome
  , isValidSome
  )

import CHPCircuit (CHPCircuit(..), CHPOperation(..))

-- | Result of simulating a CHP circuit.
data SimulationResult = SimulationResult
  { finalTableau :: SomeTableau
  , measurementOutcomes :: [Bool]
  , measurementCount :: Int
  }

-- | Run a CHP circuit simulation.
-- Returns the final tableau and all measurement outcomes.
runCHPCircuit :: CHPCircuit -> IO SimulationResult
runCHPCircuit circuit = do
  -- Use random seed from IO
  seed <- randomIO
  runCHPCircuitWithSeed seed circuit

-- | Run a CHP circuit with a specific random seed (for reproducibility).
runCHPCircuitWithSeed :: Int -> CHPCircuit -> IO SimulationResult
runCHPCircuitWithSeed seed circuit = do
  let n = numQubits circuit
  (tableau, outcomes) <- runWith n (runOperations (operations circuit))
  return $ SimulationResult
    { finalTableau = tableau
    , measurementOutcomes = reverse outcomes  -- Reverse to get chronological order
    , measurementCount = length outcomes
    }

-- | Run a list of operations in the Clifford monad.
-- Collects measurement outcomes.
runOperations :: [CHPOperation] -> Clifford [Bool]
runOperations ops = foldM step [] ops
  where
    step :: [Bool] -> CHPOperation -> Clifford [Bool]
    step acc (GateOp g) = do
      gate g
      return acc
    step acc (MeasureOp p idx) = do
      result <- measurePauli p
      return (result : acc)

-- ============================================================================
-- Output Formatting
-- ============================================================================

-- | Print simulation results in a human-readable format.
printResults :: SimulationResult -> IO ()
printResults result = do
  putStrLn "========================================"
  putStrLn "  CHP Simulation Results"
  putStrLn "========================================"
  putStrLn ""
  
  -- Print measurement outcomes
  putStrLn $ "Measurements performed: " ++ show (measurementCount result)
  if measurementCount result > 0
    then do
      putStrLn "Measurement outcomes:"
      mapM_ (\(i, outcome) -> 
        putStrLn $ "  M" ++ show i ++ ": " ++ showOutcome outcome) 
        (zip [0..] (measurementOutcomes result))
    else putStrLn "No measurements performed."
  
  putStrLn ""
  
  -- Print tableau info
  let tab = finalTableau result
  putStrLn $ "Number of qubits: " ++ show (nQubitsSome tab)
  putStrLn $ "Tableau valid: " ++ show (isValidSome tab)
  
  putStrLn ""
  putStrLn "Stabilizers (generators of the stabilizer group):"
  printStabilizers tab
  
  putStrLn ""
  putStrLn "Destabilizers (dual to stabilizers):"
  printDestabilizers tab

-- | Format a measurement outcome (+1 or -1 eigenvalue).
showOutcome :: Bool -> String
showOutcome True  = "+1 (|0⟩ or |+⟩)"
showOutcome False = "-1 (|1⟩ or |-⟩)"

-- | Print stabilizer generators.
printStabilizers :: SomeTableau -> IO ()
printStabilizers (SomeTableau tab) = go 0
  where
    n = nQubitsSome (SomeTableau tab)
    go i
      | i >= n = return ()
      | otherwise = case stabilizerSome (SomeTableau tab) i of
          Just p -> do
            putStrLn $ "  S" ++ show i ++ ": " ++ showPauli p
            go (i + 1)
          Nothing -> go (i + 1)

-- | Print destabilizer generators.
printDestabilizers :: SomeTableau -> IO ()
printDestabilizers (SomeTableau tab) = go 0
  where
    n = nQubitsSome (SomeTableau tab)
    go i
      | i >= n = return ()
      | otherwise = case destabilizerSome (SomeTableau tab) i of
          Just p -> do
            putStrLn $ "  D" ++ show i ++ ": " ++ showPauli p
            go (i + 1)
          Nothing -> go (i + 1)

-- | Format a Pauli operator for display.
showPauli :: Pauli -> String
showPauli (Pauli x z phase) = 
  let phaseStr = case phase `mod` 4 of
        0 -> "+"
        1 -> "+i"
        2 -> "-"
        3 -> "-i"
        _ -> "?"
      n = max (bitLength x) (bitLength z)
      n' = if n == 0 then 1 else n
      ops = [showSinglePauli (testBit x i) (testBit z i) | i <- [0..n'-1]]
  in phaseStr ++ concat ops
  where
    bitLength 0 = 0
    bitLength w = floor (logBase 2 (fromIntegral w)) + 1
    testBit w i = (w `div` (2^i)) `mod` 2 == 1
    
    showSinglePauli False False = "I"
    showSinglePauli True  False = "X"
    showSinglePauli False True  = "Z"
    showSinglePauli True  True  = "Y"
