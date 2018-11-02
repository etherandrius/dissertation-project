# Journal

Quick notes on milestones/features/problems/bugs during implementation.

## TODO

- Use `Qualified` for all types: only way to handle data constructors properly. When assigning a data constructor
  expression to a pattern, use `simplify` to pull a subset of the predicates from the expression qualifiers to the
  pattern matched variable qualifiers.
- Wording change: instantiated/uninstantiated -> concrete/scheme?
- Need to unique-ify type scheme variables too? Otherwise eg. `A a, B a => (a, a -> a)` is ambiguous if the `a`'s came
  from different original types when constructing the tuple.
- ~~Need to handle assigning a type scheme to a variable: `x = \y -> y` should make `x` be a type scheme, but then it
  needs to handle eg. `x = \y -> y < y` which requires `x` to somehow carry the context of `Ord a`~~. Maybe solved by
  using `Qualified` for everything.
- Make sure functions defined in `let` statements are deinstantiated to make them polymorphic - same applies for
  lambdas??????
- Optimise finding the predicates for each type: `Map Id [ClassName]`?
- Initial static analysis pass to extract datatypes/class hierarchies etc. Topological sort/dependency analysis?
- Rewrite to use `Text` instead of `String`.

## Type Checking

The approach used on this branch doesn't work: say we have an instantiated type `t1` and an uninstantiated type
`t2`: what type does the pair `(t1, t2)` have?

Consensus from the development of GHC's typechecker that using **references** instead of substitutions and pain is worth
it.

- thih.pdf is generally okay but is noticeably aged. Spent quite a bit of time polishing things up from it (moving from
  lists to sets etc).
- ~~Rather than using the hacky runtime-level approach to instantiating variables, converted it into a type-level
  approach. *demonstrate problems when unifying with local variables*, now this can never happen because globally unique
  variables enforced at the type level whooo~~. This **doesn't work** :(. A tuple containing a function and a variable
  needs to have a type combining uninstantiated and instantiated types.
- Check for eg. `Num Bool` problems at the end, when converting to HNF.
- Type classes have heavy impact on the code gen stage, not just type level stuff. Need to instantiate eg. the `+`
  operator to use addition on the type used at the call site. Function resolution has to be done at **runtime**, not
  **compile time** - eg. for polymorphic functions, don't know what we're going to be given in advance.
- ~~When inferring the type of a function application, need to use `match` instead of `mgu`. Otherwise can end up unifying
  the type variables from the function, rather than from the expression, which allows for expressions like `(+) 1 2 3`
  to type check (see [`sketches/match_not_mgu.jpg`](sketches/match_not_mgu.jpg))~~. Actually do use `mgu` - check the
  type of `(+) 1 2` vs `(+) 1 2 3` in GHCi, looks like Haskell infers that there must be a `Num` instance that's a
  function, in order for `3` to be the argument to the `Num` instance.
- No defaulting atm - unnecessary complexity, weird language feature.
- More scalable/local/modular approach? `OutsideIn(X)` claims to be a solution.
- Dealing with typeclasses during inference: if we make a substitution `a/t` then:
  - If `a` is a type variable then simply substitute `a` for `t` in all of `t`'s constraints and add them to `a`'s
    constraints.
  - If `a` is a type constant then unify the head of each constraint with `a` and recurse on sub-type variables.