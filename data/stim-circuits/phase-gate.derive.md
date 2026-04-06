# Phase Gate (S² = Z): Mathematical Derivation

## Circuit Specification

```
H 0
S 0
S 0
M 0
```

## Objective

Demonstrate that $S^2 = Z$ and verify phase kickback on superposition states.

---

## S Gate Properties

### Definition
$$S = \begin{pmatrix} 1 & 0 \\ 0 & i \end{pmatrix}, \quad S^2 = \begin{pmatrix} 1 & 0 \\ 0 & -1 \end{pmatrix} = Z$$

### Action on Computational Basis
$$S|0\rangle = |0\rangle, \quad S|1\rangle = i|1\rangle$$

### Conjugation Relations
$$S X S^\dagger = Y, \quad S Y S^\dagger = -X, \quad S Z S^\dagger = Z$$

**Key Property:** S rotates around the Z-axis by $\pi/2$ in the Bloch sphere.

---

## State Evolution

### Initial State

$$|\psi_0\rangle = |0\rangle$$

**Tableau:**
```yaml
stabilizers: ["+Z"]
destabilizers: ["+X"]
```

### Step 1: Hadamard

$$|\psi_1\rangle = H|0\rangle = |+\rangle = \frac{|0\rangle + |1\rangle}{\sqrt{2}}$$

**Tableau after H:**
```yaml
stabilizers: ["+X"]
destabilizers: ["+Z"]
```

### Step 2: Apply S² = Z

Using the identity $S^2 = Z$:

$$|\psi_2\rangle = S^2 |+\rangle = Z|+\rangle = \frac{Z|0\rangle + Z|1\rangle}{\sqrt{2}} = \frac{|0\rangle - |1\rangle}{\sqrt{2}} = |-\rangle$$

**Phase Kickback:** The Z gate introduces a relative phase $\pi$ between $|0\rangle$ and $|1\rangle$.

**Tableau after first S:**
```yaml
stabilizers: ["+Y"]
destabilizers: ["+Z"]
```

**Conjugation:** $SXS^\dagger = Y$

**Tableau after second S (pre-measurement):**
```yaml
stabilizers: ["-X"]
destabilizers: ["+Z"]
```

**Conjugation:** $SYS^\dagger = -X$, so $+Y \rightarrow -X$

---

## Alternative: Two S Gates

Applying S twice:

**First S:**
$$S|+\rangle = \frac{|0\rangle + i|1\rangle}{\sqrt{2}} = |+i\rangle$$

This rotates from +X to +Y on Bloch sphere.

**Second S:**
$$S|+i\rangle = \frac{|0\rangle + i^2|1\rangle}{\sqrt{2}} = \frac{|0\rangle - |1\rangle}{\sqrt{2}} = |-\rangle$$

This rotates from +Y to -X on Bloch sphere.

**Combined:** +X → +Y → -X, equivalent to 180° rotation around Z-axis.

---

## Measurement Analysis

### Final State

$$|\psi_2\rangle = |-\rangle = \frac{|0\rangle - |1\rangle}{\sqrt{2}}$$

### Z-Basis Measurement

The state $|-\rangle$ is an equal superposition, not a Z eigenstate.

**Outcome Probabilities:**
$$\Pr(+1) = |\langle 0 | - \rangle|^2 = \frac{1}{2}$$
$$\Pr(-1) = |\langle 1 | - \rangle|^2 = \frac{1}{2}$$

**Interpretation:** The measurement outcome is **random**.

**Case 1: Outcome +1**
```yaml
probability: 0.5
measurement_outcomes: [+1]
post_measurement_tableau:
  stabilizers: ["+Z"]
  destabilizers: ["-X"]
```

**Case 2: Outcome -1**
```yaml
probability: 0.5
measurement_outcomes: [-1]
post_measurement_tableau:
  stabilizers: ["-Z"]
  destabilizers: ["-X"]
```

---

## Comparison: S vs S²

| Gate | Action on $\|+\rangle$ | Bloch Rotation |
|------|---------------------|----------------|
| S | $\|+\rangle \rightarrow \|+i\rangle$ | +90° around Z |
| S² | $\|+\rangle \rightarrow \|-\rangle$ | +180° around Z |
| S³ | $\|+\rangle \rightarrow \|-i\rangle$ | +270° around Z |
| S⁴ | $\|+\rangle \rightarrow \|+\rangle$ | +360° around Z (= I) |

**Periodicity:** $S^4 = I$ (order 4 in SU(2))

---

## Expected Outcome

| Property | Expected Value |
|----------|---------------|
| **Circuit Identity** | $S^2 = Z$ |
| **Final State** | $\|-\rangle = \frac{\|0\rangle - \|1\rangle}{\sqrt{2}}$ |
| **Final Stabilizer** | `-X` |
| **Pre-measurement destabilizer** | `+Z` |
| **Z-Basis Measurement** | Random |
| **P(+1)** | 0.5 |
| **P(-1)** | 0.5 |
| **Tableau Validity** | True |

**Key Insight:** The S gate's square is Z, which anti-commutes with X. This flips the stabilizer from +X to -X.

**Physical Interpretation:**
- Start at north pole $|0\rangle$
- Rotate to +X axis by Hadamard
- Rotate 180° around Z by S²
- End at -X axis $|-\rangle$
- Z measurement is random (state lies in XY plane)
