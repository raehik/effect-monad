{-# LANGUAGE TypeFamilies, MultiParamTypeClasses, FlexibleInstances, GADTs, 
             EmptyDataDecls, UndecidableInstances, RebindableSyntax, OverlappingInstances, 
             DataKinds, TypeOperators, PolyKinds #-}

module Control.IxMonad.Reader where

import Control.IxMonad
import Prelude hiding (Monad(..))
import GHC.TypeLits
import Data.Proxy

-- Type-level list

data Nil
data Cons (k :: Symbol) (v :: *) (xs :: *)

data List n where
    Nil :: List Nil
    Cons :: Proxy (k :: Symbol) -> v -> List xs -> List (Cons k v xs)

-- Type-level set union
--    implemented using lists, with a canonical ordering and duplicates removed
type family Union s t where Union s t = RemDup (Bubble (Append' s t))

-- Type-level list append
type family Append' s t where
       Append' Nil t = t
       Append' (Cons k x xs) ys = Cons k x (Append' xs ys)

-- Remove duplicates from a type-level list
type family RemDup t where
            RemDup Nil                      = Nil
            RemDup (Cons k a  Nil)          = Cons k a Nil
            RemDup (Cons k a (Cons k a as)) = Cons k a (RemDup as)
            RemDup (Cons k a (Cons j b as)) = Cons k a (Cons j b (RemDup as))

-- Type-level bubble sort on list
type family Bubble l where
            Bubble Nil                     = Nil
            Bubble (Cons k a Nil)          = Cons k a Nil
            Bubble (Cons j a (Cons k b c)) = Cons (MinKey j k j k) (MinKey j k a b) 
                                               (Bubble (Cons (MaxKey j k j k) (MaxKey j k a b) c))

-- Return the minimum or maximum of two types which consistitue key-value pairs
type MinKey (a :: Symbol) (b :: Symbol) (p :: k) (q :: k) = Choose (CmpSymbol a b) p q
type MaxKey (a :: Symbol) (b :: Symbol) (p :: k) (q :: k) = Choose (CmpSymbol a b) q p

type family Choose (g :: Ordering) a b where
    Choose LT p q = p
    Choose EQ p q = p
    Choose GT p q = q

-- Indexed reader type

data IxReader s a = IxR { unIxR :: List s -> a }

-- Indexed monad instance

instance IxMonad IxReader where
    type Inv IxReader s t = Split s t (Union s t)

    type Unit IxReader = Nil
    type Plus IxReader s t = Union s t

    return x = IxR $ \Nil -> x
    (IxR e) >>= k = IxR $ \xs -> let (s, t) = split xs
                                 in (unIxR $ k (e s)) t

-- 'ask' monadic primitive

ask :: Proxy (k::Symbol) -> IxReader (Cons k a Nil) a
ask Proxy = IxR $ \(Cons Proxy a Nil) -> a

-- Split operation (with type level version)

class Split s t z where
   split :: List z -> (List s, List t)

instance Split Nil Nil Nil where
   split Nil = (Nil, Nil) 

instance Split (Cons k x xs) Nil (Cons k x xs) where
    split t = (t, Nil)

instance Split Nil (Cons k x xs) (Cons k x xs) where
   split t = (Nil, t)

instance Split (Cons k x Nil) (Cons k x Nil) (Cons k x Nil) where
   split (Cons Proxy x Nil) = (Cons Proxy x Nil, Cons Proxy x Nil)

instance Split xs ys zs => Split (Cons k x xs) (Cons k x ys) (Cons k x zs) where
   split (Cons k x zs) = let (xs', ys') = split zs
                         in (Cons k x xs', Cons k x ys')

instance (Split xs ys zs) => Split (Cons j x xs) (Cons k y ys) (Cons j x (Cons k y zs)) where
   split (Cons j x (Cons k y zs)) = let (xs', ys') = split zs
                                    in (Cons j x xs', Cons k y ys')

instance (Split xs ys zs) => Split (Cons j x xs) (Cons k y ys) (Cons k y (Cons j x zs)) where
   split (Cons j x (Cons k y zs)) = let (xs', ys') = split zs
                                    in (Cons k y xs', Cons j x ys')

foo :: IxReader (Cons "x" a (Cons "xs" [a] Nil)) [a]
foo = do x <- ask (Proxy::(Proxy "x"))
         xs <- ask (Proxy::(Proxy "xs"))
         return (x:xs)
