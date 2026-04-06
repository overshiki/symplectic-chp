# SWAP Gate: Mathematical Derivation

## Circuit Specification

```
X 1
SWAP 0 1
M 0
M 1
```

## Objective

Verify SWAP gate exchanges qubit states and prove SWAP = CNOT₁₂ ∘ CNOT₂₁ ∘ CNOT₁₂.

---

## SWAP Gate Decomposition

### Theorem
$$\text{SWAP}(a, b) = \text{CNOT}(a, b) \cdot \text{CNOT}(b, a) \cdot \text{CNOT}(a, b)$$

### Proof via Truth Table

| Step | State | After CNOT(a,b) | After CNOT(b,a) | After CNOT(a,b) |
|------|-------|-----------------|-----------------|-----------------|
| 1 | $\|00\rangle$ | $\|00\rangle$ | $\|00\rangle$ | $\|00\rangle$ |
| 2 | $\|01\rangle$ | $\|01\rangle$ | $\|11\rangle$ | $\|10\rangle$ |
| 3 | $\|10\rangle$ | $\|11\rangle$ | $\|01\rangle$ | $\|01\rangle$ |
| 4 | $\|11\rangle$ | $\|10\rangle$ | $\|10\rangle$ | $\|11\rangle$ |

**Result mapping:**
- $|00\rangle \rightarrow |00\rangle$ ✓
- $|01\rangle \rightarrow |10\rangle$ ✓
- $|10\rangle \rightarrow |01\rangle$ ✓
- $|11\rangle \rightarrow |11\rangle$ ✓

**Q.E.D.** The circuit swaps qubit states.

### Verification for |01⟩

1. **CNOT(0,1)**: Control=0, no flip → $|01\rangle$
2. **CNOT(1,0)**: Control=1, flip qubit 0 → $|11\rangle$
3. **CNOT(0,1)**: Control=1, flip qubit 1 → $|10\rangle$

Result: $|01\rangle \rightarrow |10\rangle$ ✓

---

## State Evolution

### Initial State

$$|\psi_0\rangle = |00\rangle$$

**Tableau:**
```yaml
stabilizers: ["+ZI", "+IZ"]
destabilizers: ["+XI", "+IX"]
```

### Step 1: X Gate on Qubit 1

$$X = \begin{pmatrix} 0 & 1 \\ 1 & 0 \end{pmatrix}$$

$$|\psi_1\rangle = |01\rangle$$

**Tableau after X₁:**
```yaml
stabilizers: ["+ZI", "-IZ"]
destabilizers: ["+XI", "+IX"]
```

### Step 2: SWAP(0, 1)

$$\text{SWAP}|01\rangle = |10\rangle$$

**Final state before measurement:**
$$|\psi_2\rangle = |10\rangle$$

**Tableau after SWAP (post-measurement):**
```yaml
stabilizers: ["+IZ", "-ZI"]
destabilizers: ["+IX", "+XI"]
```

### SWAP Action on Pauli Operators

The SWAP gate exchanges Pauli operators:
$$\text{SWAP} \cdot X_0 \cdot \text{SWAP}^\dagger = X_1$$
$$\text{SWAP} \cdot Z_0 \cdot \text{SWAP}^\dagger = Z_1$$
$$\text{SWAP} \cdot X_1 \cdot \text{SWAP}^\dagger = X_0$$
$$\text{SWAP} \cdot Z_1 \cdot \text{SWAP}^\dagger = Z_0$$

This is equivalent to exchanging rows in the CHP tableau.

---

## Measurement Analysis

### Final State

$$|\psi_2\rangle = |10\rangle = |1\rangle_0 \otimes |0\rangle_1$$

### Z-Basis Measurements

| Qubit | State | Z Eigenvalue | Outcome |
|-------|-------|-------------|---------|
| 0 | $\|1\rangle$ | -1 | **-1** |
| 1 | $\|0\rangle$ | +1 | **+1** |

**Expected result:**
```yaml
deterministic: true
measurement_outcomes: [-1, +1]
post_measurement_tableau:
  stabilizers: ["+IZ", "-ZI"]
  destabilizers: ["+IX", "+XI"]
```

---

## Expected Outcome

| Property | Expected Value |
|----------|---------------|
| **Circuit Identity** | SWAP = CNOT₁₂ ∘ CNOT₂₁ ∘ CNOT₁₂ |
| **Final State** | $\|10\rangle$ |
| **Measurement 0** | -1 (deterministic) |
| **Measurement 1** | +1 (deterministic) |
| **Final Stabilizers** | `+IZ`, `-ZI` |
| **Final Destabilizers** | `+IX`, `+XI` |
| **Tableau Validity** | True |
| **P(M₀=-1, M₁=+1)** | 1.0 |
| **All other outcomes** | 0.0 |

**Key Property:** The SWAP exchanges both the quantum state and the stabilizer assignments between qubits.

**Geometric Interpretation:**
- Initial: Qubit 0 at |0⟩ (north pole), Qubit 1 at |1⟩ (south pole)
- After SWAP: Qubit 0 at |1⟩ (south pole), Qubit 1 at |0⟩ (north pole)
- The SWAP is its own inverse: SWAP² = I
