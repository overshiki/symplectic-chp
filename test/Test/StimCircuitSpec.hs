{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RecordWildCards #-}

-- | Integration tests for STIM circuit files.
-- Tests circuits from data/stim-circuits/ directory.
-- Updated to support the new YAML-like .expected format.
module Test.StimCircuitSpec (spec) where

import Test.Hspec
import System.FilePath
import System.Directory
import Control.Monad (forM, forM_, when)
import Data.List (isPrefixOf, isSuffixOf, sort, stripPrefix)
import Data.Maybe (catMaybes, listToMaybe, fromMaybe)
import Data.Char (isSpace)
import Text.Read (readMaybe)

import SymplecticCHP
import StimToCHP
import CHPCircuit
import Simulator

import qualified StimParser.Expr as Stim
import qualified StimParser.Parse as Stim
import qualified StimParser.ParseUtils as Stim

-- ============================================================================
-- PARSER FOR .EXPECTED FILES
-- ============================================================================

-- | Measurement outcome: +1 or -1
data Outcome = Plus | Minus
  deriving (Eq, Show)

instance Read Outcome where
  readsPrec _ ('+':'1':rest) = [(Plus, rest)]
  readsPrec _ ('-':'1':rest) = [(Minus, rest)]
  readsPrec _ _ = []

outcomeToBool :: Outcome -> Bool
outcomeToBool Plus = True
outcomeToBool Minus = False

boolToOutcome :: Bool -> Outcome
boolToOutcome True = Plus
boolToOutcome False = Minus

-- | Tableau specification
data TableauSpec = TableauSpec
  { specStabilizers :: [String]
  , specDestabilizers :: [String]
  } deriving (Show, Eq)

-- | A possible outcome case for non-deterministic measurements
data OutcomeCase = OutcomeCase
  { caseProbability :: Double
  , caseOutcomes :: [Outcome]
  , caseTableau :: TableauSpec
  } deriving (Show, Eq)

-- | Expected results from .expected file
data ExpectedResults = ExpectedResults
  { expDeterministic :: Bool
  , expMeasurementOutcomes :: Maybe [Outcome]
  , expPreMeasurementTableau :: Maybe TableauSpec
  , expPostMeasurementTableau :: Maybe TableauSpec
  , expCases :: [OutcomeCase]
  , expErrorExpected :: Maybe String
  } deriving (Show, Eq)

-- | Parse a .expected file
parseExpectedFile :: String -> ExpectedResults
parseExpectedFile content =
  let ls = filter (not . isCommentOrEmpty) $ lines content
      -- Parse top-level fields
      deterministic = parseBoolField "deterministic:" ls
      errorExpected = parseStringField "error_expected:" ls
      outcomes = parseOutcomesField "measurement_outcomes:" ls
      preTableau = parseTableauSection "pre_measurement_tableau:" ls
      postTableau = parseTableauSection "post_measurement_tableau:" ls
      cases = parseCases ls
  in ExpectedResults
       { expDeterministic = fromMaybe False deterministic
       , expMeasurementOutcomes = outcomes
       , expPreMeasurementTableau = preTableau
       , expPostMeasurementTableau = postTableau
       , expCases = cases
       , expErrorExpected = errorExpected
       }

-- | Check if a line is a comment or empty
isCommentOrEmpty :: String -> Bool
isCommentOrEmpty line = 
  let trimmed = trim line
  in null trimmed || "#" `isPrefixOf` trimmed

-- | Trim whitespace from both ends
trim :: String -> String
trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse

-- | Drop a prefix from a string if it exists
dropPrefix :: String -> String -> String
dropPrefix prefix str = 
  if prefix `isPrefixOf` str 
  then drop (length prefix) str 
  else str

-- | Parse a boolean field
parseBoolField :: String -> [String] -> Maybe Bool
parseBoolField prefix lines = 
  case findLine prefix lines of
    Just line -> 
      let val = trim $ drop (length prefix) line
      in case val of
           "true" -> Just True
           "false" -> Just False
           _ -> Nothing
    Nothing -> Nothing

-- | Parse a string field (remaining content after colon)
parseStringField :: String -> [String] -> Maybe String
parseStringField prefix lines =
  case findLine prefix lines of
    Just line -> Just $ trim $ drop (length prefix) line
    Nothing -> Nothing

-- | Parse measurement outcomes field
parseOutcomesField :: String -> [String] -> Maybe [Outcome]
parseOutcomesField prefix lines =
  case findLine prefix lines of
    Just line -> 
      let val = trim $ drop (length prefix) line
      in parseOutcomeList val
    Nothing -> Nothing

-- | Parse a list of outcomes like [+1, -1, +1]
parseOutcomeList :: String -> Maybe [Outcome]
parseOutcomeList s = 
  let trimmed = trim s
      inner = case trimmed of
                '[':rest -> reverse $ dropWhile (== ']') $ reverse rest
                _ -> trimmed
      parts = map trim $ splitOn ',' inner
  in mapM parseOutcome parts
  where
    parseOutcome "+1" = Just Plus
    parseOutcome "-1" = Just Minus
    parseOutcome _ = Nothing

-- | Parse a tableau section
tableauSectionNames :: [String]
tableauSectionNames = ["pre_measurement_tableau:", "post_measurement_tableau:"]

parseTableauSection :: String -> [String] -> Maybe TableauSpec
parseTableauSection sectionName lines =
  case findLine sectionName lines of
    Just _ -> 
      let afterSection = dropWhile (not . isSectionHeader) $ dropWhile (not . (sectionName `isPrefixOf`)) lines
          -- Find the lines within this section (until next section or end)
          sectionLines = takeWhile (not . isTopLevelField) $ tail $ dropWhile (not . (sectionName `isPrefixOf`)) lines
          stabLine = findLine "stabilizers:" sectionLines
          destabLine = findLine "destabilizers:" sectionLines
          stabs = stabLine >>= parseStringList . dropPrefix ("stabilizers:" :: String) . trim
          destabs = destabLine >>= parseStringList . dropPrefix ("destabilizers:" :: String) . trim
      in case (stabs, destabs) of
           (Just s, Just d) -> Just $ TableauSpec s d
           (Just s, Nothing) -> Just $ TableauSpec s []
           (Nothing, Just d) -> Just $ TableauSpec [] d
           _ -> Nothing
    Nothing -> Nothing
  where
    isSectionHeader line = any (`isPrefixOf` trim line) tableauSectionNames
    isTopLevelField line = 
      let t = trim line
      in any (`isPrefixOf` t) ["deterministic:", "cases:", "error_expected:", 
                               "measurement_outcomes:", "pre_measurement_tableau:",
                               "post_measurement_tableau:"]

-- | Parse string list like ["+ZZ", "+XX"]
parseStringList :: String -> Maybe [String]
parseStringList s =
  let trimmed = trim s
      inner = case trimmed of
                '[':rest -> reverse $ dropWhile (== ']') $ reverse rest
                _ -> trimmed
      -- Handle quoted strings
      parseQuoted str = case str of
        '"':rest -> Just $ takeWhile (/= '"') rest
        _ -> Just str
      parts = map (trim . filter (/= '"')) $ splitOn ',' inner
  in if null inner then Just [] else Just parts

-- | Parse cases section for non-deterministic measurements
parseCases :: [String] -> [OutcomeCase]
parseCases lines =
  case findLine "cases:" lines of
    Just _ -> 
      let afterCases = tail $ dropWhile (not . ("cases:" `isPrefixOf`)) lines
          -- Each case starts with "- probability:"
          caseBlocks = splitCases afterCases
      in catMaybes $ map parseCaseBlock caseBlocks
    Nothing -> []
  where
    splitCases :: [String] -> [[String]]
    splitCases [] = []
    splitCases ls = 
      let (current, rest) = break (isPrefixOf "- probability:") $ dropWhile (not . isPrefixOf "- probability:") ls
      in if null rest then [] else 
         let (thisCase, next) = span (not . isPrefixOf "- probability:") (tail rest)
         in (head rest : thisCase) : splitCases next

parseCaseBlock :: [String] -> Maybe OutcomeCase
parseCaseBlock block = do
  probLine <- findLine "- probability:" block <|> findLine "probability:" block
  prob <- readMaybe $ filter (/= '-') $ trim $ dropWhile (/= ':') probLine
  outcomes <- parseOutcomesField "measurement_outcomes:" block
  stabLine <- findLine "stabilizers:" block
  destabLine <- findLine "destabilizers:" block
  stabs <- parseStringList $ drop (length ("stabilizers:" :: String)) stabLine
  destabs <- parseStringList $ drop (length ("destabilizers:" :: String)) destabLine
  return $ OutcomeCase prob outcomes (TableauSpec stabs destabs)

-- | Find a line starting with given prefix
findLine :: String -> [String] -> Maybe String
findLine prefix lines = listToMaybe $ filter (isPrefixOf prefix . trim) lines

(<|>) :: Maybe a -> Maybe a -> Maybe a
(<|>) (Just x) _ = Just x
(<|>) Nothing y = y
infixr 1 <|>

-- | Split string on delimiter
splitOn :: Char -> String -> [String]
splitOn _ [] = []
splitOn delim str = 
  let (first, rest) = break (== delim) str
  in first : case rest of
               [] -> []
               (_:xs) -> splitOn delim xs

-- ============================================================================
-- TEST INFRASTRUCTURE
-- ============================================================================

-- | Test case data
data TestCase = TestCase
  { testName :: String
  , stimPath :: FilePath
  , expectedPath :: FilePath
  , stimContent :: String
  , expectedContent :: Maybe String
  } deriving (Show)

-- | Find all test cases in the data directory
findTestCases :: IO [TestCase]
findTestCases = do
  let dataDir = "data" </> "stim-circuits"
  exists <- doesDirectoryExist dataDir
  if not exists
    then return []
    else do
      files <- listDirectory dataDir
      let stimFiles = sort $ filter (".stim" `isSuffixOf`) files
      
      forM stimFiles $ \stimFile -> do
        let baseName = dropExtension stimFile
            stimPath' = dataDir </> stimFile
            expectedPath' = dataDir </> (baseName ++ ".expected")
        
        stimContent <- readFile stimPath'
        expectedExists <- doesFileExist expectedPath'
        expectedContent <- if expectedExists 
                           then Just <$> readFile expectedPath'
                           else return Nothing
        
        return $ TestCase
          { testName = baseName
          , stimPath = stimPath'
          , expectedPath = expectedPath'
          , stimContent = stimContent
          , expectedContent = expectedContent
          }

-- ============================================================================
-- SIMULATION AND CHECKING
-- ============================================================================

-- | Run a single test case
runTestCase :: TestCase -> IO (Maybe String)
runTestCase tc = do
  -- Parse expected results
  let expected = maybe (ExpectedResults False Nothing Nothing Nothing [] Nothing) 
                       parseExpectedFile 
                       (expectedContent tc)
  
  -- Try to read and parse STIM file
  stimResult <- tryReadStim (stimPath tc)
  
  case stimResult of
    Left parseErr ->
      case expErrorExpected expected of
        Just _ -> return Nothing  -- Error expected
        Nothing -> return $ Just $ "Parse error: " ++ parseErr
    
    Right stim -> 
      -- Try to translate to CHP
      case translateStim stim of
        Left err -> 
          case expErrorExpected expected of
            Just _ -> return Nothing  -- Error expected and got error = pass
            Nothing -> return $ Just $ "Translation error: " ++ show err
        
        Right circuit -> 
          case expErrorExpected expected of
            Just _ -> return $ Just "Expected error but translation succeeded"
            Nothing -> do
              -- Run simulation
              result <- runCHPCircuit circuit
              
              -- Run all checks
              let checks = catMaybes 
                    [ checkTableauValid result
                    , checkResults expected result
                    ]
              
              case concat checks of
                [] -> return Nothing
                errors -> return $ Just $ unlines errors

-- | Try to read STIM file
tryReadStim :: FilePath -> IO (Either String Stim.Stim)
tryReadStim path = do
  content <- readFile path
  let prefixed = "!!!Start " ++ content
  return $ Right $ Stim.run Stim.parseStim prefixed

-- | Check tableau validity
checkTableauValid :: SimulationResult -> Maybe [String]
checkTableauValid result = 
  let valid = isValidSome (finalTableau result)
  in if valid 
     then Nothing 
     else Just ["Tableau is not valid"]

-- | Main checking function
checkResults :: ExpectedResults -> SimulationResult -> Maybe [String]
checkResults expected result =
  let actualOutcomes = map boolToOutcome $ measurementOutcomes result
      actualStabs = getStabilizerStrings $ finalTableau result
      actualDestabs = getDestabilizerStrings $ finalTableau result
      actualTableau = TableauSpec actualStabs actualDestabs
  in case expErrorExpected expected of
       Just _ -> Just ["Expected error but simulation succeeded"]
       Nothing ->
         if expDeterministic expected
         then checkDeterministic expected actualOutcomes actualTableau
         else checkNonDeterministic expected actualOutcomes actualTableau

-- | Check deterministic case
checkDeterministic :: ExpectedResults -> [Outcome] -> TableauSpec -> Maybe [String]
checkDeterministic expected actualOutcomes actualTableau =
  let errors = catMaybes
        [ checkField "measurement_outcomes" 
            (expMeasurementOutcomes expected) (Just actualOutcomes)
        , checkField "post_measurement_tableau" 
            (expPostMeasurementTableau expected) (Just actualTableau)
        ]
  in if null errors then Nothing else Just errors
  where
    checkField :: (Eq a, Show a) => String -> Maybe a -> Maybe a -> Maybe String
    checkField name (Just expected) (Just actual) =
      if expected == actual 
      then Nothing 
      else Just $ name ++ " mismatch: expected " ++ show expected ++ ", got " ++ show actual
    checkField name Nothing _ = Nothing
    checkField name (Just _) Nothing = Just $ name ++ " not found in actual result"

-- | Check non-deterministic case
checkNonDeterministic :: ExpectedResults -> [Outcome] -> TableauSpec -> Maybe [String]
checkNonDeterministic expected actualOutcomes actualTableau =
  let cases = expCases expected
      -- Check if actual outcome matches any case
      matchingCase = findMatchingCase actualOutcomes actualTableau cases
  in case matchingCase of
       Just _ -> Nothing  -- Found a matching case
       Nothing -> 
         if null cases
         then Nothing  -- No cases specified, skip
         else Just ["No matching case found for outcomes: " ++ show actualOutcomes ++ 
                   ", tableau: " ++ show actualTableau]

-- | Find a matching case for the actual results
findMatchingCase :: [Outcome] -> TableauSpec -> [OutcomeCase] -> Maybe OutcomeCase
findMatchingCase outcomes tableau = find matches
  where
    matches c = caseOutcomes c == outcomes && caseTableau c == tableau
    find _ [] = Nothing
    find p (x:xs) = if p x then Just x else find p xs

-- | Extract stabilizer strings from tableau
getStabilizerStrings :: SomeTableau -> [String]
getStabilizerStrings tab = 
  let n = nQubitsSome tab
  in catMaybes [stabilizerString tab i | i <- [0..n-1]]

-- | Extract destabilizer strings from tableau  
getDestabilizerStrings :: SomeTableau -> [String]
getDestabilizerStrings tab =
  let n = nQubitsSome tab
  in catMaybes [destabilizerString tab i | i <- [0..n-1]]

-- | Get stabilizer as string
stabilizerString :: SomeTableau -> Int -> Maybe String
stabilizerString tab i = 
  case stabilizerSome tab i of
    Nothing -> Nothing
    Just p -> Just $ showPauliCompact p (nQubitsSome tab)

-- | Get destabilizer as string
destabilizerString :: SomeTableau -> Int -> Maybe String
destabilizerString tab i =
  case destabilizerSome tab i of
    Nothing -> Nothing
    Just p -> Just $ showPauliCompact p (nQubitsSome tab)

-- | Show Pauli operator in compact format (+XX, -ZI, etc.)
showPauliCompact :: Pauli -> Int -> String
showPauliCompact (Pauli x z phase) n =
  let phaseStr = case phase `mod` 4 of
        0 -> "+"
        1 -> "+i"
        2 -> "-"
        3 -> "-i"
        _ -> "?"
      ops = [showSinglePauli (testBit x i) (testBit z i) | i <- [0..n-1]]
  in phaseStr ++ concat ops
  where
    testBit w i = (w `div` (2^i)) `mod` 2 == 1
    showSinglePauli False False = "I"
    showSinglePauli True  False = "X"
    showSinglePauli False True  = "Z"
    showSinglePauli True  True  = "Y"

-- ============================================================================
-- HSPEC SPEC
-- ============================================================================

spec :: Spec
spec = do
  testCases <- runIO findTestCases
  
  if null testCases
    then describe "STIM Circuit Tests" $ 
         it "test circuits found" $ 
         pendingWith "No STIM circuits found in data/stim-circuits/"
    else describe "STIM Circuit Tests" $ do
      forM_ testCases $ \tc -> do
        it (testName tc) $ do
          result <- runTestCase tc
          case result of
            Nothing -> return ()
            Just err -> expectationFailure err
