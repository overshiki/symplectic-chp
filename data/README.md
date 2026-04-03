# STIM Test Circuits

This directory contains test circuits for the STIM-to-CHP simulator.

## Directory Structure

```
data/
├── README.md           # This file
├── test-stim.rkt       # Racket test script
└── stim-circuits/      # Test circuit files
    ├── *.stim          # Circuit definition files
    └── *.expected      # Expected results
```

## Running Tests

### Method 1: Haskell Test Suite (Recommended)

The STIM circuits are automatically tested as part of the cabal test suite:

```bash
cabal test
```

This runs all tests including:
- 58 original Haskell unit tests
- 10 STIM circuit integration tests

### Method 2: Racket Script

Alternative test runner using Racket:

#### Prerequisites

- Racket (>= 7.0)
- Built symplectic-chp executable (`cabal build`)

#### Run All Tests

```bash
cd data
./test-stim.rkt
```

#### With Verbose Output

```bash
./test-stim.rkt -v
```

## Test Circuit Format

### STIM Files (.stim)

Standard STIM circuit format with comments starting with `#`.

Example:
```
# Bell State Preparation
H 0
CNOT 0 1
M 0
M 1
```

### Expected Files (.expected)

Comment-based format specifying expected results:

```
# Comments start with #
measurements_correlated: true    # All measurements should be equal
measurement_outcomes: [#t, #f]   # Exact expected outcomes
stabilizers: ["+ZZ", "+XX"]      # Expected stabilizers
```

### Derivation Files (.derive.md)

Mathematical derivations explaining the quantum mechanics behind each circuit. These document:
- State evolution through each gate
- Stabilizer transformations
- Measurement outcome predictions
- Relevant quantum mechanics theory

Example: See `bell-state.derive.md` for the Bell state preparation derivation.

## Supported Test Checks

1. **Tableau validity** - Always checked
2. **Measurement correlations** - Checked if `measurements_correlated: true`
3. **Exact outcomes** - Checked if `measurement_outcomes: [...]` specified

## Test Circuits

| Circuit | Description | Checks |
|---------|-------------|--------|
| `bell-state.stim` | Bell state (\|Φ⁺⟩) | Correlated measurements |
| `ghz-state.stim` | GHZ state | Correlated measurements |
| `single-hadamard.stim` | Single qubit H gate | Exact outcome |
| `stabilizer-cycle.stim` | X = HSSH decomposition | Exact outcome |
| `cz-gate.stim` | CZ gate | Validity only |
| `swap-gate.stim` | SWAP gate | Exact outcome |
| `multi-target.stim` | Multiple H gates | Exact outcomes |
| `y-measurement.stim` | Y-basis measurement | Validity only |
| `phase-gate.stim` | S gate test | Validity only |
| `unsupported-rx.stim` | Error handling test | Error expected |

## Adding New Tests

1. Create a `.stim` file in `stim-circuits/`
2. Create a `.expected` file with expected results
3. Run `./test-stim.rkt` to verify
