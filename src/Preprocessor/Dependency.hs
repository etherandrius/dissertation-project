{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TupleSections    #-}

module Preprocessor.Dependency where

import           BasicPrelude
import           Control.Monad.Except        (MonadError)
import           Data.Graph                  (flattenSCC, stronglyConnComp)
import           Data.List                   (nub)
import qualified Data.Set                    as S
import           Language.Haskell.Syntax

import           Logger                      (MonadLogger)
import           NameGenerator
import           Preprocessor.ContainedNames

dependencyOrder :: (MonadNameGenerator m, MonadError Text m, MonadLogger m) => [HsDecl] -> m [[HsDecl]]
dependencyOrder ds = do
    declBindings <- getBoundVariables ds -- The names bound in this declaration group
    let declToNodes d = do
            boundVars <- getBoundVariables d -- All names bound by this declaration
            -- If this is a declaration that doesn't actually bind any variables, we want to add it as a node that can't
            -- be depended on but can depend on others: this is an exceptional case. We generate a fresh unique variable
            -- name and pretend this declaration binds that variable.
            boundVars' <- if S.null boundVars then S.singleton <$> freshVarName else return boundVars
            -- Any variables used in this declaration that are also defined in this binding group
            freeVars <- getFreeVariables d
            let contained = S.intersection declBindings freeVars
            -- We make one node for each bound variable: the "node" is the declaration binding that variable, the
            -- key is the variable itself, and the dependencies are all variables used in the declaration along with
            -- all other variables bound by the declaration: otherwise vars bound in the same decl are seen as
            -- independent.
            return $ map (d,, S.toList $ S.union contained boundVars') (S.toList boundVars')
    adjacencyList <- concat <$> mapM declToNodes ds
    let sccs = stronglyConnComp adjacencyList
    return $ map (nub . flattenSCC) sccs
