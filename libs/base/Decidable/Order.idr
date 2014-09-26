module Decidable.Order

import Decidable.Decidable
import Decidable.Equality

%access public

--------------------------------------------------------------------------------
-- Utility Lemmas
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Preorders, Posets, total Orders, Equivalencies, Congruencies
--------------------------------------------------------------------------------

class Preorder t (po : t -> t -> Type) where
  total transitive : (a : t) -> (b : t) -> (c : t) -> po a b -> po b c -> po a c
  total Reflexive : (a : t) -> po a a

class (Preorder t po) => Poset t (po : t -> t -> Type) where
  total antisymmetric : (a : t) -> (b : t) -> po a b -> po b a -> a = b

class (Poset t to) => Ordered t (to : t -> t -> Type) where
  total order : (a : t) -> (b : t) -> Either (to a b) (to b a)

class (Preorder t eq) => Equivalence t (eq : t -> t -> Type) where
  total symmetric : (a : t) -> (b : t) -> eq a b -> eq b a

class (Equivalence t eq) => Congruence t (f : t -> t) (eq : t -> t -> Type) where
  total congruent : (a : t) -> 
                    (b : t) -> 
                    eq a b -> 
                    eq (f a) (f b)

minimum : (Ordered t to) => t -> t -> t
minimum x y with (order x y)
  | Left _ = x
  | Right _ = y

maximum : (Ordered t to) => t -> t -> t
maximum x y with (order x y)
  | Left _ = y
  | Right _ = x

--------------------------------------------------------------------------------
-- Syntactic equivalence (=)
--------------------------------------------------------------------------------

instance Preorder t ((=) {A = t} {B = t}) where
  transitive a b c = trans {a = a} {b = b} {c = c}
  Reflexive a = Refl

instance Equivalence t ((=) {A = t} {B = t}) where
  symmetric a b prf = sym prf

instance Congruence t f ((=) {A = t} {B = t}) where
  congruent a b = cong {a = a} {b = b} {f = f}

--------------------------------------------------------------------------------
-- Natural numbers
--------------------------------------------------------------------------------

data NatLTE : Nat -> Nat -> Type where
  nEqn   : NatLTE n n
  nLTESm : NatLTE n m -> NatLTE n (S m)

total NatLTEIsTransitive : (m : Nat) -> (n : Nat) -> (o : Nat) ->
                           NatLTE m n -> NatLTE n o ->
                           NatLTE m o
NatLTEIsTransitive m n n      mLTEn (nEqn) = mLTEn
NatLTEIsTransitive m n (S o)  mLTEn (nLTESm nLTEo)
  = nLTESm (NatLTEIsTransitive m n o mLTEn nLTEo)

total NatLTEIsReflexive : (n : Nat) -> NatLTE n n
NatLTEIsReflexive _ = nEqn

instance Preorder Nat NatLTE where
  transitive = NatLTEIsTransitive
  Reflexive  = NatLTEIsReflexive

total NatLTEIsAntisymmetric : (m : Nat) -> (n : Nat) ->
                              NatLTE m n -> NatLTE n m -> m = n
NatLTEIsAntisymmetric n n nEqn nEqn = Refl
NatLTEIsAntisymmetric n m nEqn (nLTESm _) impossible
NatLTEIsAntisymmetric n m (nLTESm _) nEqn impossible
NatLTEIsAntisymmetric n m (nLTESm _) (nLTESm _) impossible

instance Poset Nat NatLTE where
  antisymmetric = NatLTEIsAntisymmetric

total zeroNeverGreater : {n : Nat} -> NatLTE (S n) Z -> _|_
zeroNeverGreater {n} (nLTESm _) impossible
zeroNeverGreater {n}  nEqn      impossible

total zeroAlwaysSmaller : {n : Nat} -> NatLTE Z n
zeroAlwaysSmaller {n = Z  } = nEqn
zeroAlwaysSmaller {n = S k} = nLTESm (zeroAlwaysSmaller {n = k}) 

total
nGTSm : {n : Nat} -> {m : Nat} -> (NatLTE n m -> _|_) -> NatLTE n (S m) -> _|_
nGTSm         disprf (nLTESm nLTEm) = FalseElim (disprf nLTEm)
nGTSm {n} {m} disprf (nEqn) impossible

total
decideNatLTE : (n : Nat) -> (m : Nat) -> Dec (NatLTE n m)
decideNatLTE    Z      Z  = Yes nEqn
decideNatLTE (S x)     Z  = No  zeroNeverGreater
decideNatLTE    x   (S y) with (decEq x (S y))
  | Yes eq      = rewrite eq in Yes nEqn
  | No _ with (decideNatLTE x y)
    | Yes nLTEm = Yes (nLTESm nLTEm)
    | No  nGTm  = No (nGTSm nGTm)

instance Decidable [Nat,Nat] NatLTE where
  decide = decideNatLTE

total
lte : (m : Nat) -> (n : Nat) -> Dec (NatLTE m n)
lte m n = decide {ts = [Nat,Nat]} {p = NatLTE} m n

total
shift : (m : Nat) -> (n : Nat) -> NatLTE m n -> NatLTE (S m) (S n)
shift Z      Z        _            = nEqn
shift Z     (S Z)     _            = nLTESm nEqn
shift Z     (S (S j)) _            = nLTESm (shift Z (S j) zeroAlwaysSmaller)
shift (S k)  Z        prf          = FalseElim (zeroNeverGreater prf)
shift (S k) (S k)     nEqn         = nEqn
shift (S k) (S j)     (nLTESm prf) = nLTESm (shift (S k) j prf)

instance Ordered Nat NatLTE where
  order Z      n = Left zeroAlwaysSmaller
  order m      Z = Right zeroAlwaysSmaller
  order (S k) (S j) with (order k j)
    order (S k) (S j) | Left  prf = Left  (shift k j prf)
    order (S k) (S j) | Right prf = Right (shift j k prf)

--------------------------------------------------------------------------------
-- Finite numbers
--------------------------------------------------------------------------------

using (k : Nat)
  data FinLTE : Fin k -> Fin k -> Type where
    FromNatPrf : {m : Fin k} -> {n : Fin k} -> NatLTE (finToNat m) (finToNat n) -> FinLTE m n

  instance Preorder (Fin k) FinLTE where
    transitive m n o (FromNatPrf p1) (FromNatPrf p2) = 
      FromNatPrf (NatLTEIsTransitive (finToNat m) (finToNat n) (finToNat o) p1 p2)
    Reflexive n = FromNatPrf (NatLTEIsReflexive (finToNat n))

  instance Poset (Fin k) FinLTE where
    antisymmetric m n (FromNatPrf p1) (FromNatPrf p2) =
      finToNatInjective m n (NatLTEIsAntisymmetric (finToNat m) (finToNat n) p1 p2)
  
  instance Decidable [Fin k, Fin k] FinLTE where
    decide m n with (decideNatLTE (finToNat m) (finToNat n))
      | Yes prf    = Yes (FromNatPrf prf)
      | No  disprf = No (\ (FromNatPrf prf) => disprf prf)

  instance Ordered (Fin k) FinLTE where
    order m n =
      either (Left . FromNatPrf) 
             (Right . FromNatPrf)
             (order (finToNat m) (finToNat n))

