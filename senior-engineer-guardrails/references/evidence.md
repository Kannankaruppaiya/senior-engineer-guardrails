# Evidence behind the rules

The rules in this skill come from a literature review of research and incident
reports published **May–September 2026**, compiled in September 2026. Most arXiv
items are preprints and not yet peer reviewed; arXiv IDs encode the month
(`2607` = July 2026). Figures are as reported by each source. Items marked
**[vendor]** come from companies selling related tools; **[practitioner]** are
single-team reports; **[background]** predate May 2026 and are included for
context only.

Contributions that add, correct or update sources are welcome — see
`CONTRIBUTING.md` in the repository.

## Security and authorization

| Finding | Source |
|---|---|
| 200 deployed vibe-coded apps audited, 1,471 validated vulns: 90% of apps vulnerable, broken access control in 75.5%, 82.8% of those missing server-side checks, 43.9% caused by unstated "hidden security rules"; agent aware of risk yet shipped in 32% of reintroductions | [arXiv 2606.23130](https://arxiv.org/html/2606.23130) (Jun 2026, rev. Sep) |
| ~100 models: 56% average security pass rate; XSS 15%, log injection 12%, SQLi 83% **[vendor]** | [Veracode 2026 GenAI Code Security Report](https://www.veracode.com/blog/2026-genai-code-security-report-ai-risk/) (Jul 2026) |
| Frontier models invent package names 4.6–6.1% of the time; 127 names shared by five models, 53 registrable | [arXiv 2605.17062](https://arxiv.org/abs/2605.17062) (May 2026) |
| 38.9% of agent PRs have a security smell, 82.3% of them unpinned actions/images/installs; review missed 81.1% of leaked credentials | [arXiv 2607.12428](https://arxiv.org/html/2607.12428) (Jul 2026) |
| Static-analysis feedback cut findings 29–69%, but fixes introduced new vulnerabilities in 15–22% of cases | [arXiv 2608.16187](https://arxiv.org/html/2608.16187) (Aug 2026) |
| Visible security tests as an executable spec: +19.3 pp correct-and-secure | [arXiv 2608.09740](https://arxiv.org/html/2608.09740) (Aug 2026) |
| Next.js middleware auth bypass (`x-middleware-subrequest`) | CVE-2025-29927 **[background]** |

## Functional correctness of full-stack apps

| Finding | Source |
|---|---|
| Hardened HTTP contract oracle: best models 17.9–28.6% (from ~55–59% before hardening); failures in authorization, validation, state, side effects | [BackendForge, arXiv 2607.11042](https://arxiv.org/html/2607.11042v1) (Jul 2026) |
| Enterprise SaaS benchmark: best 20.7%; in 63.5% of failed units the app never ran stably | [SaaSBench, arXiv 2605.17526](https://arxiv.org/html/2605.17526) (May 2026) |
| Requiring PostgreSQL alone cost 19.3 pp; stacking architecture + DB + ORM cost ~30 pp | [Constraint Decay, arXiv 2605.06445](https://arxiv.org/html/2605.06445) (May 2026) |
| 81% of 43 AI-generated repos had cross-file structural defects (phantom APIs, missing migrations, routes missing sibling auth guards); 97% evaded types, tests and scanners | [arXiv 2607.08981](https://arxiv.org/html/2607.08981v1) (Jul 2026) |
| Acceptance tests before code, browser-validated: +34 to +48 pp on full-stack generation | [TDDev, arXiv 2605.17242](https://arxiv.org/abs/2605.17242) (May 2026) |

## Agent behaviour

| Finding | Source |
|---|---|
| Failed runs make the decisive error at median step 7 of 27; 26% fabricate success; "repairs the wrong problem" causes 39% of wasted execution | [arXiv 2607.09510](https://arxiv.org/pdf/2607.09510) (Jul 2026) |
| 20,574 real sessions: developer-constraint violation is the most common misalignment; 91.5% needed developer pushback | [arXiv 2605.29442](https://arxiv.org/abs/2605.29442) (May 2026) |
| Incident taxonomy: deception 15.7%, fabrication 9.7%, tool/API misconfiguration 24.5%; destructive operations cluster in bug-fix and setup tasks | [arXiv 2605.30777](https://arxiv.org/html/2605.30777) (May 2026) |
| Instruction compliance falls ~5.6% (odds) per additional generated function | [arXiv 2605.10039](https://arxiv.org/pdf/2605.10039v1) (May 2026) |
| Instruction files grow 226%; 16 noisy rules cut compliance 65.6% → 41.5% | [arXiv 2608.11095](https://arxiv.org/html/2608.11095) (Aug 2026) |
| Over-editing is the default; "keep the original code" cut excess edits and raised Pass@1 by 2.3 pp | [arXiv 2609.04061](https://arxiv.org/html/2609.04061v1) (Sep 2026) |
| Agents fabricate files or values instead of reporting they are blocked; follow stale convention files over code | [arXiv 2608.16630](https://arxiv.org/abs/2608.16630) (Aug 2026) |
| Models abandon correct answers under sustained pushback | [SPINE, arXiv 2609.09090](https://arxiv.org/abs/2609.09090) (Sep 2026) |
| Destructive incidents: production DB + backups deleted; Prisma shadow DB pointed at production dropped 22 tables | [Railway](https://blog.railway.com/p/your-ai-wants-to-nuke-your-database) (Apr 2026, borderline) **[vendor/party]**; [AIID 1676](https://incidentdatabase.ai/cite/1676/) (Jul 2026) |

## Tests

| Finding | Source |
|---|---|
| 80.2% of 86,156 agent test patches have weak or no assertions | [arXiv 2606.18168](https://arxiv.org/abs/2606.18168) (Jun 2026) |
| 50.4% of agent PRs changing tested code add no tests; 81–86% of error-handling blocks untested | [arXiv 2607.18057](https://arxiv.org/pdf/2607.18057) (Jul 2026) |
| LLM tests written from buggy code assert the bug; coverage stops predicting detection | [arXiv 2607.22880](https://arxiv.org/html/2607.22880v1) (Jul 2026) |
| Fault detection for LLM-introduced faults often near zero | [arXiv 2609.09315](https://arxiv.org/abs/2609.09315) (Sep 2026) |
| Visible-vs-hidden test gap widens 28 pp per 10× code size; 2,900-line lookup table submitted as a "compiler" | [SpecBench, arXiv 2605.21384](https://arxiv.org/html/2605.21384) (May 2026) |

## Frontend

| Finding | Source |
|---|---|
| 68% of AI pages fail in ≥1 of 9 browser/device environments vs 40% human; causes: missing viewport meta 46%, non-wrapping flex 29.5% | [WebCompat, arXiv 2608.12518](https://arxiv.org/html/2608.12518) (Aug 2026) |
| Best model passes 74.9% of UI turns but only 37.3% of five-turn episodes | [EvoGenUI-Bench, arXiv 2608.29387](https://arxiv.org/abs/2608.29387) (Aug 2026) |
| 541 semantic a11y violations that pass axe-core across 300 UIs (generic labels most common) | [CHI EA '26](https://tommasocalo.github.io/papers/26-semacces-chiea.pdf) (Apr 2026, borderline) |
| 42–117 design-system violations per 8-task run; zero after one lint-feedback round **[vendor]** | [shadcn lint](https://github.com/shadcn-ui/lint) (Sep 2026) |
| Agent PRs add `any` ~9× more than humans (2.16 vs 0.24 per PR) | [arXiv 2602.17955](https://arxiv.org/html/2602.17955) **[background]** |
| Version-matched docs for agents in Next.js | [nextjs.org — AI agents guide](https://nextjs.org/docs/app/guides/ai-agents) |

## Structure and maintainability

| Finding | Source |
|---|---|
| More capable models write more bloated, coupled code; volume predicts structural decay; prompting doesn't fix it | [arXiv 2605.02741](https://arxiv.org/html/2605.02741) (May 2026) |
| Duplicated blocks +81%, moved code 21% → 3.8%, copy/paste 15.7%, error-masking code +47% **[vendor]** | [GitClear](https://www.gitclear.com/the_ai_code_quality_maintainability_gap) (mid-2026) |
| Isolated AI functions ~half the size of human ones | [arXiv 2609.12708](https://arxiv.org/abs/2609.12708) (Sep 2026) |
| Claude Code median PR 495 lines vs 52 human; revert rates vary by agent (6.1%–14.5%, human 11.5%) | [arXiv 2609.17598](https://arxiv.org/html/2609.17598v1) (Sep 2026) |
| Right file for 92% of required deletions, exact line <52%; 29% of passing patches guard instead of delete | [arXiv 2607.28887](https://arxiv.org/abs/2607.28887) (Jul 2026) |
| Trimming search residue cut redundant edits 18–33% | [TRIM, arXiv 2607.18161](https://arxiv.org/abs/2607.18161) (Jul 2026) |
| Heavy multi-agent pipelines: 50–130% more complexity, no accuracy gain | [arXiv 2606.00308](https://www.emergentmind.com/papers/2606.00308) (Jun 2026) |
| AI-built systems surfaced fault-specific signals for ≤13.99% of injected faults | [arXiv 2607.05785](https://arxiv.org/html/2607.05785v1) (Jul 2026) |

## Known gaps

- No study in the window compared agents with *senior* developers specifically on
  identical tasks; comparisons are against human contributors in general.
- No measured rates yet for useEffect misuse, `'use client'` placement, double
  submits, CSRF/rate-limiting omissions or stray-file frequency; those rules rest
  on consistent practitioner reports.
- Several figures conflict across sources (e.g. secret-leak rates in client
  bundles range 5.4%–78% depending on method); the rules avoid depending on any
  single number.
