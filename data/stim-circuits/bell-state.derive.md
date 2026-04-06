# Bell State Preparation: Mathematical Derivation

## Circuit Specification

```
H 0
CNOT 0 1
M 0
M 1
```

## Objective

Prepare the maximally entangled Bell state $|\Phi^+\rangle = \frac{1}{\sqrt{2}}(|00\rangle + |11\rangle)$ and verify its properties through measurement.

---

## Step-by-Step Derivation

### Initial State

$$|\psi_0\rangle = |0\rangle_0 \otimes |0\rangle_1 = |00\rangle$$

**Tableau:**
```yaml
stabilizers: ["+ZI", "+IZ"]
destabilizers: ["+XI", "+IX"]
```

### Step 1: Hadamard Gate on Qubit 0

The Hadamard gate creates superposition:

$$H = \frac{1}{\sqrt{2}}\begin{pmatrix} 1 & 1 \\ 1 & -1 \end{pmatrix}$$

$$H|0\rangle = \frac{|0\rangle + |1\rangle}{\sqrt{2}} = |+\rangle$$

**State after H:**
$$|\psi_1\rangle = |+\rangle_0 \otimes |0\rangle_1 = \frac{1}{\sqrt{2}}(|00\rangle + |10\rangle)$$

**Tableau after H:**
```yaml
stabilizers: ["+XI", "+IZ"]
destabilizers: ["+ZI", "+IX"]
```

**Conjugation:** $HZH^\dagger = X$, so stabilizer $Z_0 \rightarrow X_0$

### Step 2: CNOT Gate (Control=0, Target=1)

The CNOT operation: $\text{CNOT}|a,b\rangle = |a, b \oplus a\rangle$

Applying to each term:
| Input | Output |
|-------|--------|
| $|00\rangle$ | $|00\rangle$ |
| $|10\rangle$ | $|11\rangle$ |

**State after CNOT:**
$$|\psi_2\rangle = \frac{1}{\sqrt{2}}(|00\rangle + |11\rangle) = |\Phi^+\rangle$$

**Tableau after CNOT (pre-measurement):**
```yaml
stabilizers: ["+XX", "+ZZ"]
destabilizers: ["+ZI", "+IX"]
```

**Conjugation:** 
- $X \otimes I \rightarrow X \otimes X$ (control X propagates to target)
- $I \otimes Z \rightarrow Z \otimes Z$ (target Z propagates to control)

---

## Measurement Analysis

### Z-Basis Measurement

The Bell state in computational basis:
$$|\Phi^+\rangle = \frac{|00\rangle + |11\rangle}{\sqrt{2}}$$

**Measurement outcomes:**
- $|00\rangle$ with probability $|\frac{1}{\sqrt{2}}|^2 = \frac{1}{2}$ → Both outcomes +1
- $|11\rangle$ with probability $|\frac{1}{\sqrt{2}}|^2 = \frac{1}{2}$ → Both outcomes -1

**Case 1: Outcomes [+1, +1]**
```yaml
probability: 0.5
measurement_outcomes: [+1, +1]
post_measurement_tableau:
  stabilizers: ["+ZI", "+ZZ"]
  destabilizers: ["+XX", "+IX"]
```

**Case 2: Outcomes [-1, -1]**
```yaml
probability: 0.5
measurement_outcomes: [-1, -1]
post_measurement_tableau:
  stabilizers: ["-ZI", "-ZZ"]
  destabilizers: ["+XX", "+IX"]
```

**Correlation:** The outcomes are perfectly correlated:
$$\langle Z_0 Z_1 \rangle = +1$$

---

## Expected Outcome

| Property | Expected Value |
|----------|---------------|
| **Measurement Correlation** | Perfect (M0 = M1) |
| **Pre-measurement stabilizers** | `+XX`, `+ZZ` |
| **Pre-measurement destabilizers** | `+ZI`, `+IX` |
| **Tableau Validity** | True |
| **P(+1,+1)** | 0.5 |
| **P(-1,-1)** | 0.5 |
| **P(+1,-1)** | 0 |
| **P(-1,+1)** | 0 |

**Key Property:** $\Pr(M_0 = M_1) = 1$ (perfect correlation)
