{-# Language FlexibleContexts, TupleSections #-}

module Preprocessor.Dependency where

import Data.Graph
import qualified Data.Set as S
import Data.List (nub)
import Control.Monad.Except
import Language.Haskell.Syntax

import Names
import NameGenerator
import Preprocessor.ContainedNames

dependencyOrder :: (MonadNameGenerator VariableName m, MonadError String m) => [HsDecl] -> m [[HsDecl]]
dependencyOrder ds = do
    declBindings <- getDeclsBoundNames ds -- The names bound in this declaration group
    let declToNodes d = do
            bound <- getDeclBoundNames d -- All names bound by this declaration
            -- If this is a declaration that doesn't actually bind any variables, we want to add it as a node that can't
            -- be depended on but can depend on others: this is an exceptional case. We generate a fresh unique variable
            -- name and pretend this declaration binds that variable.
            bound' <- if S.null bound then S.singleton <$> freshName else return bound
            -- Any variables used in this declaration that are also defined in this binding group
            contained <- S.intersection declBindings <$> getDeclContainedNames d 
            -- We make one node for each bound variable: the "node" is the declaration binding that variable, the
            -- key is the variable itself, and the dependencies are all variables used in the declaration along with
            -- all other variables bound by the declaration: otherwise vars bound in the same decl are seen as
            -- independent.
            return $ map (d,, S.toList $ S.union contained bound') (S.toList bound')
    adjacencyList <- concat <$> mapM declToNodes ds
    let sccs = stronglyConnComp adjacencyList
    return $ map (nub . flattenSCC) sccs