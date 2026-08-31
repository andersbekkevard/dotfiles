# Project architecture pattern catalogue

Status: working hypotheses from Anders's current projects. This catalogue is
evidence, not a template. The agent applying `/project` owns the judgment to
copy, combine, simplify, critique, or reject a pattern for the repository in
front of it.

Keep this catalogue current as projects reveal better structures or failure
modes. Record where a pattern came from and whether it is proven practice,
stated intent, or still an open experiment. A project should not inherit a
folder, document type, or workflow merely because it appears here.

## How to reason about growth

Outline the information architecture before changing it. Work through the
questions in this order:

1. What distinct questions must the repository answer?
2. Which file, data set, code path, or external system currently owns each
   answer?
3. Which items are evidence, current knowledge, rationale, future intent,
   executable work, volatile state, or dated outcomes?
4. Where would an agent place a new item, and where would the next agent search
   for it?
5. Which combined owner is still simple, and which split would remove drift or
   irrelevant reading?
6. Which recurring failure can a rule, link check, lint, test, receipt, or
   deterministic script expose or repair?

Start combined. A small project may let one file both route and own current
knowledge. Split it when independent claims, update rhythms, rules, or reading
paths begin to interfere. At that point a Map routes without restating claims,
while a Note owns a current claim or coherent claim domain. This is a growth
path, not a requirement to create Maps and Notes on day one.

## Patterns seen across repositories

| Pattern | Pressure and transition | Context where it appeared |
|---|---|---|
| Cold-start router | One short entrypoint names the project, authority, reading route, and branches. Add nested routers only when independent areas need different rules or reading sets. | Training stays at one root router. MIT split into administration, courses, and spring. Seatankers and Odin route into packages and work areas. |
| One owner per question | Assign current knowledge, plans, rationale, evidence, and behavior to owners with different jobs. Routes may multiply, owners should not. | Explicit in all six repositories. Seatankers and Odin formalized it most strongly. |
| One physical home, many routes | Placement and retrieval are one design problem. Classify an item once, link it into every useful view, and quarantine genuinely unclassified material in an inbox. | Seatankers calls placement the dual of search and checks its graph. Odin used the same convergence rule during its source migration. |
| Combined Map and Note, then split | One file can route and own claims while the domain is small. Split routing from claims when selective reading or separate change rhythms appear. | Training's small area files remain combined. Seatankers uses Maps only for routing and Notes for claims. Odin uses Maps, Notes, Cases, and Reports once the research graph needs them. |
| Referential docs | Documentation explains the system, its ownership rules, and its mechanisms. Present behavior stays in code, configuration, tests, and owning package docs. Current claims and work stay with their own owners. | Seatankers states this boundary in `docs/README.md`. Hub and Odin approximate it with document maps, though stale landing pages show the failure mode. |
| Obsidian graph routing | Use wikilinks and thin Maps or indexes so one item can appear in several reading paths without duplicate ownership. | MIT, Training, Cooking, Seatankers, and Odin use Obsidian-compatible Markdown. Hub's broken vault-qualified link shows why moves need link checks or repaired routes. |
| Provenance and uncertainty near the claim | Record the source URL or file, date, authorship, confidence, hashes when useful, and what remains inference. Preserve ambiguity instead of turning clean prose into false certainty. | Training preserves uncertain reported history. MIT reconciles peer and official evidence. Seatankers and Odin carry detailed source metadata. Hub distinguishes seller claims, official capability, and physical verification. |
| Raw evidence, faithful derivation, interpretation | Keep immutable input separate from a faithful, searchable transformation and from judgment. The layers name authority and transformation, not generic quality. | MIT uses the split selectively for Facebook and email. Seatankers and Odin use it for financial sources. Cooking proposes raw transcript versus compiled notes but has not yet exercised the store. |
| Bronze, Silver, Gold when sources justify it | Bronze is the received source. Silver is a faithful reviewed derivation with no silent loss. Gold is a deterministic integrated projection. Qualitative interpretation belongs in Notes, not automatically in Gold. Markdown-native sources may need no duplicate Unit or Silver copy. | Seatankers is the clearest proven version. Odin adapts it with Units, manifests, and machine custody. MIT uses the vocabulary only where a transformation trail helps. Training, Cooking, and Hub have not earned the hierarchy. |
| Source Units or manifests | Give non-Markdown sources an addressable record of origin, date, hash, confidentiality, coverage, and unresolved issues. Use manifests instead when a machine-fetched corpus makes one Unit per item wasteful. | Seatankers co-locates Units with manager material. Odin uses Units for hand-placed sources and manifests for filings. |
| ADR only for consequential rationale | Write an ADR when a decision is hard to reverse, surprising without context, and contains a real trade-off. Preserve failed or superseded decisions while removing their present authority. | Seatankers states the three-part test. Odin's abandoned semantic source compiler shows why a failed ADR can remain useful evidence. Hub has now earned ADR candidates but has not created the owner. |
| Conversation, planning, and execution at different time scales | Keep one-turn work in the current task. When work must survive sessions, create one planning surface. Add a tracker only when dependencies, claims, or concurrent execution need durable state. Reconcile resolved planning into code, Notes, docs, or ADRs. | Training and Cooking need no tracker. MIT uses one compact action queue. Hub uses maps, tickets, and assets. Seatankers uses a work register and effort maps. Odin adds Beads at larger execution scale. |
| Durable intent versus volatile state | Keep the goal and operating doctrine separate from a dated external-state snapshot. Do not let the snapshot become an unchecked archive. | Hub developed this during Europa migration. MIT's conflicting status and todo files show the cost of two live state owners. Odin's stale dev-server receipt shows that a named owner still needs reconciliation. |
| Dated outcome versus reusable method | Record what happened separately from what should be tried next. Let lived evidence correct the reusable method without inventing outcomes that were never reported. | Cooking's T-bone cook rewrote the method. Training anticipates session records but has not yet exercised that split. |
| Definitions tracked, materializations selective | Track authored definitions, scripts, configuration, and compact receipts. Ignore reproducible runs unless a result needs durable promotion, audit, or delivery. | Seatankers' `analysis/` follows this rule. Odin keeps most generated outputs ignored but retains hash-bound receipts and accepted artifacts. |
| Models propose, fixed code performs effects | Let the agent interpret and propose. Put irreversible or exact effects such as publication, mail, database writes, deployment, and validation behind deterministic code and explicit approval. | Seatankers learned this in its email ingest system. Odin uses typed acceptance for model artifacts. Small Markdown projects do not need the machinery. |
| Benchmark the real journey | A convenient proxy can pass while the user's actual workflow fails. Add a full journey test after a proxy failure proves the gap, and keep claims such as generated, tested, reviewed, deployed, and accepted distinct. | Seatankers rebuilt its ingest evaluation after a focused test gave false confidence. Odin makes artifact acceptance state explicit in Models. |
| Current truth can change, rationale remains | Update the current owner when reality changes. Preserve meaningful supersession in an ADR, dated outcome, evidence record, or Git instead of leaving old claims active beside new ones. | Seatankers updated its data-source Note when Arcana replaced SFTP assumptions. Hub preserved the Windows and SSD reversals. Odin tombstoned the failed compiler while keeping its evidence. |
| Structure appears with the first real owner | Add a location when the first concrete item lacks a home. Add a category after repeated items reveal a stable concept. Avoid empty taxonomies that make absence look like missing work. | Cooking earned `cooks/` and `sauces/` through use, while its empty pantry and transcript tree show the opposite. Training added activity areas only after Anders's story made them real. MIT added modules as new exchange work appeared. |
| Determinism follows repetition or risk | Move a method into code, tests, lint, or an application when repeated interpretation, precision, or consequential effects make prose unreliable. | MIT added scrapers and ingestion scripts around evidence. Hub added systemd maintenance after deployment. Seatankers and Odin grew full applications around repeated analytical work. |
| Custody follows actual constraints | Decide separately what Git tracks, what remains encrypted or ignored, what lives on an authority host, and what external service owns. Preserve enough metadata to locate and verify material without copying restricted bytes everywhere. | MIT uses ignored private evidence. Hub exposed the danger of exhaustive secret-bearing handoffs. Seatankers keeps confidential sources in controlled Git. Odin splits tracked provenance from Europa-retained source bytes. |
| Harness-neutral contract | Keep repository instructions and durable knowledge independent of a particular model or subscription. Expose one repository-owned instruction body to each harness instead of maintaining divergent copies. | MIT, Seatankers, and Odin use symlinked harness entrypoints. Cooking and Training rely on the repository rather than resumed chat. |
| Git flow follows governance | Publish durable changes through the repository's authorized flow. A private single-owner project may synchronize `main` every changed turn. Shared work may require branches, review, path-scoped commits, and explicit push authority. | MIT and Cooking favor direct `main`. Hub uses path-scoped cross-machine synchronization. Seatankers and Odin preserve concurrent work and follow shared-repository controls. |

## Repository contexts

These portraits preserve where the patterns were learned. They are concise on
purpose. Inspect the live repository before copying anything.

| Repository | Context | Patterns worth remembering | Cautions |
|---|---|---|---|
| Training | Young Markdown coaching project with little operational history | Layered cold start; background as durable personal context; plan as current direction; activity and concern owners; uncertainty kept visible; structure earned by real material | Its anticipated sessions, sources, outputs, decisions, and tracker have not been tested. A single file may still beat a Map and Note split. |
| Cooking | Small personal knowledge base with methods and lived cooks | Taste as identity; reusable method versus dated cook; lived outcome updates "Next time"; URL-keyed raw and compiled source idea; retired path signposts; direct Git continuity | The transcript store and pantry were scaffolded before use. `log.md` duplicates canonical writes. Its machine-specific YouTube workaround is not an architecture. |
| MIT | Obsidian exchange workspace combining administration, courses, and evidence | Progressive module routing; state, rules, preferences, entity decisions, dashboards, and sources have distinct owners; generated Bases are views; feasibility is separate from preference; selective source tiers | The queue and status register drift. Local catalog snapshots can become stale. Direct `main` and raw private evidence policy are specific to this private repo. |
| Hub | Planning and operations for Europa and a bounded bookmark pilot | Authority by question; volatile state separate from intent; maps, tickets, and evidence assets; meaningful supersession; destructive-change gates; operational code added only after deployment | Broken wikilinks, stale state, overlong handoffs, and secret leakage show that named rules need checks and bounded capture. Its ticket vocabulary is not general. |
| Seatankers | Mature financial research, source custody, analytics, and operated ingest monorepo | Placement as the dual of search; Map, Note, ADR, Source, planning, and code authority; graph lint; Bronze, Silver, Gold and Units; models propose while code performs effects; journey benchmarks; compact reconstructable evidence | The full graph, source, planning, and ingest machinery would burden a small project. Some once-small owners have grown too large. |
| Odin | Large investment-research system, source archive, applications, and thousands of tracked tasks | One physical home with many routes; context maps, Cases, Notes, Reports, manifests, source custody, accepted-artifact states, ADR tombstones, planning versus Beads, generated receipts | Tracker and instruction surfaces can become stale at scale. Its finance-specific Case temperatures, source topology, Rust workbook gates, and Europa custody are local choices. |

## Evidence basis

This catalogue was distilled in August 2026 from read-only repository reviews
and live source documents. The reviewed snapshots were MIT `0f30831`, Hub
`ee7c9ca`, Seatankers `a5f20b6c` plus later constitutional documents, Odin
`e14a7ba13`, Training `64aecea`, and Cooking `c6d0a4cb`. Useful source documents
include each repository's root instructions and maps, plus Seatankers
`docs/placement.md`, `docs/graph.md`, `docs/data-plane.md`,
`docs/adr-conventions.md`, and `docs/planning.md`.

These revisions identify the origin of the ideas. They do not claim that the
repositories remain unchanged. Recheck live files before applying or updating
a pattern.
