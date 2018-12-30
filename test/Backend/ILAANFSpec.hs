{-# LANGUAGE FlexibleContexts #-}

module Backend.ILAANFSpec where

import           BasicPrelude            hiding (head)
import           Control.Monad.Except    (MonadError, runExceptT, throwError)
import qualified Data.Map                as M
import qualified Data.Set                as S
import           Data.Text               (pack, unpack)
import           Language.Haskell.Parser (ParseResult(..), parseModule)
import           Language.Haskell.Syntax
import           Test.Tasty              (TestTree, testGroup)
import           Test.Tasty.HUnit        (assertFailure, testCase)
import           TextShow                (showt)

import           AlphaEq                 (alphaEqError)
import           Backend.Deoverload      (deoverloadModule, deoverloadQuantType, evalDeoverload)
import           Backend.ILA             hiding (Expr(..), makeError, makeList, makeTuple)
import           Backend.ILAANF
import           ExtraDefs
import           Logger                  (runLogger, runLoggerT)
import           NameGenerator           (evalNameGenerator, freshDummyTypeVarName)
import           Typechecker.Hardcoded   (builtinKinds, builtinClasses, builtinDictionaries)
import           Typechecker.Typechecker
import           Typechecker.Types       hiding (makeFun, makeList, makeTuple)
import qualified Typechecker.Types       as T

parse :: MonadError Text m => Text -> m HsModule
parse s = case parseModule $ unpack s of
    ParseOk m           -> return m
    ParseFailed loc msg -> throwError $ pack msg <> ": " <> showt loc

makeTest :: Text -> [Binding AnfComplex] -> TestTree
makeTest input expected = testCase (unpack $ deline input) $
    case evalNameGenerator (runLoggerT $ runExceptT foo) 0 of
        (Left err, logs) -> assertFailure $ unpack $ unlines [err, "Logs:", unlines logs]
        (Right binds, logs1) -> case runLogger $ runExceptT $ alphaEqError (S.fromList expected) (S.fromList binds) of
            (Left err, logs2) -> assertFailure $ unpack $ unlines [err, showt expected, "vs", showt binds, "Logs:", unlines logs1, unlines logs2]
            _ -> return ()
    where foo = do
            m <- parse input
            (m', ts) <- evalTypeInferrer (inferModuleWithBuiltins m)
            m'' <- evalDeoverload (deoverloadModule m') builtinDictionaries ts builtinKinds builtinClasses
            -- Convert the overloaded types (Num a => a) into deoverloaded types (Num a -> a).
            let dets = map deoverloadQuantType ts
            -- Run the ILA conversion on the deoverloaded module+types
            evalConverter (toIla m'' >>= ilaToAnf) dets builtinKinds


test :: TestTree
test = testGroup "ILA-ANF"
    [
        let input = "f = \\x -> x"
            fBody = Lam "x" a $ Case (Var "x" a) ["x'"] [ Alt Default [] $ Var "x'" a]
            fType = T.makeFun [a] a
            [fBodyWrappedBinding] = makeTupleUnsafe [(Var "fBody'" fType, "fBodyWrapped")]
            fBodyWrapped = Var "fBodyWrapped" $ T.makeTuple [fType]
            fWrapped = Var "fWrapped" $ T.makeTuple [fType]
            expected =
                [ fBodyWrappedBinding -- The tuple (\x -> x)
                , Rec $ M.fromList -- The pattern declaration for f, returning a tuple containing f's value
                    [ ("fWrapped", Case fBody ["fBody'"] [ Alt Default [] fBodyWrapped ]) ]
                  -- f's actual binding, extracting the lambda body from the tuple
                , NonRec "f" $ Case fWrapped [] [ Alt (DataCon "(,)") ["f'"] $ Var "f'" fType, errAlt fType ] ]
        in makeTest input expected
    ,
        let input = "f = \\x -> x + x ; y = f 1 :: Int"
            expected = []
        in makeTest input expected
    ]
    where a:b:c:_ = map (\t -> TypeVar $ TypeVariable t KindStar) $ evalNameGenerator (replicateM 10 freshDummyTypeVarName) 1
          true = Var "True" typeBool
          false = Var "False" typeBool
          trueCon = DataCon "True"
          falseCon = DataCon "False"
          tupleCon = DataCon "(,)"
          consCon = DataCon ":"
          nilCon = DataCon "[]"
          errAlt t = Alt Default [] (makeError t)
          plus t = Var "+" (T.makeFun [t, t] t)
