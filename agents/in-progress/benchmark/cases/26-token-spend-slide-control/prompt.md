# Design brief: token-spend slide for "Organization of Agents v2"

## Task

Design one new slide for the deck "Organization of Agents v2" (file: `Organization of Agents v2.dc.html`, built on the Odin design system in `_ds/`). The slide presents how tokens were spent over the project's lifetime. All design decisions — chart form, layout, typography, annotation style, what to emphasize or omit, slide title, and where in the deck it belongs — are yours. This brief supplies only the deck context, the candidate narrative, and the verified data.

## Deck context

The deck is an internal walkthrough (10.08.2026) titled "Building an organization of agents — how 36 Excel models were made, and why you can trust them." Sections: 01 The problem, 02 What is an agent, 03 Organization, 04 Trust, then Takeaways.

The Organization section (slides 8–12) runs a repeated arc: "Replaced myself at X" for five jobs — doing the work, repeating myself, checking, dispatching, finding problems. Each slide ends with a "Firms solved this long ago" parallel. Slide 13 concludes: "What was left standing was not a firm. It was a factory." Slide 14: "Now I am left on copy" (the presenter only reviews screen recordings of finished work).

Slide conventions you should match:
- Every slide title is a full assertion sentence, not a label.
- Evidence carries a "Kilde:" (source) line. For this slide the source line is: "Kilde: agent-usage-evidence, strict scope."
- The voice is first person, dry, concrete. Numbers are never rounded to the point of vagueness.

## Candidate narrative

The slide should let the token data tell the story of the presenter removing himself from the operation. Three candidate takeaways, in no required order or combination:

1. **The spend migrated off the laptop.** The first four days ran entirely on the presenter's Mac. A rented dev server came online 2026-06-20, and a second server ("Europa") on 2026-08-03. By August the Mac carries a rounding-error share of daily tokens. The machine split is the physical trace of "I stopped being the dispatcher."
2. **A large share of tokens were spent while the presenter slept.** 12.11 billion tokens — 29.5% of the total — were consumed between 00:00 and 06:59 local time. 02:00 is among the busiest hours of the whole operation. This is the cleanest quantitative claim for "work happened without human interference."
3. **Cumulative spend is convex.** The first four days totaled 1.24B tokens. The single busiest days late in the period (5.04B on Aug 5, 4.87B on Aug 10, 4.45B on Jul 12) each exceed the entire first two weeks. The run-rate kept rising as each human job was replaced by infrastructure.

## Headline numbers (verified, strict scope)

- Total: **40,987,665,179 comparable tokens** (~41.0B), 2026-06-16 → 2026-08-13 (frozen cutoff), 325,582 canonical request events, 1,468 provider-machine sessions.
- Provider split: OpenAI/Codex 37.26B (90.9%), Anthropic/Claude 3.73B (9.1%).
- Machine totals: Mac 5.10B · devserver 19.92B · Europa 15.97B.
- Machine first-seen dates: Mac 2026-06-16 · devserver 2026-06-20 · Europa 2026-08-03.
- Night tokens (00:00–06:59 Oslo time): 12,108,603,735 (29.5%).
- API-equivalent cost at current list rates: $25,682.74–$26,113.67 (excludes 1.51B tokens with unavailable pricing; not an invoice — actual spend ran on subscriptions).

## Daily series (comparable tokens by machine, Oslo dates)

Dates absent from the table had zero recorded usage. The quiet stretch 2026-07-19 → 2026-08-02 is real (only two tiny entries), not missing data; usage resumed at a higher run-rate after it.

```csv
date,mac,devserver,europa,day_total,cumulative
2026-06-16,71230352,0,0,71230352,71230352
2026-06-17,316433719,0,0,316433719,387664071
2026-06-18,549042580,0,0,549042580,936706651
2026-06-19,304632748,0,0,304632748,1241339399
2026-06-20,4530885,261785547,0,266316432,1507655831
2026-06-21,24523481,785983117,0,810506598,2318162429
2026-06-22,153641600,65156227,0,218797827,2536960256
2026-06-23,468582356,406970492,0,875552848,3412513104
2026-06-24,10352708,173639964,0,183992672,3596505776
2026-06-25,196017205,95778178,0,291795383,3888301159
2026-06-26,65004180,4806879,0,69811059,3958112218
2026-06-27,108523,0,0,108523,3958220741
2026-06-28,0,1608161,0,1608161,3959828902
2026-07-01,0,13355857,0,13355857,3973184759
2026-07-02,33362007,1289880,0,34651887,4007836646
2026-07-03,10673483,150000625,0,160674108,4168510754
2026-07-04,0,177356029,0,177356029,4345866783
2026-07-05,0,1046766718,0,1046766718,5392633501
2026-07-06,23366295,474396872,0,497763167,5890396668
2026-07-07,20766722,215808417,0,236575139,6126971807
2026-07-08,47336436,202203711,0,249540147,6376511954
2026-07-09,119958370,190579725,0,310538095,6687050049
2026-07-10,0,3475321,0,3475321,6690525370
2026-07-11,0,825502249,0,825502249,7516027619
2026-07-12,44463439,4408346698,0,4452810137,11968837756
2026-07-13,171779383,630949103,0,802728486,12771566242
2026-07-14,929060835,380662844,0,1309723679,14081289921
2026-07-15,97782208,144493171,0,242275379,14323565300
2026-07-16,385365149,1052090680,0,1437455829,15761021129
2026-07-17,0,433704699,0,433704699,16194725828
2026-07-18,0,325819769,0,325819769,16520545597
2026-07-20,0,25567329,0,25567329,16546112926
2026-07-26,1443953,0,0,1443953,16547556879
2026-08-03,0,932937557,4118876,937056433,17484613312
2026-08-04,0,2303556902,5167988,2308724890,19793338202
2026-08-05,84509308,4092841828,867548884,5044900020,24838238222
2026-08-06,315788000,91841663,1431984742,1839614405,26677852627
2026-08-07,277477219,0,500526129,778003348,27455855975
2026-08-08,0,0,1482968326,1482968326,28938824301
2026-08-09,0,0,8551211,8551211,28947375512
2026-08-10,241643871,0,4629864235,4871508106,33818883618
2026-08-11,93024554,0,3096158943,3189183497,37008067115
2026-08-12,195758,0,2793576016,2793771774,39801838889
2026-08-13,41097107,0,1144729183,1185826290,40987665179
```

## Hour-of-day distribution (comparable tokens, Oslo local hour, whole period)

```csv
hour,tokens
0,1150000000
1,1420000000
2,2180000000
3,1960000000
4,1830000000
5,1850000000
6,1720000000
7,930000000
8,840000000
9,1080000000
10,1880000000
11,1120000000
12,1510000000
13,2490000000
14,2540000000
15,2400000000
16,2480000000
17,2640000000
18,1550000000
19,1840000000
20,2200000000
21,1140000000
22,940000000
23,1300000000
```

(Hour values rounded to the nearest 0.01B; the exact 00:00–06:59 sum is 12,108,603,735. Exact per-hour figures are available in `agent-usage-evidence/data/odin/strict_by_hour.csv` if needed.)

## Integrity caveats (must survive into whatever the slide claims)

- "Comparable tokens" is the strict-scope metric defined in the evidence pack's methodology; ~96% of it is cached-input reads (39.5B of 41.0B). Do not present the number as if it were all fresh model output.
- Use "Kilde: agent-usage-evidence, strict scope" as the source line.
- The dollar figure is an API-list-rate equivalent, not money spent; if shown, label it as such.
- Do not attribute tokens to the five "jobs" from slides 8–12 — the event data has no job dimension, and this deck's credibility rests on every number being traceable.
