{-# LANGUAGE LambdaCase #-}

-- | Command-line interface for the STIM-to-CHP simulator.
-- Handles argument parsing, file I/O, and error reporting.
module CLI
  ( Config(..)
  , parseArgs
  , readStimFile
  , formatError
  , printUsage
  ) where

import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import StimParser.Expr (Stim)
import StimParser.Parse (parseStim)
import StimParser.ParseUtils (run)

import StimToCHP (TranslationError(..))

-- | Configuration for the simulator.
data Config = Config
  { inputFile :: FilePath
  , verbose :: Bool
  , showTableau :: Bool
  , seed :: Maybe Int  -- ^ Optional random seed for reproducibility
  } deriving (Show)

-- | Default configuration.
defaultConfig :: Config
defaultConfig = Config
  { inputFile = ""
  , verbose = False
  , showTableau = True
  , seed = Nothing
  }

-- | Parse command-line arguments.
parseArgs :: IO Config
parseArgs = getArgs >>= \case
  [] -> do
    printUsage
    exitFailure
    
  ["-h"] -> do
    printUsage
    exitFailure
    
  ["--help"] -> do
    printUsage
    exitFailure
    
  ["-v", file] -> return $ defaultConfig { inputFile = file, verbose = True }
  [file, "-v"] -> return $ defaultConfig { inputFile = file, verbose = True }
  
  ["--seed", s, file] -> 
    case reads s of
      [(n, "")] -> return $ defaultConfig { inputFile = file, seed = Just n }
      _ -> do
        hPutStrLn stderr $ "Error: Invalid seed: " ++ s
        exitFailure
        
  [file, "--seed", s] -> 
    case reads s of
      [(n, "")] -> return $ defaultConfig { inputFile = file, seed = Just n }
      _ -> do
        hPutStrLn stderr $ "Error: Invalid seed: " ++ s
        exitFailure
  
  ["--no-tableau", file] -> 
    return $ defaultConfig { inputFile = file, showTableau = False }
  
  [file, "--no-tableau"] -> 
    return $ defaultConfig { inputFile = file, showTableau = False }
  
  [file] -> return $ defaultConfig { inputFile = file }
  
  args -> do
    hPutStrLn stderr $ "Error: Unknown arguments: " ++ unwords args
    printUsage
    exitFailure

-- | Print usage information.
printUsage :: IO ()
printUsage = do
  putStrLn "STIM-to-CHP Simulator"
  putStrLn ""
  putStrLn "Usage: symplectic-chp [OPTIONS] <input.stim>"
  putStrLn ""
  putStrLn "Options:"
  putStrLn "  -h, --help         Show this help message"
  putStrLn "  -v                 Enable verbose output"
  putStrLn "  --seed N           Use specific random seed for measurements"
  putStrLn "  --no-tableau       Don't show final tableau"
  putStrLn ""
  putStrLn "Examples:"
  putStrLn "  symplectic-chp circuit.stim"
  putStrLn "  symplectic-chp -v circuit.stim"
  putStrLn "  symplectic-chp --seed 42 circuit.stim"

-- | Read and parse a STIM file.
-- Prepends "!!!Start " as required by the stim-parser.
readStimFile :: FilePath -> IO Stim
readStimFile path = do
  content <- readFile path
  -- stim-parser requires "!!!Start " prefix
  let prefixed = "!!!Start " ++ content
  return $ run parseStim prefixed

-- | Format a translation error for display.
formatError :: TranslationError -> String
formatError = \case
  UnsupportedGate gateType ->
    "Unsupported gate: " ++ show gateType ++ "\n" ++
    "This gate is not a Clifford gate or is not yet implemented."
    
  UnsupportedMeasure measureType ->
    "Unsupported measurement: " ++ show measureType ++ "\n" ++
    "Only single-qubit Pauli measurements (M, MX, MY, MZ) are supported."
    
  UnsupportedNoise noiseType ->
    "Unsupported noise: " ++ show noiseType ++ "\n" ++
    "Noise channels are not supported by CHP simulator."
    
  UnsupportedGpp gppType ->
    "Unsupported Pauli product operation: " ++ show gppType ++ "\n" ++
    "Pauli product measurements (MPP) are not yet supported."
    
  UnsupportedAnnotation annType ->
    "Unsupported annotation: " ++ show annType ++ "\n" ++
    "Annotations like QUBIT_COORDS, DETECTOR, etc. are not supported."
    
  UnsupportedRepeat ->
    "REPEAT blocks are not supported.\n" ++
    "Please unroll loops manually in your STIM file."
    
  OddCNOTTargets qubits ->
    "Invalid CNOT: odd number of targets (" ++ show (length qubits) ++ ")\n" ++
    "CNOT requires an even number of targets: control1 target1 control2 target2 ..."
    
  EmptyCircuit ->
    "Empty circuit or no qubits found."
