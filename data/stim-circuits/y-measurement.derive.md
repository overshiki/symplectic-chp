# Y-Basis Measurement: Mathematical Derivation

## Circuit Specification

```
H 0
S 0
H 0
S 0
MY 0
```

## Objective

Analyze the final state's Y-basis measurement and demonstrate non-deterministic outcomes.

---

## Pauli Y Operator

### Definition
$$Y = -iXZ = \begin{pmatrix} 0 & -i \\ i & 0 \end{pmatrix}$$

### Eigenbasis

| Eigenstate | Eigenvalue | Form |
|-----------|-----------|------|
| $\|+i\rangle = \frac{\|0\rangle + i\|1\rangle}{\sqrt{2}}$ | +1 | $(1, 0, 1)/\sqrt{2}$ on Bloch sphere |
| $\|-i\rangle = \frac{\|0\rangle - i\|1\rangle}{\sqrt{2}}$ | -1 | $(1, 0, -1)/\sqrt{2}$ on Bloch sphere |

**Note:** $Y = -iXZ$ implies $|+i\rangle$ is eigenstate of both Y and the combination XZ.

---

## State Evolution Analysis

### Initial State

$$|\psi_0\rangle = |0\rangle$$

**Tableau:**
```yaml
stabilizers: ["+Z"]
destabilizers: ["+X"]
```

### Step 1: H

**Tableau after H:**
```yaml
stabilizers: ["+X"]
destabilizers: ["+Z"]
```

### Step 2: S

**Tableau after S:**
```yaml
stabilizers: ["+Y"]
destabilizers: ["+Z"]
```

### Step 3: H

**Tableau after H:**
```yaml
stabilizers: ["-Y"]
destabilizers: ["+Z"]
```

### Step 4: S

**Tableau after S (pre-measurement):**
```yaml
stabilizers: ["+X"]
destabilizers: ["+Y"]
```

### Stabilizer Evolution

| Step | Gate | Stabilizer | Bloch Vector |
|------|------|-----------|--------------|
| 0 | — | $+Z$ | $(0, 0, 1)$ |
| 1 | H | $+X$ | $(1, 0, 0)$ |
| 2 | S | $+Y$ | $(0, 1, 0)$ |
| 3 | H | $-Y$ | $(0, -1, 0)$ |
| 4 | S | $+X$ | $(1, 0, 0)$ |

### Conjugation Verification

**S gate action:**
- $SXS^\dagger = Y$
- $SYS^\dagger = -X$
- $SZS^\dagger = Z$

**H gate action:**
- $HXH^\dagger = Z$
- $HYH^\dagger = -Y$
- $HZH^\dagger = X$

**Verification:**
- Step 0→1: $HZH^\dagger = X$ ✓
- Step 1→2: $SXS^\dagger = Y$ ✓
- Step 2→3: $HYH^\dagger = -Y$ ✓
- Step 3→4: $S(-Y)S^\dagger = -SYS^\dagger = -(-X) = +X$ ✓

---

## Y-Basis Measurement

### Final State

$$|\psi_4\rangle = |+\rangle = \frac{|0\rangle + |1\rangle}{\sqrt{2}}$$

### Y Eigenstate Decomposition

$$|+\rangle = \frac{|+i\rangle + |-i\rangle}{\sqrt{2}} \cdot \frac{1+i}{\sqrt{2}}$$

More precisely:
$$\langle +i | + \rangle = \frac{1 + (-i)}{\sqrt{2}\sqrt{2}} = \frac{1-i}{2}$$

$$|\langle +i | + \rangle|^2 = \frac{|1-i|^2}{4} = \frac{2}{4} = \frac{1}{2}$$

$$|\langle -i | + \rangle|^2 = \frac{|1+i|^2}{4} = \frac{2}{4} = \frac{1}{2}$$

### Measurement Cases

**Case 1: Outcome +1**
```yaml
probability: 0.5
measurement_outcomes: [+1]
post_measurement_tableau:
  stabilizers: ["+Y"]
  destabilizers: ["+X"]
```

**Case 2: Outcome -1**
```yaml
probability: 0.5
measurement_outcomes: [-1]
post_measurement_tableau:
  stabilizers: ["-Y"]
  destabilizers: ["+X"]
```

---

## Expected Outcome

| Property | Expected Value |
|----------|---------------|
| **Final State** | $\|+\rangle$ |
| **Final Stabilizer** | `+X` |
| **Final Destabilizer** | `+Y` |
| **Y-Basis Measurement** | Random |
| **P(+1)** | 0.5 |
| **P(-1)** | 0.5 |
| **Tableau Validity** | True |

**Key Property:** The state $|+\rangle$ is **not** a Y eigenstate, so Y measurement gives random outcomes.

**Physical Interpretation:**
- $|+\rangle$ lies on the X-axis of the Bloch sphere
- Y measurement projects onto Y-axis (±Y poles)
- X and Y axes are orthogonal, giving equal probabilities

This tests the CHP simulator's handling of **non-deterministic measurements** in non-eigenbases.
