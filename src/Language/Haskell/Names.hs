module Language.Haskell.Names
  (
  -- * Core functions
    computeInterfaces
  , getInterfaces
  , annotateModule
  , qualifySymbols
  -- * Types
  , SymValueInfo(..)
  , SymTypeInfo(..)
  , Symbols(..)
  , Scoped(..)
  , NameInfo(..)
  , NameS
  , ModuleNameS
  , GName(..)
  , ppGName
  , OrigName(..)
  , ppOrigName
  , Error(..)
  , ppError
  , SymFixity
  , HasOrigName(..)
  ) where

import Language.Haskell.Names.Types
import Language.Haskell.Names.Recursive
import Language.Haskell.Names.ScopeUtils
