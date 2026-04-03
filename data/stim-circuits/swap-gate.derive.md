# SWAP Gate Derivation

## Circuit
```
X 1
SWAP 0 1
M 0
M 1
```

## Mathematical Derivation

### Step 1: Initial State
$$|\psi_0\rangle = |00\rangle$$

### Step 2: X Gate on Qubit 1
$$|\psi_1\rangle = |01\rangle$$

### Step 3: SWAP Gate
The SWAP gate exchanges the states of two qubits:
$$\text{SWAP}|a,b\rangle = |b,a\rangle$$

Therefore:
$$|\psi_2\rangle = \text{SWAP}|01\rangle = |10\rangle$$

## SWAP Decomposition

In the CHP simulator, SWAP is decomposed as three CNOT gates:
$$\text{SWAP}(a, b) = \text{CNOT}(a, b) \cdot \text{CNOT}(b, a) \cdot \text{CNOT}(a, b)$$

Verification:
1. CNOT(a,b): |01⟩ → |01⟩ (control is 0, no change)
2. CNOT(b,a): |01⟩ → |11⟩ (control is 1, flip a)
3. CNOT(a,b): |11⟩ → |10⟩ (control is 1, flip b)

Result: |10⟩ ✓

## Why Three CNOTs?

The SWAP decomposition uses the identity:
$$\text{SWAP} = \text{CNOT}_{ab} \cdot \text{CNOT}_{ba} \cdot \text{CNOT}_{ab}$$

Geometric interpretation:
- First CNOT: create entanglement
- Second CNOT (reversed): transfer state  
- Third CNOT: disentangle

## Measurement

Final state: $|10\rangle$

Z-basis measurements:
- Qubit 0: |1⟩ → measurement outcome **-1**
- Qubit 1: |0⟩ → measurement outcome **+1**

## Stabilizer Analysis

Initial state |01⟩ has stabilizers:
- $+Z_0$ (qubit 0 in |0⟩)
- $-Z_1$ (qubit 1 in |1⟩)

After SWAP(|01⟩) = |10⟩:
- $-Z_0$ (qubit 0 now in |1⟩)
- $+Z_1$ (qubit 1 now in |0⟩)

The SWAP exchanges both the state and the stabilizers:
$$\text{SWAP} \cdot Z_0 \cdot \text{SWAP}^\dagger = Z_1$$
$$\text{SWAP} \cdot Z_1 \cdot \text{SWAP}^\dagger = Z_0$$

## General Property

SWAP is a Clifford gate that exchanges Pauli operators:
- SWAP: $X_a \leftrightarrow X_b$, $Z_a \leftrightarrow Z_b$

This makes it particularly simple in the CHP tableau representation - it just swaps the corresponding rows.
