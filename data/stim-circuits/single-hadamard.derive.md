# Single Hadamard Gate: Mathematical Derivation

## Circuit Specification

```
H 0
MX 0
```

## Objective

Demonstrate that $|+\rangle = H|0\rangle$ is the +1 eigenstate of $X$, giving deterministic measurement outcome.

---

## Step-by-Step Derivation

### Initial State

$$|\psi_0\rangle = |0\rangle$$

**Tableau:**
```yaml
stabilizers: ["+Z"]
destabilizers: ["+X"]
```

### Step 1: Hadamard Gate

$$H = \frac{1}{\sqrt{2}}\begin{pmatrix} 1 & 1 \\ 1 & -1 \end{pmatrix}$$

$$|\psi_1\rangle = H|0\rangle = \frac{1}{\sqrt{2}}\begin{pmatrix} 1 & 1 \\ 1 & -1 \end{pmatrix}\begin{pmatrix} 1 \\ 0 \end{pmatrix} = \frac{1}{\sqrt{2}}\begin{pmatrix} 1 \\ 1 \end{pmatrix} = |+\rangle$$

**Bloch Sphere Representation:**
- Initial: North pole ($|0\rangle$)
- After H: +X axis ($|+\rangle$)

**Tableau after H (pre-measurement):**
```yaml
stabilizers: ["+X"]
destabilizers: ["+Z"]
```

**Conjugation:** $HZH^\dagger = X$, so stabilizer flips from +Z to +X

---

## Eigenstate Analysis

### Pauli X Operator

$$X = \begin{pmatrix} 0 & 1 \\ 1 & 0 \end{pmatrix}$$

**Eigenvalue Equation:**
$$X|+\rangle = \frac{1}{\sqrt{2}}\begin{pmatrix} 0 & 1 \\ 1 & 0 \end{pmatrix}\begin{pmatrix} 1 \\ 1 \end{pmatrix} = \frac{1}{\sqrt{2}}\begin{pmatrix} 1 \\ 1 \end{pmatrix} = +1 \cdot |+\rangle$$

**Conclusion:** $|+\rangle$ is the +1 eigenstate of $X$.

### Complete Eigenbasis of X

| Eigenstate | Eigenvalue | Bloch Vector |
|-----------|-----------|--------------|
| $\|+\rangle = \frac{\|0\rangle + \|1\rangle}{\sqrt{2}}$ | +1 | $(1, 0, 0)$ |
| $\|-\rangle = \frac{\|0\rangle - \|1\rangle}{\sqrt{2}}$ | -1 | $(-1, 0, 0)$ |

---

## Measurement Analysis

### X-Basis Measurement (MX)

Projective measurement operators:
$$P_+ = |+\rangle\langle+|, \quad P_- = |-\rangle\langle-|$$

**Outcome Probabilities:**
$$\begin{aligned}
\Pr(+1) &= \langle\psi_1|P_+|\psi_1\rangle = |\langle+|+\rangle|^2 = 1 \\
\Pr(-1) &= \langle\psi_1|P_-|\psi_1\rangle = |\langle-|+\rangle|^2 = 0
\end{aligned}$$

**Result:** Deterministic outcome +1

**Post-measurement tableau:**
```yaml
deterministic: true
measurement_outcomes: [+1]
post_measurement_tableau:
  stabilizers: ["+X"]
  destabilizers: ["+Z"]
```

---

## Expected Outcome

| Property | Expected Value |
|----------|---------------|
| **Final State** | $\|+\rangle = \frac{\|0\rangle + \|1\rangle}{\sqrt{2}}$ |
| **Measurement Outcome** | +1 (deterministic) |
| **Pre-measurement stabilizer** | `+X` |
| **Pre-measurement destabilizer** | `+Z` |
| **Tableau Validity** | True |
| **P(+1)** | 1.0 |
| **P(-1)** | 0.0 |

**Key Insight:** Hadamard transforms a Z eigenstate into an X eigenstate. Measuring in the eigenbasis gives a deterministic outcome.
