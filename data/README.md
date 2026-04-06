# STIM Test Circuits

This directory contains test circuits for the STIM-to-CHP simulator.

## Formal Verification

The `.expected` test case files are derived from the [symplectic-pauli](https://github.com/overshiki/symplectic-pauli) Agda formalization project, which provides machine-checked proofs of the CHP algorithm based on the Symplectic Basis Theorem.

### Agda Formalization Highlights

- **Symplectic Basis Theorem**: Complete proof that every symplectic vector space admits a canonical basis
- **Fundamental Correspondence**: Proven equivalence between Pauli commutation and symplectic form
- **Tableau as Symplectic Basis**: Formal verification that the CHP tableau satisfies geometric constraints
- **Verified Circuit Examples**: All 10 test circuits have mechanically verified proofs in `CircuitExamples.agda`

The test expectations represent the ground truth from these formal proofs, validated against the Haskell implementation.

## Directory Structure

```
data/
├── README.md           # This file
└── stim-circuits/      # Test circuit files
    ├── *.stim          # Circuit definition files
    ├── *.expected      # Expected results
    └── *.derive.md     # Mathematical derivations
```

## Running Tests

The STIM circuits are automatically tested as part of the cabal test suite:

```bash
cabal test
```

This runs all tests including:
- 58 original Haskell unit tests
- 10 STIM circuit integration tests

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

YAML-based format specifying expected results:

```yaml
# Deterministic circuit
deterministic: true
measurement_outcomes: [+1, +1]
post_measurement_tableau:
  stabilizers: ["+XX", "+ZZ"]
  destabilizers: ["+ZI", "+IX"]

# Random circuit with cases
deterministic: false
cases:
  - probability: 0.5
    measurement_outcomes: [+1, +1]
    post_measurement_tableau:
      stabilizers: ["+ZI", "+ZZ"]
      destabilizers: ["+XX", "+IX"]
  - probability: 0.5
    measurement_outcomes: [-1, -1]
    post_measurement_tableau:
      stabilizers: ["-ZI", "-ZZ"]
      destabilizers: ["+XX", "+IX"]
pre_measurement_tableau:
  stabilizers: ["+XX", "+ZZ"]
  destabilizers: ["+ZI", "+IX"]
```

### Derivation Files (.derive.md)

Formal mathematical derivations with:
- **LaTeX-formatted equations** for all quantum states and operators
- **Step-by-step state evolution** through each gate
- **Tableau state at each step** (stabilizers and destabilizers)
- **Stabilizer analysis** with verification tables
- **Bloch sphere representations** where applicable
- **Expected outcome tables** summarizing deterministic/random results
- **Physical interpretations** of the quantum phenomena

Each derivation includes:
1. Circuit specification and objective
2. Theoretical background (gate definitions, identities)
3. Rigorous mathematical derivation
4. Tableau evolution at each circuit step
5. Stabilizer evolution table
6. Measurement analysis with probabilities
7. Summary table of expected outcomes

Example: See `bell-state.derive.md` for the Bell state preparation derivation.

## Test Circuits

| Circuit | Description | Type |
|---------|-------------|------|
| `bell-state.stim` | Bell state (\|Φ⁺⟩) | Random (2 cases) |
| `ghz-state.stim` | GHZ state | Random (2 cases) |
| `single-hadamard.stim` | Single qubit H gate | Deterministic |
| `stabilizer-cycle.stim` | X = HSSH decomposition | Deterministic |
| `cz-gate.stim` | CZ gate | Random (4 cases) |
| `swap-gate.stim` | SWAP gate | Deterministic |
| `multi-target.stim` | Multiple H gates | Deterministic |
| `y-measurement.stim` | Y-basis measurement | Random (2 cases) |
| `phase-gate.stim` | S gate test | Random (2 cases) |
| `unsupported-rx.stim` | Error handling test | Error expected |

## Adding New Tests

1. Create a `.stim` file in `stim-circuits/`
2. Create a `.expected` file with expected results following the YAML format
3. Optionally create a `.derive.md` file with mathematical derivation
4. Run `cabal test` to verify
