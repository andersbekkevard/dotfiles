---
name: codebase-design
description: Shared vocabulary for designing deep modules. Use when the user wants to design or improve a module's interface, find deepening opportunities, decide where a seam goes, make code more testable or AI-navigable, or when another skill needs the deep-module vocabulary.
---

# Codebase design

Design **deep modules** that put a lot of behaviour behind a small interface. Place each module at a clean seam and test it through that interface. Use this language and these principles wherever code is being designed or restructured. The aim is leverage for callers, locality for maintainers, and testability for everyone.

## Glossary

Use these terms exactly. Don't substitute "component," "service," "API," or "boundary." Consistent language is the whole point.

**Module.** Anything with an interface and an implementation. Deliberately scale-agnostic: a function, class, package, or tier-spanning slice. _Avoid_: unit, component, service.

**Interface.** Everything a caller must know to use the module correctly: the type signature, invariants, ordering constraints, error modes, required configuration, and performance characteristics. _Avoid_: API, signature. Those terms refer only to the type-level interface.

**Implementation.** What's inside a module, its body of code. Distinct from **Adapter**. A thing can be a small adapter with a large implementation, such as a Postgres repo, or a large adapter with a small implementation, such as an in-memory fake. Reach for "adapter" when the seam is the topic and "implementation" otherwise.

**Depth.** Leverage at the interface: the amount of behaviour a caller or test can exercise per unit of interface they have to learn. A module is **deep** when a large amount of behaviour sits behind a small interface, and **shallow** when the interface is nearly as complex as the implementation.

**Seam** _(Michael Feathers)._ A place where you can alter behaviour without editing in that place. It is the *location* at which a module's interface lives. Where to put the seam is its own design decision, distinct from what goes behind it. _Avoid_: boundary, which is overloaded with DDD's bounded context.

**Adapter.** A concrete thing that satisfies an interface at a seam. Describes *role*, meaning what slot it fills, rather than substance, meaning what's inside.

**Leverage.** What callers get from depth: more capability per unit of interface they learn. One implementation pays back across N call sites and M tests.

**Locality.** What maintainers get from depth: change, bugs, knowledge, and verification concentrate in one place rather than spreading across callers. Fix once, fixed everywhere.

## Deep vs shallow

**Deep module** = small interface + lots of implementation:

```
┌─────────────────────┐
│   Small Interface   │  ← Few methods, simple params
├─────────────────────┤
│                     │
│  Deep Implementation│  ← Complex logic hidden
│                     │
└─────────────────────┘
```

**Shallow module** = large interface + little implementation. Avoid this shape:

```
┌─────────────────────────────────┐
│       Large Interface           │  ← Many methods, complex params
├─────────────────────────────────┤
│  Thin Implementation            │  ← Just passes through
└─────────────────────────────────┘
```

When designing an interface, ask:

- Can I reduce the number of methods?
- Can I simplify the parameters?
- Can I hide more complexity inside?

## Principles

- **Depth is a property of the interface, not the implementation.** A deep module can be internally composed of small, mockable, swappable parts. They just aren't part of the interface. A module can have **internal seams**, private to its implementation and used by its own tests, as well as the **external seam** at its interface.
- **The deletion test.** Imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep.
- **Test through the interface.** Callers and tests cross the same seam. If you want to test *past* the interface, the module is probably the wrong shape.
- **One adapter means a hypothetical seam. Two adapters means a real one.** Introduce a seam when something actually varies across it.

## Designing for testability

Good interfaces make testing natural:

1. **Accept dependencies instead of creating them.**

   ```typescript
   // Testable
   function processOrder(order, paymentGateway) {}

   // Hard to test
   function processOrder(order) {
     const gateway = new StripeGateway();
   }
   ```

2. **Return results instead of producing side effects.**

   ```typescript
   // Testable
   function calculateDiscount(cart): Discount {}

   // Hard to test
   function applyDiscount(cart): void {
     cart.total -= discount;
   }
   ```

3. **Keep the interface small.** Fewer methods require fewer tests. Fewer params make test setup simpler.

## Relationships

- A **Module** has exactly one **Interface**, which it presents to callers and tests.
- **Depth** is a property of a **Module**, measured against its **Interface**.
- A **Seam** is where a **Module**'s **Interface** lives.
- An **Adapter** sits at a **Seam** and satisfies the **Interface**.
- **Depth** produces **Leverage** for callers and **Locality** for maintainers.

## Rejected framings

- **Depth as ratio of implementation-lines to interface-lines** (Ousterhout): rewards padding the implementation. We use depth-as-leverage instead.
- **"Interface" as the TypeScript `interface` keyword or a class's public methods**: too narrow. Interface here includes every fact a caller must know.
- **"Boundary"**: overloaded with DDD's bounded context. Say **seam** or **interface**.

## Going deeper

- **Deepening a cluster given its dependencies.** See [DEEPENING.md](DEEPENING.md) for dependency categories, seam discipline, and replace-don't-layer testing.
- **Exploring alternative interfaces.** See [DESIGN-IT-TWICE.md](DESIGN-IT-TWICE.md) to spin up parallel sub-agents, design the interface several radically different ways, then compare depth, locality, and seam placement.
