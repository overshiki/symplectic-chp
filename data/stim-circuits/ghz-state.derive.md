# GHZ State Preparation: Mathematical Derivation

## Circuit Specification

```
H 0
CNOT 0 1
CNOT 0 2
M 0
M 1
M 2
```

## Objective

Prepare the 3-qubit GHZ state $|GHZ\rangle = \frac{1}{\sqrt{2}}(|000\rangle + |111\rangle)$ and verify tripartite entanglement.

---

## Step-by-Step Derivation

### Initial State

$$|\psi_0\rangle = |000\rangle$$

**Tableau:**
```yaml
stabilizers: ["+ZII", "+IZI", "+IIZ"]
destabilizers: ["+XII", "+IXI", "+IIX"]
```

### Step 1: Hadamard on Qubit 0

$$|\psi_1\rangle = |+\rangle_0 \otimes |00\rangle_{12} = \frac{1}{\sqrt{2}}(|000\rangle + |100\rangle)$$

**Tableau after H:**
```yaml
stabilizers: ["+XII", "+IZI", "+IIZ"]
destabilizers: ["+ZII", "+IXI", "+IIX"]
```

### Step 2: CNOT(0, 1)

| Input | Output |
|-------|--------|
| $\|000\rangle$ | $\|000\rangle$ |
| $\|100\rangle$ | $\|110\rangle$ |

$$|\psi_2\rangle = \frac{1}{\sqrt{2}}(|000\rangle + |110\rangle)$$

**Tableau after CNOT(0,1):**
```yaml
stabilizers: ["+XXI", "+ZZI", "+IIZ"]
destabilizers: ["+ZII", "+IXI", "+IIX"]
```

### Step 3: CNOT(0, 2)

| Input | Output |
|-------|--------|
| $\|000\rangle$ | $\|000\rangle$ |
| $\|110\rangle$ | $\|111\rangle$ |

$$|\psi_3\rangle = \frac{1}{\sqrt{2}}(|000\rangle + |111\rangle) = |GHZ\rangle$$

**Tableau after CNOT(0,2) (pre-measurement):**
```yaml
stabilizers: ["+XXX", "+ZZI", "+ZIZ"]
destabilizers: ["+ZII", "+IXI", "+IIX"]
```

---

## Entanglement Properties

### Tripartite Entanglement

The GHZ state exhibits **genuine multipartite entanglement**:

$$|GHZ\rangle \neq |\phi\rangle_0 \otimes |\psi\rangle_{12}$$

**Reduced Density Matrix (trace out qubit 2):**
$$\rho_{01} = \text{Tr}_2(|GHZ\rangle\langle GHZ|) = \frac{1}{2}(|00\rangle\langle 00| + |11\rangle\langle 11|)$$

This is a **mixed state** (classical correlation only), demonstrating that the entanglement is truly tripartite.

---

## Measurement Analysis

### Z-Basis Measurements

The state in computational basis:
$$|GHZ\rangle = \frac{|000\rangle + |111\rangle}{\sqrt{2}}$$

**Possible outcomes:**
- $(+1, +1, +1)$ with probability $\frac{1}{2}$
- $(-1, -1, -1)$ with probability $\frac{1}{2}$

**Case 1: Outcomes [+1, +1, +1]**
```yaml
probability: 0.5
measurement_outcomes: [+1, +1, +1]
post_measurement_tableau:
  stabilizers: ["+ZII", "+ZZI", "+ZIZ"]
  destabilizers: ["+XXX", "+IXI", "+IIX"]
```

**Case 2: Outcomes [-1, -1, -1]**
```yaml
probability: 0.5
measurement_outcomes: [-1, -1, -1]
post_measurement_tableau:
  stabilizers: ["-ZII", "-ZZI", "-ZIZ"]
  destabilizers: ["+XXX", "+IXI", "+IIX"]
```

**Correlation Structure:**
$$\langle Z_i Z_j \rangle = +1 \quad \forall i \neq j$$

Any two qubits are perfectly correlated.

---

## Expected Outcome

| Property | Expected Value |
|----------|---------------|
| **Measurement Correlation** | All three outcomes equal |
| **Pre-measurement stabilizers** | `+XXX`, `+ZZI`, `+ZIZ` |
| **Pre-measurement destabilizers** | `+ZII`, `+IXI`, `+IIX` |
| **Tableau Validity** | True |
| **P(all +1)** | 0.5 |
| **P(all -1)** | 0.5 |
| **Any mixed outcome** | 0 |

**Key Property:** $\Pr(M_0 = M_1 = M_2) = 1$ (perfect 3-way correlation)

**Comparison with Bell State:**

| Feature | Bell State | GHZ State |
|---------|-----------|-----------|
| Qubits | 2 | 3 |
| Form | $\frac{|00\rangle+|11\rangle}{\sqrt{2}}$ | $\frac{|000\rangle+|111\rangle}{\sqrt{2}}$ |
| Entanglement | Bipartite | Tripartite |
| Stabilizers | 2 | 3 |
