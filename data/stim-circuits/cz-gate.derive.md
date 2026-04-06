# CZ Gate: Mathematical Derivation

## Circuit Specification

```
H 0
H 1
CZ 0 1
MX 0
MX 1
```

## Objective

Demonstrate CZ gate creates phase entanglement and verify its decomposition.

---

## CZ Gate Decomposition

### Theorem
$$CZ(c, t) = H(t) \cdot CNOT(c, t) \cdot H(t)$$

### Proof
The CZ gate applies phase -1 when both qubits are |1⟩:
$$CZ|ab\rangle = (-1)^{a \cdot b}|ab\rangle$$

The circuit $H_t \cdot CNOT_{c,t} \cdot H_t$:

1. $H_t$ transforms target from Z to X basis
2. $CNOT_{c,t}$ creates controlled-X in X basis → controlled-phase in Z basis
3. $H_t$ transforms back to Z basis

**Verification via truth table:**

| $\|ab\rangle$ | After $H_t$ | After CNOT | After $H_t$ | CZ Target |
|-------------|-------------|-----------|-------------|-----------|
| $\|00\rangle$ | $\|0+\rangle$ | $\|0+\rangle$ | $\|00\rangle$ | $+\|00\rangle$ |
| $\|01\rangle$ | $\|0-\rangle$ | $\|0-\rangle$ | $\|01\rangle$ | $+\|01\rangle$ |
| $\|10\rangle$ | $\|1+\rangle$ | $\|1+\rangle$ | $\|10\rangle$ | $+\|10\rangle$ |
| $\|11\rangle$ | $\|1-\rangle$ | $\|0-\rangle$ | $-\|11\rangle$ | $-\|11\rangle$ |

Both give the same phase pattern. **Q.E.D.**

---

## State Evolution

### Initial State

$$|\psi_0\rangle = |00\rangle$$

**Tableau:**
```yaml
stabilizers: ["+ZI", "+IZ"]
destabilizers: ["+XI", "+IX"]
```

### Step 1: Hadamard on Both Qubits

$$|\psi_1\rangle = |+\rangle \otimes |+\rangle = \frac{1}{2}(|00\rangle + |01\rangle + |10\rangle + |11\rangle)$$

**Tableau after H⊗H:**
```yaml
stabilizers: ["+XI", "+IX"]
destabilizers: ["+ZI", "+IZ"]
```

### Step 2: CZ Gate

Applying $CZ|ab\rangle = (-1)^{ab}|ab\rangle$:

$$|\psi_2\rangle = \frac{1}{2}(|00\rangle + |01\rangle + |10\rangle - |11\rangle)$$

**Tableau after CZ (pre-measurement):**
```yaml
stabilizers: ["+XZ", "+ZX"]
destabilizers: ["+ZI", "+IZ"]
```

**Conjugation:**
- $X \otimes I \rightarrow X \otimes Z$
- $I \otimes X \rightarrow Z \otimes X$

---

## Measurement Analysis

### X-Basis Measurement

The stabilizers $g_1 = XZ$ and $g_2 = ZX$ do not commute with $X \otimes I$ or $I \otimes X$ individually:

$$[X \otimes I, X \otimes Z] = 0 \quad \text{(commute)}$$
$$[X \otimes I, Z \otimes X] \neq 0 \quad \text{(anticommute)}$$

**Result:** Measurements are **random** and **correlated**.

### Correlation Structure

The product $X \otimes X$ commutes with both stabilizers:
$$[X \otimes X, X \otimes Z] = [X \otimes X, Z \otimes X] = 0$$

Therefore:
$$\langle X \otimes X \rangle = \pm 1$$

The sign depends on the random outcomes of individual measurements.

**Case 1: Outcomes [+1, +1]**
```yaml
probability: 0.25
measurement_outcomes: [+1, +1]
post_measurement_tableau:
  stabilizers: ["+IX", "+XI"]
  destabilizers: ["+XZ", "+ZX"]
```

**Case 2: Outcomes [+1, -1]**
```yaml
probability: 0.25
measurement_outcomes: [+1, -1]
post_measurement_tableau:
  stabilizers: ["-IX", "+XI"]
  destabilizers: ["+XZ", "+ZX"]
```

**Case 3: Outcomes [-1, +1]**
```yaml
probability: 0.25
measurement_outcomes: [-1, +1]
post_measurement_tableau:
  stabilizers: ["+IX", "-XI"]
  destabilizers: ["+XZ", "+ZX"]
```

**Case 4: Outcomes [-1, -1]**
```yaml
probability: 0.25
measurement_outcomes: [-1, -1]
post_measurement_tableau:
  stabilizers: ["-IX", "-XI"]
  destabilizers: ["+XZ", "+ZX"]
```

---

## Expected Outcome

| Property | Expected Value |
|----------|---------------|
| **Final State** | $\frac{1}{2}(\|00\rangle + \|01\rangle + \|10\rangle - \|11\rangle)$ |
| **Pre-measurement stabilizers** | `+XZ`, `+ZX` |
| **Pre-measurement destabilizers** | `+ZI`, `+IZ` |
| **Measurement Type** | Random |
| **Tableau Validity** | True |
| **P(+1,+1)** | ≈ 0.25 |
| **P(+1,-1)** | ≈ 0.25 |
| **P(-1,+1)** | ≈ 0.25 |
| **P(-1,-1)** | ≈ 0.25 |

**Key Property:** The state is entangled with maximal entropy for reduced density matrices.

**Note:** Unlike Bell state, X measurements are not perfectly correlated. The test only verifies tableau validity, not specific outcomes.
