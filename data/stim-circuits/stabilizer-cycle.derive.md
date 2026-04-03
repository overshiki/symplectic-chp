# Stabilizer Cycle: X Gate Decomposition

## Circuit
```
H 0
S 0
S 0
H 0
M 0
```

## Mathematical Derivation

This circuit implements the Pauli X gate using only H and S gates.

### Step 1: Initial State
$$|\psi_0\rangle = |0\rangle$$

### Step 2: First Hadamard
$$|\psi_1\rangle = H|0\rangle = |+\rangle = \frac{|0\rangle + |1\rangle}{\sqrt{2}}$$

### Step 3: First Phase Gate
The S gate acts as:
$$S|0\rangle = |0\rangle$$
$$S|1\rangle = i|1\rangle$$

So:
$$|\psi_2\rangle = S|+\rangle = \frac{|0\rangle + i|1\rangle}{\sqrt{2}}$$

This is the $|+i\rangle$ state (Y eigenstate).

### Step 4: Second Phase Gate
$$|\psi_3\rangle = S|\psi_2\rangle = \frac{|0\rangle + i^2|1\rangle}{\sqrt{2}} = \frac{|0\rangle - |1\rangle}{\sqrt{2}} = |-\rangle$$

Note: $S^2 = Z$ (up to phase), so $S^2|+\rangle = Z|+\rangle = |-\rangle$.

### Step 5: Second Hadamard
$$|\psi_4\rangle = H|-\rangle = H\left(\frac{|0\rangle - |1\rangle}{\sqrt{2}}\right) = |1\rangle$$

Since $H|-\rangle = |1\rangle$ and $H|+\rangle = |0\rangle$.

## Verification: HSSH = X

Let's verify algebraically:
$$HSSH = HS^2H = HZH$$

Since $S^2 = Z$ (the phase gate squared is the Z gate).

And we know:
$$HZH = X$$

This is the conjugation relation: H swaps X and Z.

Therefore: **HSSH = X**

## Measurement

After applying X to |0⟩:
$$X|0\rangle = |1\rangle$$

Measuring in Z-basis gives outcome **-1** (since |1⟩ is the -1 eigenstate of Z).

## Stabilizer Evolution

| Step | Gate | Stabilizer | State |
|------|------|------------|-------|
| 0 | - | +Z | \|0⟩ |
| 1 | H | +X | \|+⟩ |
| 2 | S | +Y | \|+i⟩ |
| 3 | S | -X | \|-⟩ |
| 4 | H | -Z | \|1⟩ |

The stabilizer cycle: Z → X → Y → -X → -Z

This demonstrates the Clifford group action on Pauli operators.
