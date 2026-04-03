{-# LANGUAGE LambdaCase #-}

-- | Main entry point for the STIM-to-CHP simulator.
-- 
-- This executable parses STIM circuit files and simulates them using
-- the CHP Clifford simulator via symplectic geometry.
--
-- Supported STIM features:
--   - Clifford gates: H, S, CNOT, CZ, X, Y, Z, SWAP
--   - Measurements: M, MX, MY, MZ
--
-- Unsupported features (will report error):
--   - Non-Clifford gates (T, RX, RY, RZ, etc.)
--   - Noise channels
--   - Reset operations
--   - Pauli product measurements (MPP)
--   - Repeat blocks
--   - Annotations
module Main where

import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import CHPCircuit (CHPCircuit(..))
import qualified CLI
import qualified Simulator
import StimToCHP (translateStim)

main :: IO ()
main = do
  -- Parse command-line arguments
  config <- CLI.parseArgs
  
  let path = CLI.inputFile config
  
  -- Step 1: Read and parse the STIM file
  whenVerbose config $ putStrLn $ "Reading STIM file: " ++ path
  stim <- CLI.readStimFile path
  whenVerbose config $ putStrLn "Successfully parsed STIM file"
  
  -- Step 2: Translate to CHP circuit
  whenVerbose config $ putStrLn "Translating to CHP circuit..."
  case translateStim stim of
    Left err -> do
      hPutStrLn stderr $ "Translation error:\n" ++ CLI.formatError err
      exitFailure
      
    Right circuit -> do
      whenVerbose config $ do
        putStrLn $ "Circuit has " ++ show (numQubits circuit) ++ " qubit(s)"
        putStrLn $ "Circuit has " ++ show (length (operations circuit)) ++ " operation(s)"
      
      -- Step 3: Run simulation
      whenVerbose config $ putStrLn "Running simulation..."
      result <- case CLI.seed config of
        Nothing -> Simulator.runCHPCircuit circuit
        Just s -> Simulator.runCHPCircuitWithSeed s circuit
      
      -- Step 4: Print results
      if CLI.showTableau config
        then Simulator.printResults result
        else putStrLn $ "Measurements: " ++ show (Simulator.measurementOutcomes result)

-- | Print message only in verbose mode.
whenVerbose :: CLI.Config -> IO () -> IO ()
whenVerbose config action = if CLI.verbose config then action else return ()
