{-# Language FlexibleContexts, FlexibleInstances, LambdaCase #-}

module Typechecker.Simplifier where

import Typechecker.Types
import Typechecker.Substitution
import Typechecker.Typeclasses

import Text.Printf
import Data.Foldable
import Control.Monad.Except
import qualified Data.Set as S
import ExtraDefs

class HasHnf t where
    -- |Returns whether `t` is in head-normal form, as defined by the Haskell report
    -- In practice, this means that if we have environment `(Ord a, Ord b) => Ord (a, b)` and have `Ord (a, b)` in a
    -- qualifier we must expand it into `(Ord a, Ord b)`.
    inHnf :: t -> Bool

    -- |Converts a `t` into hnf
    toHnf :: (TypeInstantiator m, MonadError String m) => ClassEnvironment -> t -> m (S.Set TypePredicate)

instance HasHnf Type where
    inHnf (TypeVar _) = True
    inHnf (TypeDummy _) = True
    inHnf (TypeConstant _ _ ts) = inHnf ts

    toHnf _ _ = throwError "Can't convert a type to HNF"
instance HasHnf TypePredicate where
    inHnf (IsInstance _ x) = inHnf x

    -- |If the predicate is already in head normal form, return it. Otherwise, get the predicates that can be used to
    -- infer it from the environment.
    toHnf ce p | inHnf p = return (S.singleton p)
               | otherwise = ifPThenByInstance ce p >>= \case
                    Nothing -> throwError "Failed to convert predicate to HNF"
                    Just ps -> toHnf ce ps
instance HasHnf t => HasHnf (S.Set t) where
    inHnf = all inHnf
    toHnf ce s = S.unions <$> mapM (toHnf ce) (S.toList s)
instance HasHnf t => HasHnf [t] where
    inHnf = all inHnf
    toHnf ce ts = S.unions <$> mapM (toHnf ce) ts

detectInvalidPredicate :: (TypeInstantiator m, MonadError String m) => ClassEnvironment -> TypePredicate -> m ()
detectInvalidPredicate ce inst@(IsInstance classname (TypeConstant _ _ _)) = do
    -- valid is true if the given predicate is an "immediate" instance of the class (has no qualifiers, like `Eq Int`)
    -- and it has the same as the given predicate. We can use `==` instead of eg. `hasMgu` because these ground terms
    -- should be structurally equal.
    let valid (Qualified quals t) = (\t' -> S.null quals && inst == t') <$> doInstantiate t
    isInstance <- anyM valid =<< instances classname ce
    unless isInstance (throwError $ printf "Predicate %s doesn't hold in the environment." (show inst))
detectInvalidPredicate _ _ = return ()

-- |Removes redundant predicates from the given set. A predicate is redundant if it's entailed by any of the other
-- predicates
removeRedundant :: (TypeInstantiator m, MonadError String m) => ClassEnvironment -> S.Set TypePredicate -> m (S.Set TypePredicate)
removeRedundant ce s = foldlM removeIfEntailed S.empty s
    where removeIfEntailed acc p = do
            -- A predicate is redundant if it can be entailed by the other predicates
            let otherPreds = acc `S.union` S.filter (> p) s
            redundant <- entails ce otherPreds p
            return (if redundant then acc else S.insert p acc)

-- |Simplify a context as specified in the Haskell report: reduce each predicate to head-normal form then remove
-- redundant predicates.
simplify :: (TypeInstantiator m, MonadError String m) => ClassEnvironment -> S.Set TypePredicate -> m (S.Set TypePredicate)
simplify ce s = do
    hnfs <- toHnf ce s
    mapM_ (detectInvalidPredicate ce) hnfs
    removeRedundant ce hnfs

-- |Splits a set of predicates into those that belong in the constraints for a type, and those which belong in some
-- enclosing type.
-- TODO(kc506): thih uses another argument and handles defaults. Can this be ignored here?
split :: (TypeInstantiator m, MonadError String m) => ClassEnvironment -> S.Set TypeVariable -> S.Set TypePredicate -> m (S.Set TypePredicate, S.Set TypePredicate)
split env fixed preds = do
    simplePreds <- simplify env preds
    let (deferredPreds, qualifyingPreds) = S.partition ((`S.isSubsetOf` fixed) . S.fromList . getInstantiatedTypeVars) simplePreds
    return (qualifyingPreds, deferredPreds)