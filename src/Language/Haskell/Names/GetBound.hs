{-# LANGUAGE MultiParamTypeClasses, FunctionalDependencies,
             FlexibleInstances, UndecidableInstances, NamedFieldPuns,
             ScopedTypeVariables #-}
module Language.Haskell.Names.GetBound
  ( GetBound(..)
  ) where

import Data.Generics.Uniplate.Data
import Data.Data
import qualified Data.Map as Map
import qualified Data.Set as Set
import Data.Maybe
import Control.Monad
import Control.Applicative

import Language.Haskell.Exts.Annotated
import Language.Haskell.Names.Types
import Language.Haskell.Names.SyntaxUtils
import qualified Language.Haskell.Names.GlobalSymbolTable as Global

-- | Get bound value identifiers.
class GetBound a l | a -> l where
    -- | For record wildcards we need to know which fields the given
    -- constructor has. So we pass the global table for that.
    getBound :: Global.Table -> a -> [Name l]

-- XXX account for shadowing?
instance (GetBound a l) => GetBound [a] l where
    getBound ctx xs = concatMap (getBound ctx) xs

instance (GetBound a l) => GetBound (Maybe a) l where
    getBound ctx = maybe [] (getBound ctx)

instance (GetBound a l, GetBound b l) => GetBound (a, b) l where
    getBound ctx (a, b) = getBound ctx a ++ getBound ctx b

instance (Data l) => GetBound (Binds l) l where
    getBound ctx e = case e of
      BDecls _ ds -> getBound ctx ds
      IPBinds _ _ -> []  -- XXX doesn't bind regular identifiers

instance (Data l) => GetBound (Decl l) l where
    getBound ctx e = case e of
      TypeDecl{} -> []
      TypeFamDecl{} -> []
      DataDecl _ _ _ _ ds _ -> getBound ctx ds
      GDataDecl _ _ _ _ _ ds _ -> getBound ctx ds
      DataFamDecl{} -> []
      TypeInsDecl{} -> []
      DataInsDecl _ _ _ ds _ -> getBound ctx ds
      GDataInsDecl _ _ _ _ ds _ -> getBound ctx ds
      ClassDecl _ _ _ _ mds -> getBound ctx mds
      InstDecl{} -> []
      DerivDecl{} -> []
      InfixDecl{} -> []
      DefaultDecl{} -> []
      SpliceDecl{} -> []
      TypeSig{} -> []
      FunBind _ [] -> error "getBound: FunBind []"
      FunBind _ (Match _ n _ _ _ : _) -> [n]
      FunBind _ (InfixMatch _ _ n _ _ _ : _) -> [n]
      PatBind _ p _ _ _ -> getBound ctx p
      ForImp _ _ _ _ n _ -> [n]
      ForExp _ _ _ n _ -> [n]
      RulePragmaDecl{} -> []
      DeprPragmaDecl{} -> []
      WarnPragmaDecl{} -> []
      InlineSig{} -> []
      SpecSig{} -> []
      SpecInlineSig{} -> []
      InstSig{} -> []
      AnnPragma{} -> []
      InlineConlikeSig{} -> []

instance (Data l) => GetBound (QualConDecl l) l where
    getBound ctx (QualConDecl _ _ _ d) = getBound ctx d

instance (Data l) => GetBound (GadtDecl l) l where
    getBound _ctx (GadtDecl _ n _) = [n]

instance (Data l) => GetBound (ConDecl l) l where
    getBound ctx e = case e of
      ConDecl _ n _ -> [n]
      InfixConDecl _ _ n _ -> [n]
      RecDecl _ n fs -> n : getBound ctx fs

instance (Data l) => GetBound (FieldDecl l) l where
    getBound _ctx (FieldDecl _ ns _) = ns

instance (Data l) => GetBound (ClassDecl l) l where
    getBound _ctx e = case e of
      ClsDecl _ d -> getBoundSign d
      ClsDataFam{} -> []
      ClsTyFam{} -> []
      ClsTyDef{} -> []

instance (Data l) => GetBound (Match l) l where
    getBound _ctx e = case e of
      Match _ n _ _ _ -> [n]
      InfixMatch _ _ n _ _ _ -> [n]

instance (Data l) => GetBound (Stmt l) l where
  getBound ctx e =
    case e of
      Generator _ pat _ -> getBound ctx pat
      LetStmt _ bnds    -> getBound ctx bnds
      RecStmt _ stmts   -> getBound ctx stmts
      Qualifier {} -> []

instance (Data l) => GetBound (QualStmt l) l where
  getBound ctx e =
    case e of
      QualStmt _ stmt -> getBound ctx stmt
      _ -> []

instance (Data l) => GetBound (Pat l) l where
  getBound gt p =
    [ n | p' <- universe $ transform dropExp p, n <- varp p' ]

    where

      varp (PVar _ n) = [n]
      varp (PAsPat _ n _) = [n]
      varp (PNPlusK _ n _) = [n]
      varp (PRec _ con fs) =
        [ n
        | -- (lazily) compute elided fields for the case when 'f' below is a wildcard
          let elidedFields = getElidedFields con fs
        , f <- fs
        , n <- getRecVars elidedFields f
        ]
      varp _ = []

      getElidedFields :: QName l -> [PatField l] -> Set.Set (Name ())
      getElidedFields con patfs =
        let
          givenFieldNames :: Set.Set (Name ())
          givenFieldNames =
            Set.fromList . map void . flip mapMaybe patfs $ \pf ->
              case pf of
                PFieldPat _ qn _ -> Just $ qNameToName qn
                PFieldPun _ n -> Just n
                PFieldWildcard {} -> Nothing

          -- FIXME must report error when the constructor cannot be
          -- resolved
          mbConOrigName =
            case Global.lookupValue con gt of
              Global.Result info@SymConstructor{} -> Just $ sv_origName info
              _ -> Nothing

          allValueInfos :: Set.Set (SymValueInfo OrigName)
          allValueInfos = Set.unions $ Map.elems $ Global.values gt

          ourFieldInfos :: Set.Set (SymValueInfo OrigName)
          ourFieldInfos =
            case mbConOrigName of
              Nothing -> Set.empty
              Just conOrigName ->
                flip Set.filter allValueInfos $ \v ->
                  case v of
                    SymSelector { sv_constructors }
                      | conOrigName `elem` sv_constructors -> True
                    _ -> False

          ourFieldNames :: Set.Set (Name ())
          ourFieldNames =
            Set.map
              (stringToName . (\(GName _ n) -> n) . origGName . sv_origName)
              ourFieldInfos

        in ourFieldNames `Set.difference` givenFieldNames

      -- must remove nested Exp so universe doesn't descend into them
      dropExp (PViewPat _ _ x) = x
      dropExp x = x

      getRecVars :: Set.Set (Name ()) -> PatField l -> [Name l]
      getRecVars _ PFieldPat {} = [] -- this is already found by the generic algorithm
      getRecVars _ (PFieldPun _ n) = [n]
      getRecVars elidedFields (PFieldWildcard l) = map (l <$) $ Set.toList elidedFields

getBoundSign :: Decl l -> [Name l]
getBoundSign (TypeSig _ ns _) = ns
getBoundSign _ = []
