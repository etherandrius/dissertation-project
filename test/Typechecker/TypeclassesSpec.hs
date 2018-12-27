module Typechecker.TypeclassesSpec where

import BasicPrelude
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, assertFailure)

import Data.Text (unpack)
import TextShow (showt)
import Names (TypeVariableName(..))
import NameGenerator (evalNameGenerator)
import Typechecker.Typechecker (evalTypeInferrer)
import Typechecker.Hardcoded
import Typechecker.Typeclasses
import Typechecker.Types

import qualified Data.Set as S
import Control.Monad ()
import Control.Monad.Except (runExceptT)

makeTest :: ClassEnvironment -> S.Set TypePredicate -> TypePredicate -> TestTree
makeTest ce ps goal = testCase (unpack $ showt goal) $ case result of
        Left err -> assertFailure (unpack err)
        Right success -> if success then return () else assertFailure "Failed to prove"
    where result = evalNameGenerator (runExceptT $ evalTypeInferrer $ entails ce ps goal) 0

makeFailTest :: ClassEnvironment -> S.Set TypePredicate -> TypePredicate -> TestTree
makeFailTest ce ps goal = testCase (unpack $ "Fails: " <> showt goal) $ case result of
        Left _ -> return ()
        Right success -> when success (assertFailure "Succeeded in proving")
    where result = evalNameGenerator (runExceptT $ evalTypeInferrer $ entails ce ps goal) 0

test :: TestTree
test = testGroup "Type Classes"
    [ 
        makeTest builtinClasses S.empty (IsInstance (TypeVariableName "Eq") typeBool),
        makeTest builtinClasses S.empty (IsInstance (TypeVariableName "Eq") typeString),
        makeFailTest builtinClasses S.empty (IsInstance (TypeVariableName "Eq") typeFloat)
    ]