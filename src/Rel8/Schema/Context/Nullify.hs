{-# language DataKinds #-}
{-# language FlexibleContexts #-}
{-# language FlexibleInstances #-}
{-# language MultiParamTypeClasses #-}
{-# language StandaloneKindSignatures #-}
{-# language TypeFamilies #-}

module Rel8.Schema.Context.Nullify
  ( Nullifiable( encodeTag, decodeTag, nullifier, unnullifier )
  , NullifiableEq
  , unnull, runTag
  )
where

-- base
import Data.Kind ( Constraint )
import Prelude hiding ( null )

-- opaleye
import qualified Opaleye.Internal.HaskellDB.PrimQuery as Opaleye

-- rel8
import {-# SOURCE #-} Rel8.Expr ( Expr )
import Rel8.Expr.Bool ( boolExpr )
import Rel8.Expr.Null ( nullify, unsafeUnnullify )
import Rel8.Expr.Opaleye ( fromPrimExpr )
import Rel8.Kind.Labels ( KnownLabels )
import Rel8.Kind.Necessity ( Necessity( Required ) )
import Rel8.Schema.Context ( Interpretation, Col(..) )
import qualified Rel8.Schema.Kind as K
import Rel8.Schema.Nullability ( Nullability( Nullable, NonNullable ), Sql )
import Rel8.Schema.Spec ( Spec( Spec ), SSpec )
import Rel8.Type.Eq ( DBEq )
import Rel8.Type.Monoid ( DBMonoid )


type Nullifiable :: K.Context -> Constraint
class Interpretation context => Nullifiable context where
  encodeTag :: (Sql DBEq a, KnownLabels labels)
    => Expr a
    -> Col context ('Spec labels 'Required db a)

  decodeTag :: Sql DBMonoid a
    => Col context ('Spec labels 'Required db a)
    -> Expr a

  nullifier :: ()
    => Expr Bool
    -> SSpec ('Spec labels necessity db a)
    -> Col context ('Spec labels necessity db a)
    -> Col context ('Spec labels necessity db (Maybe db))

  unnullifier :: ()
    => Expr Bool
    -> SSpec ('Spec labels necessity db a)
    -> Col context ('Spec labels necessity db (Maybe db))
    -> Col context ('Spec labels necessity db a)


type NullifiableEq :: K.Context -> K.Context -> Constraint
class (a ~ b, Nullifiable b) => NullifiableEq a b
instance (a ~ b, Nullifiable b) => NullifiableEq a b


runTag :: Nullability db a -> Expr Bool -> Expr a -> Expr (Maybe db)
runTag nullability tag a = case nullability of
  Nullable -> boolExpr null a tag
  NonNullable -> boolExpr null (nullify a) tag
  where
    null = fromPrimExpr $ Opaleye.ConstExpr Opaleye.NullLit


unnull :: Nullability db a -> Expr (Maybe db) -> Expr a
unnull nullability a = case nullability of
  Nullable -> a
  NonNullable -> unsafeUnnullify a
