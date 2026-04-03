# Phase Gate Derivation

## Circuit
```
H 0
S 0
S 0
M 0
```

## Mathematical Derivation

### Step 1: Initial State
$$|\psi_0\rangle = |0\rangle$$

### Step 2: Hadamard
$$|\psi_1\rangle = H|0\rangle = |+\rangle = \frac{|0\rangle + |1\rangle}{\sqrt{2}}$$

### Step 3: Apply S² = Z
Since $S^2 = Z$:
$$|\psi_2\rangle = Z|+\rangle = \frac{Z|0\rangle + Z|1\rangle}{\sqrt{2}} = \frac{|0\rangle - |1\rangle}{\sqrt{2}} = |-\rangle$$

## Z-Basis Measurement

The final state is $|-\rangle$. Measuring in Z-basis:

The Z operator eigenstates:
- $|0\rangle$ with eigenvalue +1
- $|1\rangle$ with eigenvalue -1

Since:
$$|-\rangle = \frac{|0\rangle - |1\rangle}{\sqrt{2}}$$

This is a superposition, not an eigenstate. The measurement is **random** with:
- P(+1) = |⟨0|-⟩|² = 1/2
- P(-1) = |⟨1|-⟩|² = 1/2

## Stabilizer Analysis

Initial: +Z

After H: +X

After Z: -X (since ZXZ† = -X, or equivalently, Z anticommutes with X)

Actually, let me verify the stabilizer evolution:

Starting state |0⟩: stabilizer = +Z

H|0⟩ = |+⟩: stabilizer = +X

Z|+⟩ = |−⟩: stabilizer = -X

## Alternative View: Phase Kickback

The circuit can be seen as:
1. Prepare |+⟩ (X eigenstate)
2. Apply Z (phase flip on |1⟩)

The Z gate introduces a relative phase between |0⟩ and |1⟩, converting |+⟩ to |−⟩.

## Expected Outcome

The Z-basis measurement outcome is **random**:
- Cannot predict +1 or -1 deterministically
- Both outcomes have probability 1/2
- The tableau validity is maintained

This tests that the CHP simulator correctly handles:
1. S² = Z decomposition
2. Random measurement outcomes
3. Stabilizer sign changes
