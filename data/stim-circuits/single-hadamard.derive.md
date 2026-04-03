# Single Hadamard Gate Derivation

## Circuit
```
H 0
MX 0
```

## Mathematical Derivation

### Step 1: Initial State
$$|\psi_0\rangle = |0\rangle$$

### Step 2: Hadamard Gate
$$H = \frac{1}{\sqrt{2}}\begin{pmatrix} 1 & 1 \\ 1 & -1 \end{pmatrix}$$

$$H|0\rangle = \frac{|0\rangle + |1\rangle}{\sqrt{2}} = |+\rangle$$

### Step 3: X-Basis Measurement
The state $|+\rangle$ is the +1 eigenstate of the Pauli X operator:
$$X|+\rangle = +|+\rangle$$

Since we're measuring in the X-basis (MX), the outcome is **deterministic +1**.

## Eigenstate Analysis

The Pauli X operator has eigenstates:
- $|+\rangle = \frac{|0\rangle + |1\rangle}{\sqrt{2}}$ with eigenvalue +1
- $|-\rangle = \frac{|0\rangle - |1\rangle}{\sqrt{2}}$ with eigenvalue -1

After applying H to |0⟩, we obtain exactly $|+\rangle$, so measuring X gives +1 with certainty.

## CHP Tableau

After H gate:
- Stabilizer: +X (instead of initial +Z)
- Destabilizer: +Z (instead of initial +X)

This swap reflects that H exchanges X and Z:
$$H X H^\dagger = Z, \quad H Z H^\dagger = X$$

## Key Insight

This circuit demonstrates that:
1. H creates a coherent superposition from a computational basis state
2. The resulting state is an eigenstate of the "conjugate" basis
3. Measurement outcome is deterministic when measuring in the eigenbasis
