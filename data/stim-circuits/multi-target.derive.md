# Multi-Target Gates: Mathematical Derivation

## Circuit Specification

```
H 0
H 1
H 2
MX 0
MX 1
MX 2
```

## Objective

Demonstrate independent evolution of multiple qubits and verify product state structure.

---

## State Evolution

### Initial State

$$|\psi_0\rangle = |000\rangle$$

**Tableau:**
```yaml
stabilizers: ["+ZII", "+IZI", "+IIZ"]
destabilizers: ["+XII", "+IXI", "+IIX"]
```

### Step 1: Hadamard on All Qubits

Since $H^{\otimes 3} = H \otimes H \otimes H$:

$$\begin{aligned}
|\psi_1\rangle &= H|0\rangle \otimes H|0\rangle \otimes H|0\rangle \\
&= |+\rangle \otimes |+\rangle \otimes |+\rangle \\
&= |+++\rangle
\end{aligned}$$

**Tableau after H⊗H⊗H (pre-measurement):**
```yaml
stabilizers: ["+XII", "+IXI", "+IIX"]
destabilizers: ["+ZII", "+IZI", "+IIZ"]
```

### Product State Form

$$|+++\rangle = \frac{1}{\sqrt{8}}\sum_{x=0}^{7}|x\rangle$$

Explicitly:
$$|\psi_1\rangle = \frac{|000\rangle + |001\rangle + |010\rangle + |011\rangle + |100\rangle + |101\rangle + |110\rangle + |111\rangle}{\sqrt{8}}$$

**Key Property:** This is a **product state**, not entangled.

---

## Product vs. Entangled States

### Factorization Test

$$|+++\rangle = |+\rangle_0 \otimes |+\rangle_1 \otimes |+\rangle_2$$

**Separability:** The state can be written as a tensor product of single-qubit states.

**Reduced Density Matrix:**
$$\rho_0 = \text{Tr}_{12}(|+++\rangle\langle+++|) = |+\rangle\langle+|$$

This is a **pure state**, confirming no entanglement.

### Contrast with GHZ State

| Property | $|+++\rangle$ | $|GHZ\rangle$ |
|----------|---------------|---------------|
| **Form** | Product $\bigotimes_i |+\rangle_i$ | Entangled $\frac{\|000\rangle+\|111\rangle}{\sqrt{2}}$ |
| **Entanglement** | None | Tripartite |
| **Reduced ρ** | Pure | Mixed |
| **Stabilizers** | Independent | Correlated |

---

## Stabilizer Analysis

### Independent Stabilizers

The state $|+++\rangle$ has stabilizer generators:

$$\{+X_0, +X_1, +X_2\} = \{+XII, +IXI, +IIX\}$$

**Verification:**
$$X_i |+++\rangle = |+++\rangle \quad \forall i$$

Each stabilizer acts on only one qubit, confirming the product structure.

### Stabilizer Group

All stabilizers are of the form:
$$g = (+/-)X^{a_0} \otimes X^{a_1} \otimes X^{a_2}, \quad a_i \in \{0, 1\}$$

Total: $2^3 = 8$ stabilizer elements.

---

## Measurement Analysis

### X-Basis Eigenstates

For each qubit:
$$X|+\rangle = +|+\rangle$$

The state $|+\rangle$ is the +1 eigenstate of X.

### Measurement Outcomes

**Outcome Probabilities:**
$$\Pr(M_i = +1) = |\langle+|+\rangle|^2 = 1$$
$$\Pr(M_i = -1) = |\langle-|+\rangle|^2 = 0$$

All three measurements give **deterministic** outcome +1.

**Joint Probability:**
$$\Pr(M_0=+1, M_1=+1, M_2=+1) = 1$$

**Post-measurement tableau:**
```yaml
deterministic: true
measurement_outcomes: [+1, +1, +1]
post_measurement_tableau:
  stabilizers: ["+XII", "+IXI", "+IIX"]
  destabilizers: ["+ZII", "+IZI", "+IIZ"]
```

---

## Expected Outcome

| Property | Expected Value |
|----------|---------------|
| **Final State** | $\|+++\rangle = \|+\rangle^{\otimes 3}$ |
| **State Type** | Product state (not entangled) |
| **Pre-measurement stabilizers** | `+XII`, `+IXI`, `+IIX` |
| **Pre-measurement destabilizers** | `+ZII`, `+IZI`, `+IIZ` |
| **Measurement 0** | +1 (deterministic) |
| **Measurement 1** | +1 (deterministic) |
| **Measurement 2** | +1 (deterministic) |
| **Tableau Validity** | True |
| **P(+1,+1,+1)** | 1.0 |
| **All other outcomes** | 0.0 |

**Key Property:** Multi-target gate syntax `H 0 1 2` applies independent single-qubit gates.

**Physical Interpretation:**
Each qubit evolves independently in its own Bloch sphere:
- Initial: All at north pole $|0\rangle$
- After H: All at +X axis $|+\rangle$
- X measurement: Deterministic +1 for each

This tests the CHP simulator's handling of **product states** and **multi-target gate syntax**.
