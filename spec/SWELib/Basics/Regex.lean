/-!
# Regular Expressions

Abstract syntax of POSIX Extended Regular Expressions (ERE) per IEEE 1003.1 §9.
Models the structure of regular expressions without a matching engine —
matching semantics belong to the code layer.
-/

namespace SWELib.Basics

/-- A character class element within a bracket expression. -/
inductive CharClass where
  /-- A literal character. -/
  | literal (c : Char) : CharClass
  /-- A character range, e.g. a-z. -/
  | range (lo hi : Char) : CharClass
  /-- A POSIX named class, e.g. [:alpha:], [:digit:]. -/
  | posix (name : String) : CharClass
  deriving DecidableEq, Repr

/-- Abstract syntax of an Extended Regular Expression (ERE). -/
inductive Regex where
  /-- Matches the empty string. -/
  | empty : Regex
  /-- Matches a single character. -/
  | char (c : Char) : Regex
  /-- Bracket expression: matches one character in (or not in) the class list. -/
  | charClass (cs : List CharClass) (negated : Bool) : Regex
  /-- Dot: matches any character except newline. -/
  | dot : Regex
  /-- Concatenation: r1 followed by r2. -/
  | seq (r1 r2 : Regex) : Regex
  /-- Alternation: r1 | r2. -/
  | alt (r1 r2 : Regex) : Regex
  /-- Kleene star: zero or more repetitions of r. -/
  | star (r : Regex) : Regex
  /-- One or more repetitions of r. -/
  | plus (r : Regex) : Regex
  /-- Zero or one occurrence of r. -/
  | opt (r : Regex) : Regex
  /-- Capturing group: (r). -/
  | group (r : Regex) : Regex
  deriving DecidableEq, Repr

/-- Can the regex match the empty string? -/
def Regex.isNullable : Regex → Bool
  | .empty       => true
  | .char _      => false
  | .charClass _ _ => false
  | .dot         => false
  | .seq r1 r2   => r1.isNullable && r2.isNullable
  | .alt r1 r2   => r1.isNullable || r2.isNullable
  | .star _      => true
  | .plus r      => r.isNullable
  | .opt _       => true
  | .group r     => r.isNullable

/-- Does the regex contain at least one capturing group? -/
def Regex.hasCaptures : Regex → Bool
  | .empty       => false
  | .char _      => false
  | .charClass _ _ => false
  | .dot         => false
  | .seq r1 r2   => r1.hasCaptures || r2.hasCaptures
  | .alt r1 r2   => r1.hasCaptures || r2.hasCaptures
  | .star r      => r.hasCaptures
  | .plus r      => r.hasCaptures
  | .opt r       => r.hasCaptures
  | .group _     => true

/-- Kleene star is always nullable. -/
theorem Regex.star_is_nullable (r : Regex) : (Regex.star r).isNullable = true := by
  simp [isNullable]

/-- Optional is always nullable. -/
theorem Regex.opt_is_nullable (r : Regex) : (Regex.opt r).isNullable = true := by
  simp [isNullable]

/-- Plus is nullable iff its operand is nullable. -/
theorem Regex.plus_nullable_iff (r : Regex) :
    (Regex.plus r).isNullable = r.isNullable := by
  simp [isNullable]

end SWELib.Basics
