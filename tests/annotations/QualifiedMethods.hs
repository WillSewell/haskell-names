{-# LANGUAGE TypeFamilies #-}
module QualifiedMethods where

import qualified ExportListWildcards as ExportListWildcards

import qualified DataFamilies as DataFamilies

data Rodor = Rodor

x = ExportListWildcards.Foo1

instance ExportListWildcards.Bar Rodor where
    x Rodor = x

instance DataFamilies.ListLike Rodor where
    type I Rodor = Rodor
    h _ = Rodor
