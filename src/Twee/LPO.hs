{-# LANGUAGE CPP, PatternGuards #-}
module Twee.LPO where

#include "errors.h"
import Twee.Base hiding (lessEq, lessIn)
import Twee.Constraints
import qualified Data.Map.Strict as Map
import Data.Maybe
import Control.Monad

lessEq :: Function f => Term f -> Term f -> Bool
lessEq t u = isJust (lessIn (Model Map.empty) t u)

lessIn :: Function f => Model f -> Term f -> Term f -> Maybe Strictness
lessIn model (Var x) t
  | or [isJust (varLessIn x u) | u <- properSubterms t] = Just Strict
  | Just str <- varLessIn x t = Just str
  | otherwise = Nothing
  where
    varLessIn x t = fromTerm t >>= lessEqInModel model (Variable x)
lessIn model t (Var x) = do
  a <- fromTerm t
  lessEqInModel model a (Variable x)
lessIn model t@(Fun f ts) u@(Fun g us) =
  case compare f g of
    LT -> do
      guard (and [ lessIn model t u == Just Strict | t <- fromTermList ts ])
      return Strict
    EQ -> lexLess t u ts us
    GT -> do
      msum [ lessIn model t u | u <- fromTermList us ]
      return Strict
  where
    lexLess _ _ Empty Empty = Just Nonstrict
    lexLess t u (Cons t' ts) (Cons u' us)
      | t' == u' = lexLess t u ts us
      | Just str <- lessIn model t' u' = do
        guard (and [ lessIn model t u == Just Strict | t <- fromTermList ts ])
        case str of
          Strict -> Just Strict
          Nonstrict ->
            let Just sub = unify t' u' in
            lexLess (subst sub t) (subst sub u) (subst sub ts) (subst sub us)
      | otherwise = do
        msum [ lessIn model t u | u <- fromTermList us ]
        return Strict
    lexLess _ _ _ _ = ERROR("incorrect function arity")