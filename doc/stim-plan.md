# STIM-to-CHP Integration Plan

## Overview

This document describes the integration of `stim-parser` with `symplectic-chp` to enable parsing and simulation of STIM circuit files using the CHP Clifford simulator.

## 1. Current State Analysis

### symplectic-chp Library (`src/SymplecticCHP.hs`)

- Provides CHP simulation using symplectic geometry
- **Supported gates**: `Hadamard`, `Phase` (S), `CNOT`
- **Supported measurements**: Pauli measurements via `measurePauli`
- Uses type-safe tableau representation with `Tableau n Pauli`
- Monadic interface via `Clifford` monad with `runWith`

### stim-parser Library

- Parses STIM circuit files into an AST
- Key types:
  - `Gate GateTy (Maybe Float) [Q]` - Clifford and non-Clifford gates
  - `Measure MeasureTy (Maybe Float) (Maybe Float) [Q]` - Measurements
  - `StimList [Stim]` - Circuit container
  - `StimRepeat Int Stim` - Repeat blocks
  - `Gpp GppTy ...` - Pauli product measurements (MPP)
  - `Noise...` - Various noise channels

## 2. Supported STIM Subset (CHP-compatible)

### Supported Gates

| STIM Gate | CHP Equivalent | Notes |
|-----------|---------------|-------|
| `H q` | `Local (Hadamard q)` | ✅ Direct support |
| `S q` | `Local (Phase q)` | ✅ Direct support |
| `CNOT c t` | `CNOT c t` | ✅ Direct support |
| `CZ c t` | `H t; CNOT c t; H t` | Decompose |
| `X q` | `H q; S q; S q; H q` | Decompose |
| `Y q` | Complex decomposition | See below |
| `Z q` | `S q; S q` | Decompose |
| `SWAP a b` | `CNOT a b; CNOT b a; CNOT a b` | Decompose |
| `I q` | No-op | ✅ Skip |

### Gate Decomposition Details

```haskell
-- CZ using CNOT and Hadamard
CZ c t = H t; CNOT c t; H t

-- Pauli X using Hadamard and Phase
X q = H q; S q; S q; H q

-- Pauli Z using Phase
Z q = S q; S q

-- Pauli Y (Y = iXZ = -iZX, use decomposition)
Y q = S q; X q; S q; S q; S q
    = S q; (H q; S q; S q; H q); S q; S q; S q

-- SWAP using three CNOTs
SWAP a b = CNOT a b; CNOT b a; CNOT a b
```

### Supported Measurements

| STIM Measure | CHP Equivalent |
|--------------|----------------|
| `M q` / `MZ q` | `measurePauli (Pauli 0 (bit q) 0)` | Z-basis |
| `MX q` | `measurePauli (Pauli (bit q) 0 0)` | X-basis |
| `MY q` | `measurePauli (Pauli (bit q) (bit q) 1)` | Y-basis |

### NOT Supported (Error/Skip)

- **All noise channels**: `X_ERROR`, `DEPOLARIZE1/2`, `PAULI_CHANNEL_*`, etc.
- **Non-Clifford gates**: `T`, `RX`, `RY`, `RZ`, `SQRT_*` (except `S=SQRT_Z`)
- **Reset operations**: `R`, `MR`, `MRX`, `MRY`, `MRZ`
- **Pauli product measurements** (`MPP`) - could be added later via `measurePauli`
- **Record references** (`rec[-1]`) for feed-forward operations
- **Annotations**: `QUBIT_COORDS`, `DETECTOR`, `OBSERVABLE_INCLUDE`, etc.
- **Multi-target CNOT with odd targets**: `CNOT 0 1 2` (invalid)

## 3. Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   STIM File     │────▶│  stim-parser     │────▶│   AST (Stim)    │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                              ┌───────────────────────────┘
                              ▼
                    ┌─────────────────────┐
                    │   STIM-to-CHP       │
                    │   Translator        │
                    │                     │
                    │  • Gate mapping     │
                    │  • Decomposition    │
                    │  • Error detection  │
                    │  • Qubit tracking   │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   CHP Clifford Monad │
                    │   Simulation        │
                    │                     │
                    │  runWith n circuit  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Results/Output    │
                    └─────────────────────┘
```

## 4. Implementation Modules

### `app/StimToCHP.hs`

Core translation module:
- `translateStim :: Stim -> Either TranslationError CHPCircuit`
- `translateGate :: Gate -> Either TranslationError [SymplecticGate]`
- `translateMeasure :: Measure -> Either TranslationError Pauli`
- `countQubits :: Stim -> Int`
- `validateCircuit :: Stim -> Either TranslationError ()`

### `app/CHPCircuit.hs`

Intermediate representation:
```haskell
data CHPCircuit = CHPCircuit 
  { numQubits :: Int
  , operations :: [CHPOperation]
  , measurements :: [(Int, Pauli)]  -- (measurementIndex, pauli)
  }

data CHPOperation 
  = GateOp SymplecticGate
  | MeasureOp Pauli Int  -- Pauli to measure, result index
```

### `app/Simulator.hs`

Simulation runner:
```haskell
runCHPCircuit :: CHPCircuit -> IO (SomeTableau, [Bool])
runCHPCircuit circuit = runWith (numQubits circuit) $ do
  -- Apply gates
  -- Collect measurements
```

### `app/CLI.hs`

Command-line interface:
- File input handling
- Error reporting with source locations
- Output formatting (tableau state, measurement results)

### `app/Main.hs`

Entry point:
1. Parse command line arguments (input file, options)
2. Read and parse STIM file
3. Translate to CHP circuit
4. Run simulation
5. Print results

## 5. Design Decisions

### Qubit Count Determination

Scan the entire AST to find maximum qubit index:
```haskell
getMaxQubit :: Stim -> Int
getMaxQubit = ...
```

Use for `runWith` initialization.

### Gate Decomposition Strategy

**Decision**: Decompose all gates to H/S/CNOT in the translator (no src changes).

This keeps the translation layer separate from the core simulator.

### Multi-target Gates

STIM allows:
- `H 0 1 2` → Apply H to each qubit
- `CNOT 0 1 2 3` → Pair as (0,1), (2,3)

**Odd CNOT targets** (e.g., `CNOT 0 1 2`) → Error

### Error Handling

```haskell
data TranslationError 
  = UnsupportedGate GateTy SourcePos
  | UnsupportedNoise NoiseTy SourcePos
  | UnsupportedMeasure MeasureTy SourcePos
  | InvalidQubitCount String
  | NonCliffordRotation String
  | OddCNOTTargets [Q]
  deriving (Show)
```

### Measurement Results

Track measurement outcomes with indices for deterministic replay and analysis.

## 6. Example Workflow

```haskell
-- Input: example.stim
-- H 0
-- CNOT 0 1
-- M 0

main :: IO ()
main = do
  -- 1. Parse
  stimText <- readFile "example.stim"
  let stim = run parseStim ("!!!Start " ++ stimText)
  
  -- 2. Validate & Translate
  case translateStim stim of
    Left err -> putStrLn $ "Error: " ++ show err
    Right circuit -> do
      -- 3. Run simulation
      (tableau, results) <- runCHPCircuit circuit
      
      -- 4. Output results
      putStrLn "Final tableau:"
      printTableau tableau
      putStrLn $ "Measurement results: " ++ show results
```

## 7. Testing Strategy

### Unit Tests

- Individual gate decomposition correctness
- Measurement translation
- Qubit counting
- Error detection for unsupported features

### Property Tests

- Round-trip invariants
- Decomposition equivalence (tableau state matches)

### Integration Tests

- Bell state preparation
- GHZ state preparation  
- Simple error correction codes
- Example STIM files from Stim documentation

## 8. Future Extensions

1. **Pauli Product Measurements** (`MPP`): Add via `measurePauli` with product construction
2. **Repeat Blocks**: Unroll loops during translation
3. **More Clifford Gates**: Add native support in src to avoid decomposition overhead
4. **Circuit Visualization**: Output intermediate CHP operations
