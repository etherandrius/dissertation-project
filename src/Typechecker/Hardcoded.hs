module Typechecker.Hardcoded where

import qualified Data.Map as M
import qualified Data.Set as S

import Typechecker.Types
import Typechecker.Typeclasses

builtinConstructors :: M.Map Id QualifiedType
builtinConstructors = M.fromList
    [ ("True", Qualified S.empty typeBool),
      ("False", Qualified S.empty typeBool)
    ]

builtinFunctions :: M.Map Id QualifiedType
builtinFunctions = M.fromList
    [
      let v = TypeDummy (TypeVariable "a" KindStar)
          t = makeFun [v, v] v
      in ("+", Qualified (S.singleton (IsInstance "Num" v)) t)
    ,
      ("&&", Qualified S.empty (makeFun [typeBool, typeBool] typeBool))
    ,
      ("||", Qualified S.empty (makeFun [typeBool, typeBool] typeBool))
    ,
      ("not", Qualified S.empty (makeFun [typeBool] typeBool))
    ]

builtinClasses :: ClassEnvironment
builtinClasses = M.fromList
    [
        ("Eq", Class S.empty $ S.fromList
            [
                Qualified S.empty (IsInstance "Eq" typeBool),
                Qualified S.empty (IsInstance "Eq" typeInt),
                Qualified S.empty (IsInstance "Eq" typeChar),
                Qualified (S.fromList [IsInstance "Eq" a]) (IsInstance "Eq" $ makeList a),
                Qualified (S.fromList [IsInstance "Eq" a, IsInstance "Eq" b]) (IsInstance "Eq" $ makeTuple [a, b])
            ]
        ),
        ("Num", Class (S.singleton "Eq") $ S.fromList
            [
                Qualified S.empty (IsInstance "Num" typeInt)
            ]
        ),
        ("Fractional", Class (S.singleton "Num") $ S.fromList
            [
                Qualified S.empty (IsInstance "Fractional" typeFloat)
            ]
        ),
        ("Show", Class S.empty $ S.fromList 
            [
                Qualified S.empty (IsInstance "Show" typeBool),
                Qualified S.empty (IsInstance "Show" typeInt),
                Qualified S.empty (IsInstance "Show" typeChar),
                Qualified (S.singleton $ IsInstance "Show" a) (IsInstance "Show" $ makeList a),
                Qualified (S.fromList [IsInstance "Show" a, IsInstance "Show" b]) (IsInstance "Show" $ makeTuple [a, b])
            ])
    ]
    where
        a = TypeDummy (TypeVariable "a" KindStar)
        b = TypeDummy (TypeVariable "a" KindStar)