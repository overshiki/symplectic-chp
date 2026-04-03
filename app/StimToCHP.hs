{-# LANGUAGE LambdaCase #-}

-- | Translation from STIM AST to CHP circuit representation.
-- This module handles the conversion of stim-parser's AST into
-- operations that can be executed by the symplectic-chp simulator.
module StimToCHP
  ( TranslationError(..)
  , translateStim
  , translateGate
  , translateMeasure
  , countQubits
  ) where

import Data.Bits (setBit)
import Data.Word (Word64)
import qualified Data.Set as Set

import StimParser.Expr hiding (Pauli(..))

import qualified SymplecticCHP as CHP

import CHPCircuit (CHPCircuit(..), CHPOperation(..))

-- | Errors that can occur during translation from STIM to CHP.
data TranslationError
  = UnsupportedGate GateTy
  | UnsupportedMeasure MeasureTy
  | UnsupportedNoise NoiseTy
  | UnsupportedGpp GppTy
  | UnsupportedAnnotation AnnTy
  | UnsupportedRepeat
  | OddCNOTTargets [Q]  -- ^ CNOT requires even number of targets
  | EmptyCircuit
  deriving (Show)

-- | Translate a STIM AST into a CHP circuit.
-- Returns Left if the circuit contains unsupported features.
translateStim :: Stim -> Either TranslationError CHPCircuit
translateStim stim = do
  ops <- collectOperations stim
  let n = countQubits stim
  if n == 0
    then Left EmptyCircuit
    else Right $ CHPCircuit n ops

-- | Collect all operations from a STIM AST (flattening nested structures).
collectOperations :: Stim -> Either TranslationError [CHPOperation]
collectOperations = go 0
  where
    -- go tracks the next measurement index
    go :: Int -> Stim -> Either TranslationError [CHPOperation]
    go _ (StimList items) = concat <$> mapM (go 0) items
    go _idx (StimG gate) = do
      gates <- translateGate gate
      return $ map GateOp gates
    go idx (StimM measure) = do
      pauli <- translateMeasure measure
      return [MeasureOp pauli idx]
    go _ (StimNoise noise) = Left $ UnsupportedNoise (getNoiseType noise)
    go _ (StimGpp gpp) = Left $ UnsupportedGpp (getGppType gpp)
    go _ (StimAnn ann) = Left $ UnsupportedAnnotation (getAnnType ann)
    go _ (StimRepeat _ _) = Left UnsupportedRepeat

    getNoiseType (NoiseNormal ty _ _ _ _) = ty
    getNoiseType (NoiseE ty _ _ _) = ty
    
    getGppType (Gpp ty _ _ _) = ty
    
    getAnnType (Ann ty _ _ _) = ty

-- | Translate a STIM gate to a list of CHP symplectic gates.
-- May decompose gates into sequences of H, S, and CNOT.
translateGate :: Gate -> Either TranslationError [CHP.SymplecticGate]
translateGate (Gate gateType _ qubits) =
  case gateType of
    -- Directly supported gates
    H -> Right $ map (CHP.Local . CHP.Hadamard . qubitIndex) qubits
    S -> Right $ map (CHP.Local . CHP.Phase . qubitIndex) qubits
    CNOT -> translateCNOT qubits
    I -> Right []  -- Identity is a no-op
    
    -- Gates requiring decomposition
    X -> Right $ concatMap decomposeX qubits
    Y -> Right $ concatMap decomposeY qubits
    Z -> Right $ concatMap decomposeZ qubits
    CZ -> Right $ concatMap decomposeCZ (pairs qubits)
    SWAP -> Right $ concatMap decomposeSWAP (pairs qubits)
    
    -- Non-Clifford gates (unsupported)
    RX -> Left $ UnsupportedGate RX
    RY -> Left $ UnsupportedGate RY
    RZ -> Left $ UnsupportedGate RZ
    
    -- Other gates that might be Clifford but need verification
    SQRT_X -> Left $ UnsupportedGate SQRT_X
    SQRT_X_DAG -> Left $ UnsupportedGate SQRT_X_DAG
    SQRT_Y -> Left $ UnsupportedGate SQRT_Y
    SQRT_Y_DAG -> Left $ UnsupportedGate SQRT_Y_DAG
    SQRT_Z -> Right $ map (CHP.Local . CHP.Phase . qubitIndex) qubits  -- SQRT_Z = S
    SQRT_Z_DAG -> Right $ concatMap decomposeSdag qubits
    
    -- Two-qubit Clifford gates needing decomposition
    CY -> Left $ UnsupportedGate CY
    CX -> translateCNOT qubits  -- CX is another name for CNOT
    CZSWAP -> Left $ UnsupportedGate CZSWAP
    CXSWAP -> Left $ UnsupportedGate CXSWAP
    SWAPCX -> Left $ UnsupportedGate SWAPCX
    SWAPCZ -> Left $ UnsupportedGate SWAPCZ
    ISWAP -> Left $ UnsupportedGate ISWAP
    ISWAP_DAG -> Left $ UnsupportedGate ISWAP_DAG
    SQRT_XX -> Left $ UnsupportedGate SQRT_XX
    SQRT_XX_DAG -> Left $ UnsupportedGate SQRT_XX_DAG
    SQRT_YY -> Left $ UnsupportedGate SQRT_YY
    SQRT_YY_DAG -> Left $ UnsupportedGate SQRT_YY_DAG
    SQRT_ZZ -> Left $ UnsupportedGate SQRT_ZZ
    SQRT_ZZ_DAG -> Left $ UnsupportedGate SQRT_ZZ_DAG
    
    -- Controlled Pauli variants
    XCZ -> translateCNOT (reverse qubits)  -- XCZ = CNOT with reversed control/target
    XCY -> Left $ UnsupportedGate XCY
    YCX -> Left $ UnsupportedGate YCX
    YCY -> Left $ UnsupportedGate YCY
    YCZ -> Left $ UnsupportedGate YCZ
    ZCX -> translateCNOT qubits  -- ZCX = CNOT
    ZCY -> Left $ UnsupportedGate ZCY
    ZCZ -> Right $ concatMap decomposeCZ (pairs qubits)
    
    -- Hadamard variants
    H_XY -> Left $ UnsupportedGate H_XY
    H_XZ -> Right $ map (CHP.Local . CHP.Hadamard . qubitIndex) qubits  -- H_XZ = H
    H_YZ -> Left $ UnsupportedGate H_YZ
    H_NXY -> Left $ UnsupportedGate H_NXY
    H_NXZ -> Left $ UnsupportedGate H_NXZ
    H_NYZ -> Left $ UnsupportedGate H_NYZ
    
    -- Identity variants
    II -> Right []
    
    -- Controlled rotation variants
    C_XYZ -> Left $ UnsupportedGate C_XYZ
    C_ZYX -> Left $ UnsupportedGate C_ZYX
    C_XYNZ -> Left $ UnsupportedGate C_XYNZ
    C_XNYZ -> Left $ UnsupportedGate C_XNYZ
    C_NXYZ -> Left $ UnsupportedGate C_NXYZ
    C_NZYX -> Left $ UnsupportedGate C_NZYX
    C_ZYNX -> Left $ UnsupportedGate C_ZYNX
    C_ZNYX -> Left $ UnsupportedGate C_ZNYX
    
    -- S dagger (S^3)
    S_DAG -> Right $ concatMap decomposeSdag qubits
    
    -- Controlled Pauli variants (additional)
    XCX -> Left $ UnsupportedGate XCX
    
    -- Reset (not a unitary gate)
    R -> Left $ UnsupportedGate R

-- | Translate CNOT with multiple targets.
-- STIM allows CNOT 0 1 2 3 which means CNOT(0,1) and CNOT(2,3).
-- Odd number of targets is an error.
translateCNOT :: [Q] -> Either TranslationError [CHP.SymplecticGate]
translateCNOT qubits = 
  if even (length qubits)
    then Right $ concatMap (\(c, t) -> [CHP.CNOT (qubitIndex c) (qubitIndex t)]) (pairs qubits)
    else Left $ OddCNOTTargets qubits

-- | Translate a STIM measurement to a Pauli operator.
translateMeasure :: Measure -> Either TranslationError CHP.Pauli
translateMeasure (Measure measureType _ _ qubits) =
  case measureType of
    M -> Right $ pauliZ qubits
    MZ -> Right $ pauliZ qubits
    MX -> Right $ pauliX qubits
    MY -> Right $ pauliY qubits
    -- Measure-reset operations (not supported)
    MR -> Left $ UnsupportedMeasure MR
    MRX -> Left $ UnsupportedMeasure MRX
    MRY -> Left $ UnsupportedMeasure MRY
    MRZ -> Left $ UnsupportedMeasure MRZ
    -- Pauli product measurements (would need different interface)
    MXX -> Left $ UnsupportedMeasure MXX
    MYY -> Left $ UnsupportedMeasure MYY
    MZZ -> Left $ UnsupportedMeasure MZZ

-- | Count the total number of qubits used in a STIM circuit.
-- Returns max qubit index + 1 (since indices are 0-based).
countQubits :: Stim -> Int
countQubits stim = 
  let qs = collectQubits stim
  in if Set.null qs then 0 else Set.findMax qs + 1
  where
    collectQubits :: Stim -> Set.Set Int
    collectQubits = \case
      StimList items -> Set.unions $ map collectQubits items
      StimG gate -> gateQubits gate
      StimM measure -> measureQubits measure
      StimNoise noise -> noiseQubits noise
      StimGpp gpp -> gppQubits gpp
      StimAnn ann -> annotationQubits ann
      StimRepeat _ body -> collectQubits body

    gateQubits (Gate _ _ qs) = Set.fromList $ map qubitIndex qs
    measureQubits (Measure _ _ _ qs) = Set.fromList $ map qubitIndex qs
    noiseQubits (NoiseNormal _ _ _ _ qs) = Set.fromList $ map qubitIndex qs
    noiseQubits (NoiseE _ _ _ pauliInds) = Set.fromList $ map piQubit pauliInds
    gppQubits (Gpp _ _ _ pcs) = Set.fromList $ concatMap pcQubits pcs

    
    pcQubits (P pauliInds) = map piQubit pauliInds
    pcQubits (N pauliInds) = map piQubit pauliInds
    
    piQubit (PauliInd _ idx) = idx  -- PauliInd contains qubit index directly
    
    annotationQubits (Ann _ _ _ qs) = Set.fromList $ map qubitIndex qs

-- | Extract the qubit index from a Q value.
qubitIndex :: Q -> Int
qubitIndex (Q i) = i
qubitIndex (Not idx) = idx  -- Negated qubit (measurement inversion) - Not contains index
qubitIndex (QRec _) = error "Record references not supported"
qubitIndex (QSweep _) = error "Sweep qubits not supported"

-- ============================================================================
-- Gate Decompositions
-- ============================================================================

-- | Decompose Pauli X into H and S gates.
-- X = H * S * S * H
decomposeX :: Q -> [CHP.SymplecticGate]
decomposeX q =
  let i = qubitIndex q
  in [ CHP.Local (CHP.Hadamard i)
     , CHP.Local (CHP.Phase i)
     , CHP.Local (CHP.Phase i)
     , CHP.Local (CHP.Hadamard i)
     ]

-- | Decompose Pauli Y into H and S gates.
-- Y = iXZ = S * X * S^3 = S * (HSSS) * SSS
decomposeY :: Q -> [CHP.SymplecticGate]
decomposeY q =
  let i = qubitIndex q
      sOps = [CHP.Local (CHP.Phase i)]
      sDagOps = [CHP.Local (CHP.Phase i), CHP.Local (CHP.Phase i), CHP.Local (CHP.Phase i)]
      xOps = decomposeX q
  in sOps ++ xOps ++ sDagOps

-- | Decompose Pauli Z into S gates.
-- Z = S * S
decomposeZ :: Q -> [CHP.SymplecticGate]
decomposeZ q =
  let i = qubitIndex q
  in [ CHP.Local (CHP.Phase i)
     , CHP.Local (CHP.Phase i)
     ]

-- | Decompose S^dagger (S^† = S^3).
decomposeSdag :: Q -> [CHP.SymplecticGate]
decomposeSdag q =
  let i = qubitIndex q
  in [ CHP.Local (CHP.Phase i)
     , CHP.Local (CHP.Phase i)
     , CHP.Local (CHP.Phase i)
     ]

-- | Decompose CZ (controlled-Z) into H and CNOT.
-- CZ(c,t) = H(t) * CNOT(c,t) * H(t)
decomposeCZ :: (Q, Q) -> [CHP.SymplecticGate]
decomposeCZ (c, t) =
  let ci = qubitIndex c
      ti = qubitIndex t
  in [ CHP.Local (CHP.Hadamard ti)
     , CHP.CNOT ci ti
     , CHP.Local (CHP.Hadamard ti)
     ]

-- | Decompose SWAP into three CNOTs.
-- SWAP(a,b) = CNOT(a,b) * CNOT(b,a) * CNOT(a,b)
decomposeSWAP :: (Q, Q) -> [CHP.SymplecticGate]
decomposeSWAP (a, b) =
  let ai = qubitIndex a
      bi = qubitIndex b
  in [ CHP.CNOT ai bi
     , CHP.CNOT bi ai
     , CHP.CNOT ai bi
     ]

-- ============================================================================
-- Pauli Construction Helpers
-- ============================================================================

-- | Construct a Pauli Z measurement on multiple qubits.
-- For single qubit: Z; For multiple: tensor product of Z's.
pauliZ :: [Q] -> CHP.Pauli
pauliZ qs = 
  let indices = map qubitIndex qs
      zVec = foldl setBit (0 :: Word64) indices
  in CHP.Pauli 0 zVec 0

-- | Construct a Pauli X measurement on multiple qubits.
pauliX :: [Q] -> CHP.Pauli
pauliX qs =
  let indices = map qubitIndex qs
      xVec = foldl setBit (0 :: Word64) indices
  in CHP.Pauli xVec 0 0

-- | Construct a Pauli Y measurement on multiple qubits.
-- Y = iXZ, so we set both X and Z bits.
pauliY :: [Q] -> CHP.Pauli
pauliY qs =
  let indices = map qubitIndex qs
      mask = foldl setBit (0 :: Word64) indices
      -- Phase 1 for Y (iXZ)
  in CHP.Pauli mask mask 1

-- ============================================================================
-- Utility Functions
-- ============================================================================

-- | Pair up elements of a list.
-- [a,b,c,d] -> [(a,b), (c,d)]
-- Fails if list has odd length.
pairs :: [a] -> [(a, a)]
pairs [] = []
pairs (x:y:rest) = (x, y) : pairs rest
pairs [_] = error "Odd number of elements in pairs"
