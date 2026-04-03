{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

-- | Integration tests for STIM circuit files.
-- Tests circuits from data/stim-circuits/ directory.
module Test.StimCircuitSpec (spec) where

import Test.Hspec
import System.FilePath
import System.Directory
import Control.Monad (forM, forM_, when)
import Data.List (isPrefixOf, isSuffixOf, sort)
import Data.Maybe (catMaybes, listToMaybe)

import SymplecticCHP
import StimToCHP
import CHPCircuit
import Simulator

import qualified StimParser.Expr as Stim
import qualified StimParser.Parse as Stim
import qualified StimParser.ParseUtils as Stim

-- | Test case data
data TestCase = TestCase
  { testName :: String
  , stimPath :: FilePath
  , expectedPath :: FilePath
  , stimContent :: String
  , expectedContent :: Maybe String
  } deriving (Show)

-- | Expected results from .expected file
data ExpectedResults = ExpectedResults
  { expectCorrelated :: Bool
  , expectOutcomes :: Maybe [Bool]
  , expectError :: Bool
  , expectStabilizers :: Maybe [String]
  } deriving (Show)

-- | Parse expected results file
parseExpected :: String -> ExpectedResults
parseExpected content = ExpectedResults
  { expectCorrelated = hasTrue "measurements_correlated"
  , expectOutcomes = parseOutcomes content
  , expectError = hasField "error_expected"
  , expectStabilizers = Nothing  -- Not implemented yet
  }
  where
    lines' = lines content
    trim = dropWhile (== ' ') . reverse . dropWhile (== ' ') . reverse
    hasTrue field = any (\l -> field `isPrefixOf` l && "true" `isInfixOf` l) 
                        (map trim lines')
    hasField field = any (isPrefixOf field) (map trim lines')
    isInfixOf needle haystack = any (isPrefixOf needle) (tails haystack)
    tails [] = []
    tails xs = xs : tails (drop 1 xs)

-- | Parse measurement outcomes from expected content
parseOutcomes :: String -> Maybe [Bool]
parseOutcomes content = 
  case filter (isPrefixOf "measurement_outcomes:") (lines content) of
    [] -> Nothing
    (line:_) -> case extractList line of
      Just listStr -> readMaybe listStr
      Nothing -> Nothing
  where
    extractList line = 
      let afterColon = drop 1 $ dropWhile (/= ':') line
          trimmed = dropWhile (== ' ') afterColon
      in if null trimmed then Nothing else Just trimmed
    
    readMaybe str = 
      case reads str of
        [(val, "")] -> Just val
        _ -> Nothing

-- | Find all test cases in the data directory
findTestCases :: IO [TestCase]
findTestCases = do
  let dataDir = "data" </> "stim-circuits"
  exists <- doesDirectoryExist dataDir
  if not exists
    then return []  -- Return empty if directory doesn't exist (e.g., during cabal check)
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

-- | Run a single test case
runTestCase :: TestCase -> IO (Maybe String)
runTestCase tc = do
  -- Read and parse STIM file (may throw on parse error)
  stim <- tryReadStim (stimPath tc)
  
  -- Try to translate to CHP
  case translateStim stim of
    Left err -> 
      if expectError expected
      then return Nothing  -- Error expected and got error = pass
      else return $ Just $ "Translation error: " ++ show err
    Right circuit -> 
      if expectError expected
      then return $ Just "Expected error but translation succeeded"
      else do
        -- Run simulation
        result <- runCHPCircuit circuit
        
        -- Run checks
        let checks = catMaybes 
              [ checkTableauValid result
              , checkCorrelated expected result
              , checkExactOutcomes expected result
              ]
        
        case concat checks of
          [] -> return Nothing
          errors -> return $ Just $ unlines errors
  where
    expected = maybe (ExpectedResults False Nothing False Nothing) 
                     parseExpected 
                     (expectedContent tc)

-- | Try to read STIM file
-- Note: Uses unsafe run which throws exceptions on parse errors
tryReadStim :: FilePath -> IO Stim.Stim
tryReadStim path = do
  content <- readFile path
  let prefixed = "!!!Start " ++ content
  return $ Stim.run Stim.parseStim prefixed

-- | Check tableau validity
checkTableauValid :: SimulationResult -> Maybe [String]
checkTableauValid result = 
  let valid = isValidSome (finalTableau result)
  in if valid 
     then Nothing 
     else Just ["Tableau is not valid"]

-- | Check measurement correlations
checkCorrelated :: ExpectedResults -> SimulationResult -> Maybe [String]
checkCorrelated expected result = 
  if not (expectCorrelated expected)
  then Nothing
  else 
    let outcomes = measurementOutcomes result
        correlated = null outcomes || all (== head outcomes) outcomes
    in if correlated 
       then Nothing 
       else Just ["Measurements not correlated: " ++ show outcomes]

-- | Check exact measurement outcomes
checkExactOutcomes :: ExpectedResults -> SimulationResult -> Maybe [String]
checkExactOutcomes expected result = 
  case expectOutcomes expected of
    Nothing -> Nothing
    Just expectedOuts ->
      let actual = measurementOutcomes result
      in if actual == expectedOuts
         then Nothing
         else Just ["Outcomes mismatch: expected " ++ show expectedOuts ++ 
                    ", got " ++ show actual]

-- | Hspec spec
spec :: Spec
spec = do
  testCases <- runIO findTestCases
  
  -- Only run tests if test directory exists
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
