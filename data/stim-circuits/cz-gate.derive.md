# CZ Gate Derivation

## Circuit
```
H 0
H 1
CZ 0 1
MX 0
MX 1
```

## Mathematical Derivation

### Step 1: Initial State
$$|\psi_0\rangle = |00\rangle$$

### Step 2: Hadamard on Both Qubits
$$|\psi_1\rangle = |+\rangle \otimes |+\rangle = \frac{1}{2}(|00\rangle + |01\rangle + |10\rangle + |11\rangle)$$

### Step 3: CZ Gate
The controlled-Z gate applies a phase of -1 when both qubits are |1⟩:
$$\text{CZ}|ab\rangle = (-1)^{a \cdot b}|ab\rangle$$

Applying to each term:
- CZ|00⟩ = +|00⟩
- CZ|01⟩ = +|01⟩
- CZ|10⟩ = +|10⟩
- CZ|11⟩ = -|11⟩

Therefore:
$$|\psi_2\rangle = \frac{1}{2}(|00\rangle + |01\rangle + |10\rangle - |11\rangle)$$

## CZ Decomposition

In the CHP simulator, CZ is decomposed as:
$$\text{CZ}(c, t) = H(t) \cdot \text{CNOT}(c, t) \cdot H(t)$$

Verification:
- CNOT creates phase entanglement in X-basis
- H transforms between X and Z bases
- The combination creates the controlled-phase

## X-Basis Measurement Analysis

The final state can be rewritten in X-basis:
$$|\psi_2\rangle = \frac{1}{\sqrt{2}}(|++\rangle + |--\rangle)$$

Wait, let's verify:
$$|++\rangle = \frac{1}{2}(|00\rangle + |01\rangle + |10\rangle + |11\rangle)$$
$$|--\rangle = \frac{1}{2}(|00\rangle - |01\rangle - |10\rangle + |11\rangle)$$

So:
$$\frac{|++\rangle + |--\rangle}{\sqrt{2}} = \frac{1}{2\sqrt{2}}(2|00\rangle + 0|01\rangle + 0|10\rangle + 2|11\rangle) = \frac{|00\rangle + |11\rangle}{\sqrt{2}}$$

This is different from our state. Let's try another approach.

Actually, our state is:
$$|\psi_2\rangle = \frac{|00\rangle + |01\rangle + |10\rangle - |11\rangle}{2}$$

In terms of |±⟩:
$$|0\rangle = \frac{|+\rangle + |-\rangle}{\sqrt{2}}, \quad |1\rangle = \frac{|+\rangle - |-\rangle}{\sqrt{2}}$$

Computing each basis state:
- |00⟩ → |++⟩
- |01⟩ → |+-⟩  
- |10⟩ → |-+⟩
- |11⟩ → |--⟩

So:
$$|\psi_2\rangle = \frac{|++\rangle + |+-\rangle + |-+\rangle - |--\rangle}{2}$$

This is not a product state - measuring X on each qubit gives correlated outcomes.

## Measurement Correlations

The state $|\psi_2\rangle$ is actually an eigenstate of $X \otimes X$:
$$(X \otimes X)|\psi_2\rangle = \frac{|10\rangle + |11\rangle + |00\rangle - |01\rangle}{2} \neq \pm|\psi_2\rangle$$

Wait, let me recalculate. Actually:
$$(X \otimes X)|ab\rangle = |\bar{a}\bar{b}\rangle$$

So:
$$(X \otimes X)|\psi_2\rangle = \frac{|11\rangle + |10\rangle + |01\rangle - |00\rangle}{2} \neq \pm|\psi_2\rangle$$

The X measurements are **not perfectly correlated** - they show quantum correlations but not the simple correlation of the Bell state.

## Key Insight

This circuit demonstrates:
1. CZ creates phase entanglement
2. Measuring in X-basis reveals quantum correlations
3. Unlike Bell state, correlations are not perfect
4. The CHP simulator correctly handles the gate decomposition
