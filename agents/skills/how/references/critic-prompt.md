# Critic prompt

Review the architecture described in the supplied explanation. Treat the
explanation as orientation and the supplied source as authority.

Find architectural problems rather than line-level bugs or style preferences.
Ask whether the subsystem is well-shaped for its current responsibilities and
plausible evolution. Suggest no rewrite without first demonstrating a problem.
An empty critique is valid.

For each finding return:

1. **Severity:** `structural`, `concern`, or `observation`.
2. **Finding:** the specific boundary, model, or coupling problem.
3. **Evidence:** exact supplied source references that demonstrate it.
4. **Impact:** the practical cost to correctness, change, testing, performance,
   or comprehension.

Avoid generic requests for more abstraction, criticism of deliberate tradeoffs
without weighing their benefit, and claims unsupported by the source packet.
