import Lean
import Auto.Embedding.Lift
import Auto.Embedding.LCtx
import Auto.Lib.ExprExtra
import Auto.Lib.NatExtra
import Auto.Lib.IntExtra
import Auto.Lib.HEqExtra
import Auto.Lib.ListExtra
-- import Mathlib.Data.Real.Basic
-- import Mathlib.Data.BitVec.Defs
-- import Mathlib.Data.Int.Basic
import Auto.MathlibEmulator

-- Embedding Simply Typed Lambda Calculus into Dependent Type Theory
-- Simply Typed Lambda Calculus = HOL (without polymorphism)
namespace Auto.Embedding.Lam

/-- Interpreted sorts -/
inductive LamBaseSort
  | prop   : LamBaseSort             -- GLift `Prop`
  | bool   : LamBaseSort             -- GLift `Bool`
  | nat    : LamBaseSort             -- GLift `Nat`
  | int    : LamBaseSort             -- GLift `Int`
  | string : LamBaseSort             -- GLift `String`
  | real   : LamBaseSort             -- GLift `Real`
  | bv     : (n : Nat) → LamBaseSort -- GLift `BitVec n`
deriving Hashable, Inhabited, Lean.ToExpr

def LamBaseSort.reprPrec (b : LamBaseSort) (n : Nat) :=
  let str :=
    match b with
    | .prop => ".prop"
    | .bool => ".bool"
    | .nat  => ".nat"
    | .int  => ".int"
    | .string => ".string"
    | .real => ".real"
    | .bv n => s!".bv {n}"
  if n == 0 then
    f!"LamBaseSort." ++ str
  else
    f!"({str})"

instance : Repr LamBaseSort where
  reprPrec s n := s.reprPrec n

def LamBaseSort.toString : LamBaseSort → String
| .prop   => "Prop"
| .bool   => "Bool"
| .nat    => "Nat"
| .int    => "Int"
| .string => "String"
| .real   => "Real"
| .bv n   => s!"Bitvec {n}"

instance : ToString LamBaseSort where
  toString := LamBaseSort.toString

def LamBaseSort.beq : LamBaseSort → LamBaseSort → Bool
| .prop,   .prop => true
| .bool,   .bool => true
| .nat,    .nat  => true
| .int,    .int  => true
| .string, .string => true
| .real,   .real => true
| .bv n,   .bv m => n.beq m
| _,       _     => false

instance : BEq LamBaseSort where
  beq := LamBaseSort.beq

theorem LamBaseSort.beq_def {a b : LamBaseSort} : (a == b) = a.beq b := rfl

theorem LamBaseSort.beq_refl : {b : LamBaseSort} → (b.beq b) = true
| .prop   => rfl
| .bool   => rfl
| .nat    => rfl
| .int    => rfl
| .string => rfl
| .real   => rfl
| .bv n   => Nat.beq_refl' n

theorem LamBaseSort.eq_of_beq_eq_true {b₁ b₂ : LamBaseSort} : b₁.beq b₂ → b₁ = b₂ :=
  match b₁, b₂ with
  | .prop,   .prop   => fun _ => rfl
  | .bool,   .bool   => fun _ => rfl
  | .nat,    .nat    => fun _ => rfl
  | .int,    .int    => fun _ => rfl
  | .string, .string => fun _ => rfl
  | .real,   .real   => fun _ => rfl
  | .bv n,   .bv m   => fun H => Nat.eq_of_beq_eq_true H ▸ rfl
  | .prop,   .bool   => fun H => by cases H
  | .prop,   .nat    => fun H => by cases H
  | .prop,   .int    => fun H => by cases H
  | .prop,   .string => fun H => by cases H
  | .prop,   .real   => fun H => by cases H
  | .prop,   .bv m   => fun H => by cases H
  | .bool,   .prop   => fun H => by cases H
  | .bool,   .nat    => fun H => by cases H
  | .bool,   .int    => fun H => by cases H
  | .bool,   .string => fun H => by cases H
  | .bool,   .real   => fun H => by cases H
  | .bool,   .bv m   => fun H => by cases H
  | .nat,    .prop   => fun H => by cases H
  | .nat,    .bool   => fun H => by cases H
  | .nat,    .int    => fun H => by cases H
  | .nat,    .string => fun H => by cases H
  | .nat,    .real   => fun H => by cases H
  | .nat,    .bv m   => fun H => by cases H
  | .int,    .prop   => fun H => by cases H
  | .int,    .bool   => fun H => by cases H
  | .int,    .nat    => fun H => by cases H
  | .int,    .string => fun H => by cases H
  | .int,    .real   => fun H => by cases H
  | .int,    .bv m   => fun H => by cases H
  | .string, .prop   => fun H => by cases H
  | .string, .bool   => fun H => by cases H
  | .string, .nat    => fun H => by cases H
  | .string, .int    => fun H => by cases H
  | .string, .real   => fun H => by cases H
  | .string, .bv m   => fun H => by cases H
  | .real,   .prop   => fun H => by cases H
  | .real,   .bool   => fun H => by cases H
  | .real,   .nat    => fun H => by cases H
  | .real,   .int    => fun H => by cases H
  | .real,   .string => fun H => by cases H
  | .real,   .bv m   => fun H => by cases H
  | .bv n,   .prop   => fun H => by cases H
  | .bv n,   .bool   => fun H => by cases H
  | .bv n,   .nat    => fun H => by cases H
  | .bv n,   .int    => fun H => by cases H
  | .bv n,   .string => fun H => by cases H
  | .bv n,   .real   => fun H => by cases H

instance : LawfulBEq LamBaseSort where
  eq_of_beq := LamBaseSort.eq_of_beq_eq_true
  rfl := LamBaseSort.beq_refl

@[reducible] def LamBaseSort.interp.{u} : LamBaseSort → Type u
| .prop   => GLift Prop
| .bool   => GLift Bool
| .nat    => GLift Nat
| .int    => GLift Int
| .string => GLift String
| .real   => GLift Real
| .bv n   => GLift (Bitvec n)

inductive LamSort
| atom : Nat → LamSort
| base : LamBaseSort → LamSort
| func : LamSort → LamSort → LamSort
deriving Inhabited, Hashable, Lean.ToExpr

def LamSort.reprPrec (s : LamSort) (n : Nat) :=
  let str :=
    match s with
    | .atom n     => f!".atom {n}"
    | .base b     => f!".base {LamBaseSort.reprPrec b 1}"
    | .func s1 s2 => f!".func {LamSort.reprPrec s1 1} {LamSort.reprPrec s2 1}"
  if n == 0 then
    f!"Auto.Embedding.Lam.LamSort" ++ str
  else
    f!"({str})"

instance : Repr LamSort where
  reprPrec s n := s.reprPrec n 

def LamSort.toString : LamSort → String
| .atom n => s!"#{n}"
| .base b => s!"{b}"
| .func s1 s2 => s!"({LamSort.toString s1} → {LamSort.toString s2})"

instance : ToString LamSort where
  toString := LamSort.toString

def LamSort.beq : LamSort → LamSort → Bool
| .atom m,     .atom n     => m.beq n
| .base m,     .base n     => m.beq n
| .func m₁ n₁, .func m₂ n₂ => LamSort.beq m₁ m₂ && LamSort.beq n₁ n₂
| _,           _           => false

instance : BEq LamSort where
  beq := LamSort.beq

theorem LamSort.beq_def {x y : LamSort} : (x == y) = x.beq y := rfl

theorem LamSort.beq_refl : {a : LamSort} → (a.beq a) = true
| .atom m => Nat.beq_refl' m
| .base b => LamBaseSort.beq_refl
| .func m₁ n₁ => by rw [beq]; rw [LamSort.beq_refl (a:=m₁)]; rw [LamSort.beq_refl (a:=n₁)]; rfl

theorem LamSort.eq_of_beq_eq_true {a b : LamSort} : (a.beq b = true) → a = b :=
  match a, b with
  | .atom m,     .atom n     => fun H => Nat.eq_of_beq_eq_true H ▸ rfl
  | .base m,     .base n     => fun H => LamBaseSort.eq_of_beq_eq_true H ▸ rfl
  | .func m₁ n₁, .func m₂ n₂ => fun H => by
    unfold beq at H; revert H;
    match h₁ : beq m₁ m₂, h₂ : beq n₁ n₂ with
    | true,  true  =>
      intro _;
      let eq₁ := LamSort.eq_of_beq_eq_true h₁
      let eq₂ := LamSort.eq_of_beq_eq_true h₂
      rw [eq₁, eq₂]
    | true,  false => intro H; cases H
    | false, _     => intro H; cases H
  | .atom m,     .base n     => fun H => by cases H
  | .atom m,     .func m₁ n₁ => fun H => by cases H
  | .base m,     .atom n     => fun H => by cases H
  | .base m,     .func m₁ n₁ => fun H => by cases H
  | .func m₁ n₁, .atom n     => fun H => by cases H
  | .func m₁ n₁, .base n     => fun H => by cases H

instance : LawfulBEq LamSort where
  eq_of_beq := LamSort.eq_of_beq_eq_true
  rfl := LamSort.beq_refl

theorem LamSort.beq_eq_true_eq (a b : LamSort) : (a.beq b = true) = (a = b) :=
  propext <| Iff.intro eq_of_beq_eq_true (fun h => by subst h; apply beq_refl)

theorem LamSort.beq_eq_false_eq_ne (a b : LamSort) : (a.beq b = false) = (a ≠ b) := by
  cases h : a.beq b
  case true =>
    cases (eq_of_beq_eq_true h); apply propext (Iff.intro (fun h => by cases h) (fun _ => by contradiction))
  case false =>
    apply propext (Iff.intro (fun _ h' => by cases h'; rw [beq_refl] at h; cases h) (fun _ => rfl))

def LamSort.contains (s : LamSort) (sub : LamSort) : Bool :=
  match s with
  | .func argTy resTy => s.beq sub || argTy.contains sub || resTy.contains sub
  | s => s.beq sub

/-- Given `a` and `[ty₀, ty₁, ⋯, tyᵢ₋₁]`, return `ty₀ → ty₁ → ⋯ → tyᵢ₋₁ → a` -/
def LamSort.mkFuncs (a : LamSort) (tys : List LamSort) : LamSort :=
  tys.foldr (fun s cur => .func s cur) a

theorem LamSort.mkFuncs_nil : LamSort.mkFuncs a .nil = a := rfl

theorem LamSort.mkFuncs_singleton : LamSort.mkFuncs a [ty] = .func ty a := rfl

theorem LamSort.mkFuncs_cons : LamSort.mkFuncs a (ty :: tys) = .func ty (.mkFuncs a tys) := rfl

theorem LamSort.mkFuncs_append : LamSort.mkFuncs a (tys₁ ++ tys₂) = .mkFuncs (.mkFuncs a tys₂) tys₁ := by
  induction tys₁
  case nil => rfl
  case cons ty₁ tys₁ IH =>
    rw [List.cons_append, mkFuncs_cons, mkFuncs_cons, IH]

theorem LamSort.mkFuncs_append_singleton : LamSort.mkFuncs a (tys ++ [ty]) = .mkFuncs (.func ty a) tys := by
  rw [LamSort.mkFuncs_append, LamSort.mkFuncs_singleton]

/-- Given `a` and `[ty₀, ty₁, ⋯, tyᵢ₋₁]`, return `tyᵢ₋₁ → ⋯ → ty₁ → ty₀ → a` -/
def LamSort.mkFuncsRev (a : LamSort) (tys : List LamSort) : LamSort :=
  tys.foldl (fun cur s => .func s cur) a

theorem LamSort.mkFuncsRev_nil : LamSort.mkFuncsRev a .nil = a := rfl

theorem LamSort.mkFuncsRev_cons : LamSort.mkFuncsRev a (ty :: tys) = .mkFuncsRev (.func ty a) tys := rfl

theorem LamSort.mkFuncsRev_eq : LamSort.mkFuncsRev a tys = LamSort.mkFuncs a tys.reverse := by
  induction tys generalizing a
  case nil => rfl
  case cons ty tys IH =>
    rw [mkFuncsRev_cons, List.reverse_cons, mkFuncs_append_singleton, IH]

theorem LamSort.mkFuncs_eq : LamSort.mkFuncs a tys = LamSort.mkFuncsRev a tys.reverse := by
  conv => enter [1, 2]; rw [← List.reverse_reverse tys]
  apply Eq.symm mkFuncsRev_eq

/-- Given `ty₀ → ty₁ → ⋯ → tyᵢ₋₁ → a`, return `[ty₀, ty₁, ⋯, tyᵢ₋₁]` -/
def LamSort.getArgTys : LamSort → List LamSort
| .atom _ => .nil
| .base _ => .nil
| .func argTy resTy => argTy :: getArgTys resTy

/-- Given `ty₀ → ty₁ → ⋯ → tyᵢ₋₁ → a`, return `a` -/
def LamSort.getResTy : LamSort → LamSort
| .atom n => .atom n
| .base b => .base b
| .func _ resTy => resTy.getResTy

theorem LamSort.getArgTys_getResTy_eq :
  {s : LamSort} → .mkFuncs s.getResTy s.getArgTys = s
| .atom _ => rfl
| .base _ => rfl
| .func _ resTy => congrArg _ (@getArgTys_getResTy_eq resTy)

/-- Given `ty₀ → ty₁ → ⋯ → tyₙ₋₁ → a`, return `[ty₀, ty₁, ⋯, tyₙ₋₁]` -/
def LamSort.getArgTysN (n : Nat) (s : LamSort) : Option (List LamSort) :=
  match n with
  | .zero => .some .nil
  | .succ n =>
    match s with
    | .func argTy resTy => (getArgTysN n resTy).bind (argTy :: ·)
    | _ => .none

/-- Given `ty₀ → ty₁ → ⋯ → tyₙ₋₁ → a`, return `a` -/
def LamSort.getResTyN (n : Nat) (s : LamSort) : Option LamSort :=
  match n with
  | .zero => s
  | .succ n =>
    match s with
    | .func _ resTy => getResTyN n resTy
    | _ => .none

theorem LamSort.getArgTysN_getResTysN_eq_some :
  (getArgTysN n s).isSome = (getResTyN n s).isSome := by
  induction n generalizing s
  case zero => rfl
  case succ n IH =>
    dsimp [getArgTysN, getResTyN]; cases s <;> try rfl
    case func argTy resTy =>
      have IH' := @IH resTy; dsimp
      cases h₁ : getArgTysN n resTy <;> rw [h₁] at IH' <;> dsimp at IH'
        <;> cases h₂ : getResTyN n resTy <;> rw [h₂] at IH' <;> cases IH' <;> rfl

theorem LamSort.getArgTysN_eq_some_of_getResTysN_eq_some
  (heq : getResTyN n s = .some resTy) : ∃ l, getArgTysN n s = .some l := by
  apply Option.isSome_iff_exists.mp; rw [getArgTysN_getResTysN_eq_some]
  apply Option.isSome_iff_exists.mpr; exists resTy

theorem LamSort.getResTysN_eq_some_of_getArgTysN_eq_some
  (heq : getArgTysN n s = .some l) : ∃ resTy, getResTyN n s = .some resTy := by
  apply Option.isSome_iff_exists.mp; rw [← getArgTysN_getResTysN_eq_some]
  apply Option.isSome_iff_exists.mpr; exists l

theorem LamSort.getArgTysN_getResTysN_eq_none :
  (getArgTysN n s).isNone = (getResTyN n s).isNone := by
  rw [Option.isNone_eq_not_isSome, Option.isNone_eq_not_isSome]
  rw [getArgTysN_getResTysN_eq_some]

theorem LamSort.getArgTysN_getResTyN_eq
  (hArg : getArgTysN n s = .some l) (hRes : getResTyN n s = .some s') :
  s = s'.mkFuncs l := by
  induction n generalizing s s' l
  case zero =>
    cases hArg; cases hRes; rfl
  case succ n IH =>
    cases s <;> try cases hArg
    case func argTy resTy =>
      dsimp [getArgTysN] at hArg; dsimp [getResTyN] at hRes
      cases h₁ : getArgTysN n resTy <;> rw [h₁] at hArg <;> cases hArg
      case refl l' =>
        dsimp [mkFuncs]; apply congrArg; apply IH h₁ hRes

theorem LamSort.getArgTysN_mkFuncs_eq_l_iff :
  getArgTysN n (mkFuncs s l) = some l ↔ l.length = n := by
  induction n generalizing s l
  case zero =>
    dsimp [getArgTysN]; apply Iff.intro
    case mp => intro h; cases h; rfl
    case mpr => intro h; cases l <;> cases h; rfl
  case succ n IH =>
    dsimp [getArgTysN]; cases l
    case nil =>
      dsimp [mkFuncs]; apply Iff.intro
      case mp =>
        cases s <;> intro h <;> try cases h
        case func argTy resTy =>
          dsimp at h; cases h₁ : getArgTysN n resTy <;> rw [h₁] at h <;> cases h
      case mpr =>
        intro h; cases h
    case cons s' l =>
      rw [mkFuncs_cons]; dsimp; cases h₁ : getArgTysN n (mkFuncs s l)
      case none => simp; intro h; rw [IH.mpr h] at h₁; cases h₁
      case some l' =>
        simp; apply Iff.intro
        case mp => intro h; cases h; apply IH.mp h₁
        case mpr => intro h; have h₂ := (IH (s:=s)).mpr h; rw [h₁] at h₂; cases h₂; rfl

@[reducible] def LamSort.interp.{u} (val : Nat → Type u) : LamSort → Type u
| .atom n => val n
| .base b => b.interp
| .func dom cod => interp val dom → interp val cod

def LamSort.curry (f : HList (LamSort.interp tyVal) tys → LamSort.interp tyVal s) :
  LamSort.interp tyVal (s.mkFuncs tys) :=
  match tys with
  | .nil => f .nil
  | .cons _ _ => fun x => LamSort.curry (fun xs => f (.cons x xs))

def LamSort.curryRev (f : HList (LamSort.interp tyVal) tys → LamSort.interp tyVal s) :
  LamSort.interp tyVal (s.mkFuncsRev tys) :=
  match tys with
  | .nil => f .nil
  | .cons _ tys => LamSort.curryRev (tys:=tys) (fun xs x => f (.cons x xs))

inductive BoolConst
  | trueb  -- Boolean `true`
  | falseb -- Boolean `false`
  | notb   -- Boolean `not`
  | andb   -- Boolean `and`
  | orb    -- Boolean `or`
deriving Inhabited, Hashable, Lean.ToExpr

def BoolConst.reprPrec (b : BoolConst) (n : Nat) :=
  let s :=
    match b with
    | .trueb      => f!".trueb"
    | .falseb     => f!".falseb"
    | .notb       => f!".notb"
    | .andb       => f!".andb"
    | .orb        => f!".orb"
  if n == 0 then
    f!"Auto.Embedding.Lam.BoolConst" ++ s
  else
    f!"({s})"

instance : Repr BoolConst where
  reprPrec := BoolConst.reprPrec

def BoolConst.toString : BoolConst → String
| .trueb  => "true"
| .falseb => "false"
| .notb   => "!"
| .andb   => "&&"
| .orb    => "||"

instance : ToString BoolConst where
  toString := BoolConst.toString

def BoolConst.beq : BoolConst → BoolConst → Bool
| .trueb,  .trueb  => true
| .falseb, .falseb => true
| .notb,   .notb   => true
| .andb,   .andb   => true
| .orb,    .orb    => true
| _,       _       => false

instance : BEq BoolConst where
  beq := BoolConst.beq

def BoolConst.beq_refl {b : BoolConst} : (b.beq b) = true := by
  cases b <;> rfl

def BoolConst.eq_of_beq_eq_true {b₁ b₂ : BoolConst} (H : b₁.beq b₂) : b₁ = b₂ := by
  cases b₁ <;> cases b₂ <;> first | contradiction | rfl

instance : LawfulBEq BoolConst where
  eq_of_beq := BoolConst.eq_of_beq_eq_true
  rfl := BoolConst.beq_refl

def BoolConst.lamCheck : BoolConst → LamSort
| .trueb => .base .bool
| .falseb => .base .bool
| .notb => .func (.base .bool) (.base .bool)
| .andb => .func (.base .bool) (.func (.base .bool) (.base .bool))
| .orb => .func (.base .bool) (.func (.base .bool) (.base .bool))

inductive BoolConst.LamWF : BoolConst → LamSort → Type
  | ofTrueB      : LamWF .trueb (.base .bool)
  | ofFalseB     : LamWF .falseb (.base .bool)
  | ofNotB       : LamWF .notb (.func (.base .bool) (.base .bool))
  | ofAndB       : LamWF .andb (.func (.base .bool) (.func (.base .bool) (.base .bool)))
  | ofOrB        : LamWF .orb (.func (.base .bool) (.func (.base .bool) (.base .bool)))

def BoolConst.LamWF.unique {b : BoolConst} {s₁ s₂ : LamSort}
  (bcwf₁ : LamWF b s₁) (bcwf₂ : LamWF b s₂) : s₁ = s₂ ∧ HEq bcwf₁ bcwf₂ := by
  cases bcwf₁ <;> cases bcwf₂ <;> trivial

def BoolConst.LamWF.ofBoolConst : (b : BoolConst) → (s : LamSort) × BoolConst.LamWF b s
| .trueb      => ⟨.base .bool, .ofTrueB⟩
| .falseb     => ⟨.base .bool, .ofFalseB⟩
| .notb       => ⟨.func (.base .bool) (.base .bool), .ofNotB⟩
| .andb       => ⟨.func (.base .bool) (.func (.base .bool) (.base .bool)), .ofAndB⟩
| .orb        => ⟨.func (.base .bool) (.func (.base .bool) (.base .bool)), .ofOrB⟩

def BoolConst.lamWF_complete (wf : LamWF b s) : LamWF.ofBoolConst b = ⟨s, wf⟩ := by
  cases wf <;> rfl

def BoolConst.lamCheck_of_LamWF (H : LamWF b s) : b.lamCheck = s := by
  cases H <;> rfl

def BoolConst.LamWF.ofCheck (H : b.lamCheck = s) : LamWF b s := by
  cases H; cases b <;> constructor

inductive NatConst
  | natVal (n : Nat)
  | nadd
  | nsub
  | nmul
  | ndiv
  | nmod
  | nle
  | nge
  | nlt
  | ngt
deriving Inhabited, Hashable, Lean.ToExpr

def NatConst.reprPrec (nc : NatConst) (n : Nat) :=
  let s :=
    match nc with
    | .natVal n => f!".intVal {n}"
    | .nadd     => f!".nadd"
    | .nsub     => f!".nsub"
    | .nmul     => f!".nmul"
    | .ndiv     => f!".ndiv"
    | .nmod     => f!".nmod"
    | .nle      => f!".nle"
    | .nge      => f!".nge"
    | .nlt      => f!".nlt"
    | .ngt      => f!".ngt"
  if n == 0 then
    f!"Auto.Embedding.Lam.NatConst" ++ s
  else
    f!"({s})"

instance : Repr NatConst where
  reprPrec := NatConst.reprPrec

def NatConst.toString : NatConst → String
| .natVal n => s!"{n} : Nat"
| .nadd     => "+"
| .nsub     => "-"
| .nmul     => "*"
| .ndiv     => "/"
| .nmod     => "%"
| .nle      => "≤"
| .nge      => "≥"
| .nlt      => "<"
| .ngt      => ">"

instance : ToString NatConst where
  toString := NatConst.toString

def NatConst.beq : NatConst → NatConst → Bool
| .natVal n, .natVal m => Nat.beq n m
| .nadd,     .nadd  => true
| .nsub,     .nsub  => true
| .nmul,     .nmul  => true
| .ndiv,     .ndiv  => true
| .nmod,     .nmod  => true
| .nle,      .nle   => true
| .nge,      .nge   => true
| .nlt,      .nlt   => true
| .ngt,      .ngt   => true
| _,         _      => false

instance : BEq NatConst where
  beq := NatConst.beq

def NatConst.beq_refl {n : NatConst} : (n.beq n) = true := by
  cases n <;> first | rfl | apply Nat.beq_refl

def NatConst.eq_of_beq_eq_true {n₁ n₂ : NatConst} (H : n₁.beq n₂) : n₁ = n₂ := by
  cases n₁ <;> cases n₂ <;> try (first | contradiction | rfl)
  case natVal.natVal n m => apply congrArg; apply Nat.eq_of_beq_eq_true H

instance : LawfulBEq NatConst where
  eq_of_beq := NatConst.eq_of_beq_eq_true
  rfl := NatConst.beq_refl

def NatConst.lamCheck : NatConst → LamSort
| .natVal _ => .base .nat
| .nadd     => .func (.base .nat) (.func (.base .nat) (.base .nat))
| .nsub     => .func (.base .nat) (.func (.base .nat) (.base .nat))
| .nmul     => .func (.base .nat) (.func (.base .nat) (.base .nat))
| .ndiv     => .func (.base .nat) (.func (.base .nat) (.base .nat))
| .nmod     => .func (.base .nat) (.func (.base .nat) (.base .nat))
| .nle      => .func (.base .nat) (.func (.base .nat) (.base .prop))
| .nge      => .func (.base .nat) (.func (.base .nat) (.base .prop))
| .nlt      => .func (.base .nat) (.func (.base .nat) (.base .prop))
| .ngt      => .func (.base .nat) (.func (.base .nat) (.base .prop))

inductive NatConst.LamWF : NatConst → LamSort → Type
  | ofNatVal n : LamWF (.natVal n) (.base .nat)
  | ofNadd     : LamWF .nadd (.func (.base .nat) (.func (.base .nat) (.base .nat)))
  | ofNsub     : LamWF .nsub (.func (.base .nat) (.func (.base .nat) (.base .nat)))
  | ofNmul     : LamWF .nmul (.func (.base .nat) (.func (.base .nat) (.base .nat)))
  | ofNdiv     : LamWF .ndiv (.func (.base .nat) (.func (.base .nat) (.base .nat)))
  | ofNmod     : LamWF .nmod (.func (.base .nat) (.func (.base .nat) (.base .nat)))
  | ofNle      : LamWF .nle (.func (.base .nat) (.func (.base .nat) (.base .prop)))
  | ofNge      : LamWF .nge (.func (.base .nat) (.func (.base .nat) (.base .prop)))
  | ofNlt      : LamWF .nlt (.func (.base .nat) (.func (.base .nat) (.base .prop)))
  | ofNgt      : LamWF .ngt (.func (.base .nat) (.func (.base .nat) (.base .prop)))

def NatConst.LamWF.unique {n : NatConst} {s₁ s₂ : LamSort}
  (nwf₁ : LamWF n s₁) (nwf₂ : LamWF n s₂) : s₁ = s₂ ∧ HEq nwf₁ nwf₂ := by
  cases nwf₁ <;> cases nwf₂ <;> trivial

def NatConst.LamWF.ofNatConst : (n : NatConst) → (s : LamSort) × NatConst.LamWF n s
| .natVal n => ⟨.base .nat, .ofNatVal n⟩
| .nadd     => ⟨.func (.base .nat) (.func (.base .nat) (.base .nat)), .ofNadd⟩
| .nsub     => ⟨.func (.base .nat) (.func (.base .nat) (.base .nat)), .ofNsub⟩
| .nmul     => ⟨.func (.base .nat) (.func (.base .nat) (.base .nat)), .ofNmul⟩
| .ndiv     => ⟨.func (.base .nat) (.func (.base .nat) (.base .nat)), .ofNdiv⟩
| .nmod     => ⟨.func (.base .nat) (.func (.base .nat) (.base .nat)), .ofNmod⟩
| .nle      => ⟨.func (.base .nat) (.func (.base .nat) (.base .prop)), .ofNle⟩
| .nge      => ⟨.func (.base .nat) (.func (.base .nat) (.base .prop)), .ofNge⟩
| .nlt      => ⟨.func (.base .nat) (.func (.base .nat) (.base .prop)), .ofNlt⟩
| .ngt      => ⟨.func (.base .nat) (.func (.base .nat) (.base .prop)), .ofNgt⟩

def NatConst.lamWF_complete (wf : LamWF n s) : LamWF.ofNatConst n = ⟨s, wf⟩ := by
  cases wf <;> rfl

def NatConst.lamCheck_of_LamWF (H : LamWF n s) : n.lamCheck = s := by
  cases H <;> rfl

def NatConst.LamWF.ofCheck (H : n.lamCheck = s) : LamWF n s := by
  cases H; cases n <;> constructor

inductive IntConst
  | intVal (n : Int)
  | ineg
  | iabs
  | iadd
  | isub
  | imul
  | idiv
  | imod
  | iediv
  | iemod
  | ile
  | ige
  | ilt
  | igt
deriving Inhabited, Hashable, Lean.ToExpr

def IntConst.reprPrec (i : IntConst) (n : Nat) :=
  let s :=
    match i with
    | .intVal n => f!".intVal {n}"
    | .ineg     => f!".ineg"
    | .iabs     => f!".iabs"
    | .iadd     => f!".iadd"
    | .isub     => f!".isub"
    | .imul     => f!".imul"
    | .idiv     => f!".idiv"
    | .imod     => f!".imod"
    | .iediv    => f!".iediv"
    | .iemod    => f!".iemod"
    | .ile      => f!".ile"
    | .ige      => f!".ige"
    | .ilt      => f!".ilt"
    | .igt      => f!".igt"
  if n == 0 then
    f!"Auto.Embedding.Lam.IntConst" ++ s
  else
    f!"({s})"

instance : Repr IntConst where
  reprPrec := IntConst.reprPrec

def IntConst.toString : IntConst → String
| .intVal n => s!"{n} : Int"
| .ineg     => "-"
| .iabs     => "iabs"
| .iadd     => "+"
| .isub     => "-"
| .imul     => "*"
| .idiv     => "/"
| .imod     => "%"
| .iediv    => "/?"
| .iemod    => "%?"
| .ile      => "≤"
| .ige      => "≥"
| .ilt      => "<"
| .igt      => ">"

instance : ToString IntConst where
  toString := IntConst.toString

def IntConst.beq : IntConst → IntConst → Bool
| .intVal n, .intVal m => Int.beq n m
| .ineg,     .ineg  => true
| .iabs,     .iabs  => true
| .iadd,     .iadd  => true
| .isub,     .isub  => true
| .imul,     .imul  => true
| .idiv,     .idiv  => true
| .imod,     .imod  => true
| .iediv,    .iediv => true
| .iemod,    .iemod => true
| .ile,      .ile   => true
| .ige,      .ige   => true
| .ilt,      .ilt   => true
| .igt,      .igt   => true
| _,         _      => false

instance : BEq IntConst where
  beq := IntConst.beq

def IntConst.beq_refl {i : IntConst} : (i.beq i) = true := by
  cases i <;> first | rfl | apply Int.beq_refl

def IntConst.eq_of_beq_eq_true {i₁ i₂ : IntConst} (H : i₁.beq i₂) : i₁ = i₂ := by
  cases i₁ <;> cases i₂ <;> try (first | contradiction | rfl)
  case intVal.intVal n m => apply congrArg; apply Int.eq_of_beq_eq_true H

instance : LawfulBEq IntConst where
  eq_of_beq := IntConst.eq_of_beq_eq_true
  rfl := IntConst.beq_refl

def IntConst.lamCheck : IntConst → LamSort
| .intVal _ => .base .int
| .ineg     => .func (.base .int) (.base .int)
| .iabs     => .func (.base .int) (.base .int)
| .iadd     => .func (.base .int) (.func (.base .int) (.base .int))
| .isub     => .func (.base .int) (.func (.base .int) (.base .int))
| .imul     => .func (.base .int) (.func (.base .int) (.base .int))
| .idiv     => .func (.base .int) (.func (.base .int) (.base .int))
| .imod     => .func (.base .int) (.func (.base .int) (.base .int))
| .iediv     => .func (.base .int) (.func (.base .int) (.base .int))
| .iemod     => .func (.base .int) (.func (.base .int) (.base .int))
| .ile      => .func (.base .int) (.func (.base .int) (.base .prop))
| .ige      => .func (.base .int) (.func (.base .int) (.base .prop))
| .ilt      => .func (.base .int) (.func (.base .int) (.base .prop))
| .igt      => .func (.base .int) (.func (.base .int) (.base .prop))

inductive IntConst.LamWF : IntConst → LamSort → Type
  | ofIntVal n : LamWF (.intVal n) (.base .int)
  | ofIneg     : LamWF .ineg (.func (.base .int) (.base .int))
  | ofIabs     : LamWF .iabs (.func (.base .int) (.base .int))
  | ofIadd     : LamWF .iadd (.func (.base .int) (.func (.base .int) (.base .int)))
  | ofIsub     : LamWF .isub (.func (.base .int) (.func (.base .int) (.base .int)))
  | ofImul     : LamWF .imul (.func (.base .int) (.func (.base .int) (.base .int)))
  | ofIdiv     : LamWF .idiv (.func (.base .int) (.func (.base .int) (.base .int)))
  | ofImod     : LamWF .imod (.func (.base .int) (.func (.base .int) (.base .int)))
  | ofIediv    : LamWF .iediv (.func (.base .int) (.func (.base .int) (.base .int)))
  | ofIemod    : LamWF .iemod (.func (.base .int) (.func (.base .int) (.base .int)))
  | ofIle      : LamWF .ile (.func (.base .int) (.func (.base .int) (.base .prop)))
  | ofIge      : LamWF .ige (.func (.base .int) (.func (.base .int) (.base .prop)))
  | ofIlt      : LamWF .ilt (.func (.base .int) (.func (.base .int) (.base .prop)))
  | ofIgt      : LamWF .igt (.func (.base .int) (.func (.base .int) (.base .prop)))

def IntConst.LamWF.unique {i : IntConst} {s₁ s₂ : LamSort}
  (iwf₁ : LamWF i s₁) (iwf₂ : LamWF i s₂) : s₁ = s₂ ∧ HEq iwf₁ iwf₂ := by
  cases iwf₁ <;> cases iwf₂ <;> trivial

def IntConst.LamWF.ofIntConst : (i : IntConst) → (s : LamSort) × IntConst.LamWF i s
| .intVal n => ⟨.base .int, .ofIntVal n⟩
| .ineg     => ⟨.func (.base .int) (.base .int), .ofIneg⟩
| .iabs     => ⟨.func (.base .int) (.base .int), .ofIabs⟩
| .iadd     => ⟨.func (.base .int) (.func (.base .int) (.base .int)), .ofIadd⟩
| .isub     => ⟨.func (.base .int) (.func (.base .int) (.base .int)), .ofIsub⟩
| .imul     => ⟨.func (.base .int) (.func (.base .int) (.base .int)), .ofImul⟩
| .idiv     => ⟨.func (.base .int) (.func (.base .int) (.base .int)), .ofIdiv⟩
| .imod     => ⟨.func (.base .int) (.func (.base .int) (.base .int)), .ofImod⟩
| .iediv    => ⟨.func (.base .int) (.func (.base .int) (.base .int)), .ofIediv⟩
| .iemod    => ⟨.func (.base .int) (.func (.base .int) (.base .int)), .ofIemod⟩
| .ile      => ⟨.func (.base .int) (.func (.base .int) (.base .prop)), .ofIle⟩
| .ige      => ⟨.func (.base .int) (.func (.base .int) (.base .prop)), .ofIge⟩
| .ilt      => ⟨.func (.base .int) (.func (.base .int) (.base .prop)), .ofIlt⟩
| .igt      => ⟨.func (.base .int) (.func (.base .int) (.base .prop)), .ofIgt⟩

def IntConst.lamWF_complete (wf : LamWF i s) : LamWF.ofIntConst i = ⟨s, wf⟩ := by
  cases wf <;> rfl

def IntConst.lamCheck_of_LamWF (H : LamWF i s) : i.lamCheck = s := by
  cases H <;> rfl

def IntConst.LamWF.ofCheck (H : i.lamCheck = s) : LamWF i s := by
  cases H; cases i <;> constructor

inductive StringConst
  | strVal (s : String)
  | sapp
  | sle
  | sge
  | slt
  | sgt
deriving Inhabited, Hashable, Lean.ToExpr

def StringConst.reprPrec (sc : StringConst) (n : Nat) :=
  let s :=
    match sc with
    | strVal s => f!".strVal {s}"
    | sapp => f!".sapp"
    | sle => f!".sle"
    | sge => f!".sge"
    | slt => f!".slt"
    | sgt => f!".sgt"
  if n == 0 then
    f!"Auto.Embedding.Lam.StrConst" ++ s
  else
    f!"({s})"

instance : Repr StringConst where
  reprPrec := StringConst.reprPrec

def StringConst.toString : StringConst → String
| .strVal s => s!"({s} : String)"
| .sapp => "++"
| .sle => "≤"
| .sge => "≥"
| .slt => "<"
| .sgt => ">"

instance : ToString StringConst where
  toString := StringConst.toString

def StringConst.beq : StringConst → StringConst → Bool
| .strVal m, .strVal n => m == n
| .sapp,     .sapp     => true
| .sle,      .sle      => true
| .sge,      .sge      => true
| .slt,      .slt      => true
| .sgt,      .sgt      => true
| _,         _         => false

instance : BEq StringConst where
  beq := StringConst.beq

def StringConst.beq_refl {s : StringConst} : (s.beq s) = true := by
  cases s <;> try rfl
  case strVal s => apply LawfulBEq.rfl (α := String)

def StringConst.eq_of_beq_eq_true {s₁ s₂ : StringConst} (H : s₁.beq s₂) : s₁ = s₂ := by
  cases s₁ <;> cases s₂ <;> try (first | contradiction | rfl)
  case strVal.strVal n m => apply congrArg; apply LawfulBEq.eq_of_beq (α := String) H

instance : LawfulBEq StringConst where
  eq_of_beq := StringConst.eq_of_beq_eq_true
  rfl := StringConst.beq_refl

def StringConst.lamCheck : StringConst → LamSort
| strVal _ => .base .string
| sapp     => .func (.base .string) (.func (.base .string) (.base .string))
| sle      => .func (.base .string) (.func (.base .string) (.base .prop))
| sge      => .func (.base .string) (.func (.base .string) (.base .prop))
| slt      => .func (.base .string) (.func (.base .string) (.base .prop))
| sgt      => .func (.base .string) (.func (.base .string) (.base .prop))

inductive StringConst.LamWF : StringConst → LamSort → Type
  | ofStrVal s : LamWF (.strVal s) (.base .string)
  | ofSapp     : LamWF .sapp (.func (.base .string) (.func (.base .string) (.base .string)))
  | ofSle      : LamWF .sle (.func (.base .string) (.func (.base .string) (.base .prop)))
  | ofSge      : LamWF .sge (.func (.base .string) (.func (.base .string) (.base .prop)))
  | ofSlt      : LamWF .slt (.func (.base .string) (.func (.base .string) (.base .prop)))
  | ofSgt      : LamWF .sgt (.func (.base .string) (.func (.base .string) (.base .prop)))

def StringConst.LamWF.unique {s : StringConst} {s₁ s₂ : LamSort}
  (iwf₁ : LamWF s s₁) (iwf₂ : LamWF s s₂) : s₁ = s₂ ∧ HEq iwf₁ iwf₂ := by
  cases iwf₁ <;> cases iwf₂ <;> trivial

def StringConst.LamWF.ofStringConst : (sc : StringConst) → (s : LamSort) × StringConst.LamWF sc s
| .strVal s => ⟨.base .string, .ofStrVal s⟩
| .sapp     => ⟨.func (.base .string) (.func (.base .string) (.base .string)), .ofSapp⟩
| .sle      => ⟨.func (.base .string) (.func (.base .string) (.base .prop)), .ofSle⟩
| .sge      => ⟨.func (.base .string) (.func (.base .string) (.base .prop)), .ofSge⟩
| .slt      => ⟨.func (.base .string) (.func (.base .string) (.base .prop)), .ofSlt⟩
| .sgt      => ⟨.func (.base .string) (.func (.base .string) (.base .prop)), .ofSgt⟩

def StringConst.lamWF_complete (wf : LamWF sc s) : LamWF.ofStringConst sc = ⟨s, wf⟩ := by
  cases wf <;> rfl

def StringConst.lamCheck_of_LamWF (H : LamWF sc s) : sc.lamCheck = s := by
  cases H <;> rfl

def StringConst.LamWF.ofCheck (H : sc.lamCheck = s) : LamWF sc s := by
  cases H; cases sc <;> constructor

/--
  Interpreted constants
  Note that `eq`, `forallE`, `existE` have `ilVal/lamILTy`
    associated with them. During proof reconstruction, we should collect
    the sort arguments of all `eq, forallE, existE` that occurs in the
    proof into `ilVal`.
  For `ilVal`, we need to use `ILLift.ofIsomTy` to construct
    `ILLift` structures. The idea is that we want the interpretation
    of reified assumptions to be definitionally
    equal to the assumption (or `GLift.up` applied to the assumption, to
    be precise), so we'll have to use the specially designed
    `of(Eq/Forall/Exist)Lift` function.
  Note that at the end of the proof, we'll have a `LamTerm.base .falseE`,
    no `=, ∀, ∃` left, so whatever `(Eq/Forall/Exist)Lift`
    structure are within the `(eq/forall/lam)Val`, the final result
    will always interpret to `GLift.up False`.
-/
inductive LamBaseTerm
  | trueE    : LamBaseTerm -- Propositional `true`
  | falseE   : LamBaseTerm -- Propositional `false`
  | not      : LamBaseTerm -- Propositional `not`
  | and      : LamBaseTerm -- Propositional `and`
  | or       : LamBaseTerm -- Propositional `or`
  | imp      : LamBaseTerm -- Propositional `imp`
  | iff      : LamBaseTerm -- Propositional `iff`
  | bcst     : BoolConst → LamBaseTerm
  | ncst     : NatConst → LamBaseTerm
  | icst     : IntConst → LamBaseTerm
  | scst     : StringConst → LamBaseTerm
  | bvVal    : List Bool → LamBaseTerm
  -- Versions of `eq, ∀, ∃` when we're importing external facts
  -- Note that the [import versions] of `eq, ∀, ∃` should only be used when
  --   we're importing external facts. When facts are imported, we call
  --   `resolveImport` on them and these [import versions] are turned into
  --   [non-import versions]
  | eqI      : Nat → LamBaseTerm
  | forallEI : Nat → LamBaseTerm
  | existEI  : Nat → LamBaseTerm
  -- Non-import versions of `eq, ∀, ∃`
  | eq       : LamSort → LamBaseTerm
  | forallE  : LamSort → LamBaseTerm
  | existE   : LamSort → LamBaseTerm
deriving Inhabited, Hashable, Lean.ToExpr

def LamBaseTerm.trueb' := LamBaseTerm.bcst .trueb

def LamBaseTerm.falseb' := LamBaseTerm.bcst .falseb

def LamBaseTerm.notb' := LamBaseTerm.bcst .notb

def LamBaseTerm.andb' := LamBaseTerm.bcst .andb

def LamBaseTerm.orb' := LamBaseTerm.bcst .orb

def LamBaseTerm.natVal' (n : Nat) := LamBaseTerm.ncst (.natVal n)

def LamBaseTerm.nadd' := LamBaseTerm.ncst .nadd

def LamBaseTerm.nsub' := LamBaseTerm.ncst .nsub

def LamBaseTerm.nmul' := LamBaseTerm.ncst .nmul

def LamBaseTerm.ndiv' := LamBaseTerm.ncst .ndiv

def LamBaseTerm.nmod' := LamBaseTerm.ncst .nmod

def LamBaseTerm.nle' := LamBaseTerm.ncst .nle

def LamBaseTerm.nlt' := LamBaseTerm.ncst .nlt

def LamBaseTerm.nge' := LamBaseTerm.ncst .nge

def LamBaseTerm.ngt' := LamBaseTerm.ncst .ngt

def LamBaseTerm.intVal' (i : Int) := LamBaseTerm.icst (.intVal i)

def LamBaseTerm.ineg' := LamBaseTerm.icst .ineg

def LamBaseTerm.iabs' := LamBaseTerm.icst .iabs

def LamBaseTerm.iadd' := LamBaseTerm.icst .iadd

def LamBaseTerm.isub' := LamBaseTerm.icst .isub

def LamBaseTerm.imul' := LamBaseTerm.icst .imul

def LamBaseTerm.idiv' := LamBaseTerm.icst .idiv

def LamBaseTerm.imod' := LamBaseTerm.icst .imod

def LamBaseTerm.iediv' := LamBaseTerm.icst .iediv

def LamBaseTerm.iemod' := LamBaseTerm.icst .iemod

def LamBaseTerm.ile' := LamBaseTerm.icst .ile

def LamBaseTerm.ilt' := LamBaseTerm.icst .ilt

def LamBaseTerm.ige' := LamBaseTerm.icst .ige

def LamBaseTerm.igt' := LamBaseTerm.icst .igt

def LamBaseTerm.strVal' s := LamBaseTerm.scst (.strVal s)

def LamBaseTerm.sapp' := LamBaseTerm.scst .sapp

def LamBaseTerm.sle' := LamBaseTerm.scst .sle

def LamBaseTerm.sge' := LamBaseTerm.scst .sge

def LamBaseTerm.slt' := LamBaseTerm.scst .slt

def LamBaseTerm.sgt' := LamBaseTerm.scst .sgt

def LamBaseTerm.isBcst : LamBaseTerm → Bool
| .bcst _ => true
| _       => false

def LamBaseTerm.isNcst : LamBaseTerm → Bool
| .ncst _ => true
| _       => false

def LamBaseTerm.isIcst : LamBaseTerm → Bool
| .icst _ => true
| _       => false

def LamBaseTerm.isScst : LamBaseTerm → Bool
| .scst _ => true
| _       => false

def LamBaseTerm.isBvVal : LamBaseTerm → Bool
| .bvVal _ => true
| _        => false

def LamBaseTerm.isEqI : LamBaseTerm → Bool
| .eqI _ => true
| _      => false

def LamBaseTerm.isForallEI : LamBaseTerm → Bool
| .forallEI _ => true
| _           => false

def LamBaseTerm.isExistEI : LamBaseTerm → Bool
| .existEI _ => true
| _          => false

def LamBaseTerm.isEq : LamBaseTerm → Bool
| .eq _ => true
| _     => false

def LamBaseTerm.isForallE : LamBaseTerm → Bool
| .forallE _ => true
| _          => false

def LamBaseTerm.isExistE : LamBaseTerm → Bool
| .existE _ => true
| _         => false

def LamBaseTerm.reprPrec (l : LamBaseTerm) (n : Nat) :=
  let s :=
    match l with
    | .trueE      => f!".trueE"
    | .falseE     => f!".falseE"
    | .not        => f!".not"
    | .and        => f!".and"
    | .or         => f!".or"
    | .imp        => f!".imp"
    | .iff        => f!".iff"
    | .bcst bc    => f!".bcst {BoolConst.reprPrec bc 1}"
    | .ncst nc    => f!".ncst {NatConst.reprPrec nc 1}"
    | .icst ic    => f!".icst {IntConst.reprPrec ic 1}"
    | .scst sc    => f!".scst {StringConst.reprPrec sc 1}"
    | .bvVal l    => f!".bvVal {l}"
    | .eqI n      => f!".eqI {n}"
    | .forallEI n => f!".forallEI {n}"
    | .existEI n  => f!".existEI {n}"
    | .eq s       => f!".eq {LamSort.reprPrec s 1}"
    | .forallE s  => f!".forallE {LamSort.reprPrec s 1}"
    | .existE s   => f!".existE {LamSort.reprPrec s 1}"
  if n == 0 then
    f!"Auto.Embedding.Lam.LamBaseTerm" ++ s
  else
    f!"({s})"

instance : Repr LamBaseTerm where
  reprPrec := LamBaseTerm.reprPrec

def LamBaseTerm.toString : LamBaseTerm → String
| .trueE      => "True"
| .falseE     => "False"
| .not        => "¬"
| .and        => "∧"
| .or         => "∨"
| .imp        => "→"
| .iff        => "↔"
| .bcst bc    => s!"{bc}"
| .ncst nc    => s!"{nc}"
| .icst ic    => s!"{ic}"
| .scst sc    => s!"{sc}"
| .bvVal l    => s!"{l} : Bitvec {l.length}"
| .eqI _      => "="
| .forallEI _ => "∀"
| .existEI _  => "∃"
| .eq _       => "="
| .forallE _  => "∀"
| .existE _   => "∃"

instance : ToString LamBaseTerm where
  toString := LamBaseTerm.toString

def LamBaseTerm.beq : LamBaseTerm → LamBaseTerm → Bool
| .trueE,       .trueE       => true
| .falseE,      .falseE      => true
| .not,         .not         => true
| .and,         .and         => true
| .or,          .or          => true
| .imp,         .imp         => true
| .iff,         .iff         => true
| .bcst bc₁,    .bcst bc₂    => bc₁.beq bc₂
| .ncst nc₁,    .ncst nc₂    => NatConst.beq nc₁ nc₂
| .icst ic₁,    .icst ic₂    => IntConst.beq ic₁ ic₂
| .scst sc₁,    .scst sc₂    => StringConst.beq sc₁ sc₂
| .bvVal l₁,    .bvVal l₂    => l₁.beq l₂
| .eqI n₁,      .eqI n₂      => n₁.beq n₂
| .forallEI n₁, .forallEI n₂ => n₁.beq n₂
| .existEI n₁,  .existEI n₂  => n₁.beq n₂
| .eq s₁,       .eq s₂       => s₁.beq s₂
| .forallE s₁,  .forallE s₂  => s₁.beq s₂
| .existE s₁,   .existE s₂   => s₁.beq s₂
| _,            _            => false

instance : BEq LamBaseTerm where
  beq := LamBaseTerm.beq

def LamBaseTerm.beq_refl {b : LamBaseTerm} : (b.beq b) = true := by
  cases b <;> first | rfl | apply LamSort.beq_refl | apply Nat.beq_refl | skip
  case bcst bc => apply LawfulBEq.rfl (α := BoolConst)
  case ncst n => apply LawfulBEq.rfl (α := NatConst)
  case icst i => apply LawfulBEq.rfl (α := IntConst)
  case scst s => apply LawfulBEq.rfl (α := StringConst)
  case bvVal s => apply LawfulBEq.rfl (α := List Bool)

def LamBaseTerm.eq_of_beq_eq_true {b₁ b₂ : LamBaseTerm} (H : b₁.beq b₂) : b₁ = b₂ := by
  cases b₁ <;> cases b₂ <;> (first | contradiction | rfl | apply congrArg) <;>
    (try apply LamSort.eq_of_beq_eq_true H) <;> (try apply Nat.eq_of_beq_eq_true H)
  case bcst.bcst.h bc₁ bc₂ => apply LawfulBEq.eq_of_beq (α := BoolConst) H
  case ncst.ncst.h nc₁ nc₂ => apply LawfulBEq.eq_of_beq (α := NatConst) H
  case icst.icst.h n₁ n₂ => apply LawfulBEq.eq_of_beq (α := IntConst) H
  case scst.scst.h s₁ s₂ => apply LawfulBEq.eq_of_beq (α := StringConst) H
  case bvVal.bvVal.h v₁ v₂ => apply LawfulBEq.eq_of_beq (α := List Bool) H

instance : LawfulBEq LamBaseTerm where
  eq_of_beq := LamBaseTerm.eq_of_beq_eq_true
  rfl := LamBaseTerm.beq_refl

def LamBaseTerm.containsSort (b : LamBaseTerm) (s : LamSort) : Bool :=
  match b with
  | .trueE      => false
  | .falseE     => false
  | .not        => false
  | .and        => false
  | .or         => false
  | .imp        => false
  | .iff        => false
  | .bcst _     => false
  | .ncst _     => false
  | .icst _     => false
  | .scst _     => false
  | .bvVal _    => false
  | .eqI _      => false
  | .forallEI _ => false
  | .existEI _  => false
  | .eq s'      => s'.contains s
  | .forallE s' => s'.contains s
  | .existE s'  => s'.contains s

structure LamTyVal where
  lamVarTy     : Nat → LamSort
  lamILTy      : Nat → LamSort
  lamEVarTy    : Nat → LamSort

instance : Inhabited LamTyVal where
  default := let func := fun _ => .atom 0; ⟨func, func, func⟩

def LamBaseTerm.lamCheck (ltv : LamTyVal) : LamBaseTerm → LamSort
| .trueE      => .base .prop
| .falseE     => .base .prop
| .not        => .func (.base .prop) (.base .prop)
| .and        => .func (.base .prop) (.func (.base .prop) (.base .prop))
| .or         => .func (.base .prop) (.func (.base .prop) (.base .prop))
| .imp        => .func (.base .prop) (.func (.base .prop) (.base .prop))
| .iff        => .func (.base .prop) (.func (.base .prop) (.base .prop))
| .bcst bc    => bc.lamCheck
| .ncst nc    => nc.lamCheck
| .icst ic    => ic.lamCheck
| .scst sc    => sc.lamCheck
| .bvVal ls   => .base (.bv ls.length)
| .eqI n      =>
  let s := ltv.lamILTy n
  .func s (.func s (.base .prop))
| .forallEI n =>
  let s := ltv.lamILTy n
  .func (.func s (.base .prop)) (.base .prop)
| .existEI n  =>
  let s := ltv.lamILTy n
  .func (.func s (.base .prop)) (.base .prop)
| .eq s       => .func s (.func s (.base .prop))
| .forallE s  => .func (.func s (.base .prop)) (.base .prop)
| .existE s   => .func (.func s (.base .prop)) (.base .prop)

inductive LamBaseTerm.LamWF (ltv : LamTyVal) : LamBaseTerm → LamSort → Type
  | ofTrueE      : LamWF ltv .trueE (.base .prop)
  | ofFalseE     : LamWF ltv .falseE (.base .prop)
  | ofNot        : LamWF ltv .not (.func (.base .prop) (.base .prop))
  | ofAnd        : LamWF ltv .and (.func (.base .prop) (.func (.base .prop) (.base .prop)))
  | ofOr         : LamWF ltv .or (.func (.base .prop) (.func (.base .prop) (.base .prop)))
  | ofImp        : LamWF ltv .imp (.func (.base .prop) (.func (.base .prop) (.base .prop)))
  | ofIff        : LamWF ltv .iff (.func (.base .prop) (.func (.base .prop) (.base .prop)))
  | ofBcst       : (bcwf : BoolConst.LamWF bc s) → LamWF ltv (.bcst bc) s
  | ofNcst       : (ncwf : NatConst.LamWF nc s) → LamWF ltv (.ncst nc) s
  | ofIcst       : (icwf : IntConst.LamWF ic s) → LamWF ltv (.icst ic) s
  | ofScst       : (scwf : StringConst.LamWF sc s) → LamWF ltv (.scst sc) s
  | ofBvVal ls   : LamWF ltv (.bvVal ls) (.base (.bv ls.length))
  | ofEqI n      : LamWF ltv (.eqI n) (.func (ltv.lamILTy n) (.func (ltv.lamILTy n) (.base .prop)))
  | ofForallEI n : LamWF ltv (.forallEI n) (.func (.func (ltv.lamILTy n) (.base .prop)) (.base .prop))
  | ofExistEI n  : LamWF ltv (.existEI n) (.func (.func (ltv.lamILTy n) (.base .prop)) (.base .prop))
  | ofEq s       : LamWF ltv (.eq s) (.func s (.func s (.base .prop)))
  | ofForallE s  : LamWF ltv (.forallE s) (.func (.func s (.base .prop)) (.base .prop))
  | ofExistE s   : LamWF ltv (.existE s) (.func (.func s (.base .prop)) (.base .prop))

def LamBaseTerm.LamWF.unique {ltv : LamTyVal} {b : LamBaseTerm} {s₁ s₂ : LamSort}
  (lbwf₁ : LamWF ltv b s₁) (lbwf₂ : LamWF ltv b s₂) : s₁ = s₂ ∧ HEq lbwf₁ lbwf₂ := by
  cases lbwf₁ <;> cases lbwf₂ <;> try trivial
  case ofBcst.ofBcst bc wf₁ wf₂ =>
    rcases BoolConst.LamWF.unique wf₁ wf₂ with ⟨⟨⟩, ⟨⟩⟩; trivial
  case ofNcst.ofNcst bc wf₁ wf₂ =>
    rcases NatConst.LamWF.unique wf₁ wf₂ with ⟨⟨⟩, ⟨⟩⟩; trivial
  case ofIcst.ofIcst ic wf₁ wf₂ =>
    rcases IntConst.LamWF.unique wf₁ wf₂ with ⟨⟨⟩, ⟨⟩⟩; trivial
  case ofScst.ofScst sc wf₁ wf₂ =>
    rcases StringConst.LamWF.unique wf₁ wf₂ with ⟨⟨⟩, ⟨⟩⟩; trivial

def LamBaseTerm.LamWF.eVarIrrelevance
  (hLamVarTy : ltv₁.lamVarTy = ltv₂.lamVarTy)
  (hLamILTy : ltv₁.lamILTy = ltv₂.lamILTy)
  (lbwf : LamWF ltv₁ b s) : LamWF ltv₂ b s := by
  cases b <;> cases lbwf <;> (try constructor) <;> cases ltv₁ <;> cases ltv₂ <;>
    cases hLamVarTy <;> cases hLamILTy <;> first | constructor | assumption

def LamBaseTerm.LamWF.ofTrueB' {ltv : LamTyVal} := LamWF.ofBcst (ltv:=ltv) .ofTrueB

def LamBaseTerm.LamWF.ofFalseB' {ltv : LamTyVal} := LamWF.ofBcst (ltv:=ltv) .ofFalseB

def LamBaseTerm.LamWF.ofNotB' {ltv : LamTyVal} := LamWF.ofBcst (ltv:=ltv) .ofNotB

def LamBaseTerm.LamWF.ofAndB' {ltv : LamTyVal} := LamWF.ofBcst (ltv:=ltv) .ofAndB

def LamBaseTerm.LamWF.ofOrB' {ltv : LamTyVal} := LamWF.ofBcst (ltv:=ltv) .ofOrB

def LamBaseTerm.LamWF.ofIntVal' {ltv : LamTyVal} (n : Nat) := LamWF.ofIcst (ltv:=ltv) (.ofIntVal n)

def LamBaseTerm.LamWF.ofIneg' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofIneg

def LamBaseTerm.LamWF.ofIabs' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofIabs

def LamBaseTerm.LamWF.ofIadd' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofIadd

def LamBaseTerm.LamWF.ofIsub' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofIsub

def LamBaseTerm.LamWF.ofImul' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofImul

def LamBaseTerm.LamWF.ofIdiv' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofIdiv

def LamBaseTerm.LamWF.ofImod' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofImod

def LamBaseTerm.LamWF.ofIediv' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofIediv

def LamBaseTerm.LamWF.ofIemod' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofIemod

def LamBaseTerm.LamWF.ofIle' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofIle

def LamBaseTerm.LamWF.ofIlt' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofIlt

def LamBaseTerm.LamWF.ofIge' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofIge

def LamBaseTerm.LamWF.ofIgt' {ltv : LamTyVal} := LamWF.ofIcst (ltv:=ltv) .ofIgt

def LamBaseTerm.LamWF.ofStrVal' {ltv : LamTyVal} (s : String) := LamWF.ofScst (ltv:=ltv) (.ofStrVal s)

def LamBaseTerm.LamWF.ofSapp' {ltv : LamTyVal} := LamWF.ofScst (ltv:=ltv) .ofSapp

def LamBaseTerm.LamWF.ofSle' {ltv : LamTyVal} := LamWF.ofScst (ltv:=ltv) .ofSle

def LamBaseTerm.LamWF.ofSge' {ltv : LamTyVal} := LamWF.ofScst (ltv:=ltv) .ofSge

def LamBaseTerm.LamWF.ofSlt' {ltv : LamTyVal} := LamWF.ofScst (ltv:=ltv) .ofSlt

def LamBaseTerm.LamWF.ofSgt' {ltv : LamTyVal} := LamWF.ofScst (ltv:=ltv) .ofSgt

def LamBaseTerm.LamWF.getBcst (wf : LamWF ltv (.bcst bc) s) : BoolConst.LamWF bc s :=
  match wf with | .ofBcst bcwf => bcwf

def LamBaseTerm.LamWF.getNcst (wf : LamWF ltv (.ncst nc) s) : NatConst.LamWF nc s :=
  match wf with | .ofNcst ncwf => ncwf

def LamBaseTerm.LamWF.getIcst (wf : LamWF ltv (.icst ic) s) : IntConst.LamWF ic s :=
  match wf with | .ofIcst icwf => icwf

def LamBaseTerm.LamWF.getScst (wf : LamWF ltv (.scst sc) s) : StringConst.LamWF sc s :=
  match wf with | .ofScst scwf => scwf

def LamBaseTerm.LamWF.ofLamBaseTerm (ltv : LamTyVal) : (b : LamBaseTerm) → (s : LamSort) × LamBaseTerm.LamWF ltv b s
| .trueE      => ⟨.base .prop, .ofTrueE⟩
| .falseE     => ⟨.base .prop, .ofFalseE⟩
| .not        => ⟨.func (.base .prop) (.base .prop), .ofNot⟩
| .and        => ⟨.func (.base .prop) (.func (.base .prop) (.base .prop)), .ofAnd⟩
| .or         => ⟨.func (.base .prop) (.func (.base .prop) (.base .prop)), .ofOr⟩
| .imp        => ⟨.func (.base .prop) (.func (.base .prop) (.base .prop)), .ofImp⟩
| .iff        => ⟨.func (.base .prop) (.func (.base .prop) (.base .prop)), .ofIff⟩
| .bcst bc    => have ⟨s, wf⟩ := BoolConst.LamWF.ofBoolConst bc; ⟨s, .ofBcst wf⟩
| .ncst nc    => have ⟨s, wf⟩ := NatConst.LamWF.ofNatConst nc; ⟨s, .ofNcst wf⟩
| .icst ic    => have ⟨s, wf⟩ := IntConst.LamWF.ofIntConst ic; ⟨s, .ofIcst wf⟩
| .scst sc    => have ⟨s, wf⟩ := StringConst.LamWF.ofStringConst sc; ⟨s, .ofScst wf⟩
| .bvVal ls   => ⟨.base (.bv ls.length), .ofBvVal ls⟩
| .eqI n      => ⟨.func _ (.func _ (.base .prop)), .ofEqI n⟩
| .forallEI n => ⟨.func (.func _ (.base .prop)) (.base .prop), .ofForallEI n⟩
| .existEI n  => ⟨.func (.func _ (.base .prop)) (.base .prop), .ofExistEI n⟩
| .eq s       => ⟨.func _ (.func _ (.base .prop)), .ofEq s⟩
| .forallE s  => ⟨.func (.func _ (.base .prop)) (.base .prop), .ofForallE s⟩
| .existE s   => ⟨.func (.func _ (.base .prop)) (.base .prop), .ofExistE s⟩

def LamBaseTerm.lamWF_complete (wf : LamWF ltv b s) : LamWF.ofLamBaseTerm ltv b = ⟨s, wf⟩ := by
  cases wf <;> try rfl
  case ofBcst bc wf => dsimp [LamWF.ofLamBaseTerm]; rw [BoolConst.lamWF_complete wf]
  case ofNcst bc wf => dsimp [LamWF.ofLamBaseTerm]; rw [NatConst.lamWF_complete wf]
  case ofIcst ic wf => dsimp [LamWF.ofLamBaseTerm]; rw [IntConst.lamWF_complete]
  case ofScst bc wf => dsimp [LamWF.ofLamBaseTerm]; rw [StringConst.lamWF_complete wf]

def LamBaseTerm.lamCheck_of_LamWF (H : LamWF ltv b s) : b.lamCheck ltv = s := by
  cases H <;> try rfl
  case ofBcst bc wf => apply BoolConst.lamCheck_of_LamWF wf
  case ofNcst bc wf => apply NatConst.lamCheck_of_LamWF wf
  case ofIcst bc wf => apply IntConst.lamCheck_of_LamWF wf
  case ofScst sc wf => apply StringConst.lamCheck_of_LamWF wf

def LamBaseTerm.LamWF.ofCheck (H : b.lamCheck ltv = s) : LamWF ltv b s := by
  cases H; cases b <;> constructor
  case refl.bcst.bcwf => apply BoolConst.LamWF.ofCheck; rfl
  case refl.ncst.ncwf => apply NatConst.LamWF.ofCheck; rfl
  case refl.icst.icwf => apply IntConst.LamWF.ofCheck; rfl
  case refl.scst.scwf => apply StringConst.LamWF.ofCheck; rfl

structure ILLift (β : Type u) where
  eqL     : EqLift.{u + 1, u} β
  forallL : ForallLift.{u + 1, u, 0, 0} β
  existL  : ExistLift.{u + 1, u} β

def ILLift.ofIsomTy {α : Sort u} {β : Type v} (I : IsomType α β) : ILLift β :=
  ⟨EqLift.ofIsomTy I, ForallLift.ofIsomTy I, ExistLift.ofIsomTy I⟩

def ILLift.default (β : Type u) : ILLift β :=
  ⟨EqLift.default β, ForallLift.default β, ExistLift.default β⟩

structure LamValuation extends LamTyVal where
  tyVal    : Nat → Type u
  varVal   : ∀ (n : Nat), (lamVarTy n).interp tyVal
  ilVal    : ∀ (n : Nat), ILLift.{u} ((lamILTy n).interp tyVal)
  eVarVal  : ∀ (n : Nat), (lamEVarTy n).interp tyVal

def BoolConst.interp (tyVal : Nat → Type u) : (b : BoolConst) → b.lamCheck.interp tyVal
| .trueb      => GLift.up true
| .falseb     => GLift.up false
| .notb       => notbLift
| .andb       => andbLift
| .orb        => orbLift

def BoolConst.LamWF.interp (tyVal : Nat → Type u) : (lwf : LamWF b s) → s.interp tyVal
| .ofTrueB      => GLift.up true
| .ofFalseB     => GLift.up false
| .ofNotB       => notbLift
| .ofAndB       => andbLift
| .ofOrB        => orbLift

theorem BoolConst.LamWF.interp_lvalIrrelevance
  (tyVal₁ tyVal₂ : Nat → Type u) (bcwf₁ : LamWF b₁ s₁) (bcwf₂ : LamWF b₂ s₂)
  (HBeq : b₁ = b₂) (hTyVal : tyVal₁ = tyVal₂) :
  HEq (bcwf₁.interp tyVal₁) (bcwf₂.interp tyVal₂) := by
  cases HBeq; cases hTyVal; rcases BoolConst.LamWF.unique bcwf₁ bcwf₂ with ⟨⟨⟩, ⟨⟩⟩; rfl

def BoolConst.interp_equiv (tyVal : Nat → Type u) (bcwf : LamWF b s) :
  HEq (LamWF.interp tyVal bcwf) (interp tyVal b) := by
  cases bcwf <;> rfl

def NatConst.interp (tyVal : Nat → Type u) : (n : NatConst) → n.lamCheck.interp tyVal
| .natVal n => GLift.up n
| .nadd     => naddLift
| .nsub     => nsubLift
| .nmul     => nmulLift
| .ndiv     => ndivLift
| .nmod     => nmodLift
| .nle      => nleLift
| .nge      => ngeLift
| .nlt      => nltLift
| .ngt      => ngtLift

def NatConst.LamWF.interp (tyVal : Nat → Type u) : (lwf : LamWF i s) → s.interp tyVal
| .ofNatVal n => GLift.up n
| .ofNadd     => naddLift
| .ofNsub     => nsubLift
| .ofNmul     => nmulLift
| .ofNdiv     => ndivLift
| .ofNmod     => nmodLift
| .ofNle      => nleLift
| .ofNge      => ngeLift
| .ofNlt      => nltLift
| .ofNgt      => ngtLift

theorem NatConst.LamWF.interp_lvalIrrelevance
  (tyVal₁ tyVal₂ : Nat → Type u) (ncwf₁ : LamWF n₁ s₁) (ncwf₂ : LamWF n₂ s₂)
  (HBeq : n₁ = n₂) (hTyVal : tyVal₁ = tyVal₂) :
  HEq (ncwf₁.interp tyVal₁) (ncwf₂.interp tyVal₂) := by
  cases HBeq; cases hTyVal; rcases NatConst.LamWF.unique ncwf₁ ncwf₂ with ⟨⟨⟩, ⟨⟩⟩; rfl

def NatConst.interp_equiv (tyVal : Nat → Type u) (ncwf : LamWF n s) :
  HEq (LamWF.interp tyVal ncwf) (interp tyVal n) := by
  cases ncwf <;> rfl

def IntConst.interp (tyVal : Nat → Type u) : (i : IntConst) → i.lamCheck.interp tyVal
| .intVal n => GLift.up n
| .ineg     => inegLift
| .iabs     => iabsLift
| .iadd     => iaddLift
| .isub     => isubLift
| .imul     => imulLift
| .idiv     => idivLift
| .imod     => imodLift
| .iediv    => iedivLift
| .iemod    => iemodLift
| .ile      => ileLift
| .ige      => igeLift
| .ilt      => iltLift
| .igt      => igtLift

def IntConst.LamWF.interp (tyVal : Nat → Type u) : (lwf : LamWF i s) → s.interp tyVal
| .ofIntVal n => GLift.up n
| .ofIneg     => inegLift
| .ofIabs     => iabsLift
| .ofIadd     => iaddLift
| .ofIsub     => isubLift
| .ofImul     => imulLift
| .ofIdiv     => idivLift
| .ofImod     => imodLift
| .ofIediv    => iedivLift
| .ofIemod    => iemodLift
| .ofIle      => ileLift
| .ofIge      => igeLift
| .ofIlt      => iltLift
| .ofIgt      => igtLift

theorem IntConst.LamWF.interp_lvalIrrelevance
  (tyVal₁ tyVal₂ : Nat → Type u) (icwf₁ : LamWF i₁ s₁) (icwf₂ : LamWF i₂ s₂)
  (HBeq : i₁ = i₂) (hTyVal : tyVal₁ = tyVal₂) :
  HEq (icwf₁.interp tyVal₁) (icwf₂.interp tyVal₂) := by
  cases HBeq; cases hTyVal; rcases IntConst.LamWF.unique icwf₁ icwf₂ with ⟨⟨⟩, ⟨⟩⟩; rfl

def IntConst.interp_equiv (tyVal : Nat → Type u) (icwf : LamWF i s) :
  HEq (LamWF.interp tyVal icwf) (interp tyVal i) := by
  cases icwf <;> rfl

def StringConst.interp (tyVal : Nat → Type u) : (b : StringConst) → b.lamCheck.interp tyVal
| .strVal s => GLift.up s
| .sapp     => sappLift
| .sle      => sleLift
| .sge      => sgeLift
| .slt      => sltLift
| .sgt      => sgtLift

def StringConst.LamWF.interp (tyVal : Nat → Type u) : (lwf : LamWF i s) → s.interp tyVal
| .ofStrVal s => GLift.up s
| .ofSapp     => sappLift
| .ofSle      => sleLift
| .ofSge      => sgeLift
| .ofSlt      => sltLift
| .ofSgt      => sgtLift

theorem StringConst.LamWF.interp_lvalIrrelevance
  (tyVal₁ tyVal₂ : Nat → Type u) (scwf₁ : LamWF sc₁ s₁) (scwf₂ : LamWF sc₂ s₂)
  (HBeq : sc₁ = sc₂) (hTyVal : tyVal₁ = tyVal₂) :
  HEq (scwf₁.interp tyVal₁) (scwf₂.interp tyVal₂) := by
  cases HBeq; cases hTyVal; rcases StringConst.LamWF.unique scwf₁ scwf₂ with ⟨⟨⟩, ⟨⟩⟩; rfl

def StringConst.interp_equiv (tyVal : Nat → Type u) (scwf : LamWF sc s) :
  HEq (LamWF.interp tyVal scwf) (interp tyVal sc) := by
  cases scwf <;> rfl

def LamBaseTerm.interp (lval : LamValuation.{u}) : (b : LamBaseTerm) → (b.lamCheck lval.toLamTyVal).interp lval.tyVal
| .trueE      => GLift.up True
| .falseE     => GLift.up False
| .not        => notLift
| .and        => andLift
| .or         => orLift
| .imp        => impLift
| .iff        => iffLift
| .bcst bc    => bc.interp lval.tyVal
| .ncst nc    => nc.interp lval.tyVal
| .icst ic    => ic.interp lval.tyVal
| .scst sc    => sc.interp lval.tyVal
| .bvVal ls   => GLift.up ⟨ls, rfl⟩
| .eqI n      => (lval.ilVal n).eqL.eqF
| .forallEI n => (lval.ilVal n).forallL.forallF
| .existEI n  => (lval.ilVal n).existL.existF
| .eq s       => @eqLiftFn (s.interp lval.tyVal)
| .forallE s  => @forallLiftFn (s.interp lval.tyVal)
| .existE s   => @existLiftFn (s.interp lval.tyVal)

def LamBaseTerm.LamWF.interp (lval : LamValuation.{u}) : (lwf : LamWF lval.toLamTyVal b s) → s.interp lval.tyVal
| .ofTrueE      => GLift.up True
| .ofFalseE     => GLift.up False
| .ofNot        => notLift
| .ofAnd        => andLift
| .ofOr         => orLift
| .ofImp        => impLift
| .ofIff        => iffLift
| .ofBcst wf    => wf.interp lval.tyVal
| .ofNcst wf    => wf.interp lval.tyVal
| .ofIcst wf    => wf.interp lval.tyVal
| .ofScst wf    => wf.interp lval.tyVal
| .ofBvVal ls   => GLift.up ⟨ls, rfl⟩
| .ofEqI n      => (lval.ilVal n).eqL.eqF
| .ofForallEI n => (lval.ilVal n).forallL.forallF
| .ofExistEI n  => (lval.ilVal n).existL.existF
| .ofEq s       => @eqLiftFn (s.interp lval.tyVal)
| .ofForallE s  => @forallLiftFn (s.interp lval.tyVal)
| .ofExistE s   => @existLiftFn (s.interp lval.tyVal)

theorem LamBaseTerm.LamWF.interp_heq (lval : LamValuation.{u})
  (lwf₁ : LamWF lval.toLamTyVal b₁ s₁)
  (lwf₂ : LamWF lval.toLamTyVal b₂ s₂)
  (HBeq : b₁ = b₂) : HEq (LamWF.interp lval lwf₁) (LamWF.interp lval lwf₂) := by
  cases HBeq;
  cases LamWF.unique lwf₁ lwf₂
  case intro seq lweq =>
    cases seq; cases lweq; apply HEq.rfl

theorem LamBaseTerm.LamWF.interp_lvalIrrelevance
  (lval₁ lval₂ : LamValuation.{u})
  (lwf₁ : LamWF lval₁.toLamTyVal b₁ s₁)
  (lwf₂ : LamWF lval₂.toLamTyVal b₂ s₂)
  (HBeq : b₁ = b₂)
  (hTyVal : lval₁.tyVal = lval₂.tyVal)
  (hLamILTy : lval₁.lamILTy = lval₂.lamILTy)
  (hILVal : HEq lval₁.ilVal lval₂.ilVal) :
  HEq (LamWF.interp lval₁ lwf₁) (LamWF.interp lval₂ lwf₂) := by
  cases HBeq
  cases lval₁
  case mk toLamTyVal₁ tyVal₁ varVal₁ ilVal₁ eVarVal₁ =>
    cases toLamTyVal₁
    case mk lamVarTy₁ lamILTy₁ lamEVarTy₁ =>
      cases lval₂
      case mk toLamTyVal₂ tyVal₂ varVal₂ ilVal₂ eVarVal₂ =>
        cases toLamTyVal₂
        case mk lamVarTy₂ lamILTy₂ lamEVarTy₂ =>
          dsimp at varVal₁ ilVal₁ eVarVal₁ lwf₁ varVal₂ ilVal₂ eVarVal₂ lwf₂
          dsimp at hTyVal hLamILTy hILVal;
          cases hTyVal; cases hLamILTy; cases hILVal
          cases lwf₁ <;> cases lwf₂ <;> dsimp [interp] <;> try apply HEq.rfl
          case ofBcst => apply BoolConst.LamWF.interp_lvalIrrelevance <;> rfl
          case ofNcst => apply NatConst.LamWF.interp_lvalIrrelevance <;> rfl
          case ofIcst => apply IntConst.LamWF.interp_lvalIrrelevance <;> rfl
          case ofScst => apply StringConst.LamWF.interp_lvalIrrelevance <;> rfl

def LamBaseTerm.interp_equiv (lval : LamValuation.{u})
  (lwf : LamWF lval.toLamTyVal b s) :
  HEq (LamWF.interp lval lwf) (interp lval b) := by
  cases lwf <;> try rfl
  case ofBcst => apply BoolConst.interp_equiv
  case ofNcst => apply NatConst.interp_equiv
  case ofIcst => apply IntConst.interp_equiv
  case ofScst => apply StringConst.interp_equiv

def LamValuation.insertEVarAt (lval : LamValuation.{u})
  (ty : LamSort) (val : ty.interp lval.tyVal) (pos : Nat) :=
  {lval with lamEVarTy := replaceAt ty pos lval.lamEVarTy,
             eVarVal := replaceAtDep val pos lval.eVarVal}

theorem LamTyVal.insertEVarAt_eVarIrrelevance
  {ltv₁ : LamTyVal} (H : n < pos) :
  let ltv₂ := {ltv₁ with lamEVarTy := replaceAt ty pos ltv₁.lamEVarTy}
  ltv₁.lamEVarTy n = ltv₂.lamEVarTy n := by
  dsimp [replaceAt]
  cases h : Nat.beq n pos
  case true =>
    dsimp; cases Nat.eq_of_beq_eq_true h;
    have H' := (Nat.not_le).mpr H; apply False.elim (H' _); apply Nat.le_refl
  case false => rfl

theorem LamValuation.insertEVarAt_eVarIrrelevance
  {lval₁ : LamValuation.{u}} {val} (H : n < pos) :
  let lval₂ := lval₁.insertEVarAt ty val pos;
  lval₁.lamEVarTy n = lval₂.lamEVarTy n ∧ HEq (lval₁.eVarVal n) (lval₂.eVarVal n) := by
  dsimp [insertEVarAt, replaceAt, replaceAtDep]
  cases h : Nat.beq n pos
  case true =>
    dsimp; cases Nat.eq_of_beq_eq_true h;
    have H' := (Nat.not_le).mpr H; apply False.elim (H' _); apply Nat.le_refl
  case false => apply And.intro rfl HEq.rfl

inductive LamTerm
  | atom    : Nat → LamTerm
  -- Existential atoms. Supports definition and skolemization
  | etom    : Nat → LamTerm
  | base    : LamBaseTerm → LamTerm
  | bvar    : Nat → LamTerm
  | lam     : LamSort → LamTerm → LamTerm
  -- The `LamSort` is here so that both the type of
  --   the function and argument can be inferred directly
  --   when we know the type of the application
  | app     : LamSort → LamTerm → LamTerm → LamTerm
deriving Inhabited, Hashable, Lean.ToExpr

def LamTerm.isAtom : LamTerm → Bool
| .atom _ => true
| _ => false

def LamTerm.isEtom : LamTerm → Bool
| .etom _ => true
| _ => false

def LamTerm.isBase : LamTerm → Bool
| .base _ => true
| _ => false

def LamTerm.isbvar : LamTerm → Bool
| .bvar _ => true
| _ => false

def LamTerm.isLam : LamTerm → Bool
| .lam _ _ => true
| _ => false

def LamTerm.isApp : LamTerm → Bool
| .app _ _ _ => true
| _ => false

def LamTerm.isForallE : LamTerm → Bool
| .base (.forallE _) => true
| _ => false

def LamTerm.isExistE : LamTerm → Bool
| .base (.existE _) => true
| _ => false

def LamTerm.isEq : LamTerm → Bool
| .base (.eq _) => true
| _ => false

def LamTerm.isMkForallE : LamTerm → Bool
| .app _ (.base (.forallE _)) _ => true
| _ => false

def LamTerm.isMkExistE : LamTerm → Bool
| .app _ (.base (.existE _)) _ => true
| _ => false

def LamTerm.isMkEq : LamTerm → Bool
| .app _ (.app _ (.base (.eq _)) _) _ => true
| _ => false

def LamTerm.size : LamTerm → Nat
| .atom _ => 1
| .etom _ => 1
| .base _ => 1
| .bvar _ => 1
| .lam _ t => t.size + 1
| .app _ t₁ t₂ => t₁.size + t₂.size

theorem LamTerm.size_ne_zero : size t > 0 := by
  induction t <;> try (dsimp [size]; apply Nat.le_refl)
  case lam s body IH =>
    dsimp [size]; apply Nat.le_trans IH (Nat.le_succ _)
  case app s fn arg _ IHArg =>
    dsimp [size]; apply Nat.le_trans IHArg (Nat.le_add_left _ _)

theorem LamTerm.size_lam_gt_size_body : size (.lam s t) > size t := Nat.le_refl _

theorem LamTerm.size_app_gt_size_fn : size (.app s fn arg) > size fn :=
  Nat.add_le_add_left size_ne_zero _

theorem LamTerm.size_app_gt_size_arg : size (.app s fn arg) > size arg := by
  dsimp [size]; rw [Nat.add_comm]; apply Nat.add_le_add_left size_ne_zero

/--
  Check whether the term contains loose bound variables `idx` levels
    above local context root
-/
def LamTerm.hasLooseBVarEq (idx : Nat) : LamTerm → Bool
| .atom _ => false
| .etom _ => false
| .base _ => false
| .bvar n => idx.beq n
| .lam _ t => t.hasLooseBVarEq (.succ idx)
| .app _ t₁ t₂ => t₁.hasLooseBVarEq idx || t₂.hasLooseBVarEq idx

/--
  Check whether the term contains loose bound variables greater
    or equal to `idx` levels above local context root
-/
def LamTerm.hasLooseBVarGe (idx : Nat) : LamTerm → Bool
| .atom _ => false
| .etom _ => false
| .base _ => false
| .bvar n => idx.ble n
| .lam _ t => t.hasLooseBVarGe (.succ idx)
| .app _ t₁ t₂ => t₁.hasLooseBVarGe idx || t₂.hasLooseBVarGe idx

-- Whether the term contains any loose bound variables
def LamTerm.hasLooseBVar := LamTerm.hasLooseBVarGe 0

def LamTerm.maxLooseBVarSucc : LamTerm → Nat
| .atom _ => 0
| .etom _ => 0
| .base _ => 0
| .bvar n => .succ n
| .lam _ t => .pred t.maxLooseBVarSucc
| .app _ t₁ t₂ => Nat.max t₁.maxLooseBVarSucc t₂.maxLooseBVarSucc

theorem LamTerm.maxLooseBVarSucc.spec (m : Nat) :
  (t : LamTerm) → t.hasLooseBVarGe m = true ↔ t.maxLooseBVarSucc > m
| .atom _ => by
  apply Iff.intro
  case mp => intro h; cases h
  case mpr => intro h; cases h
| .etom _ => by
  apply Iff.intro
  case mp => intro h; cases h
  case mpr => intro h; cases h
| .base _ => by
  apply Iff.intro
  case mp => intro h; cases h
  case mpr => intro h; cases h
| .bvar n => by
  dsimp [hasLooseBVarGe, maxLooseBVarSucc];
  apply Iff.intro <;> intro h
  case mp => exact Nat.succ_le_succ (Nat.le_of_ble_eq_true h)
  case mpr => exact Nat.ble_eq_true_of_le (Nat.le_of_succ_le_succ h)
| .lam _ t => by
  dsimp [hasLooseBVarGe, maxLooseBVarSucc];
  let IH := spec (Nat.succ m) t
  apply Iff.intro <;> intro h
  case mp =>
    let IH' := Nat.pred_le_pred (IH.mp h)
    rw [Nat.pred_succ] at IH'; exact IH'
  case mpr =>
    let h' := Nat.succ_le_succ h
    apply IH.mpr; rw [Nat.succ_pred] at h'; exact h'
    revert h; cases (maxLooseBVarSucc t)
    case zero => intro h; cases h
    case succ _ => intro _; simp
| .app _ t₁ t₂ => by
  dsimp [hasLooseBVarGe, maxLooseBVarSucc];
  rw [Bool.or_eq_true]; rw [spec m t₁]; rw [spec m t₂];
  simp [Nat.max]; rw [Nat.gt_eq_succ_le]; rw [Nat.gt_eq_succ_le]; rw [Nat.gt_eq_succ_le];
  rw [Nat.le_max_iff]

def LamTerm.maxEVarSucc : LamTerm → Nat
| .atom _ => 0
| .etom n => .succ n
| .base _ => 0
| .bvar _ => 0
| .lam _ t => t.maxEVarSucc
| .app _ t₁ t₂ => Nat.max t₁.maxEVarSucc t₂.maxEVarSucc

def LamTerm.mkNot (t : LamTerm) : LamTerm :=
  .app (.base .prop) (.base .not) t

theorem LamTerm.maxEVarSucc_mkNot :
  (mkNot t).maxEVarSucc = t.maxEVarSucc := by
  dsimp [maxEVarSucc]; rw [Nat.max, Nat.max_zero_left]

def LamTerm.mkAnd (t₁ t₂ : LamTerm) : LamTerm :=
  .app (.base .prop) (.app (.base .prop) (.base .and) t₁) t₂

theorem LamTerm.maxEVarSucc_mkAnd :
  (mkAnd t₁ t₂).maxEVarSucc = max t₁.maxEVarSucc t₂.maxEVarSucc := by
  dsimp [maxEVarSucc]; rw [Nat.max, Nat.max, Nat.max_zero_left]

def LamTerm.mkOr (t₁ t₂ : LamTerm) : LamTerm :=
  .app (.base .prop) (.app (.base .prop) (.base .or) t₁) t₂

theorem LamTerm.maxEVarSucc_mkOr :
  (mkOr t₁ t₂).maxEVarSucc = max t₁.maxEVarSucc t₂.maxEVarSucc := by
  dsimp [maxEVarSucc]; rw [Nat.max, Nat.max, Nat.max_zero_left]

def LamTerm.mkImp (t₁ t₂ : LamTerm) : LamTerm :=
  .app (.base .prop) (.app (.base .prop) (.base .imp) t₁) t₂

theorem LamTerm.maxEVarSucc_mkImp :
  (mkImp t₁ t₂).maxEVarSucc = max t₁.maxEVarSucc t₂.maxEVarSucc := by
  dsimp [maxEVarSucc]; rw [Nat.max, Nat.max, Nat.max_zero_left]

def LamTerm.mkIff (t₁ t₂ : LamTerm) : LamTerm :=
  .app (.base .prop) (.app (.base .prop) (.base .iff) t₁) t₂

theorem LamTerm.maxEVarSucc_mkIff :
  (mkIff t₁ t₂).maxEVarSucc = max t₁.maxEVarSucc t₂.maxEVarSucc := by
  dsimp [maxEVarSucc]; rw [Nat.max, Nat.max, Nat.max_zero_left]

def LamTerm.mkEq (s : LamSort) (t₁ t₂ : LamTerm) : LamTerm :=
  .app s (.app s (.base (.eq s)) t₁) t₂

theorem LamTerm.maxLooseBVarSucc_mkEq :
  (mkEq s t₁ t₂).maxLooseBVarSucc = max t₁.maxLooseBVarSucc t₂.maxLooseBVarSucc := by
  dsimp [maxLooseBVarSucc, Nat.max]; rw [Nat.max_zero_left]

theorem LamTerm.maxEVarSucc_mkEq :
  (mkEq s t₁ t₂).maxEVarSucc = max t₁.maxEVarSucc t₂.maxEVarSucc := by
  dsimp [maxEVarSucc, Nat.max]; rw[Nat.max_zero_left]

def LamTerm.mkForallE (s : LamSort) (p : LamTerm) : LamTerm :=
  .app (.func s (.base .prop)) (.base (.forallE s)) p

theorem LamTerm.maxLooseBVarSucc_mkForallE :
  (mkForallE s p).maxLooseBVarSucc = p.maxLooseBVarSucc := by
  dsimp [maxLooseBVarSucc, Nat.max]; rw [Nat.max_zero_left]

theorem LamTerm.maxEVarSucc_mkForallE :
  (mkForallE s p).maxEVarSucc = p.maxEVarSucc := by
  dsimp [maxEVarSucc]; apply Nat.max_zero_left

def LamTerm.mkForallEF (s : LamSort) (p : LamTerm) : LamTerm :=
  .app (.func s (.base .prop)) (.base (.forallE s)) (.lam s p)

theorem LamTerm.maxLooseBVarSucc_mkForallEF :
  (mkForallEF s p).maxLooseBVarSucc = p.maxLooseBVarSucc.pred := by
  dsimp [maxLooseBVarSucc, Nat.max]; rw [Nat.max_zero_left]

theorem LamTerm.maxEVarSucc_mkForallEF :
  (mkForallEF s p).maxEVarSucc = p.maxEVarSucc := by
  dsimp [maxEVarSucc]; apply Nat.max_zero_left

def LamTerm.mkExistE (s : LamSort) (p : LamTerm) : LamTerm :=
  .app (.func s (.base .prop)) (.base (.existE s)) p

theorem LamTerm.maxLooseBVarSucc_mkExistE :
  (mkExistE s p).maxLooseBVarSucc = p.maxLooseBVarSucc := by
  dsimp [maxLooseBVarSucc, Nat.max]; rw [Nat.max_zero_left]

theorem LamTerm.maxEVarSucc_mkExistE :
  (mkExistE s p).maxEVarSucc = p.maxEVarSucc := by
  dsimp [maxEVarSucc]; apply Nat.max_zero_left

def LamTerm.mkExistEF (s : LamSort) (p : LamTerm) : LamTerm :=
  .app (.func s (.base .prop)) (.base (.existE s)) (.lam s p)

theorem LamTerm.maxLooseBVarSucc_mkExistEF :
  (mkExistEF s p).maxLooseBVarSucc = p.maxLooseBVarSucc.pred := by
  dsimp [maxLooseBVarSucc, Nat.max]; rw [Nat.max_zero_left]

theorem LamTerm.maxEVarSucc_mkExistEF :
  (mkExistEF s p).maxEVarSucc = p.maxEVarSucc := by
  dsimp [maxEVarSucc]; apply Nat.max_zero_left

def LamTerm.mkAppN (t : LamTerm) : List (LamSort × LamTerm) → LamTerm
| .nil => t
| .cons (s, arg) args => (LamTerm.app s t arg).mkAppN args

theorem LamTerm.maxEVarSucc_mkAppN
  (hs : HList (fun (_, arg) => arg.maxEVarSucc ≤ n) args) (ht : t.maxEVarSucc ≤ n) :
  (LamTerm.mkAppN t args).maxEVarSucc ≤ n := by
  induction hs generalizing t
  case nil => exact ht
  case cons head tail IH =>
    dsimp [mkAppN]; apply IH; dsimp [maxEVarSucc]
    rw [Nat.max_le]; exact And.intro ht head

-- Given `t` and `[s₀, s₁, ⋯, sᵢ₋₁]`, return `λ (? : s₀) ⋯ (? : sᵢ₋₁), t`
def LamTerm.mkLamFN (t : LamTerm) : List LamSort → LamTerm
| .nil => t
| .cons s lctx => LamTerm.lam s (t.mkLamFN lctx)

theorem LamTerm.mkLamFN_append :
  mkLamFN t (l₁ ++ l₂) = mkLamFN (mkLamFN t l₂) l₁ := by
  induction l₁ generalizing t
  case nil => rfl
  case cons s l₁ IH =>
    rw [List.cons_append]; dsimp [mkLamFN]; rw [IH]

theorem LamTerm.mkLamFN_append_singleton :
  mkLamFN t (l₁ ++ [s]) = mkLamFN (.lam s t) l₁ := by
  rw [mkLamFN_append]; rfl

theorem LamTerm.maxEVarSucc_mkLamFN {t : LamTerm} :
  (t.mkLamFN lctx).maxEVarSucc = t.maxEVarSucc := by
  induction lctx generalizing t
  case nil => rfl
  case cons s lctx IH =>
    dsimp [mkLamFN, maxEVarSucc]; rw [IH]

-- Given `t` and `[s₀, s₁, ⋯, sᵢ₋₁]`, return `∀ (? : sᵢ₋₁) ⋯ (? : s₀), t`
def LamTerm.mkForallEFN (t : LamTerm) : List LamSort → LamTerm
| .nil => t
| .cons s lctx => LamTerm.mkForallEF s (t.mkForallEFN lctx)

theorem LamTerm.maxEVarSucc_mkForallEFN {t : LamTerm} :
  (t.mkForallEFN lctx).maxEVarSucc = t.maxEVarSucc := by
  induction lctx generalizing t
  case nil => rfl
  case cons s lctx IH =>
    dsimp [mkForallEFN, maxEVarSucc]; rw [IH]
    rw [Nat.max, Nat.max_zero_left]

theorem LamTerm.mkForallEFN_append :
  mkForallEFN t (l₁ ++ l₂) = mkForallEFN (mkForallEFN t l₂) l₁ := by
  induction l₁ generalizing t
  case nil => rfl
  case cons s l₁ IH =>
    dsimp [mkForallEFN]; rw [IH]

theorem LamTerm.mkForallEFN_append_singleton :
  mkForallEFN t (l₁ ++ [s]) = mkForallEFN (mkForallEF s t) l₁ := by
  rw [mkForallEFN_append]; rfl

/-- Given `λ (_ : ty₀) ⋯ (_ : tyᵢ₋₁), body`, return `body` -/
def LamTerm.getLamBody : LamTerm → LamTerm
| .lam _ body => getLamBody body
| t => t

theorem LamTerm.maxEVarSucc_getLamBody : (LamTerm.getLamBody t).maxEVarSucc = t.maxEVarSucc := by
  induction t <;> try rfl
  case lam s body IH => dsimp [getLamBody]; apply IH

/-- Given `λ (_ : ty₀) ⋯ (_ : tyᵢ₋₁), _`, return `[ty₀, ⋯, tyᵢ₋₁]` -/
def LamTerm.getLamTys : LamTerm → List LamSort
| .lam argTy body => argTy :: getLamTys body
| _ => []

theorem LamTerm.lamBody_lamTys_eq (t : LamTerm) : t = LamTerm.mkLamFN t.getLamBody t.getLamTys := by
  induction t <;> try rfl
  case lam s body IH =>
    dsimp [getLamBody, getLamTys]; dsimp [mkLamFN]; rw [← IH]

def LamTerm.getLamBodyN (n : Nat) (t : LamTerm) : Option LamTerm :=
  match n with
  | .zero => t
  | .succ n' =>
    match t with
    | .lam _ body => getLamBodyN n' body
    | _ => .none

theorem LamTerm.maxEVarSucc_getLamBodyN
  (heq : LamTerm.getLamBodyN n t = .some t') :
  t'.maxEVarSucc = t.maxEVarSucc := by
  induction n generalizing t t'
  case zero => cases heq; rfl
  case succ n IH =>
    cases t <;> try cases heq
    case lam s body =>
      dsimp [getLamBodyN] at heq; dsimp [maxEVarSucc]; apply IH heq

theorem LamTerm.getLamBodyN_mkLamFN_length_eq
  (h : l.length = n) : getLamBodyN n (mkLamFN t l) = .some t := by
  induction n generalizing l t
  case zero => cases l <;> cases h; rfl
  case succ n IH =>
    cases l <;> cases h
    case refl s' l =>
      dsimp [mkLamFN, getLamBodyN]
      dsimp [Nat.add] at IH; apply IH; rfl

def LamTerm.getLamTysN (n : Nat) (t : LamTerm) : Option (List LamSort) :=
  match n with
  | .zero => .some []
  | .succ n' =>
    match t with
    | .lam argTy body => (getLamTysN n' body).bind (List.cons argTy ·)
    | _ => .none

theorem LamTerm.getLamTysN_getLamBodyN_eq_some :
  (getLamTysN n t).isSome = (getLamBodyN n t).isSome := by
  induction n generalizing t
  case zero => rfl
  case succ n IH =>
    dsimp [getLamTysN, getLamBodyN]; cases t <;> try rfl
    case lam s body => dsimp; rw [← IH]; cases getLamTysN n body <;> rfl

theorem LamTerm.getLamTysN_eq_some_of_getLamBodyN_eq_some
  (heq : getLamBodyN n t = .some body) : ∃ l, getLamTysN n t = .some l := by
  apply Option.isSome_iff_exists.mp; rw [getLamTysN_getLamBodyN_eq_some]
  apply Option.isSome_iff_exists.mpr; exists body

theorem LamTerm.getLamBodyN_eq_some_of_getLamTysN_eq_some
  (heq : getLamTysN n t = .some l) : ∃ body, getLamBodyN n t = .some body := by
  apply Option.isSome_iff_exists.mp; rw [← getLamTysN_getLamBodyN_eq_some]
  apply Option.isSome_iff_exists.mpr; exists l

theorem LamTerm.getLamTysN_getLamBodyN_eq_none :
  (getLamTysN n t).isNone = (getLamBodyN n t).isNone := by
  rw [Option.isNone_eq_not_isSome, Option.isNone_eq_not_isSome]
  rw [getLamTysN_getLamBodyN_eq_some]

theorem LamTerm.getLamTysN_getLamBodyN_eq
  (hTys : getLamTysN n t = .some l) (hBody : getLamBodyN n t = .some body) :
  t = body.mkLamFN l := by
  induction n generalizing t body l
  case zero => cases hTys; cases hBody; rfl
  case succ n IH =>
    cases t <;> try cases hTys
    case lam s body' =>
      dsimp [getLamTysN] at hTys; dsimp [getLamBodyN] at hBody
      cases h₁ : getLamTysN n body' <;> rw [h₁] at hTys <;> cases hTys
      case refl l' =>
        dsimp [mkLamFN]; rw [← IH h₁ hBody]

theorem LamTerm.getLamTysN_mkLamFN_eq_l_iff :
  getLamTysN n (mkLamFN t l) = .some l ↔ l.length = n := by
  induction n generalizing t l
  case zero =>
    dsimp [getLamTysN]; apply Iff.intro
    case mp => intro h; cases l <;> cases h; rfl
    case mpr => intro h; cases l <;> cases h; rfl
  case succ n IH =>
    dsimp [getLamTysN]; cases l
    case nil =>
      dsimp [mkLamFN]; apply Iff.intro
      case mp =>
        cases t <;> intro h <;> try cases h
        case lam s body =>
          dsimp at h; cases h₁ : getLamTysN n body <;> rw [h₁] at h <;> cases h
      case mpr =>
        intro h; cases h
    case cons s' l =>
      dsimp [mkLamFN]; cases h₁ : getLamTysN n (mkLamFN t l)
      case none => simp; intro h; rw [IH.mpr h] at h₁; cases h₁
      case some l' =>
        simp; apply Iff.intro
        case mp => intro h; cases h; apply IH.mp h₁
        case mpr => intro h; have h₂ := (IH (t:=t)).mpr h; rw [h₁] at h₂; cases h₂; rfl

def LamTerm.getAppFn : LamTerm → LamTerm
| .app _ fn _ => getAppFn fn
| t           => t

theorem LamTerm.maxEVarSucc_getAppFn : (LamTerm.getAppFn t).maxEVarSucc ≤ t.maxEVarSucc := by
  induction t <;> try apply Nat.le_refl
  case app s fn arg IHFn _ =>
    dsimp [getAppFn]; apply Nat.le_trans IHFn; apply Nat.le_max_left

def LamTerm.isHeadBetaTarget (t : LamTerm) :=
  t.isApp && t.getAppFn.isLam

def LamTerm.getAppArgsAux (args : List (LamSort × LamTerm)) : LamTerm → List (LamSort × LamTerm)
| .app s fn arg => getAppArgsAux ((s, arg) :: args) fn
| _             => args

theorem LamTerm.getAppArgsAux_eq : getAppArgsAux args t = getAppArgsAux [] t ++ args := by
  induction t generalizing args <;> try rfl
  case app s fn arg IHFn _ =>
    dsimp [getAppArgsAux]; rw [IHFn (args:=(s, arg) :: args), IHFn (args:=[(s, arg)])]
    rw [List.append_assoc]; rfl

theorem LamTerm.maxEVarSucc_getAppArgsAux
  (hs : HList (fun (_, arg) => arg.maxEVarSucc ≤ n) args) (ht : t.maxEVarSucc ≤ n) :
  HList (fun (_, arg) => arg.maxEVarSucc ≤ n) (LamTerm.getAppArgsAux args t) := by
  induction t generalizing args <;> try exact hs
  case app s fn arg IHFn IHArg =>
    dsimp [maxEVarSucc] at ht; rw [Nat.max_le] at ht
    exact IHFn (.cons ht.right hs) ht.left

def LamTerm.getAppArgs := getAppArgsAux []

theorem LamTerm.getAppArgs_app : getAppArgs (.app s fn arg) = getAppArgs fn ++ [(s, arg)] := by
  dsimp [getAppArgs, getAppArgsAux]; rw [getAppArgsAux_eq]

theorem LamTerm.maxEVarSucc_getAppArgs :
  HList (fun (_, arg) => arg.maxEVarSucc ≤ t.maxEVarSucc) (LamTerm.getAppArgs t) :=
  LamTerm.maxEVarSucc_getAppArgsAux .nil (Nat.le_refl _)

theorem LamTerm.appFn_appArg_eqAux (args : List (LamSort × LamTerm)) (t : LamTerm) :
  LamTerm.mkAppN t args = LamTerm.mkAppN t.getAppFn (t.getAppArgsAux args) := by
  induction t generalizing args <;> try rfl
  case app s _ arg IHFn _ => apply IHFn ((s, arg) :: args)

theorem LamTerm.appFn_appArg_eq (t : LamTerm) : t = LamTerm.mkAppN t.getAppFn t.getAppArgs := appFn_appArg_eqAux [] t

def LamTerm.getAppFnN (n : Nat) (t : LamTerm) : Option LamTerm :=
  match n with
  | .zero => t
  | .succ n =>
    match t with
    | .app _ fn _ => getAppFnN n fn
    | _ => .none

theorem LamTerm.getAppFnN_add : getAppFnN (n + m) t = (getAppFnN n t).bind (getAppFnN m) := by
  induction n generalizing m t
  case zero => rw [Nat.zero_add]; rfl
  case succ n IH =>
    rw [Nat.succ_add]; cases t <;> try rfl
    case app s fn arg => dsimp [getAppFnN]; rw [IH]

theorem LamTerm.getAppFnN_succ' : getAppFnN (.succ n) t = (getAppFnN n t).bind (getAppFnN 1) := by
  rw [Nat.succ_eq_add_one]; rw [getAppFnN_add]

theorem LamTerm.maxEVarSucc_getAppFnN (heq : LamTerm.getAppFnN n t = .some t') :
  t'.maxEVarSucc ≤ t.maxEVarSucc := by
  induction n generalizing t t'
  case zero => cases heq; apply Nat.le_refl
  case succ n IH =>
    cases t <;> try cases heq
    case app s fn arg =>
      dsimp [getAppFnN] at heq; dsimp [maxEVarSucc]; apply Nat.le_trans _ (Nat.le_max_left _ _)
      apply IH heq

def LamTerm.getAppArgsNAux (n : Nat) (args : List (LamSort × LamTerm)) (t : LamTerm) : Option (List (LamSort × LamTerm)) :=
  match n with
  | .zero => args 
  | .succ n =>
    match t with
    | .app s fn arg => getAppArgsNAux n ((s, arg) :: args) fn
    | _ => .none

theorem LamTerm.getAppArgsNAux_eq : getAppArgsNAux n args t = (getAppArgsNAux n [] t).bind (· ++ args) := by
  induction n generalizing t args
  case zero => rfl
  case succ n IH =>
    cases t <;> try rfl
    case app s fn arg =>
      dsimp [getAppArgsNAux]; rw [IH (args:=(s, arg) :: args), IH (args:=[(s, arg)])]
      cases getAppArgsNAux n [] fn <;> dsimp
      rw [List.append_assoc]; rfl

theorem LamTerm.maxEVarSucc_getAppArgsNAux
  (hs : HList (fun (_, arg) => arg.maxEVarSucc ≤ m) args) (ht : t.maxEVarSucc ≤ m)
  (heq : LamTerm.getAppArgsNAux n args t = .some args') :
  HList (fun (_, arg) => arg.maxEVarSucc ≤ m) args' := by
  induction n generalizing t args args'
  case zero => cases heq; exact hs
  case succ n IH =>
    cases t <;> try cases heq
    case app s fn arg =>
      dsimp [getAppArgsNAux] at heq; dsimp [maxEVarSucc]; dsimp [maxEVarSucc] at ht
      rw [Nat.max_le] at ht; apply IH (.cons _ hs) ht.left heq; apply ht.right

def LamTerm.getAppArgsN n := getAppArgsNAux n []

theorem LamTerm.maxEVarSucc_getAppArgsN
  (heq : LamTerm.getAppArgsN n t = .some l) :
  HList (fun (_, arg) => arg.maxEVarSucc ≤ t.maxEVarSucc) l :=
  LamTerm.maxEVarSucc_getAppArgsNAux .nil (Nat.le_refl _) heq

theorem LamTerm.getAppArgsN_zero : LamTerm.getAppArgsN 0 = fun _ => .some [] := rfl

theorem LamTerm.getAppArgsN_succ_app :
  LamTerm.getAppArgsN (.succ n) (.app s fn arg) = (getAppArgsN n fn).bind (· ++ [(s, arg)]) := by
  dsimp [getAppArgsN, getAppArgsNAux]; rw [getAppArgsNAux_eq]

def LamTerm.bvarApps (t : LamTerm) (lctx : List LamSort) (idx : Nat) :=
  match lctx with
  | .nil => t
  | s :: lctx => .app s (bvarApps t lctx (.succ idx)) (.bvar idx)

theorem LamTerm.maxEVarSucc_bvarApps : (LamTerm.bvarApps t lctx idx).maxEVarSucc = t.maxEVarSucc := by
  induction lctx generalizing idx
  case nil => rfl
  case cons ty tys IH =>
    dsimp [bvarApps, maxEVarSucc]; rw [IH]; rw [Nat.max, Nat.max_comm, Nat.max_def]; simp

theorem LamTerm.maxLooseBVarSucc_bvarApps : (LamTerm.bvarApps t lctx idx).maxLooseBVarSucc ≤ max t.maxLooseBVarSucc (lctx.length + idx) := by
  induction lctx generalizing idx
  case nil => apply Nat.le_max_left
  case cons ty tys IH =>
    dsimp [bvarApps, maxLooseBVarSucc]; rw [Nat.max, Nat.max_le]; apply And.intro
    case left =>
      apply Nat.le_trans IH; rw [Nat.max_le]; apply And.intro (Nat.le_max_left _ _)
      apply Nat.le_trans _ (Nat.le_max_right _ _); rw [Nat.succ_add]; apply Nat.le_refl
    case right =>
      apply Nat.le_trans _ (Nat.le_max_right _ _); rw [Nat.succ_add]
      rw [Nat.succ_le_succ_iff]; apply Nat.le_add_left

def LamTerm.bvarAppsRev (t : LamTerm) (lctx : List LamSort) :=
  match lctx with
  | .nil => t
  | s :: lctx => bvarAppsRev (.app s t (.bvar lctx.length)) lctx

theorem LamTerm.maxEVarSucc_bvarAppsRev : (LamTerm.bvarAppsRev t lctx).maxEVarSucc = t.maxEVarSucc := by
  induction lctx generalizing t
  case nil => rfl
  case cons ty tys IH =>
    dsimp [maxEVarSucc, bvarAppsRev]; rw [IH]
    dsimp [maxEVarSucc]; rw [Nat.max, Nat.max_zero_right]

theorem LamTerm.maxLooseBVarSucc_bvarAppsRev : (LamTerm.bvarAppsRev t lctx).maxLooseBVarSucc = max t.maxLooseBVarSucc lctx.length := by
  induction lctx generalizing t
  case nil => apply Eq.symm; apply Nat.max_zero_right
  case cons ty tys IH =>
    dsimp [bvarAppsRev, maxLooseBVarSucc]; rw [IH]
    dsimp [maxLooseBVarSucc]; rw [Nat.max, ← Nat.max_assoc]
    rw [Nat.max_eq_left (b:=tys.length)]; apply Nat.le_succ

theorem LamTerm.getAppFnN_bvarAppsRev_length_eq
  (heq : l.length = n) : getAppFnN n (bvarAppsRev t l) = t := by
  induction n generalizing l t
  case zero => cases l <;> cases heq; rfl
  case succ n IH =>
    cases l <;> cases heq
    case refl s' l =>
      rw [getAppFnN_succ']; dsimp [bvarAppsRev]
      dsimp [Nat.add] at IH; rw [IH rfl]; rfl

def LamTerm.getForallEFBody (t : LamTerm) : LamTerm :=
  match t with
  | .app _ (.base (.forallE _)) (.lam _ body) => getForallEFBody body
  | _ => t

theorem LamTerm.maxEVarSucc_getForallEFBody : (LamTerm.getForallEFBody t).maxEVarSucc = t.maxEVarSucc := by
  generalize hsize' : t.size = n
  have hsize : t.size ≤ n := by cases hsize'; apply Nat.le_refl
  clear hsize'; induction n generalizing t
  case zero => have hnz := @size_ne_zero t; rw [Nat.le_zero.mp hsize] at hnz; cases hnz
  case succ n IH =>
    cases t <;> try rfl
    case app s fn arg =>
      cases fn <;> try rfl
      case base b =>
        cases b <;> try rfl
        case forallE s' =>
          cases arg <;> try rfl
          case lam s'' body =>
            dsimp [getForallEFBody, maxEVarSucc]
            rw [IH, Nat.max, Nat.max_zero_left]
            have hsize' := Nat.le_trans size_app_gt_size_arg hsize
            apply Nat.le_of_succ_le_succ (Nat.le_of_succ_le hsize')

def LamTerm.getForallEFTys (t : LamTerm) : List LamSort :=
  match t with
  | .app _ (.base (.forallE s)) (.lam _ body) => s :: getForallEFTys body
  | _ => []

def LamTerm.reprPrec (t : LamTerm) (n : Nat) :=
  let s :=
    match t with
    | .atom m => f!".atom {m}"
    | .etom m => f!".etom {m}"
    | .base b => f!".base {LamBaseTerm.reprPrec b 1}"
    | .bvar m => f!".bvar {m}"
    | .lam s t => f!".lam {LamSort.reprPrec s 1} {LamTerm.reprPrec t 1}"
    | .app s t₁ t₂ => f!".app {LamSort.reprPrec s 1} {LamTerm.reprPrec t₁ 1} {LamTerm.reprPrec t₂ 1}"
  if n == 0 then
    f!"Auto.Embedding.Lam.LamTerm" ++ s
  else
    f!"({s})"

instance : Repr LamTerm where
  reprPrec f n := LamTerm.reprPrec f n

def LamTerm.beq : LamTerm → LamTerm → Bool
| .atom n₁, .atom n₂ => n₁.beq n₂
| .etom n₁, .etom n₂ => n₁.beq n₂
| .base b₁, .base b₂ => b₁.beq b₂
| .bvar n₁, .bvar n₂ => n₁.beq n₂
| .lam s₁ t₁, .lam s₂ t₂ => s₁.beq s₂ && t₁.beq t₂
| .app s₁ fn₁ arg₁, .app s₂ fn₂ arg₂ => s₁.beq s₂ && fn₁.beq fn₂ && arg₁.beq arg₂
| _, _ => false

instance : BEq LamTerm where
  beq := LamTerm.beq

theorem LamTerm.beq_def {x y : LamTerm} : (x == y) = x.beq y := rfl

theorem LamTerm.beq_refl {t : LamTerm} : (t.beq t = true) := by
  induction t <;> dsimp [beq] <;> try apply Nat.beq_refl
  case base b => apply LamBaseTerm.beq_refl
  case lam s t IH => rw [LamSort.beq_refl, IH]; rfl
  case app s fn arg IHFn IHArg =>
    rw [LamSort.beq_refl, IHFn, IHArg]; rfl

theorem LamTerm.eq_of_beq_eq_true {t₁ t₂ : LamTerm} : (t₁.beq t₂ = true) → t₁ = t₂ := by
  induction t₁ generalizing t₂ <;> intro H <;> cases t₂ <;> try cases H
  case atom.atom n₁ n₂ => apply congrArg _ (Nat.eq_of_beq_eq_true H)
  case etom.etom n₁ n₂ => apply congrArg _ (Nat.eq_of_beq_eq_true H)
  case base.base b₁ b₂ => apply congrArg _ (LamBaseTerm.eq_of_beq_eq_true H)
  case bvar.bvar n₁ n₂ => apply congrArg _ (Nat.eq_of_beq_eq_true H)
  case lam.lam s₁ t₁ IH s₂ t₂ =>
    dsimp [beq] at H; rw [Bool.and_eq_true] at H
    have seq := LamSort.eq_of_beq_eq_true H.left
    have teq := IH H.right
    rw [seq, teq]
  case app.app s₁ fn₁ arg₁ IHFn IHArg s₂ fn₂ arg₂ =>
    dsimp [beq] at H; rw [Bool.and_eq_true] at H; rw [Bool.and_eq_true] at H
    let seq := LamSort.eq_of_beq_eq_true H.left.left
    let fneq := IHFn H.left.right
    let argeq := IHArg H.right
    rw [seq, fneq, argeq]

instance : LawfulBEq LamTerm where
  eq_of_beq := LamTerm.eq_of_beq_eq_true
  rfl := LamTerm.beq_refl

/--
  `LamTerm.containsSort` has a nice property :
  · Let `s` be a non-function type. If a term `t` satisfies
    `LamWF ltv ⟨lctx, t, s'⟩`, and `s` occurs in neither `t`
    nor `s'`, then for all atoms occurring in `t`, `s` does
    not occur in the atom's type.
  To see this, notice that the argument type is recorded
    in `.app`, and the binder type is recorded in `.lam`
-/
def LamTerm.containsSort (t : LamTerm) (s : LamSort) :=
  match t with
  | .atom _ => false
  | .etom _ => false
  | .base b => b.containsSort s
  | .bvar _ => false
  | .lam s' body => s'.contains s || body.containsSort s
  | .app s' fn arg => s'.contains s || fn.containsSort s || arg.containsSort s

-- Typecheck. `ltv, lctx ⊢ term : type?`
-- `ltv`          : LamTyVal
-- `Nat → LamSort` : Local Context
def LamTerm.lamCheck? (ltv : LamTyVal) :
  (Nat → LamSort) → LamTerm → Option LamSort
| _,    .atom n  => ltv.lamVarTy n
| _,    .etom n  => ltv.lamEVarTy n
| _,    .base b  => b.lamCheck ltv
| lctx, .bvar n  => lctx n
| lctx, .lam s t =>
  match t.lamCheck? ltv (pushLCtx s lctx) with
  | .some ty => .some (.func s ty)
  | .none    => .none
| lctx, .app s fn arg =>
  match fn.lamCheck? ltv lctx, arg.lamCheck? ltv lctx with
  | .some (.func ty₁ ty₂), .some argTy =>
    match ty₁.beq argTy, ty₁.beq s with
    | true, true => .some ty₂ 
    | _,    _    => none
  | _, _ => .none

theorem LamTerm.lamCheck?_irrelevence
  {ltv : LamTyVal} {lctx₁ lctx₂ : Nat → LamSort} {t : LamTerm}
  (hirr : ∀ n, n < t.maxLooseBVarSucc → lctx₁ n = lctx₂ n) :
  LamTerm.lamCheck? ltv lctx₁ t = LamTerm.lamCheck? ltv lctx₂ t := by
  induction t generalizing lctx₁ lctx₂ <;> dsimp [LamTerm.lamCheck?]
  case bvar n =>
    apply congrArg; apply hirr; exact .refl
  case lam s t IHt =>
    rw [IHt]; intros n hlt; cases n
    case zero => rfl
    case succ n =>
      dsimp [pushLCtx]; rw [hirr]; dsimp [maxLooseBVarSucc]
      apply Nat.le_pred_of_succ_le _ hlt;
      apply Nat.not_eq_zero_of_lt hlt
  case app s fn arg IHFn IHArg =>
    rw [IHFn]; rw [IHArg];
    intros n hlt; rw [hirr n (Nat.le_trans hlt (Nat.le_max_right _ _))]
    intros n hlt; rw [hirr n (Nat.le_trans hlt (Nat.le_max_left _ _))]

/--
  Judgement. `lamVarTy, lctx ⊢ term : type?`
  We put `rterm` before `rty` to avoid dependent elimination failure
-/
structure LamJudge where
  lctx   : Nat → LamSort
  rterm  : LamTerm
  rty    : LamSort
deriving Inhabited

inductive LamWF (ltv : LamTyVal) : LamJudge → Type
  | ofAtom
      {lctx : Nat → LamSort} (n : Nat) :
    LamWF ltv ⟨lctx, .atom n, ltv.lamVarTy n⟩
  | ofEtom
      {lctx : Nat → LamSort} (n : Nat) :
    LamWF ltv ⟨lctx, .etom n, ltv.lamEVarTy n⟩
  | ofBase
      {lctx : Nat → LamSort} {b : LamBaseTerm} {s : LamSort}
      (H : LamBaseTerm.LamWF ltv b s) :
    LamWF ltv ⟨lctx, .base b, s⟩
  | ofBVar
      {lctx : Nat → LamSort} (n : Nat) :
    LamWF ltv ⟨lctx, .bvar n, lctx n⟩
  | ofLam
      {lctx : Nat → LamSort}
      {argTy : LamSort} (bodyTy : LamSort) {body : LamTerm}
      (H : LamWF ltv ⟨pushLCtx argTy lctx, body, bodyTy⟩) :
    LamWF ltv ⟨lctx, .lam argTy body, .func argTy bodyTy⟩
  | ofApp
      {lctx : Nat → LamSort}
      (argTy : LamSort) {resTy : LamSort}
      {fn : LamTerm} {arg : LamTerm}
      (HFn : LamWF ltv ⟨lctx, fn, .func argTy resTy⟩)
      (HArg : LamWF ltv ⟨lctx, arg, argTy⟩) :
    LamWF ltv ⟨lctx, .app argTy fn arg, resTy⟩

def LamWF.unique {ltv : LamTyVal} :
  (lwf₁ : LamWF ltv ⟨lctx, t, s₁⟩) → (lwf₂ : LamWF ltv ⟨lctx, t, s₂⟩) →
  s₁ = s₂ ∧ HEq lwf₁ lwf₂
| .ofAtom _,  .ofAtom _  => And.intro rfl HEq.rfl
| .ofEtom _,  .ofEtom _  => And.intro rfl HEq.rfl
| .ofBase H₁, .ofBase H₂ => 
  have ⟨.refl _, .refl _⟩ := LamBaseTerm.LamWF.unique H₁ H₂
  And.intro rfl HEq.rfl
| .ofBVar _,  .ofBVar _  => And.intro rfl HEq.rfl
| .ofLam _ H₁, .ofLam _ H₂ =>
  have ⟨.refl _, .refl _⟩ := LamWF.unique H₁ H₂
  And.intro rfl HEq.rfl
| .ofApp _ HFn₁ HArg₁, .ofApp _ HFn₂ HArg₂ =>
  have ⟨.refl _, .refl _⟩ := LamWF.unique HFn₁ HFn₂
  have ⟨.refl _, .refl _⟩ := LamWF.unique HArg₁ HArg₂
  And.intro rfl HEq.rfl

def LamWF.lctxIrrelevance
  (hirr : ∀ n, n < t.maxLooseBVarSucc → lctx₁ n = lctx₂ n) :
  (lwf : LamWF ltv ⟨lctx₁, t, s⟩) → LamWF ltv ⟨lctx₂, t, s⟩
| .ofAtom _ => .ofAtom _
| .ofEtom _ => .ofEtom _
| .ofBase H => .ofBase H
| .ofBVar _ => hirr _ (Nat.le_refl _) ▸ .ofBVar _
| .ofLam bodyTy H => by
  apply LamWF.ofLam bodyTy (lctxIrrelevance _ H); intros n hlt
  cases n <;> try rfl
  case succ n =>
    apply hirr;
    apply Nat.le_pred_of_succ_le _ hlt
    apply Nat.not_eq_zero_of_lt hlt
| .ofApp argTy HFn HArg => .ofApp argTy
  (lctxIrrelevance (fun n H => hirr _ (Nat.le_trans H (Nat.le_max_left _ _))) HFn)
  (lctxIrrelevance (fun n H => hirr _ (Nat.le_trans H (Nat.le_max_right _ _))) HArg)

def LamWF.insertEVarAt_eIdx {ltv : LamTyVal} :
  LamWF {ltv with lamEVarTy := replaceAt s eIdx lamEVarTy'} ⟨lctx, .etom eIdx, s⟩ := by
  have : s = replaceAt s eIdx lamEVarTy' eIdx := by
    dsimp [replaceAt]; rw [Nat.beq_refl]
  conv =>
    arg 2; arg 3; rw [this]
  exact LamWF.ofEtom _

def LamWF.eVarIrrelevance
  (hLamVarTy : ltv₁.lamVarTy = ltv₂.lamVarTy)
  (hLamILTy : ltv₁.lamILTy = ltv₂.lamILTy)
  (hirr : ∀ n, n < t.maxEVarSucc → ltv₁.lamEVarTy n = ltv₂.lamEVarTy n) :
  (lwf : LamWF ltv₁ ⟨lctx, t, s⟩) → LamWF ltv₂ ⟨lctx, t, s⟩
| .ofAtom _ => hLamVarTy ▸ .ofAtom _
| .ofEtom _ => hirr _ (Nat.le_refl _) ▸ .ofEtom _
| .ofBase H => .ofBase (LamBaseTerm.LamWF.eVarIrrelevance hLamVarTy hLamILTy H)
| .ofBVar _ => .ofBVar _
| .ofLam bodyTy H => .ofLam bodyTy (eVarIrrelevance hLamVarTy hLamILTy hirr H)
| .ofApp argTy HFn HArg => .ofApp argTy
  (eVarIrrelevance hLamVarTy hLamILTy (fun n H => hirr _ (Nat.le_trans H (Nat.le_max_left _ _))) HFn)
  (eVarIrrelevance hLamVarTy hLamILTy (fun n H => hirr _ (Nat.le_trans H (Nat.le_max_right _ _))) HArg)

def LamWF.getAtom {ltv : LamTyVal}
  (wft : LamWF ltv ⟨lctx, .atom n, s⟩) : ltv.lamVarTy n = s :=
  match wft with
  | .ofAtom _ => rfl

def LamWF.getEtom {ltv : LamTyVal}
  (wft : LamWF ltv ⟨lctx, .etom n, s⟩) : ltv.lamEVarTy n = s :=
  match wft with
  | .ofEtom _ => rfl

def LamWF.getBase {ltv : LamTyVal}
  (wft : LamWF ltv ⟨lctx, .base b, s⟩) : LamBaseTerm.LamWF ltv b s :=
  match wft with
  | .ofBase H => H

def LamWF.getBVar {ltv : LamTyVal}
  (wft : LamWF ltv ⟨lctx, .bvar n, s⟩) : lctx n = s :=
  match wft with
  | .ofBVar _ => rfl

def LamWF.getLam {ltv : LamTyVal}
  (wft : LamWF ltv ⟨lctx, .lam s body, .func s argTy⟩) : LamWF ltv ⟨pushLCtx s lctx, body, argTy⟩ :=
  match wft with
  | .ofLam _ HBody => HBody

def LamWF.getFn {ltv : LamTyVal}
  (wft : LamWF ltv ⟨lctx, .app argTy fn arg, resTy⟩) : LamWF ltv ⟨lctx, fn, .func argTy resTy⟩ :=
  match wft with
  | .ofApp _ HFn _ => HFn

def LamWF.getArg {ltv : LamTyVal}
  (wft : LamWF ltv ⟨lctx, .app argTy fn arg, resTy⟩) : LamWF ltv ⟨lctx, arg, argTy⟩ :=
  match wft with
  | .ofApp _ _ HArg => HArg

def LamWF.mkNot {ltv : LamTyVal}
  (wft : LamWF ltv ⟨lctx, t, .base .prop⟩) : LamWF ltv ⟨lctx, .mkNot t, .base .prop⟩ :=
  LamWF.ofApp _ (.ofBase .ofNot) wft

def LamWF.mkAnd {ltv : LamTyVal}
  (wft₁ : LamWF ltv ⟨lctx, t₁, .base .prop⟩) (wft₂ : LamWF ltv ⟨lctx, t₂, .base .prop⟩) :
  LamWF ltv ⟨lctx, .mkAnd t₁ t₂, .base .prop⟩ :=
  LamWF.ofApp _ (LamWF.ofApp _ (.ofBase .ofAnd) wft₁) wft₂

def LamWF.mkOr {ltv : LamTyVal}
  (wft₁ : LamWF ltv ⟨lctx, t₁, .base .prop⟩) (wft₂ : LamWF ltv ⟨lctx, t₂, .base .prop⟩) :
  LamWF ltv ⟨lctx, .mkOr t₁ t₂, .base .prop⟩ :=
  LamWF.ofApp _ (LamWF.ofApp _ (.ofBase .ofOr) wft₁) wft₂

def LamWF.mkImp {ltv : LamTyVal}
  (wft₁ : LamWF ltv ⟨lctx, t₁, .base .prop⟩) (wft₂ : LamWF ltv ⟨lctx, t₂, .base .prop⟩) :
  LamWF ltv ⟨lctx, .mkImp t₁ t₂, .base .prop⟩ :=
  LamWF.ofApp _ (LamWF.ofApp _ (.ofBase .ofImp) wft₁) wft₂

def LamWF.mkIff {ltv : LamTyVal}
  (wft₁ : LamWF ltv ⟨lctx, t₁, .base .prop⟩) (wft₂ : LamWF ltv ⟨lctx, t₂, .base .prop⟩) :
  LamWF ltv ⟨lctx, .mkIff t₁ t₂, .base .prop⟩ :=
  LamWF.ofApp _ (LamWF.ofApp _ (.ofBase .ofIff) wft₁) wft₂

def LamWF.mkEq {ltv : LamTyVal}
  (wft₁ : LamWF ltv ⟨lctx, t₁, s⟩) (wft₂ : LamWF ltv ⟨lctx, t₂, s⟩) :
  LamWF ltv ⟨lctx, .mkEq s t₁ t₂, .base .prop⟩ :=
  LamWF.ofApp _ (LamWF.ofApp _ (.ofBase (.ofEq _)) wft₁) wft₂

theorem LamWF.mkEq_sortEq (hwf : LamWF ltv ⟨lctx, .app s' (.app s'' (.base (.eq s)) t₁) t₂, rty⟩) :
  s' = s ∧ s'' = s ∧ rty = .base .prop :=
  match hwf with
  | .ofApp _ (.ofApp _ (.ofBase (.ofEq _)) _) _ => And.intro rfl (And.intro rfl rfl)

def LamWF.mkForallE {ltv : LamTyVal}
  (wfp : LamWF ltv ⟨lctx, p, .func s (.base .prop)⟩) :
  LamWF ltv ⟨lctx, .mkForallE s p, .base .prop⟩ := LamWF.ofApp _ (.ofBase (.ofForallE _)) wfp

def LamWF.mkForallEF {ltv : LamTyVal}
  (wfp : LamWF ltv ⟨pushLCtx s lctx, p, .base .prop⟩) :
  LamWF ltv ⟨lctx, .mkForallEF s p, .base .prop⟩ := LamWF.ofApp _ (.ofBase (.ofForallE _)) (.ofLam _ wfp)

def LamWF.fromMkForallEF {ltv : LamTyVal}
  (wf : LamWF ltv ⟨lctx, .mkForallEF s p, .base .prop⟩) :
  LamWF ltv ⟨pushLCtx s lctx, p, .base .prop⟩ := wf.getArg.getLam

def LamWF.mkAppN {s : LamSort}
  (wfFn : LamWF ltv ⟨lctx, f, s.mkFuncs (args.map Prod.fst)⟩)
  (wfArgs : HList (fun (s, t) => LamWF ltv ⟨lctx, t, s⟩) args) :
  LamWF ltv ⟨lctx, f.mkAppN args, s⟩ :=
  match wfArgs with
  | .nil => wfFn
  | .cons (tys:=args) HArg HArgs =>
    LamWF.mkAppN (args:=args) (.ofApp _ wfFn HArg) HArgs

def LamWF.fnWFOfMkAppN
  (wfApp : LamWF ltv ⟨lctx, f.mkAppN args, s⟩) :
  LamWF ltv ⟨lctx, f, s.mkFuncs (args.map Prod.fst)⟩ :=
  match args with
  | .nil => wfApp
  | .cons (argTy, arg) args =>
    (LamWF.fnWFOfMkAppN (args:=args) wfApp).getFn

def LamWF.argsWFOfMkAppN {f : LamTerm}
  (wfApp : LamWF ltv ⟨lctx, f.mkAppN args, s⟩) :
  HList (fun (s, t) => LamWF ltv ⟨lctx, t, s⟩) args :=
  match args with
  | .nil => .nil
  | .cons _ args =>
    have HFn := LamWF.fnWFOfMkAppN (args:=args) wfApp
    have HArgs := LamWF.argsWFOfMkAppN (args:=args) wfApp
    .cons HFn.getArg HArgs

def LamWF.getAppFn (wft : LamWF ltv ⟨lctx, t, rty⟩) :
  (fnTy : LamSort) × LamWF ltv ⟨lctx, t.getAppFn, fnTy⟩ :=
  match wft with
  | .ofAtom n => ⟨_, .ofAtom n⟩
  | .ofEtom n => ⟨_, .ofEtom n⟩
  | .ofBase H => ⟨_, .ofBase H⟩
  | .ofBVar n => ⟨_, .ofBVar n⟩
  | .ofLam s body => ⟨_, .ofLam s body⟩
  | .ofApp argTy wfFn wfArg => by
    dsimp [LamTerm.getAppFn]
    exact LamWF.getAppFn wfFn

def LamWF.getAppArgs
  (wfApp : LamWF ltv ⟨lctx, f, s⟩) :
  HList (fun (s, t) => LamWF ltv ⟨lctx, t, s⟩) f.getAppArgs :=
  match wfApp with
  | .ofAtom n => .nil
  | .ofEtom n => .nil
  | .ofBase H => .nil
  | .ofBVar n => .nil
  | .ofLam _ body => .nil
  | .ofApp argTy wfFn wfArg => by
    rw [LamTerm.getAppArgs_app]; apply HList.append
    case xs => exact wfFn.getAppArgs
    case ys => apply HList.cons _ .nil; exact wfArg

def LamWF.mkLamFN {ltv : LamTyVal}
  (wfp : LamWF ltv ⟨pushLCtxs ls.reverse lctx, p, s⟩) :
  LamWF ltv ⟨lctx, .mkLamFN p ls, LamSort.mkFuncs s ls⟩ :=
  match ls with
  | .nil => wfp
  | .cons s ls => by
    dsimp [LamTerm.mkLamFN]
    rw [List.reverse_cons, pushLCtxs_append_singleton] at wfp
    apply LamWF.ofLam; apply LamWF.mkLamFN (ls:=ls) wfp

def LamWF.fromMkLamFN {ltv : LamTyVal}
  (wfLam : LamWF ltv ⟨lctx, .mkLamFN p ls, LamSort.mkFuncs s ls⟩) :
  LamWF ltv ⟨pushLCtxs ls.reverse lctx, p, s⟩ :=
  match ls with
  | .nil => wfLam
  | .cons s ls => by
    dsimp [LamTerm.mkLamFN] at wfLam;
    rw [List.reverse_cons, pushLCtxs_append_singleton]
    apply LamWF.fromMkLamFN (ls:=ls); apply wfLam.getLam

def LamWF.fromMkLamFN_s_eq_mkFuncs_reverse {ltv : LamTyVal}
  (wfLam : LamWF ltv ⟨lctx, .mkLamFN p ls, s⟩) :
  (s' : LamSort) ×' (s = LamSort.mkFuncs s' ls) :=
  match ls with
  | .nil => ⟨s, rfl⟩
  | .cons argTy ls => by
    dsimp [LamTerm.mkLamFN] at wfLam; cases wfLam
    case ofLam _ wfBody =>
      have ⟨s', seq⟩ := fromMkLamFN_s_eq_mkFuncs_reverse wfBody
      exists s'; cases seq; rfl

def LamWF.mkForallEFN {ltv : LamTyVal}
  (wfp : LamWF ltv ⟨pushLCtxs ls.reverse lctx, p, .base .prop⟩) :
  LamWF ltv ⟨lctx, .mkForallEFN p ls, .base .prop⟩ :=
  match ls with
  | .nil => wfp
  | .cons s ls => by
    dsimp [LamTerm.mkForallEFN]
    rw [List.reverse_cons, pushLCtxs_append_singleton] at wfp
    apply LamWF.mkForallEF; apply LamWF.mkForallEFN (ls:=ls) wfp

def LamWF.fromMkForallEFN {ltv : LamTyVal}
  (wf : LamWF ltv ⟨lctx, .mkForallEFN p ls, .base .prop⟩) :
  LamWF ltv ⟨pushLCtxs ls.reverse lctx, p, .base .prop⟩ :=
  match ls with
  | .nil => wf
  | .cons s ls => by
    dsimp [LamTerm.mkForallEFN] at wf
    rw [List.reverse_cons, pushLCtxs_append_singleton]
    apply LamWF.fromMkForallEFN (ls:=ls); apply LamWF.fromMkForallEF wf

def LamWF.mkForallEFN' {ltv : LamTyVal}
  (wfp : LamWF ltv ⟨pushLCtxs ls lctx, p, .base .prop⟩) :
  LamWF ltv ⟨lctx, .mkForallEFN p ls.reverse, .base .prop⟩ := by
  apply LamWF.mkForallEFN; rw [List.reverse_reverse]; exact wfp

def LamWF.fromMkForallEFN' {ltv : LamTyVal}
  (wf : LamWF ltv ⟨lctx, .mkForallEFN p ls.reverse, .base .prop⟩) :
  LamWF ltv ⟨pushLCtxs ls lctx, p, .base .prop⟩ := by
  rw [← List.reverse_reverse (as:=ls)]; apply LamWF.fromMkForallEFN wf

def LamWF.mkExistE {ltv : LamTyVal}
  (wfp : LamWF ltv ⟨lctx, p, .func s (.base .prop)⟩) :
  LamWF ltv ⟨lctx, .mkExistE s p, .base .prop⟩ := LamWF.ofApp _ (.ofBase (.ofExistE _)) wfp

def LamWF.mkExistEF {ltv : LamTyVal}
  (wfp : LamWF ltv ⟨pushLCtx s lctx, p, .base .prop⟩) :
  LamWF ltv ⟨lctx, .mkExistEF s p, .base .prop⟩ := LamWF.ofApp _ (.ofBase (.ofExistE _)) (.ofLam _ wfp)

def LamWF.ofAtom' {ltv : LamTyVal} {lctx : Nat → LamSort} (n : Nat)
  (s : LamSort) (heq : ltv.lamVarTy n = s) : LamWF ltv ⟨lctx, .atom n, s⟩ := by
  rw [← heq]; apply LamWF.ofAtom

def LamWF.ofEtom' {ltv : LamTyVal} {lctx : Nat → LamSort} (n : Nat)
  (s : LamSort) (heq : ltv.lamEVarTy n = s) : LamWF ltv ⟨lctx, .etom n, s⟩ := by
  rw [← heq]; apply LamWF.ofEtom

def LamWF.ofBVar' {ltv : LamTyVal} {lctx : Nat → LamSort} (n : Nat)
  (s : LamSort) (heq : lctx n = s) : LamWF ltv ⟨lctx, .bvar n, s⟩ := by
  rw [← heq]; apply LamWF.ofBVar

def LamWF.bvarApps
  (wft : LamWF ltv ⟨pushLCtxs (List.reverseAux ex lctx) lctx', t, LamSort.mkFuncsRev s lctx⟩) :
  LamWF ltv ⟨pushLCtxs (List.reverseAux ex lctx) lctx', t.bvarApps lctx ex.length, s⟩ :=
  match lctx with
  | .nil => wft
  | .cons ty lctx =>
    let lctxr := pushLCtxs (List.reverseAux ex (ty::lctx)) lctx'
    .ofApp _ (LamWF.bvarApps (ex:=ty::ex) wft) (by
      have tyeq : ty = lctxr ex.length := by
        have exlt : List.length ex < List.length (List.reverse (ty :: ex)) := by
          rw [List.length_reverse]; apply Nat.le_refl
        dsimp; rw [← List.reverseAux, List.reverseAux_eq]
        rw [pushLCtxs_lt (by rw [List.length_append]; apply Nat.le_trans exlt (Nat.le_add_right _ _))]
        dsimp [List.getD]; rw [List.get?_append exlt];
        rw [List.get?_reverse _ (by dsimp [List.length]; apply Nat.le_refl _)]
        dsimp [List.length]; simp
      conv => enter [2, 3]; rw [tyeq]
      exact .ofBVar _)

private def LamWF.bvarAppsRev_Aux :
  LamWF ltv ⟨pushLCtxs (List.reverse lctx) (pushLCtx ty lctx'), LamTerm.bvar (List.length lctx), ty⟩ := by
  have tyeq : ty = pushLCtxs lctx.reverse (pushLCtx ty lctx') lctx.length := by
    rw [pushLCtxs_ge] <;> rw [List.length_reverse]
    rw [Nat.sub_self]; apply Nat.le_refl
  conv => enter [2, 3]; rw [tyeq]
  exact .ofBVar _

def LamWF.bvarAppsRev
  (wft : LamWF ltv ⟨pushLCtxs lctx.reverse lctx', t, LamSort.mkFuncs s lctx⟩) :
  LamWF ltv ⟨pushLCtxs lctx.reverse lctx', t.bvarAppsRev lctx, s⟩ :=
  match lctx with
  | .nil => wft
  | .cons ty lctx => by
    dsimp [LamTerm.bvarAppsRev]
    revert wft; rw [List.reverse_cons, pushLCtxs_append, pushLCtxs_singleton]
    intro wft; apply bvarAppsRev (.ofApp _ wft _); apply LamWF.bvarAppsRev_Aux

def LamWF.fromBVarAppsRev
  (wfAp : LamWF ltv ⟨pushLCtxs lctx.reverse lctx', t.bvarAppsRev lctx, s⟩) :
  LamWF ltv ⟨pushLCtxs lctx.reverse lctx', t, LamSort.mkFuncs s lctx⟩ :=
  match lctx with
  | .nil => wfAp
  | .cons ty lctx => by
    dsimp [LamTerm.bvarAppsRev] at wfAp; revert wfAp
    rw [List.reverse_cons, pushLCtxs_append, pushLCtxs_singleton]
    intro wfAp; have wfAp' := fromBVarAppsRev wfAp; exact wfAp'.getFn

def LamWF.ofLamTerm {ltv : LamTyVal} :
  {lctx : Nat → LamSort} → (t : LamTerm) → Option ((rty : LamSort) × LamWF ltv ⟨lctx, t, rty⟩)
| lctx, .atom n => .some ⟨ltv.lamVarTy n, .ofAtom n⟩
| lctx, .etom n => .some ⟨ltv.lamEVarTy n, .ofEtom n⟩
| lctx, .base b =>
  let bWF := LamBaseTerm.LamWF.ofLamBaseTerm ltv b
  .some ⟨bWF.fst, .ofBase bWF.snd⟩
| lctx, .bvar n => .some ⟨lctx n, .ofBVar n⟩
| lctx, .lam argTy body =>
  let bodyWf := @LamWF.ofLamTerm ltv (pushLCtx argTy lctx) body
  match bodyWf with
  | .some ⟨bodyTy, wf⟩ => .some ⟨.func argTy bodyTy, .ofLam bodyTy wf⟩
  | .none => .none
| lctx, .app s fn arg =>
  let fnWf := @LamWF.ofLamTerm ltv lctx fn
  let argWf := @LamWF.ofLamTerm ltv lctx arg
  match fnWf, argWf with
  | .some (⟨.func ty₁ ty₂, fnWf⟩), .some ⟨argTy, argWf⟩ =>
    match heq : ty₁.beq s, heqa : argTy.beq s with
    | true, true =>
      have tyEq := LamSort.eq_of_beq_eq_true heq
      have argTyEq := LamSort.eq_of_beq_eq_true heqa
      .some ⟨ty₂, .ofApp s (tyEq ▸ fnWf) (argTyEq ▸ argWf)⟩
    | _, _ => .none
  | _, _ => .none

-- Of course `ofLamTerm` is sound with respect to `LamWF`. So, we
--   only need to show that it's complete
def LamWF.complete {ltv : LamTyVal} :
  {j : LamJudge} → (wf : LamWF ltv j) → LamWF.ofLamTerm j.rterm = .some ⟨j.rty, wf⟩
| .(_), @LamWF.ofAtom _ lctx n => rfl
| .(_), @LamWF.ofEtom _ lctx n => rfl
| .(_), @LamWF.ofBase _ lctx b s h => by
  unfold ofLamTerm; rw [LamBaseTerm.lamWF_complete]
| .(_), @LamWF.ofBVar _ lctx n => rfl
| .(_), @LamWF.ofLam _ lctx argTy bodyTy body H => by
  unfold ofLamTerm;
  have IH := LamWF.complete H; simp at IH; rw [IH];
| .(_), @LamWF.ofApp _ lctx argTy resTy fn arg HFn HArg => by
  unfold ofLamTerm;
  have IHFn := LamWF.complete HFn
  have IHArg := LamWF.complete HArg
  simp at IHFn; simp at IHArg
  rw [IHFn]; rw [IHArg]; simp; rw [LamSort.beq_refl]

def LamTerm.lamCheck?_of_lamWF
  {ltv : LamTyVal} {lctx : Nat → LamSort} {t : LamTerm} {ty : LamSort} :
  LamWF ltv ⟨lctx, t, ty⟩ → t.lamCheck? ltv lctx = .some ty := by
  generalize JudgeEq : { lctx := lctx, rterm := t, rty := ty : LamJudge} = Judge 
  intro HWf; induction HWf generalizing lctx t ty <;>
    injection JudgeEq with lctx_eq rterm_eq rty_eq <;>
    rw [rterm_eq, rty_eq] <;> try rfl
  case ofBase lctx' b s H =>
    rw [lamCheck?]; rw [LamBaseTerm.lamCheck_of_LamWF H]
  case ofBVar lctx' n =>
    rw [lctx_eq]; rfl
  case ofLam lctx' argTy bodyTy body _ H_ih =>
    rw [lctx_eq];
    simp [lamCheck?]; rw [H_ih]; rfl
  case ofApp lctx' argTy resTy fn arg _ _ HFn_ih HArg_ih =>
    rw [lctx_eq]
    simp [lamCheck?];
    rw [@HFn_ih lctx' fn (LamSort.func argTy resTy)] <;> try rfl;
    rw [@HArg_ih lctx' arg argTy] <;> try rfl;
    simp [LamSort.beq_refl]

def LamWF.ofLamCheck? {ltv : LamTyVal} :
  {lctx : Nat → LamSort} → {t : LamTerm} → {ty : LamSort} →
  t.lamCheck? ltv lctx = .some ty → LamWF ltv ⟨lctx, t, ty⟩
| lctx, .atom n, ty, HCheck => by
  have HCheck' := Option.some.inj HCheck
  rw [← HCheck']; apply LamWF.ofAtom
| lctx, .etom n, ty, HCheck => by
  have HCheck' := Option.some.inj HCheck
  rw [← HCheck']; apply LamWF.ofEtom
| lctx, .base b, ty, HCheck => by
  simp [LamTerm.lamCheck?] at HCheck; exact LamWF.ofBase (LamBaseTerm.LamWF.ofCheck HCheck)
| lctx, .bvar n, ty, HCheck => by
  simp [LamTerm.lamCheck?] at HCheck; rw [← HCheck]; apply LamWF.ofBVar
| lctx, .lam argTy body, ty, HCheck => by
  dsimp [LamTerm.lamCheck?] at HCheck; revert HCheck
  cases CheckEq : LamTerm.lamCheck? ltv (pushLCtx argTy lctx) body
  case none => intro contra; cases contra
  case some bodyTy =>
    dsimp; intro tyEq; rw [← Option.some.inj tyEq]
    apply LamWF.ofLam; apply (ofLamCheck? CheckEq)
| lctx, .app s fn arg, ty, HCheck => by
  simp [LamTerm.lamCheck?] at HCheck; revert HCheck
  match CheckFnEq : LamTerm.lamCheck? ltv lctx fn, CheckArgEq : LamTerm.lamCheck? ltv lctx arg with
  | .some (LamSort.func ty₁ ty₂), .some argTy =>
    dsimp;
    cases heq : LamSort.beq ty₁ argTy <;> try (intro contra; cases contra)
    have heq' : ty₁ = argTy := LamSort.eq_of_beq_eq_true heq; cases heq'
    cases heqa : LamSort.beq ty₁ s <;> try (intro contra; cases contra)
    cases LamSort.eq_of_beq_eq_true heqa
    apply LamWF.ofApp (argTy:=s) (ofLamCheck? CheckFnEq) (ofLamCheck? CheckArgEq)
  | .some (LamSort.func _ _), .none => intro contra; cases contra
  | .some (LamSort.atom _), _ => intro contra; cases contra
  | .some (LamSort.base _), _ => intro contra; cases contra
  | .none, _ => intro contra; cases contra

theorem LamWF.ofNonemptyLamWF (H : Nonempty (LamWF ltv ⟨lctx, t, s⟩)) :
  LamWF ltv ⟨lctx, t, s⟩ := by
  cases h₁ : LamTerm.lamCheck? ltv lctx t
  case none =>
    apply False.elim; have ⟨wf⟩ := H
    have hChk := LamTerm.lamCheck?_of_lamWF wf
    rw [h₁] at hChk; cases hChk
  case some s' =>
    cases h₂ : s'.beq s
    case false =>
      apply False.elim; have ⟨wf⟩ := H
      have hChk := LamTerm.lamCheck?_of_lamWF wf
      rw [h₁] at hChk; rw [Option.some.inj hChk] at h₂
      rw [LamSort.beq_refl] at h₂; cases h₂
    case true =>
      rw [LamSort.eq_of_beq_eq_true h₂] at h₁
      apply LamWF.ofLamCheck? h₁

def LamWF.interp.{u} (lval : LamValuation.{u}) :
  (lctxTy : Nat → LamSort) → (lctxTerm : ∀ n, (lctxTy n).interp lval.tyVal) →
  (lwf : LamWF lval.toLamTyVal ⟨lctxTy, t, rty⟩) → rty.interp lval.tyVal
| _,      _       , .ofAtom n => lval.varVal n
| _,      _       , .ofEtom n => lval.eVarVal n
| _,      _       , .ofBase H => LamBaseTerm.LamWF.interp lval H
| lctxTy, lctxTerm, .ofBVar n => lctxTerm n
| lctxTy, lctxTerm, @LamWF.ofLam _ _ argTy _ body H =>
  fun (x : argTy.interp lval.tyVal) =>
    LamWF.interp lval (pushLCtx argTy lctxTy) (pushLCtxDep (rty:=lctxTy) x lctxTerm) H
| lctxTy, lctxTerm, .ofApp _ HFn HArg =>
  let mfn := LamWF.interp lval lctxTy lctxTerm HFn
  let marg := LamWF.interp lval lctxTy lctxTerm HArg
  mfn marg

theorem LamWF.interp_eq (lval : LamValuation.{u})
  {lctxTerm₁ : ∀ n, (lctxTy n).interp lval.tyVal}
  {lctxTerm₂ : ∀ n, (lctxTy n).interp lval.tyVal}
  (HLCtxTermEq : HEq lctxTerm₁ lctxTerm₂)
  (lwf₁ : LamWF lval.toLamTyVal ⟨lctxTy, t₁, rty⟩)
  (lwf₂ : LamWF lval.toLamTyVal ⟨lctxTy, t₂, rty⟩)
  (HTeq : t₁ = t₂) :
  LamWF.interp lval lctxTy lctxTerm₁ lwf₁ = LamWF.interp lval lctxTy lctxTerm₂ lwf₂ := by
  cases HTeq; cases HLCtxTermEq;
  have HUniq := LamWF.unique lwf₁ lwf₂
  rcases HUniq with ⟨⟨⟩, ⟨⟩⟩; rfl

theorem LamWF.interp_heq (lval : LamValuation.{u})
  {lctxTy₁ lctxTy₂ : Nat → LamSort} (HLCtxTyEq : lctxTy₁ = lctxTy₂)
  {lctxTerm₁ : ∀ n, (lctxTy₁ n).interp lval.tyVal}
  {lctxTerm₂ : ∀ n, (lctxTy₂ n).interp lval.tyVal}
  (HLCtxTermEq : HEq lctxTerm₁ lctxTerm₂)
  (lwf₁ : LamWF lval.toLamTyVal ⟨lctxTy₁, t₁, rty₁⟩)
  (lwf₂ : LamWF lval.toLamTyVal ⟨lctxTy₂, t₂, rty₂⟩)
  (HTeq : t₁ = t₂) :
  HEq (LamWF.interp lval lctxTy₁ lctxTerm₁ lwf₁) (LamWF.interp lval lctxTy₂ lctxTerm₂ lwf₂) := by
  cases HTeq; cases HLCtxTyEq; cases HLCtxTermEq;
  have HUniq := LamWF.unique lwf₁ lwf₂
  cases HUniq; case intro left right =>
    cases left; cases right; rfl

-- In most use cases, we would have `b = .prop`
theorem LamWF.interp_substLCtxTerm
  {wf : LamWF lval.toLamTyVal ⟨lctxTy, t, s⟩}
  {wf' : LamWF lval.toLamTyVal ⟨lctxTy', t, s⟩}
  {lctxTerm : ∀ n, (lctxTy n).interp lval.tyVal}
  {lctxTerm' : ∀ n, (lctxTy' n).interp lval.tyVal}
  (HLCtxTyEq : lctxTy = lctxTy') (HLCtxTermEq : HEq lctxTerm lctxTerm') :
  LamWF.interp lval lctxTy lctxTerm wf = LamWF.interp lval lctxTy' lctxTerm' wf' := by
  cases HLCtxTyEq; cases HLCtxTermEq; rcases (LamWF.unique wf wf') with ⟨_, ⟨⟩⟩; rfl 

-- In most use cases, we would have `b = .prop`
theorem LamWF.interp_substLCtxTerm_rec
  {wf : LamWF lval.toLamTyVal ⟨lctxTy, t, s⟩}
  {lctxTerm : ∀ n, (lctxTy n).interp lval.tyVal}
  {lctxTerm' : ∀ n, (lctxTy' n).interp lval.tyVal}
  (HLCtxTyEq : lctxTy = lctxTy') (HLCtxTermEq : HEq lctxTerm lctxTerm') :
  LamWF.interp lval lctxTy lctxTerm wf = LamWF.interp lval lctxTy' lctxTerm' (HLCtxTyEq ▸ wf) := by
  cases HLCtxTyEq; cases HLCtxTermEq; rfl

theorem LamWF.interp_substWF
  {wf wf' : LamWF lval.toLamTyVal ⟨lctxTy, t, s⟩}
  {lctxTerm : ∀ n, (lctxTy n).interp lval.tyVal} :
  LamWF.interp lval lctxTy lctxTerm wf = LamWF.interp lval lctxTy lctxTerm wf' :=
  LamWF.interp_substLCtxTerm rfl HEq.rfl

theorem LamWF.interp_prop_eqExists
  {wf : LamWF lval.toLamTyVal ⟨lctx, t, .base .prop⟩} :
  (∃ (wf : LamWF lval.toLamTyVal ⟨lctx, t, .base .prop⟩), GLift.down (LamWF.interp lval lctx lctxTerm wf)) =
  GLift.down (LamWF.interp lval lctx lctxTerm wf) :=
  propext (Iff.intro
    (fun ⟨wf', H'⟩ => Eq.mp (by
      apply congrArg; apply eq_of_heq; apply interp_heq <;> rfl) H')
    (fun H => ⟨wf, H⟩))

theorem LamWF.interp_prop_eqForall
  {wf : LamWF lval.toLamTyVal ⟨lctx, t, .base .prop⟩} :
  (∀ (wf : LamWF lval.toLamTyVal ⟨lctx, t, .base .prop⟩), GLift.down (LamWF.interp lval lctx lctxTerm wf)) =
  GLift.down (LamWF.interp lval lctx lctxTerm wf) :=
  propext (Iff.intro
    (fun H => H wf)
    (fun H wf => Eq.mp (by
      apply congrArg; apply eq_of_heq; apply interp_heq <;> rfl) H))

theorem LamWF.interp_atom
  {lval : LamValuation.{u}}
  (wft : LamWF lval.toLamTyVal ⟨lctxTy, .atom n, s⟩) {lctxTerm} :
  HEq (wft.interp lval lctxTy lctxTerm) (lval.varVal n) :=
  match wft with
  | .ofAtom _ => HEq.rfl

theorem LamWF.interp_etom
  {lval : LamValuation.{u}}
  (wft : LamWF lval.toLamTyVal ⟨lctxTy, .etom n, s⟩) {lctxTerm} :
  HEq (wft.interp lval lctxTy lctxTerm) (lval.eVarVal n) :=
  match wft with
  | .ofEtom _ => HEq.rfl

theorem LamWF.interp_base
  {lval : LamValuation.{u}}
  (wft : LamWF lval.toLamTyVal ⟨lctxTy, .base b, s⟩) {lctxTerm} :
  wft.interp lval lctxTy lctxTerm = wft.getBase.interp lval :=
  match wft with
  | .ofBase _ => rfl

theorem LamWF.interp_base'
  {lval : LamValuation.{u}}
  (wft : LamWF lval.toLamTyVal ⟨lctxTy, .base b, s⟩) {lctxTerm} :
  HEq (wft.interp lval lctxTy lctxTerm) (b.interp lval) :=
  match wft with
  | .ofBase _ => LamBaseTerm.interp_equiv _ _

theorem LamWF.interp_bvar
  {lval : LamValuation.{u}}
  (wft : LamWF lval.toLamTyVal ⟨lctxTy, .bvar n, s⟩) {lctxTerm} :
  HEq (wft.interp lval lctxTy lctxTerm) (lctxTerm n) :=
  match wft with
  | .ofBVar _ => HEq.rfl

theorem LamWF.interp_lam
  {lval : LamValuation.{u}}
  (wft : LamWF lval.toLamTyVal ⟨lctxTy, .lam argTy body, .func argTy resTy⟩) {lctxTerm} :
  wft.interp lval lctxTy lctxTerm = (fun x => wft.getLam.interp lval
    (pushLCtx argTy lctxTy) (pushLCtxDep x lctxTerm)) :=
  match wft with
  | .ofLam _ _ => rfl

theorem LamWF.interp_app
  {lval : LamValuation.{u}}
  (wft : LamWF lval.toLamTyVal ⟨lctxTy, .app argTy fn arg, s⟩) {lctxTerm} :
  wft.interp lval lctxTy lctxTerm = (wft.getFn.interp lval lctxTy lctxTerm) (wft.getArg.interp lval lctxTy lctxTerm) :=
  match wft with
  | .ofApp _ _ _ => rfl

theorem LamWF.interp_bvarAppsRev
  {lval : LamValuation.{u}}
  (wft : LamWF lval.toLamTyVal ⟨pushLCtxs lctxTy.reverse lctxTy', t, LamSort.mkFuncs s lctxTy⟩)
  (wfAp : LamWF lval.toLamTyVal ⟨pushLCtxs lctxTy.reverse lctxTy', t.bvarAppsRev lctxTy, s⟩)
  {valPre : HList (LamSort.interp lval.tyVal) lctxTy → LamSort.interp lval.tyVal s}
  {lctxTerm : HList (LamSort.interp lval.tyVal) lctxTy}
  {lctxTerm' : ∀ (n : Nat), (lctxTy' n).interp lval.tyVal}
  (ht : HEq (wft.interp lval _ (pushLCtxsDep lctxTerm.reverse lctxTerm')) (LamSort.curry valPre)) :
  HEq
    (LamWF.interp lval (pushLCtxs lctxTy.reverse lctxTy') (pushLCtxsDep lctxTerm.reverse lctxTerm') wfAp)
    (valPre lctxTerm) := by
  induction lctxTerm generalizing t lctxTy' lctxTerm'
  case nil =>
    apply HEq.trans _ ht; apply LamWF.interp_heq <;> rfl
  case cons lty lctxTy lterm lctxTerm IH =>
    dsimp [LamSort.mkFuncs_cons] at wft;
    rw [List.reverse_cons, pushLCtxs_append_singleton] at wft
    dsimp [LamTerm.bvarAppsRev] at wfAp
    rw [List.reverse_cons, pushLCtxs_append_singleton] at wfAp
    rw [interp_substLCtxTerm_rec (by rw [List.reverse_cons])
      (pushLCtxsDep_substxs _ _ _ (List.reverse_cons _ _) HList.reverse_cons)]
    rw [interp_substLCtxTerm_rec
      (pushLCtxs_append_singleton _ _ _) (pushLCtxsDep_append_singleton _ _ _)]
    rw [LamWF.interp_substWF (wf':=wfAp)]
    apply IH (LamWF.ofApp _ wft LamWF.bvarAppsRev_Aux)
    dsimp [interp]; apply HEq.trans (b:=LamSort.curry valPre lterm) <;> try rfl
    case h₁ =>
      apply heq_of_eq; apply congr
      case h₁ =>
        apply eq_of_heq; apply HEq.trans _ ht; apply heq_of_eq; apply interp_substLCtxTerm
        rw [List.reverse_cons, pushLCtxs_append_singleton]
        apply HEq.symm; apply HEq.trans _ (pushLCtxsDep_append_singleton _ _ _)
        apply pushLCtxsDep_substxs; rw [List.reverse_cons]; apply HList.reverse_cons
      case h₂ =>
        apply eq_of_heq; apply HEq.trans (LamWF.interp_bvar _)
        apply HEq.trans (pushLCtxsDep_ge _ (Nat.le_of_eq (List.length_reverse _)))
        rw [List.length_reverse, Nat.sub_self]; rfl

theorem LamWF.interp_eqForallEF
  {wf : LamWF lval.toLamTyVal ⟨pushLCtx s lctx, t, .base .prop⟩} :
  GLift.down (LamWF.interp lval lctx lctxTerm (.mkForallEF wf)) = (∀ x,
    GLift.down (LamWF.interp lval (pushLCtx s lctx) (pushLCtxDep x lctxTerm) wf)) := rfl

theorem LamWF.interp_eqForallEFN'
  {lval : LamValuation.{u}} {lctxTerm : ∀ n, (lctx n).interp lval.tyVal}
  {wf : LamWF lval.toLamTyVal ⟨pushLCtxs ls lctx, t, .base .prop⟩} :
  GLift.down (LamWF.interp lval lctx lctxTerm (.mkForallEFN' wf)) = (∀ xs,
    GLift.down (LamWF.interp lval (pushLCtxs ls lctx) (pushLCtxsDep xs lctxTerm) wf)) := by
  generalize LamWF.mkForallEFN' wf = wfMkF
  induction ls generalizing t
  case nil =>
    dsimp [mkForallEFN, interp]
    conv =>
      enter [2]; rw [IsomType.eqForall HList.nil_IsomType.{u + 1, u + 1, 0}]
      rw [PUnit.eqForall]; unfold HList.nil_IsomType; dsimp
      dsimp [pushLCtxs, pushLCtxsDep, Nat.blt, Nat.ble]
    apply congrArg; apply interp_substWF
  case cons s ls IH =>
    revert wfMkF; rw [List.reverse_cons, LamTerm.mkForallEFN_append_singleton]; intro wfMkF
    apply Eq.trans (IH (wf:=LamWF.fromMkForallEFN' wfMkF) _)
    conv =>
      enter [2]; rw [IsomType.eqForall HList.cons_IsomType]; rw [Prod.eqForall']
      unfold HList.cons_IsomType; dsimp; enter [xs, x]
    apply forall_congr; intro xs
    rw [interp_app, interp_base, interp_lam, eq_of_heq (LamBaseTerm.interp_equiv _ _)]
    apply forall_congr; intro x
    apply congrArg; apply eq_of_heq; apply interp_heq <;> try rfl
    case HLCtxTyEq => rw [pushLCtxs_cons]
    case HLCtxTermEq => apply HEq.symm; apply pushLCtxsDep_cons

theorem LamWF.interp_eqForallEFN
  {lval : LamValuation.{u}} {ls : List LamSort} {lctxTerm : ∀ n, (lctx n).interp lval.tyVal}
  {wf : LamWF lval.toLamTyVal ⟨pushLCtxs ls.reverse lctx, t, .base .prop⟩} :
  GLift.down (LamWF.interp lval lctx lctxTerm (.mkForallEFN wf)) = (∀ xs,
    GLift.down (LamWF.interp lval (pushLCtxs ls.reverse lctx) (pushLCtxsDep xs lctxTerm) wf)) := by
  apply Eq.trans _ interp_eqForallEFN'; apply congrArg
  apply eq_of_heq; apply interp_heq <;> try rfl
  rw [List.reverse_reverse]

theorem LamWF.interp_bvarApps
  {lval : LamValuation.{u}}
  (wft : LamWF lval.toLamTyVal ⟨pushLCtxs (List.reverseAux tyex lctx) lctx', t, LamSort.mkFuncsRev s lctx⟩)
  (wfAp : LamWF lval.toLamTyVal ⟨pushLCtxs (List.reverseAux tyex lctx) lctx', LamTerm.bvarApps t lctx (List.length tyex), s⟩)
  {valPre : HList (LamSort.interp lval.tyVal) lctx → LamSort.interp lval.tyVal s}
  {termex : HList (LamSort.interp lval.tyVal) tyex}
  {lctxTerm : HList (LamSort.interp lval.tyVal) lctx}
  {lctxTerm' : ∀ (n : Nat), (lctx' n).interp lval.tyVal}
  (ht : HEq (wft.interp lval _ (pushLCtxsDep (HList.reverseAux termex lctxTerm) lctxTerm')) (LamSort.curryRev valPre)) :
  HEq
    (LamWF.interp lval
      (pushLCtxs (List.reverseAux tyex lctx) lctx')
      (pushLCtxsDep (lctxty:=LamSort.interp lval.tyVal) (HList.reverseAux termex lctxTerm) lctxTerm')
      wfAp)
    (valPre lctxTerm) := by
  induction lctxTerm generalizing s tyex
  case nil =>
    apply HEq.trans _ ht; apply LamWF.interp_heq <;> rfl
  case cons lty lctx lx lctxTerm IH =>
    dsimp [LamSort.mkFuncsRev] at wft
    dsimp [LamTerm.bvarApps] at wfAp; cases wfAp; case ofApp HArg HFn =>
      dsimp [interp]; apply congr_hd_heq (f₂:=fun lx =>valPre (HList.cons lx lctxTerm)) (x₂:=lx) <;> try rfl
      case h₁ =>
        apply @IH (lty::tyex) (.func lty s) wft _ (fun lctxTerm lx => valPre (.cons lx lctxTerm)) (.cons lx termex) ht
      case h₂ =>
        apply HEq.trans (LamWF.interp_bvar _);
        clear s t wft valPre ht HFn HArg IH
        dsimp [pushLCtxs, pushLCtxsDep]
        have hlt : tyex.length < (tyex.reverseAux (lty :: lctx)).length := by
          rw [List.reverseAux_eq, List.length_append, List.length_reverse];
          dsimp [List.length]; rw [Nat.add_succ]; apply Nat.succ_le_succ_iff.mpr
          apply Nat.le_add_right
        rw [Eq.mp (Eq.symm Nat.blt_eq) hlt]; dsimp
        apply HEq.trans (b:=HList.getD (lctxTerm' 0) (HList.append (termex.reverseAux .nil) (.cons lx lctxTerm)) tyex.length)
        case h₁ =>
          apply HList.getD_heq <;> try rfl
          case htys => rw [List.reverseAux_eq_append]
          case hhl => apply HList.reverseAux_eq_append
        case h₂ =>
          apply HEq.trans (HList.getD_append_right _ _ ?left) ?right <;>
            rw [List.reverseAux_eq, List.append_nil, List.length_reverse]
          case left => apply Nat.le_refl
          case right => rw [Nat.sub_self]; rfl

theorem LamWF.interp_insertEVarAt_eIdx
  {lval : LamValuation.{u}} {val : LamSort.interp lval.tyVal ty}
  (lwf : LamWF {lval.toLamTyVal with lamEVarTy := replaceAt ty pos lamEVarTy'} ⟨lctxTy, .etom pos, rty⟩)
  {lctxTerm : ∀ (n : Nat), LamSort.interp lval.tyVal (lctxTy n)}
  {eVarVal' : (n : Nat) → LamSort.interp lval.tyVal (lamEVarTy' n)} :
  let lval' := {lval with lamEVarTy := replaceAt ty pos lamEVarTy',
                          eVarVal := replaceAtDep val pos eVarVal'}
  HEq (lwf.interp lval' lctxTy lctxTerm) val := by
  cases lwf; dsimp [interp, replaceAt, replaceAtDep]; rw [Nat.beq_refl]

theorem LamWF.interp_eVarIrrelevance
  (lval₁ : LamValuation.{u}) (lval₂ : LamValuation.{u})
  {lctxTy₁ lctxTy₂ : Nat → LamSort}
  {lctxTerm₁ : ∀ n, (lctxTy₁ n).interp lval₁.tyVal}
  {lctxTerm₂ : ∀ n, (lctxTy₂ n).interp lval₂.tyVal}
  {t : LamTerm} {rty : LamSort}
  (lwf₁ : LamWF lval₁.toLamTyVal ⟨lctxTy₁, t, rty⟩)
  (lwf₂ : LamWF lval₂.toLamTyVal ⟨lctxTy₂, t, rty⟩)
  (hLamVarTy : lval₁.lamVarTy = lval₂.lamVarTy)
  (hLamILTy : lval₁.lamILTy = lval₂.lamILTy)
  (hTyVal : HEq lval₁.tyVal lval₂.tyVal)
  (hVarVal : HEq lval₁.varVal lval₂.varVal)
  (hILVal : HEq lval₁.ilVal lval₂.ilVal)
  (hLCtxTy : lctxTy₁ = lctxTy₂)
  (hLCtxTerm : HEq lctxTerm₁ lctxTerm₂)
  (hirr : ∀ n, n < t.maxEVarSucc →
    lval₁.lamEVarTy n = lval₂.lamEVarTy n ∧ HEq (lval₁.eVarVal n) (lval₂.eVarVal n)) :
  HEq (LamWF.interp lval₁ lctxTy₁ lctxTerm₁ lwf₁) (LamWF.interp lval₂ lctxTy₂ lctxTerm₂ lwf₂) := by
  rcases lval₁ with ⟨⟨lamVarTy₁, lamILTy₁, lamEVarTy₁⟩, tyVal₁, varVal₁, ilVal₁, eVarVal₁⟩
  rcases lval₂ with ⟨⟨lamVarTy₂, lamILTy₂, lamEVarTy₂⟩, tyVal₂, varVal₂, ilVal₂, eVarVal₂⟩
  dsimp at hLamVarTy hLamILTy hTyVal hVarVal hILVal hirr
  cases hLamVarTy; cases hLamILTy; cases hTyVal
  cases hVarVal; cases hILVal; cases hLCtxTy; cases hLCtxTerm
  case refl.refl.refl.refl.refl.refl =>
    dsimp; dsimp at varVal₁ ilVal₁ eVarVal₁ lctxTerm₁ lwf₁ eVarVal₂ lwf₂
    induction t generalizing lctxTy₁ rty <;> try (cases lwf₁; cases lwf₂; rfl)
    case etom n =>
      cases lwf₁
      have htyeq : lamEVarTy₁ n = lamEVarTy₂ n := by
        apply (hirr _ _).left; exact .refl
      dsimp at lwf₂;
      let lwf₂' := htyeq ▸ lwf₂;
      let lval₂ : LamValuation := ⟨⟨lamVarTy₁, lamILTy₁, lamEVarTy₂⟩, tyVal₁, varVal₁, ilVal₁, eVarVal₂⟩
      apply HEq.trans _ (LamWF.interp_heq (lval:=lval₂) (lwf₁ := lwf₂') rfl HEq.rfl _ rfl)
      cases lwf₂'; dsimp [interp]; apply (hirr _ _).right; exact .refl
    case base b =>
      cases lwf₁; cases lwf₂; dsimp [interp]
      apply LamBaseTerm.LamWF.interp_lvalIrrelevance <;> rfl
    case lam s t IH =>
      cases lwf₁; case ofLam bodyTy₁ H₁ =>
        cases lwf₂; case ofLam H₂ =>
          dsimp [interp]; apply HEq.funext; intro x; apply IH
          exact hirr
    case app s fn arg IHFn IHArg =>
      cases lwf₁; case ofApp HArg₁ HFn₁ =>
        cases lwf₂; case ofApp HArg₂ HFn₂ =>
          dsimp [interp]; apply congr_h_heq <;> try rfl
          case h₁ =>
            apply IHFn; intros n hlt;
            apply (hirr n (Nat.le_trans hlt (Nat.le_max_left _ _)))
          case h₂ =>
            apply IHArg; intros n hlt;
            apply (hirr n (Nat.le_trans hlt (Nat.le_max_right _ _)))

theorem LamWF.interp_lctxIrrelevance
  (lval : LamValuation.{u}) {lctxTy₁ lctxTy₂ : Nat → LamSort}
  {lctxTerm₁ : ∀ n, (lctxTy₁ n).interp lval.tyVal}
  {lctxTerm₂ : ∀ n, (lctxTy₂ n).interp lval.tyVal}
  {t : LamTerm} {rty : LamSort}
  (lwf₁ : LamWF lval.toLamTyVal ⟨lctxTy₁, t, rty⟩)
  (lwf₂ : LamWF lval.toLamTyVal ⟨lctxTy₂, t, rty⟩)
  (hirr : ∀ n, n < t.maxLooseBVarSucc → 
    lctxTy₁ n = lctxTy₂ n ∧ HEq (lctxTerm₁ n) (lctxTerm₂ n)) :
  HEq (LamWF.interp lval lctxTy₁ lctxTerm₁ lwf₁) (LamWF.interp lval lctxTy₂ lctxTerm₂ lwf₂) := by
  induction t generalizing lctxTy₁ lctxTy₂ rty <;> try (cases lwf₁; cases lwf₂; rfl)
  case base b =>
    cases lwf₁; cases lwf₂; dsimp [interp]; apply LamBaseTerm.LamWF.interp_heq <;> rfl
  case bvar n =>
    cases lwf₁; dsimp [interp]
    have htyeq : lctxTy₁ n = lctxTy₂ n := by
      apply (hirr _ _).left; exact .refl
    rw [htyeq] at lwf₂; apply HEq.trans (b:=interp _ _ lctxTerm₂ lwf₂)
    case h₁ =>
      cases lwf₂; dsimp [interp]; apply (hirr _ _).right; exact .refl
    case h₂ =>
      apply interp_heq <;> rfl
  case lam s t IH =>
    cases lwf₁; case ofLam bodyTy₁ H₁ =>
      cases lwf₂; case ofLam H₂ =>
        dsimp [interp]; apply HEq.funext; intros x; apply IH
        intros n hlt; dsimp [pushLCtx, pushLCtxDep]
        cases n
        case zero => exact And.intro rfl HEq.rfl
        case succ n =>
          apply hirr;
          apply Nat.le_pred_of_succ_le _ hlt
          apply Nat.not_eq_zero_of_lt hlt
  case app s fn arg IHFn IHArg =>
    cases lwf₁; case ofApp HArg₁ HFn₁ =>
      cases lwf₂; case ofApp HArg₂ HFn₂ =>
        dsimp [interp]; apply congr_h_heq <;> try rfl
        case h₁ =>
          apply IHFn; intros n hlt;
          apply (hirr n (Nat.le_trans hlt (Nat.le_max_left _ _)))
        case h₂ =>
          apply IHArg; intros n hlt;
          apply (hirr n (Nat.le_trans hlt (Nat.le_max_right _ _)))

theorem LamTerm.forallEFBody_forallEFTys_eq (wft : LamWF ltv ⟨lctx, t, s⟩) :
  t = LamTerm.mkForallEFN t.getForallEFBody t.getForallEFTys := by
  generalize hsize' : t.size = n
  have hsize : t.size ≤ n := by cases hsize'; apply Nat.le_refl
  clear hsize'; induction n generalizing lctx t s
  case zero => have hnz := @size_ne_zero t; rw [Nat.le_zero.mp hsize] at hnz; cases hnz
  case succ n IH =>
    cases t <;> try rfl
    case app s fn arg =>
      cases fn <;> try rfl
      case base b =>
        cases b <;> try rfl
        case forallE s' =>
          cases arg <;> try rfl
          case lam s'' body =>
            dsimp [getForallEFTys, getForallEFBody, mkForallEFN]
            cases wft.getFn.getBase; cases wft.getArg
            case ofLam wfBody =>
              rw [← IH wfBody]; rfl
              have hsize' := Nat.le_trans size_app_gt_size_arg hsize
              apply Nat.le_of_succ_le_succ (Nat.le_of_succ_le hsize')

end Auto.Embedding.Lam