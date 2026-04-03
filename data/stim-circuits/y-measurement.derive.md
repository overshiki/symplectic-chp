# Y-Basis Measurement Derivation

## Circuit
```
H 0
S 0
H 0
S 0
MY 0
```

## Mathematical Derivation

This circuit prepares a specific state and measures in the Y-basis.

### Step 1: Initial State
$$|\psi_0\rangle = |0\rangle$$

### Step 2: First H
$$|\psi_1\rangle = |+\rangle = \frac{|0\rangle + |1\rangle}{\sqrt{2}}$$

### Step 3: First S
The S gate rotates around Z-axis by π/2:
$$S = \begin{pmatrix} 1 & 0 \\ 0 & i \end{pmatrix}$$

$$S|+\rangle = \frac{|0\rangle + i|1\rangle}{\sqrt{2}} = |+i\rangle$$

This is the +1 eigenstate of Y (since Y = -iXZ).

### Step 4: Second H
$$H|+i\rangle = \frac{1}{\sqrt{2}}\left(\frac{|0\rangle + |1\rangle}{\sqrt{2}} + i\frac{|0\rangle - |1\rangle}{\sqrt{2}}\right) = \frac{(1+i)|0\rangle + (1-i)|1\rangle}{2}$$

Simplifying:
$$|\psi_3\rangle = \frac{e^{i\pi/4}|0\rangle + e^{-i\pi/4}|1\rangle}{\sqrt{2}}$$

### Step 5: Second S
$$S|\psi_3\rangle = \frac{e^{i\pi/4}|0\rangle + ie^{-i\pi/4}|1\rangle}{\sqrt{2}} = \frac{e^{i\pi/4}|0\rangle + e^{i\pi/4}|1\rangle}{\sqrt{2}}$$

Since $i \cdot e^{-i\pi/4} = e^{i\pi/2} \cdot e^{-i\pi/4} = e^{i\pi/4}$:

$$|\psi_4\rangle = \frac{e^{i\pi/4}(|0\rangle + |1\rangle)}{\sqrt{2}} = e^{i\pi/4}|+\rangle$$

## Wait - Let's Recompute

Actually, let me verify the circuit more carefully.

The circuit is: H → S → H → S

In terms of actions on Pauli operators:
- H: X ↔ Z
- S: X → Y, Z → Z (rotates X to Y around Z)

Starting stabilizer: +Z

1. H(+Z) = +X
2. S(+X) = +Y
3. H(+Y): H(-iXZ)H† = -i(HXH)(HZH) = -iZX = +Y (since ZX = -iY)

Hmm, let me be more careful. Actually:
- H Y H† = H(-iXZ)H† = -i(HXH)(HZH) = -iZX = -i(-XY) = ... 

Using the anticommutation {X, Z} = 0, and Y = -iXZ:
H Y H† = H(-iXZ)H† = -i(HXH)(HZH) = -iZX

Since ZX = -XZ and Y = -iXZ, we have XZ = iY, so ZX = -iY.

Therefore: H Y H† = -i(-iY) = -Y

4. S(-Y): S(-iXZ)S† = -i(SXS†)(SZS†) = -i(Y)(Z) = -iYZ = -i(-iX) = -X

So the final stabilizer is -X, meaning the state is |-⟩.

## Y-Basis Measurement

The Pauli Y operator has eigenstates:
- $|+i\rangle = \frac{|0\rangle + i|1\rangle}{\sqrt{2}}$ with eigenvalue +1
- $|-i\rangle = \frac{|0\rangle - i|1\rangle}{\sqrt{2}}$ with eigenvalue -1

Our final state $|-\rangle = \frac{|0\rangle - |1\rangle}{\sqrt{2}}$ is **not** a Y eigenstate!

In fact:
$$Y|-\rangle = -iXZ|-\rangle = -iX|-\rangle = -i(-|-\rangle) = i|-\rangle$$

So $|-\rangle$ is **not** an eigenstate of Y (the eigenvalues of Y are ±1, not ±i).

## Measurement Outcome

Since the state is not a Y eigenstate, the measurement outcome is **random**!

The probability of +1:
$$|\langle +i|-\rangle|^2 = \left|\frac{1}{2}(\langle 0| - i\langle 1|)(|0\rangle - |1\rangle)\right|^2 = \left|\frac{1 - i}{2}\right|^2 = \frac{1 + 1}{4} = \frac{1}{2}$$

So P(+1) = P(-1) = 1/2.

## Expected Behavior

The MY measurement should give:
- Random outcome (+1 or -1 with 50% probability each)
- The tableau remains valid
- This tests the simulator's handling of non-deterministic measurements

Note: Due to randomness, we only verify tableau validity, not the exact outcome.
