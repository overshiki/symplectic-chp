# Stabilizer Cycle: X Gate Decomposition

## Circuit Specification

```
H 0
S 0
S 0
H 0
M 0
```

## Objective

Prove that $HSSH = X$ and verify the state evolution $|0\rangle \rightarrow |1\rangle$.

---

## Algebraic Proof: HSSH = X

### Key Identities

1. $S^2 = Z$ (Phase gate squared is Pauli Z)
2. $HZH = X$ (Hadamard conjugates Z to X)

### Derivation

$$\begin{aligned}
HSSH &= H(S^2)H \\
     &= HZH \quad \text{(using } S^2 = Z\text{)} \\
     &= X \quad \text{(using } HZH = X\text{)}
\end{aligned}$$

**Q.E.D.** The circuit implements the Pauli X gate.

---

## State Evolution

### Initial State

$$|\psi_0\rangle = |0\rangle$$

**Tableau:**
```yaml
stabilizers: ["+Z"]
destabilizers: ["+X"]
```

### Step 1: H

$$|\psi_1\rangle = H|0\rangle = |+\rangle = \frac{|0\rangle + |1\rangle}{\sqrt{2}}$$

**Tableau after H:**
```yaml
stabilizers: ["+X"]
destabilizers: ["+Z"]
```

### Step 2: S

$$S = \begin{pmatrix} 1 & 0 \\ 0 & i \end{pmatrix}$$

$$S|+\rangle = \frac{S|0\rangle + S|1\rangle}{\sqrt{2}} = \frac{|0\rangle + i|1\rangle}{\sqrt{2}} = |+i\rangle$$

This is the +i eigenstate of Y (Bloch sphere +Y axis).

**Tableau after first S:**
```yaml
stabilizers: ["+Y"]
destabilizers: ["+Z"]
```

### Step 3: S (again)

$$S|+i\rangle = \frac{|0\rangle + i^2|1\rangle}{\sqrt{2}} = \frac{|0\rangle - |1\rangle}{\sqrt{2}} = |-\rangle$$

This is the -1 eigenstate of X (Bloch sphere -X axis).

**Tableau after second S:**
```yaml
stabilizers: ["-X"]
destabilizers: ["+Z"]
```

### Step 4: H

$$H|-\rangle = \frac{H|0\rangle - H|1\rangle}{\sqrt{2}} = \frac{|+\rangle - |-\rangle}{\sqrt{2}} = |1\rangle$$

Since $H|+\rangle = |0\rangle$ and $H|-\rangle = |1\rangle$.

**Tableau after final H (post-measurement):**
```yaml
stabilizers: ["-Z"]
destabilizers: ["+X"]
```

---

## Stabilizer Evolution

The stabilizer transforms as:

| Step | Gate | Stabilizer | State | Bloch Vector |
|------|------|-----------|-------|--------------|
| 0 | — | $+Z$ | $\|0\rangle$ | $(0, 0, 1)$ |
| 1 | H | $+X$ | $\|+\rangle$ | $(1, 0, 0)$ |
| 2 | S | $+Y$ | $\|+i\rangle$ | $(0, 1, 0)$ |
| 3 | S | $-X$ | $\|-\rangle$ | $(-1, 0, 0)$ |
| 4 | H | $-Z$ | $\|1\rangle$ | $(0, 0, -1)$ |

### S Gate Conjugation

The S gate rotates around Z-axis:
- $SXS^\dagger = Y$
- $SYS^\dagger = -X$  
- $SZS^\dagger = Z$

**Verification:**
- Step 1→2: $S(+X)S^\dagger = +Y$ ✓
- Step 2→3: $S(+Y)S^\dagger = -X$ ✓

---

## Measurement Analysis

### Final State

$$|\psi_4\rangle = |1\rangle$$

### Z-Basis Measurement

Z operator eigenstates:
- $|0\rangle$ with eigenvalue +1
- $|1\rangle$ with eigenvalue -1

**Outcome:**
$$Z|1\rangle = -|1\rangle \Rightarrow \text{measurement outcome } -1$$

**Expected result:**
```yaml
deterministic: true
measurement_outcomes: [-1]
post_measurement_tableau:
  stabilizers: ["-Z"]
  destabilizers: ["+X"]
```

---

## Expected Outcome

| Property | Expected Value |
|----------|---------------|
| **Circuit Identity** | $HSSH = X$ |
| **Final State** | $\|1\rangle$ |
| **Measurement Outcome** | -1 (deterministic) |
| **Final Stabilizer** | `-Z` |
| **Final Destabilizer** | `+X` |
| **Tableau Validity** | True |
| **P(-1)** | 1.0 |
| **P(+1)** | 0.0 |

**Key Insight:** This circuit demonstrates Clifford group composition. Each gate permutes Pauli operators, and the composition $HSSH$ maps $Z \rightarrow -Z$, equivalent to the X gate conjugation: $XZX^\dagger = -Z$.
