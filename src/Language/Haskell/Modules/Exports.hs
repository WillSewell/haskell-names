module Language.Haskell.Modules.Exports where

import qualified Data.Map as Map
import Control.Applicative
import Control.Monad
import Control.Monad.State
import Data.Lens.Common
import Language.Haskell.Exts.Annotated
import Language.Haskell.Modules.Types
import qualified Language.Haskell.Modules.GlobalSymbolTable as Global

resolveExportSpec
  :: Global.Table
  -> ExportSpec l
  -> ExportSpec (Scoped l)
resolveExportSpec tbl e =
  case e of
    EVar _ qn ->
      let
        ann =
          either
            (\e l -> ScopeError l e)
            (\i l -> Export l ([i],[])) $
            Global.lookupValue qn tbl
      in ann <$> e
    EAbs _ qn ->
      let
        ann =
          either
            (\e l -> ScopeError l e)
            (\i l -> Export l ([],[i])) $
            Global.lookupType qn tbl
      in ann <$> e
    -- FIXME: the rest

-- Used to detect conflicts
type SymbolSet a = (Map.Map NameS [a], Map.Map NameS [a])

type Accum a = State (SymbolSet a)

addSymbols :: a -> Symbols OrigName -> Accum a ()
addSymbols a (ts,vs) =
    mapM_ (add fstLens) vs >> mapM_ (add sndLens) ts
  where
    add lens i = do
      let GName _ n = origName i
      modify $ modL lens (Map.insertWith (++) n [a])