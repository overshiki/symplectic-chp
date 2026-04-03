# Multi-Target Gates Derivation

## Circuit
```
H 0
H 1
H 2
MX 0
MX 1
MX 2
```

## Mathematical Derivation

### Step 1: Initial State
$$|\psi_0\rangle = |000\rangle$$

### Step 2: Hadamard on All Qubits
$$|\psi_1\rangle = |+\rangle^{\otimes 3} = \frac{1}{\sqrt{8}}\sum_{x=0}^{7}|x\rangle$$

Explicitly:
$$|\psi_1\rangle = \frac{|000\rangle + |001\rangle + |010\rangle + |011\rangle + |100\rangle + |101\rangle + |110\rangle + |111\rangle}{\sqrt{8}}$$

This is the uniform superposition over all 3-bit strings.

## Product State Structure

Importantly:
$$|\psi_1\rangle = |+\rangle \otimes |+\rangle \otimes |+\rangle$$

This is a **product state**, not an entangled state!

Each qubit is in the state $|+\rangle$ independently.

## X-Basis Measurement

Since $|+\rangle$ is the +1 eigenstate of X:
$$X|+\rangle = +|+\rangle$$

Measuring each qubit in the X-basis gives outcome **+1** deterministically.

## Stabilizer Representation

The state |+++⟩ has stabilizers:
- $+X \otimes I \otimes I$
- $+I \otimes X \otimes I$
- $+I \otimes I \otimes X$

Or compactly: $\{+X_0, +X_1, +X_2\}$

## Why This Test Matters

This circuit tests:
1. **Multi-target gate support** - STIM allows `H 0 1 2` syntax
2. **Independent evolution** - Each qubit evolves separately
3. **Product state handling** - CHP correctly handles non-entangled states
4. **Deterministic measurements** - All outcomes should be +1

## Comparison with GHZ

| Property | This Circuit | GHZ Circuit |
|----------|--------------|-------------|
| Entanglement | No (product) | Yes (genuine) |
| Measurements | Deterministic | Correlated random |
| Stabilizers | Independent | Entangled |
| Gate depth | 1 layer H | 3 layers (H, CNOT, CNOT) |

The CHP simulator handles both cases correctly through the symplectic formalism.
