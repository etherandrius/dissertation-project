{-# LANGUAGE FlexibleContexts, TypeSynonymInstances, FlexibleInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Typechecker.Substitution where

import Prelude hiding (all)
import Data.Foldable (all)
import Control.Monad.Except
import Data.List (union, nub, intercalate)
import qualified Data.Map.Strict as M
import Typechecker.Types (TypeVariable(..), Type(..), AssocShow(..))

-- A substitution is a collection of assignments of a type to a variable
type Substitution = M.Map TypeVariable Type

instance AssocShow Substitution where
    assocShow _ sub = "[" ++ intercalate ", " prettyElements ++ "]"
        where prettyElements = map (\(k, v) -> assocShow True v ++ "/" ++ show k) $ M.toList sub

subEmpty :: Substitution
subEmpty = M.empty

subSingle :: TypeVariable -> Type -> Substitution
subSingle = M.singleton

subMultiple :: [(TypeVariable, Type)] -> Substitution
subMultiple = foldl subCompose subEmpty . map (uncurry subSingle)

class Substitutable t where
    -- Apply the given type variable -> type substitution
    applySub :: Substitution -> t -> t
    -- Return all the contained type variables, in left->right order and without duplicates
    getTypeVars :: t -> [TypeVariable]

instance Substitutable Type where
    applySub subs t@(TypeVar var) = M.findWithDefault t var subs
    applySub subs (TypeApp t1 t2) = TypeApp (applySub subs t1) (applySub subs t2)
    applySub _ t = t
    
    getTypeVars (TypeVar var) = [var]
    getTypeVars (TypeApp t1 t2) = getTypeVars t1 `union` getTypeVars t2
    getTypeVars _ = []
instance Substitutable a => Substitutable [a] where
    applySub subs = map (applySub subs)
    getTypeVars = nub . concatMap getTypeVars


-- Composition of substitutions
subCompose :: Substitution -> Substitution -> Substitution
subCompose s1 s2 = M.union s1' s2 -- Left-biased union with s2 applied to s1
    where s1' = M.map (applySub s2) s1

-- Merging of substitutions (the intersections of the type variables from each substitution must produce the same
-- results, the rest can do whatever).
subMerge :: MonadError String m => Substitution -> Substitution -> m Substitution
subMerge s1 s2 = if agree then return (M.union s1 s2) else throwError "Conflicting substitutions"
    where agree = all subsGiveSameResult (M.keys $ M.intersection s1 s2)
          -- Check that both substitutions give the same type when applied to the same type variables
          subsGiveSameResult var = applySub s1 (TypeVar var) == applySub s2 (TypeVar var)