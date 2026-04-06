# STIM Parser Implementation

## Overview

This document describes the implementation of STIM circuit file parsing and simulation in `symplectic-chp`.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   STIM File     │────▶│  stim-parser     │────▶│   AST (Stim)    │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                              ┌───────────────────────────┘
                              ▼
                    ┌─────────────────────┐
                    │   StimToCHP         │
                    │   (Translation)     │
                    │                     │
                    │  • Gate mapping     │
                    │  • Decomposition    │
                    │  • Error detection  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   CHPCircuit        │
                    │   (Intermediate     │
                    │    Representation)  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Simulator         │
                    │   (CHP Clifford     │
                    │    Monad)           │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Results/Output    │
                    └─────────────────────┘
```

## Implementation Modules

### `app/StimToCHP.hs`

Core translation from STIM AST to CHP operations.

**Key Functions:**
- `translateStim :: Stim -> Either TranslationError CHPCircuit` - Main translation entry point
- `translateGate :: Gate -> Either TranslationError [SymplecticGate]` - Gate translation with decomposition
- `translateMeasure :: Measure -> Either TranslationError Pauli` - Measurement translation
- `countQubits :: Stim -> Int` - Count total qubits in circuit

**Error Types:**
```haskell
data TranslationError
  = UnsupportedGate GateTy
  | UnsupportedMeasure MeasureTy
  | UnsupportedNoise NoiseTy
  | UnsupportedGpp GppTy
  | UnsupportedAnnotation AnnTy
  | UnsupportedRepeat
  | OddCNOTTargets [Q]
  | EmptyCircuit
```

### `app/CHPCircuit.hs`

Intermediate representation for CHP circuits.

```haskell
data CHPCircuit = CHPCircuit
  { numQubits :: Int
  , operations :: [CHPOperation]
  }

data CHPOperation
  = GateOp SymplecticGate
  | MeasureOp Pauli Int  -- Pauli operator and measurement index
```

### `app/Simulator.hs`

Simulation runner executing CHP circuits.

**Key Functions:**
- `runCHPCircuit :: CHPCircuit -> IO SimulationResult` - Run with random seed
- `runCHPCircuitWithSeed :: Int -> CHPCircuit -> IO SimulationResult` - Run with specific seed
- `printResults :: SimulationResult -> IO ()` - Human-readable output

**Result Type:**
```haskell
data SimulationResult = SimulationResult
  { finalTableau :: SomeTableau
  , measurementOutcomes :: [Bool]
  , measurementCount :: Int
  }
```

### `app/CLI.hs`

Command-line interface handling arguments and file I/O.

**Configuration:**
```haskell
data Config = Config
  { inputFile :: FilePath
  , verbose :: Bool
  , showTableau :: Bool
  , seed :: Maybe Int
  }
```

**Command-line Options:**
- `-h, --help` - Show help message
- `-v` - Enable verbose output
- `--seed N` - Use specific random seed
- `--no-tableau` - Don't show final tableau

### `app/Main.hs`

Entry point orchestrating the pipeline:
1. Parse command-line arguments
2. Read and parse STIM file
3. Translate to CHP circuit
4. Run simulation
5. Print results

## Supported STIM Features

### Gates

| STIM Gate | Status | Implementation |
|-----------|--------|----------------|
| `H q` | ✅ Supported | Direct: `Local (Hadamard q)` |
| `S q` | ✅ Supported | Direct: `Local (Phase q)` |
| `CNOT c t` / `CX c t` | ✅ Supported | Direct: `CNOT c t` |
| `I q` / `II q` | ✅ Supported | No-op (empty list) |
| `X q` | ✅ Supported | Decomposed: `H; S; S; H` |
| `Y q` | ✅ Supported | Decomposed: `S; X; S³` |
| `Z q` | ✅ Supported | Decomposed: `S; S` |
| `CZ c t` | ✅ Supported | Decomposed: `H(t); CNOT(c,t); H(t)` |
| `SWAP a b` | ✅ Supported | Decomposed: `CNOT(a,b); CNOT(b,a); CNOT(a,b)` |
| `SQRT_Z q` | ✅ Supported | Alias for `S q` |
| `SQRT_Z_DAG q` | ✅ Supported | Decomposed: `S³` |
| `S_DAG q` | ✅ Supported | Decomposed: `S³` |
| `XCZ c t` | ✅ Supported | Translated to `CNOT` with reversed qubits |
| `ZCX c t` | ✅ Supported | Alias for `CNOT c t` |
| `ZCZ c t` | ✅ Supported | Decomposed like `CZ` |
| `H_XZ q` | ✅ Supported | Alias for `H q` |

### Multi-Target Gates

- `H 0 1 2` → Apply H to each qubit individually
- `S 0 1 2` → Apply S to each qubit individually
- `CNOT 0 1 2 3` → Pair as (0,1), (2,3); error if odd count
- `SWAP 0 1` → Single pair only
- `CZ 0 1 2 3` → Pair as (0,1), (2,3)

### Measurements

| STIM Measure | Status | Pauli Operator |
|--------------|--------|----------------|
| `M q` / `MZ q` | ✅ Supported | `Pauli 0 (bit q) 0` (Z-basis) |
| `MX q` | ✅ Supported | `Pauli (bit q) 0 0` (X-basis) |
| `MY q` | ✅ Supported | `Pauli (bit q) (bit q) 1` (Y-basis) |

### NOT Supported (Will Error)

- **Noise channels**: `X_ERROR`, `DEPOLARIZE1/2`, `PAULI_CHANNEL_*`, etc.
- **Non-Clifford gates**: `T`, `RX`, `RY`, `RZ`, `SQRT_X`, `SQRT_Y`, etc.
- **Controlled rotations**: `C_XYZ`, `C_ZYX`, etc.
- **Two-qubit Clifford gates**: `ISWAP`, `CZSWAP`, `SQRT_XX`, etc.
- **Hadamard variants**: `H_XY`, `H_YZ`, `H_NXY`, etc.
- **Controlled Pauli variants**: `CY`, `XCY`, `YCX`, `YCY`, `YCZ`, `ZCY`, etc.
- **Reset operations**: `R`, `MR`, `MRX`, `MRY`, `MRZ`
- **Pauli product measurements**: `MPP` (Gpp)
- **Annotations**: `QUBIT_COORDS`, `DETECTOR`, `OBSERVABLE_INCLUDE`, etc.
- **Repeat blocks**: `REPEAT n { ... }`
- **Record references**: `rec[-1]` for feed-forward

## Gate Decomposition Details

### Pauli X
```haskell
-- X = H * S * S * H
decomposeX q = [H q, S q, S q, H q]
```

### Pauli Y
```haskell
-- Y = iXZ = S * X * S³
decomposeY q = [S q] ++ decomposeX q ++ [S q, S q, S q]
```

### Pauli Z
```haskell
-- Z = S * S
decomposeZ q = [S q, S q]
```

### Controlled-Z
```haskell
-- CZ(c,t) = H(t) * CNOT(c,t) * H(t)
decomposeCZ (c, t) = [H t, CNOT c t, H t]
```

### SWAP
```haskell
-- SWAP(a,b) = CNOT(a,b) * CNOT(b,a) * CNOT(a,b)
decomposeSWAP (a, b) = [CNOT a b, CNOT b a, CNOT a b]
```

## Usage Examples

### Basic Usage

```bash
# Simulate a circuit
cabal run symplectic-chp -- circuit.stim

# With verbose output
cabal run symplectic-chp -- -v circuit.stim

# With specific seed for reproducibility
cabal run symplectic-chp -- --seed 42 circuit.stim

# Hide tableau output
cabal run symplectic-chp -- --no-tableau circuit.stim
```

### Example STIM File

```
# Bell state preparation
H 0
CNOT 0 1
M 0
M 1
```

### Example Output

```
========================================
  CHP Simulation Results
========================================

Measurements performed: 2
Measurement outcomes:
  M0: +1 (|0⟩ or |+⟩)
  M1: +1 (|0⟩ or |+⟩)

Number of qubits: 2
Tableau valid: True

Stabilizers (generators of the stabilizer group):
  S0: +ZI
  S1: +ZZ

Destabilizers (dual to stabilizers):
  D0: +XX
  D1: +IX
```

## Error Handling

The translator provides descriptive error messages for unsupported features:

- **Unsupported gates**: Reports the specific gate type and suggests alternatives
- **Unsupported measurements**: Indicates only single-qubit Pauli measurements are supported
- **Noise channels**: Clearly states noise is not supported by CHP
- **Odd CNOT targets**: Explains CNOT requires even number of targets (control-target pairs)
- **Repeat blocks**: Suggests unrolling loops manually

## Testing

The implementation is tested via:
1. **Haskell Test Suite** (`cabal test`) - 68 tests including 10 STIM circuit integration tests
2. **Agda Formalization** - All test circuits verified in `symplectic-pauli`

Test circuits are in `data/stim-circuits/`:
- `bell-state.stim` - Bell state preparation
- `ghz-state.stim` - GHZ state preparation  
- `single-hadamard.stim` - Single qubit H gate
- `stabilizer-cycle.stim` - X = HSSH decomposition
- `cz-gate.stim` - CZ gate test
- `swap-gate.stim` - SWAP gate test
- `multi-target.stim` - Multi-target gates
- `y-measurement.stim` - Y-basis measurement
- `phase-gate.stim` - S gate test
- `unsupported-rx.stim` - Error handling test
