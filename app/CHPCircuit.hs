{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

-- | Intermediate representation for CHP circuits translated from STIM.
-- This module defines a simple IR that bridges the gap between STIM AST
-- and the symplectic-chp simulator.
module CHPCircuit
  ( CHPCircuit(..)
  , CHPOperation(..)
  , emptyCircuit
  , addGate
  , addMeasure
  , circuitFromOps
  ) where

import Data.Bits (setBit, testBit)
import Data.Word (Word64)

import SymplecticCHP (Pauli(..), SymplecticGate(..), LocalSymplectic(..))

-- | A CHP circuit is a sequence of operations on qubits.
-- We track the number of qubits and the sequence of operations.
data CHPCircuit = CHPCircuit
  { numQubits :: Int
  , operations :: [CHPOperation]
  } deriving (Show)

-- | A single operation in a CHP circuit.
-- Either a Clifford gate or a Pauli measurement.
data CHPOperation
  = GateOp SymplecticGate
  | MeasureOp Pauli Int  -- ^ Pauli operator and measurement result index
  deriving (Show)

-- | Create an empty circuit for n qubits.
emptyCircuit :: Int -> CHPCircuit
emptyCircuit n = CHPCircuit n []

-- | Add a gate operation to a circuit.
addGate :: SymplecticGate -> CHPCircuit -> CHPCircuit
addGate g circ = circ { operations = operations circ ++ [GateOp g] }

-- | Add a measurement operation to a circuit.
addMeasure :: Pauli -> Int -> CHPCircuit -> CHPCircuit
addMeasure p idx circ = circ { operations = operations circ ++ [MeasureOp p idx] }

-- | Create a circuit from a list of operations.
-- Infers qubit count from operations.
circuitFromOps :: [CHPOperation] -> CHPCircuit
circuitFromOps ops = CHPCircuit n ops
  where
    n = maximum $ 0 : concatMap opQubits ops
    
    opQubits (GateOp g) = gateQubits g
    opQubits (MeasureOp p _) = pauliQubits p
    
    gateQubits (SymplecticCHP.Local (SymplecticCHP.Hadamard q)) = [q]
    gateQubits (SymplecticCHP.Local (SymplecticCHP.Phase q)) = [q]
    gateQubits (SymplecticCHP.CNOT c t) = [c, t]
    
    pauliQubits (Pauli x z _) = 
      filter (testBitWord x) [0..63] ++ filter (testBitWord z) [0..63]
    testBitWord w i = (fromIntegral w :: Integer) `div` (2^i) `mod` 2 == 1
