module Typechecker.TypeclassesSpec where

import qualified Data.Set as S
import Control.Monad

import Test.Tasty
import Test.Tasty.HUnit

import Names
import NameGenerator
import Typechecker.Typechecker
import Typechecker.Hardcoded
import Typechecker.Typeclasses
import Typechecker.Types

makeTest :: ClassEnvironment -> S.Set TypePredicate -> TypePredicate -> TestTree
makeTest ce ps goal = testCase (show goal) $ case result of
        Left err -> assertFailure err
        Right success -> if success then return () else assertFailure "Failed to prove"
    where result = evalNameGenerator (evalTypeInferrer $ entails ce ps goal) 0

makeFailTest :: ClassEnvironment -> S.Set TypePredicate -> TypePredicate -> TestTree
makeFailTest ce ps goal = testCase ("Fails: " ++ show goal) $ case result of
        Left _ -> return ()
        Right success -> when success (assertFailure "Succeeded in proving")
    where result = evalNameGenerator (evalTypeInferrer $ entails ce ps goal) 0

test :: TestTree
test = testGroup "Typeclasses"
    [ 
        makeTest builtinClasses S.empty (IsInstance (TypeConstantName "Eq") typeBool),
        makeTest builtinClasses S.empty (IsInstance (TypeConstantName "Eq") typeString),
        makeFailTest builtinClasses S.empty (IsInstance (TypeConstantName "Eq") typeFloat)
    ]