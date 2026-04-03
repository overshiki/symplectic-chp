# GHZ State Derivation

## Circuit
```
H 0
CNOT 0 1
CNOT 0 2
M 0
M 1
M 2
```

## Mathematical Derivation

### Step 1: Initial State
$$|\psi_0\rangle = |000\rangle$$

### Step 2: Hadamard on Qubit 0
$$|\psi_1\rangle = |+\rangle \otimes |00\rangle = \frac{|000\rangle + |100\rangle}{\sqrt{2}}$$

### Step 3: First CNOT(0, 1)
$$\text{CNOT}(|000\rangle) = |000\rangle$$
$$\text{CNOT}(|100\rangle) = |110\rangle$$

$$|\psi_2\rangle = \frac{|000\rangle + |110\rangle}{\sqrt{2}}$$

### Step 4: Second CNOT(0, 2)
$$\text{CNOT}(|000\rangle) = |000\rangle$$
$$\text{CNOT}(|110\rangle) = |111\rangle$$

$$|\psi_3\rangle = \frac{|000\rangle + |111\rangle}{\sqrt{2}} = |\text{GHZ}\rangle$$

This is the 3-qubit GHZ state (Greenberger-Horne-Zeilinger).

## Stabilizer Analysis

The GHZ state has stabilizers:
- $Z \otimes Z \otimes I$  ($Z_0 Z_1 = +1$)
- $Z \otimes I \otimes Z$  ($Z_0 Z_2 = +1$)  
- $X \otimes X \otimes X$  ($X_0 X_1 X_2 = +1$)

From the first two, we get $I \otimes Z \otimes Z^{-1} = Z_1 Z_2 = +1$ as well.

## Measurement Properties

When measuring all three qubits in Z-basis:
- All three outcomes are perfectly correlated
- Either all +1 (|000⟩) or all -1 (|111⟩)
- This follows from the stabilizer $Z_0 Z_1 = Z_0 Z_2 = Z_1 Z_2 = +1$

## Comparison with Bell State

The GHZ state generalizes the Bell state to 3 qubits:
- Bell: $\frac{|00\rangle + |11\rangle}{\sqrt{2}}$
- GHZ: $\frac{|000\rangle + |111\rangle}{\sqrt{2}}$

Both exhibit maximal entanglement, but GHZ has tripartite entanglement that cannot be reduced to bipartite entanglement.
