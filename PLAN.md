# GridMedic — Implementation Plan for Coding Agents

> Read `CLAUDE.md` first (product, domain, data, endpoints, tests), then this file (how we build it).
> This file is the **work breakdown**: who builds what, in which order, in which files, and how agents running in parallel stay out of each other's way.
> `CLAUDE.md` and this plan are kept in sync. If you find a conflict, this plan wins on **process and file ownership**, and `CLAUDE.md` wins on **product behaviour**. If you're unsure, stop and ask the human.

---

## 0. Status board (updated 17 Oct, 12:50)

**Where things stand:** `main` runs the complete end-to-end GridMedic system on **A1's real 600-home grid** with **A2's real storm scenario** and all operational algorithms. Start Storm → complaints parsed and grouped → 4 ranked faults on live SVG map → autonomous crew dispatch with live movement and ETAs → field report twist (F4 mind-change) → tie restoration planning with safety guarding (ACT-1 blocked by work zone, ACT-2 safe restoring 70 homes) → customer outage portal with bilingual reports and simulated SMS stream.

| WP | Owner | Status | Notes / what's left |
|---|---|---|---|
| A0 Scaffold, config | A | ✅ | **Live smoke tests done 17 Oct** (see §0.1). Every member still has to star jaseci-labs/jac. |
| A1 Grid builder | A | ✅ merged | `grid_build.jac`, 12 tests. Adds SCHOOL (T1, T5), POLICE (T10), per-transformer streets and 5 facility landmarks (CLAUDE.md §6.1). `sim.jac` now uses it. |
| A2 Storm + complaints | A | ✅ merged | `grid_storm.jac` replaces the placeholder (sim import switched, placeholder deleted). `grid_storm`, `sim`, `agents_feedback` tests pass after merge. The F1-F4 acceptance check (tests 1-5, 7-9) over HTTP is still to do (A3). |
| A3 Acceptance tests | A | ✅ done | `tests/acceptance_tests.jac` (full storm F1-F4 ranking, F4 crew-report twist), `tests/noise_tests.jac` (tests 8 and 9: duplicates, T7 false reports), plus safety, dispatch, energise and microgrid suites. Test 15 (Verifier) is B7's `tests/verifier_tests.jac`. Run `jac script test` (one process per file): one `jac test -d tests/` process shares a persisted graph, so the suites interfere. HTTP-level run still open. |
| A4 Jac Hammer deploy | A | 🔴 13:00–14:00 | |
| A5 README | A | 🟡 draft on main | Updated with facilities, Jac learnings, and architecture. |
| B0 Contracts | B | ✅ | `api_mock.jac` was deleted at integration. Contract changes since the freeze: Localiser batch fields (B2), and the `children()`/`parents()` helpers in `grid.jac`. |
| B1 Parser | B | ✅ | 7 MockLLM tests. Real Gemini verified live in one batched call: 5/6 hazards, Sinhala OK (§0.1). |
| B2 Localiser + grouping | B | ✅ | One Localiser spawn per tick: 109 complaints in 0.4 s. |
| B3 Prioritiser | B | ✅ | Test 7 order passes. |
| B4 Sim + real API | B | ✅ | ~1 s per tick at 1×. `sim.LOCK` serialises the writer endpoints. All module tests pass on the A1 grid. |
| B5 Crew-report feedback | B | ✅ merged | `agents_feedback.jac` (`parse_crew_report` by llm + `pick_fault` routing: crew task, else device/street named in the text, else landmark section), `CrewReport.find` / `FaultNode.reevaluate`, `sim.apply_crew_report`, real `crew_report` endpoint. Test 6 passes (F4 -> SERVICE_WIRE, Lake Road, 15 homes, conf 0.9); a restored report resets `fuse_ok` / `line_ok` / `service_ok` (and the recloser lockout) and runs the Energiser. Contract addition: `CrewReport.homes`. Live Gemini parse of the T9 report verified once (§0.1). |
| B6 Explainer + noise | B | 🟡 explainer ✅ | `agents_explain.jac`: `explain_fault` by llm(), cached on the fault under `explanation_key` (a signature that ignores priority and age, so it recomputes only on real change); an LLM failure falls back to two sentences built from the evidence and is retried next time. New `explain(fault_id)` endpoint (contract addition, approved) returns the Fault with `explanation`. The Why? panel calls it on selection and after a crew report (checked in the browser 17 Oct, fallback text). Not tested with live Gemini. Still open: label lone false reports "possible individual issue", and a callback list for unlocatable complaints (CLAUDE.md §8.2 step 5). |
| B7 Verifier | B | ✅ | `Verifier.check` (`grid.impl/verify.impl.jac`): after a crew restores a fault, 3+ distinct homes on one transformer below it complaining within 5 min (not duplicates, no active fault there) raise a new TX_FUSE with `found_by="verifier"` and evidence "complaints continued after F1-B repair". `sim` queues `f5_followup_complaints` when F1 is restored and F5 is on, runs the verifier every tick and logs `verify` events. F5 is off by default: `start_storm` takes an optional `f5: bool`, set by the checkbox in the sim panel (checked in the browser). Contract additions: `start_storm.f5`, `Fault.found_by`, `SimState` queue/restore fields, Verifier fields. Test 15 passes (`tests/verifier_tests.jac`). The follow-up flow needs a crew report, so it has only run on MockLLM. |
| C0 UI shell + routing | C | ✅ merged | `/` operator, `/customer`. Clean control room header + minimizable floating simulation modal. |
| C1 Grid map | C | ✅ merged | `components/GridMap.cl.jac` draws 600 homes, transformers, feeders, switches, landmarks, and live crew movement. |
| C2 Panels + poll loop | C | ✅ merged | Auto-tick poll loop, live counters (Complaints, Faults, Consumers Off, Critical Loads: 🏥 Hospital & 💧 Pump, Restored), ranked faults, crew tasks, event log. |
| C3 Energiser | C | ✅ merged | `grid.impl/energise.impl.jac`: Bidirectional flood fill over `children()`/`parents()`, respecting switches, `line_ok`, `fuse_ok`, and `service_ok[street]`. 3/3 tests pass in `tests/energise_tests.jac`. Outages correctly show 310 off during storm, backfeed restores 70 homes on T5. |
| C4 Dispatcher | C | ✅ merged | `grid.impl/dispatch.impl.jac`: Autonomous priority-based dispatch matching travel-time tables, crew coordinate animation along edges, arrival detection & `work_zone` marking. Test 14 passes in `tests/dispatch_tests.jac`. |
| C5 Crew box + mind-change | C | ✅ merged | Interactive field report box with presets ("Preset: T9 Twist", "Preset: Pole 23 Safe"), "Why?" evidence breakdown, and `Mind-changed ↺` badge highlight. |
| C6 Customer page | C | ✅ merged | `ui_customer.cl.jac`: 10-digit consumer search (`4512300017`), bilingual Sinhala & English reporting form, simulated 1987 / CEBCare SMS notification stream. |
| C7 Restorer + SafetyCheck | C | ✅ merged | `grid.impl/restore.impl.jac`, `grid.impl/safety.impl.jac`, `components/ActionsPanel.cl.jac`. ACT-1 blocked by active crew work zone, ACT-2 safe via SW2 isolation (70 consumers restored) with 1-click execution. Tests 12 & 13 pass in `tests/safety_tests.jac`. |

**Current Focus:** A4 Jac Hammer test deployment. B6 noise polish (individual-issue label, callback list). Run `explain_fault` and a full uncached storm once with the user's go (§0.1), then the demo dry-run. Live dev server: `jac start --dev` (stop it before `jac clean`, §0.2).

### 0.1 Live Gemini verification (17 Oct) and quota rule

**Quota rule (also at the top of CLAUDE.md):** the key allows ~500 requests/day. No agent makes a real Gemini call without the user's explicit "go" for that run, with the request count stated first. Tests use `MockLLM`. About 2 requests used so far today.

| Check | Script | Requests | Result |
|---|---|---|---|
| Typed batched parse, English + 5 Sinhala phrases | `scripts/smoke_llm.jac` (rewritten from 6 calls to **1** batched `parse_texts`) | 1 | 6 results for 6 inputs, mapped back by `index`. 5/6 hazards matched. Sinhala wire-down, sparks and transformer noise were correct, and the two plain "no power" phrases were `NONE`. The one miss ("Wire fallen ... pole 23, sparks!") came back `SPARKS`, while the script expected `WIRE_DOWN`. The text contains both, and CLAUDE.md test 2 accepts either, so it is a loose expectation, not a parser bug. `pole 23` was extracted as the landmark. |
| F4 twist: `parse_crew_report` on the T9 crew report | `scripts/smoke_feedback.jac` (new) | 1 | PASS: `device_ok=True`, `SERVICE_WIRE`, street `Lake Road`, `restored=False`, `fault_id` copied correctly. |

**Still not tested live (ask before running):** `explain_fault` (Explainer), and a full uncached storm through `jac start` (~15 batched calls). Both run on MockLLM or the evidence fallback in tests.

**Run note:** `GEMINI_API_KEY` set with `$env:` in a terminal tab is not visible to the agent's shell. Without it, a run fails with `AuthenticationError` before using quota. The user ran both scripts in their own tab.

**Optional cleanup:** make the `smoke_llm.jac` case 1 accept either `WIRE_DOWN` or `SPARKS`.

### 0.2 Found while verifying B5-B7 (17 Oct)

- **Enums in obj lists/dicts on a node come back as ints.** `ComplaintLog.items` and `ParseCache.entries` read through a fresh node lookup gave `hazard == 2`, so `Hazard.X` comparisons were False and F1 never got its hazard (priority 745, not 1745), even with a live LLM. Fixed with `gm_types.fix_complaint` / `fix_parsed` at every read site; details in `JAC_FINDINGS.md`. Any new code reading such objs back must call them.
- **`jac clean` fails while a dev server runs** (WinError 32), and `jac test` then reuses the server's data, so cache-dependent tests fail. Stop the server first. A leftover process from a long run can cause one-off failures; rerun the file alone.
- **UI:** the 1 s poll kept calling a `loadInitial` with a stale closure and reset the selected fault to the first one every tick. The selection now lives in the module-level `_sel`. The Why? text is tagged with its fault id so a slow reply cannot show under another fault.
- **Stale test fixtures:** `tests/` imported the deleted `scenario_placeholder`; the `grid.test.jac` local-branch homes lacked `transformer_id`. Both fixed.

---

## 1. How we work

- **Three people (A, B, C), each running one or more agents in parallel.** One agent = one **work package (WP)** = one git branch = one worktree. A WP is sized for ~45–90 minutes of agent work.
- **File ownership is strict.** Every file has exactly one owning WP (§3). An agent edits **only** the files its WP owns. If it needs a change elsewhere, it stops and writes the request in its final message.
- **Contracts first.** `gm_types.jac`, `grid.jac` (declarations only) and the `api.jac` endpoint signatures are frozen at **09:50**. After that they change only with Person B's approval (CLAUDE.md §1 rule 5).
- **Mock-first API.** From 09:50, every endpoint exists and returns **mock data in its final shape**. The UI is built against the real endpoints from the start, and B swaps mock bodies for real ones endpoint by endpoint. Integration at 13:00 is then a no-op instead of a rewrite.
- **Every Jac topic → load its skill first** (CLAUDE.md §1 rule 1). Each WP below lists its skills.

### 1.1 Parallel-agent git protocol (Windows)

1. Keep the main checkout on `main`. For each WP, create a worktree on a **short path**, because deep paths break Windows installs:
   ```
   git worktree add C:\gm\<wp-id> -b wp/<wp-id>
   ```
   Then start the agent session in `C:\gm\<wp-id>`. Run `jac install` once per worktree.
2. **One server per worktree, each on its own port:** A uses 8100–8109, B 8200–8209, C 8300–8309 (`jac start --dev --port 8201`). Kill stale `jac start` processes before restarting: a held port makes the new server pick another port and breaks RPC.
   - Set `JAC_OPT_LEVEL=0` first, or `jac start` crashes (CLAUDE.md §1a).
   - **Restart the server after every `.jac` edit, client files included.** Hot reload silently breaks walkers: endpoints return empty results with no error (CLAUDE.md §1a). Dev mode also needs a second port for the API, so check the startup log for it.
3. **Done = acceptance passes:** `jac check` is clean on the WP's files, the WP's tests pass (`jac clean --all --force` first), and the agent has run the app if the WP touches it.
4. **The human merges** the branch into `main` (`git pull --rebase` first, then `jac check`, `jac test`, push). Agents never push to `main`.
5. Before starting the next WP, update from `main`. A WP that depends on another starts only after that one has merged.
6. Commit small and often (repos are checked). Message format: `WP-B2: localiser node abilities`.

### 1.2 Agent prompt template

Paste this into each new agent session, filling in the WP:

```
You are implementing work package <WP-ID> of GridMedic.
1. Read CLAUDE.md and PLAN.md fully. Find <WP-ID> in PLAN.md §5.
2. Load jac-core-cheatsheet, plus every skill listed for this WP, BEFORE writing Jac.
3. Edit ONLY the files this WP owns. Contract files (gm_types.jac, grid.jac, api.jac signatures) are read-only
   for you unless you are WP-B0. If you need a contract change, stop and describe it.
4. Never read ground-truth fault data (grid_storm.jac `_truth`) from agent code. Agents must discover faults from complaints.
5. Run `jac check` on your files and the WP's acceptance tests. Use `jac clean --all --force` before tests.
6. Commit to branch wp/<WP-ID> with messages "WP-<ID>: ...". Do not push to main.
7. Finish with: what you built, how you verified it, anything left, and any contract change you need.
```

---

## 2. Decisions this plan locks in

| Topic | Decision | Why |
|---|---|---|
| Declarations vs implementations | **All** nodes, edges and walkers (fields + ability *declarations*) go in `grid.jac`. Bodies go in `grid.impl/<feature>.impl.jac`, one file per owner. | Node abilities ("transformers tally their own complaints") need walker types, and walkers need node types. One declaration file avoids circular imports, and separate impl files avoid merge conflicts. The compiler pairs `grid.impl/*.impl.jac` with `grid.jac` automatically (skill: `jac-impl-files`). |
| Import direction | `grid.jac` imports only `gm_types.jac`. Other modules may import `grid`; `grid` never imports them. Orchestration (the `tick` pipeline) lives in `sim.jac`. | No import cycles. |
| Public vs internal walkers | Endpoints in `api.jac` are `walker:pub`. Internal walkers (`Localiser`, `Energiser`, …) are plain `walker` (not `:pub`). | Plain walkers aren't anonymous endpoints. |
| Auth | **None.** All endpoints are `:pub`, so every anonymous caller shares one guest graph (`root.shared`). That's how the operator and customer pages see the same grid. **Never add login**: a token switches `root` to that user's own empty graph (skill: `jac-sv-auth`). | Demo simplicity. State it as a limitation in the README. |
| Grid diagram | Hand-drawn **SVG in JSX** using the x/y positions in CLAUDE.md §6.1. No npm graph library. | Full control, and more of the repo stays Jac. |
| LLM parsing | Batch ~10 free-text complaints per `by llm()` call. `BD <number>` SMS skip the LLM. Parse results are cached by raw text and survive `reset`. Single-complaint parse is kept for `submit_complaint`. | Free-tier quota (CLAUDE.md §12). |
| LLM descriptions | Use `sem` statements, **not docstrings**, for every LLM-visible function, parameter and field (CLAUDE.md §8). | Skill: `jac-by-llm`. |
| LLM output types | `by llm()` returns `obj`s; code copies fields into nodes. Every output obj, including list items, is declared **in the same module as the function** (a local twin such as `LlmParsed` or `CrewFinding`), then copied into the shared `gm_types` obj. | Skill rule: LLM returns are objs, never nodes. byllm 0.6.19 crashes on output objs imported from another module (CLAUDE.md §1a, verified 16 Oct). |
| Ground truth vs belief | Physical truth (`line_ok`, `fuse_ok`, `service_ok` per street, SW1 lockout) is set by `apply_storm_truth()` in `grid_storm.jac`. Only the **Energiser** (power state) and **crew-report simulation** may read it. Parser, Localiser, grouping, Prioritiser and Explainer **must not**. | CLAUDE.md §6.2: agents discover faults. |
| Energiser traversal | Flood fill from `SS1` through **closed** switches and healthy sections, following `Feeds` edges in **both** directions, so the tie TS1 works either way. The Localiser walks **upstream** along `Feeds` in the normal configuration. | Tie switch restoration (§8.7). |
| Simulated clock | `SimState` node under root: `clock_min`, `running`, `speed`, `next_complaint_idx`. The UI calls `tick` every ~1 s real time with `minutes = 0.5 × speed` (1×, 5×, 20×). At 1× a 20-minute storm plays in ~40 s, plus LLM latency. The UI awaits each `tick` before scheduling the next. | Deterministic, replayable demo. |
| Client read cache | The jac client caches read-only endpoint responses for 60 s. Any writer call in the same tab clears the cache. **The operator poll loop calls `tick` (a writer) and then the readers.** `get_status` writes a "status checked" event, so it's a writer and the customer tab never sees stale data. | Skill: `jac-fullstack-patterns`. |
| Tests | Jac `test` blocks only, in `<module>.test.jac` annexes beside their module, or standalone files in `tests/` named `*_tests.jac` (**never** `test_*.jac`). No Python test client. LLM functions use `MockLLM`. One real-LLM smoke script lives in `scripts/`. | Skill: `jac-testing`; the 80% Jac rule. |

### 2.1 Shared conventions (all agents)

- **Node ids** are exactly as in CLAUDE.md §6.1: `SS1`, `F1-A`, `SW1`, `TS1`, `T1`…`T10`, `CSC-North`, `CSC-South`, `POLE-23`. Crews are `CREW-A`, `CREW-B`, `CREW-C` (shown as "Crew A" etc.).
- **Consumer numbers:** `"451" + str(20 + n) + f"{i:05d}"` for transformer `Tn`, home `i`, counting from 1. So T1 homes are `4512100001…`, T3 home 17 is `4512300017` (CLAUDE.md test #10), and T10 is `45130000xx`.
- **Home ids** look like `H-T3-017`, complaint ids `C0001`…, and system fault ids `FLT-001`… (assigned in creation order). Tests match faults by kind and device, never by id.
- **Critical loads:** the strings `"HOSPITAL"` (T3) and `"WATER_PUMP"` (T6).
- **Streets:** T9 has Lake Road 15, Temple Road 30, Station Road 30. Other transformers get 2–3 fictional street names (A chooses).
- **Event kinds:** `complaint`, `duplicate`, `fault_new`, `fault_update`, `mind_change`, `dispatch`, `crew_arrived`, `restored`, `action_applied`, `action_blocked`, `verify`, `status_checked`.
- **Free-text complaints carry `consumer_no`,** because they come from the app/web channel, except the 2 landmark-only complaints. A complaint with neither a number nor a landmark is logged as "unlocatable, needs callback" and creates no fault.

---

## 3. File layout and ownership

This matches CLAUDE.md §12, and adds the owning work package for each file.

```
gridmedic/
  CLAUDE.md, PLAN.md, README.md      # README: WP-A5
  jac.toml, main.jac                 # WP-A0 (C adds the client mount in WP-C0)
  .gitignore                         # WP-A0: .jac/, node_modules/, dist/
  gm_types.jac                       # WP-B0  shared objs/enums (contract); renamed from types.jac, needs B's OK
  grid.jac                           # WP-B0  ALL node/edge/walker declarations (contract)
  grid.impl/
    localize.impl.jac                # WP-B2  Localiser + Home/Transformer/Section tally abilities
    energise.impl.jac                # WP-C3  Energiser
    dispatch.impl.jac                # WP-C4  Dispatcher + crew movement
    feedback.impl.jac                # WP-B5  CrewReport walker + FaultNode re-evaluate ability
    restore.impl.jac                 # WP-C7  Restorer
    safety.impl.jac                  # WP-C7  SafetyCheck + Switch guard ability
    verify.impl.jac                  # WP-B7  Verifier
  grid_build.jac                     # WP-A1  builds the §6.1 demo grid under root
  grid_storm.jac                     # WP-A2  ground truth + complaint generator
  agents_parse.jac                   # WP-B1  BD regex, batch by llm(), cache, duplicates
  agents_group.jac                   # WP-B2  grouping complaints into Faults (§8.2 steps 1–5)
  agents_priority.jac                # WP-B3  priority formula + ranking
  agents_feedback.jac                # WP-B5  parse_crew_report by llm()
  agents_explain.jac                 # WP-B6  explain_fault by llm(), cached per fault version
  sim.jac                            # WP-B4  SimState, start_storm/tick/reset pipeline, event log
  api.jac                            # WP-B0 signatures + mocks, WP-B4 real bodies
  api_mock.jac                       # WP-B0  mock data in final shapes (deleted at WP-B4 end)
  ui_app.cl.jac (+ .impl.jac)        # WP-C0/C2  operator page shell, state, poll loop
  ui_customer.cl.jac (+ .impl.jac)   # WP-C6  customer page
  components/
    GridMap.cl.jac                   # WP-C1  SVG grid diagram
    FaultList.cl.jac                 # WP-C2  ranked faults + badges + mind-change highlight
    CrewPanel.cl.jac                 # WP-C4  crew tasks + ETAs
    EventLog.cl.jac                  # WP-C2  event strip + "Why?" panel
    CrewReportBox.cl.jac             # WP-C5  crew picker + text box + preset buttons
    ActionsPanel.cl.jac              # WP-C7  restoration actions + Apply + safety result
  scripts/smoke_llm.jac              # WP-A0  real Gemini check, ONE batched call (typed obj + Sinhala)
  scripts/smoke_feedback.jac         # real Gemini check of parse_crew_report, ONE call (F4 twist)
  tests/                             # WP-A3  CLAUDE.md §11 acceptance tests (*_tests.jac)
  *.test.jac                         # unit tests owned by the module's WP
```

---

## 4. Timeline and parallelism

| Phase | Time | A (data, tests, ship) | B (backend agents) | C (UI, ops agents) |
|---|---|---|---|---|
| **P0 Foundation** | 09:00–09:50 | **A0** scaffold → push by 09:15, then **A2** starts once `gm_types.jac` lands (09:30) | **B0** contracts + mocks (starts at 09:15 on the scaffold) | **C0** UI shell + routing (from 09:15) |
| **P1 Tier 1** | 09:50–13:00 | **A1** grid build ∥ **A2** (continued), then **A3** tests | **B1** parser ∥ **B2** localiser+grouping, then **B3** priority, then **B4** sim+real API | **C1** GridMap ∥ **C2** panels+poll loop, then **C3** Energiser |
| ✅ **13:00** | | **End to end: Start Storm → complaints → faults on map → ranked list** | | |
| **P2 Tier 2** | 13:00–15:00 | **A4** Jac Hammer deploy, then **A5** README draft | **B5** crew-report feedback ∥ **B6** explainer + noise handling | **C4** dispatcher ∥ **C5** crew box/reasoning/speed, then **C6** customer page |
| **P3 Tier 3** | 14:00–15:30 | demo script dry-run | **B7** verifier | **C7** restorer + safety + actions |
| 🧊 **15:30 freeze** | | Record the video (CLAUDE.md §14) | Bug fixes only | Bug fixes only |
| Ship | 16:30–17:15 | README final, 80% Jac check, submit | | |

`∥` = run as parallel agents. **Cap: 2 concurrent agents per person**, because human review and merging is the bottleneck. **Cut rules:** if P3 isn't working by 15:00, cut it (CLAUDE.md §13). If B2 is late at 12:30, C pauses polish to help.

---

## 5. Work packages

Each WP lists: **Owns** (the only files it may edit) · **Needs** (merged WPs) · **Skills** · **Build** · **Done when**.

### Phase 0

#### WP-A0 — Repo, scaffold, config (A)
- **Owns:** repo root files, `jac.toml`, `main.jac` (initial), `.gitignore`, `scripts/smoke_llm.jac`.
- **Needs:** — · **Skills:** `jac-project-kinds`, `jac-scaffold`, `jac-config`, `jac-by-llm`.
- **Build:**
  - `git init`, create the GitHub repo, then `jac create gridmedic --kind fullstack` and merge the scaffold into this layout.
  - In `jac.toml`, set `[plugins.byllm.model] default_model = "gemini/gemini-3.5-flash-lite"` and check that `[serve] base_route_app = "app"` is present.
  - `.gitignore` covers `.jac/`, `node_modules/` and `dist/`. Commit CLAUDE.md and PLAN.md.
  - `scripts/smoke_llm.jac`: one `by llm()` returning a small `obj`, plus the five Sinhala phrases from CLAUDE.md §6.3 → print hazard/lang.
- **Done when:**
  - `jac start --dev` serves the scaffold page, with `JAC_OPT_LEVEL=0` set.
  - The smoke script prints typed results, and `කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා` comes back as `WIRE_DOWN`.
  - It's pushed to `main`, and the GitHub language bar shows Jac.
  - Everyone stars github.com/jaseci-labs/jac.

#### WP-B0 — Contracts + mock API (B)
- **Owns:** `gm_types.jac`, `grid.jac`, `api.jac`, `api_mock.jac`.
- **Needs:** A0 · **Skills:** `jac-has-fields`, `jac-types`, `jac-node-edge-patterns`, `jac-walker-patterns`, `jac-impl-files`, `jac-sv-endpoints`.
- **Build:**
  - **`gm_types.jac`:** everything in CLAUDE.md §7, plus these. **The name changed from `types.jac`; B must approve the rename** (CLAUDE.md §7).
    - `obj ParsedText { has index: int, lang: Lang, hazard: Hazard, landmark: str; }` (one entry per batch item). This is the **stored** shape that `ParseCache` keeps. The LLM fills a local twin, `LlmParsed`, in `agents_parse.jac` (WP-B1).
    - The `sem` lines for every `Hazard`/`Lang` member, next to the enums.
    - `obj Event { has time_min: float, kind: str, text: str, fault_id: str = ""; }`
    - `obj GridNodeView { has id: str, kind: str, x: int, y: int, label: str = "", energised: bool = True, has_power: bool = True, reported: bool = False, closed: bool = True, status: str = "normal", homes: int = 0; }`
      - `kind` is one of substation/section/switch/transformer/home/depot/landmark/crew.
      - `status` is one of normal/suspected/faulted/restored.
    - `obj GridEdgeView { has from_id: str, to_id: str, kind: str, closed: bool = True; }` (`kind` is feeds/tie).
    - `obj GridView { has nodes: list[GridNodeView], edges: list[GridEdgeView], clock_min: float, counters: Counters; }`
    - `obj Counters { has complaints: int, faults: int, homes_off: int, homes_restored: int; }`
  - **`grid.jac`:** all nodes and edges from CLAUDE.md §7, with these fields added:
    - `Section.line_ok: bool = True`, `Transformer.service_ok: dict[str, bool] = {}` (per street), `Switch.locked_out: bool = False`.
    - `SimState`, plus a `ParseCache` node (`has entries: dict[str, ParsedText]`).
  - **Also in `grid.jac`:** declarations (`has` fields + `can ... with X entry;`, no bodies) for walkers `Localiser`, `Energiser`, `Dispatcher`, `CrewReport`, `Restorer`, `SafetyCheck`, `Verifier`. Include the node-ability declarations each needs (Home/Transformer/Section on `Localiser`; FaultNode on `CrewReport`; Switch on `SafetyCheck`).
    - **One exception has a body:** `SafetyCheck` gets `has blocked_by: str = "";` and a 3-line **inline** `gate` ability (`if self.blocked_by != "" { disengage; }`), declared before its `step` ability. `disengage` is rejected inside impl blocks and node abilities (CLAUDE.md §8.8). Any other walker that needs `disengage` uses the same gate pattern.
    - Use a shared base node and a typed edge, `edge Feeds: GridNode --> GridNode`, so traversals are typed (CLAUDE.md §7).
  - **`api.jac`:** all 14 endpoints from CLAUDE.md §9 as `walker:pub`, with the exact inputs. Each one `report`s typed objects from `api_mock.jac`. `get_grid` reports a `GridView` with realistic positions and mixed states. `get_faults` reports a ranked list that includes a hazard fault and a mind-changed fault.
  - **Placeholder impl files:** create every `grid.impl/*.impl.jac` from §3 with empty-bodied `impl` blocks for its declarations, so the project compiles and B4 can already spawn C's walkers. Each later WP takes over its file and fills in the bodies.
- **Merge in two steps:**
  - `gm_types.jac` by **09:30**, which unblocks A2.
  - Everything else by **09:50**, then announce the contract as frozen.
- **Done when:**
  - `jac check` is clean on all files.
  - With `jac start`, `curl -X POST localhost:<api port>/walker/get_faults` returns mock faults. In dev mode the API has its own port; see the startup log.

#### WP-C0 — UI shell + routing (C)
- **Owns:** `main.jac` client section, `ui_app.cl.jac` (+impl), `ui_customer.cl.jac` (placeholder).
- **Needs:** A0 (B0 for data) · **Skills:** `jac-fullstack-patterns`, `jac-cl-components`, `jac-cl-routing`, `jac-cl-organization`, `jac-cl-styling`.
- **Build:**
  - Operator page at `/`: the layout from CLAUDE.md §10, with a top bar, a ~70% map area, a right panel and a bottom strip, using placeholder boxes.
  - Customer page at `/customer`.
  - `ui_app` is the stateful shell: it holds all state and passes it to child components by props.
  - Once B0 merges, call `get_grid`/`get_faults` once on load and show counts.
- **Done when:** both routes render; mock counts are visible; `jac browse` snapshot shows the layout.

### Phase 1 (Tier 1)

#### WP-A1 — Demo grid builder (A)
- **Owns:** `grid_build.jac`, `grid_build.test.jac` · **Needs:** B0 · **Skills:** `jac-node-edge-patterns`, `jac-has-fields`, `jac-testing`.
- **Build:**
  - `build_grid()` builds CLAUDE.md §6.1 exactly under `root`. It is idempotent: if `SS1` exists, return it.
  - Create the `Feeds` edges in power-flow direction, with TS1 attached to both F1-C and F2-B.
  - Generate 600 `Home` nodes using the consumer-number scheme (§2.1), streets and clustered x/y.
  - Add depots, three `CrewNode`s at their depots, the `POLE-23` landmark → F1-B, and `SimState` and `ParseCache` (empty).
  - `reset_grid()` restores the normal state: all switches normal, TS1 open, every `*_ok` True, counters zero. It keeps `ParseCache`.
- **Done when (tests):**
  - 600 homes in total: F1 has 310 and F2 has 290.
  - T9's streets are 15/30/30.
  - Consumer numbers are unique and 10 digits, and `4512300017` is a T3 home.
  - Calling `build_grid()` twice creates no duplicates.

#### WP-A2 — Storm scenario + complaint generator (A)
- **Owns:** `grid_storm.jac`, `grid_storm.test.jac` · **Needs:** `gm_types.jac` from B0 (09:30). It uses the §2.1 consumer-number scheme directly; `apply_storm_truth()` needs `grid.jac` (09:50) and A1 · **Skills:** `jac-python-interop` (seeded `random`), `jac-testing`.
- **Build:**
  - Keep the ground truth (CLAUDE.md §6.2) in a private `_truth` structure.
  - `apply_storm_truth()` sets the physical state:
    - F1-B `line_ok=False`, and SW1 open with `locked_out=True`.
    - T8 and T6 `fuse_ok=False`.
    - T9 `service_ok["Lake Road"]=False`.
    - If F5 is enabled, T4 `fuse_ok=False`.
  - `generate_complaints(seed=17) -> list[Complaint]` returns ~300 raw complaints. Only `id`, `text`, `consumer_no` and `time_min` are filled; the parser fills the rest. Follow every rule in CLAUDE.md §6.3: format mix, bursty timing, 5 duplicates, 3 false reports from T7, 2 landmark-only, at least 3 F1 hazards.
  - `f5_followup_complaints()` returns ~8 complaints from T4 homes, timed after F1 is restored.
- **Done when (tests):**
  - The same seed gives the same output.
  - Counts per rule match.
  - Every complaint's `time_min` is within 0–20, with most in the first 8 minutes.
  - No BD text has a wrong number.

#### WP-A3 — Acceptance test suite (A)
- **Owns:** `tests/*_tests.jac` · **Needs:** A1, A2, B0 (runs fully after B4) · **Skills:** `jac-testing`, `jac-by-llm` (MockLLM).
- **Build:**
  - Write CLAUDE.md §11 tests 1–15 as `test` blocks against the public functions and walkers, using MockLLM for the parse step.
  - Tests for features that don't exist yet (T2/T3) are written but marked in a comment as `# expected to fail until WP-xx`.
  - Add a `[scripts] test = "jac clean --all --force && jac test -d tests/ -v"` entry, coordinating with A0's `jac.toml`.
- **Done when:** the suite runs, and the failures are only the expected not-yet-built ones.

#### WP-B1 — Complaint parser (B)
- **Owns:** `agents_parse.jac`, `agents_parse.test.jac` · **Needs:** B0 (A1 for lookups) · **Skills:** `jac-by-llm`, `jac-types`, `jac-testing`.
- **Build:**
  - `BD\s*\d{10}` is parsed deterministically, with no LLM call.
  - `parse_texts(texts: list[str]) -> list[LlmParsed] by llm();` has `sem` on the function, its parameter and every `LlmParsed` field, including the Sinhala hints from CLAUDE.md §8.1. `LlmParsed` is declared **in `agents_parse.jac`** (a `list[ParsedText]` from `gm_types` crashes byllm), and the results are copied into `gm_types.ParsedText` for the cache. Map results back by `index`, never by list position alone.
  - To overlap the batch calls with `flow`/`wait`, launch each through a helper function, never `[flow f(x) for x in xs]`, which binds `x` late (CLAUDE.md §1a).
  - Tests swap the model with `import agents_parse; agents_parse.llm = MockLLM(...)`.
  - `parse_batch(complaints)` checks `ParseCache` first and sends only cache misses, in chunks of 10. It stores the results.
  - `parse_one(text, consumer_no)` handles `submit_complaint`.
  - Resolve `consumer_no` → `Home`, and `landmark` → section (`"pole 23"` → F1-B).
  - Duplicate rule: the same `consumer_no` within 10 simulated minutes sets `is_duplicate=True`.
  - On `RateLimitError`, retry after a short wait; after 2 failures, mark the complaint `lang=MIXED, hazard=NONE` and log an event. The storm must never crash.
- **Done when (tests, MockLLM):**
  - `BD 4512300017` → the T3 home, with no LLM call (CLAUDE.md test 10).
  - Duplicates are flagged (test 8), and the cache hit path makes no LLM call.
  - The Sinhala hazard case is covered by `scripts/smoke_llm.jac` (real LLM).

#### WP-B2 — Localiser + grouping (B)
- **Owns:** `grid.impl/localize.impl.jac`, `agents_group.jac`, `agents_group.test.jac` · **Needs:** B0, A1 · **Skills:** `jac-walker-patterns`, `jac-node-edge-patterns`, `jac-impl-files`, `jac-testing`.
- **Build:**
  - The `Localiser` is spawned at a complaint's `Home` and walks upstream on `Feeds`.
  - The node abilities live **on the nodes**: Home sets `reported`; Transformer and Section increment `reports` and record distinct homes.
  - `group_faults()` implements CLAUDE.md §8.2 steps 1–5 exactly:
    - LINE_DOWN at the most upstream de-energised-looking section.
    - TX_FUSE at ratio ≥ 0.3.
    - The T9 one-street case → TX_FUSE with confidence 0.4.
    - Isolated reports → no fault.
  - Compute `homes_affected` over all homes downstream (or the street's homes for SERVICE_WIRE), plus `critical_loads`, `evidence` strings and `complaint_ids`.
  - Faults are `FaultNode`s. Regrouping updates existing faults (matched by device) instead of duplicating them.
- **Done when (tests):**
  - Feeding parsed storm complaints gives exactly F1–F4 with the CLAUDE.md test 1–5 expectations.
  - The 3 T7 false reports create no fault (test 9).

#### WP-B3 — Prioritiser (B)
- **Owns:** `agents_priority.jac`, `agents_priority.test.jac` · **Needs:** B2 · **Skills:** `jac-core-cheatsheet`, `jac-testing`.
- **Build:** the formula from CLAUDE.md §8.4 and a stable sort; `rank_faults()` returns `list[Fault]`.
- **Done when:** test 7 passes: F1 first (hazard), F3 second (water pump), then by homes.

#### WP-B4 — Simulation pipeline + real API (B)
- **Owns:** `sim.jac`, `api.jac` (bodies), deletes `api_mock.jac` · **Needs:** A1, A2, B1, B2, B3 · **Skills:** `jac-sv-endpoints`, `jac-walker-patterns`, `jac-sv-persistence`, `jac-concurrency` (optional).
- **Build:**
  - `start_storm(speed)`: `reset_grid()`, then `apply_storm_truth()`, then load the complaints into `SimState`.
  - `tick(minutes)`, in this order:
    1. Advance the clock.
    2. Release due complaints.
    3. `parse_batch`.
    4. Spawn a Localiser per non-duplicate complaint.
    5. `group_faults`.
    6. `rank_faults`.
    7. Placeholder hooks for C's `Energiser`/`Dispatcher` (no-ops until C3/C4 merge).
    8. Log events.
  - `reset` restores the grid and clears the storm, but keeps `ParseCache`.
  - Replace every mock endpoint body with the real one. `get_grid` builds `GridView` from the graph.
- **Done when:**
  - A full storm via `curl` (`start_storm`, then 40× `tick`) produces F1–F4 ranked correctly.
  - A replay after `reset` makes ~0 LLM calls (cache).
  - The A3 tier-1 tests pass.

#### WP-C1 — Grid map SVG (C)
- **Owns:** `components/GridMap.cl.jac` (+impl) · **Needs:** B0 · **Skills:** `jac-cl-components`, `jac-cl-styling`.
- **Build:**
  - An SVG drawn from `GridView`: zones shaded, feeders as lines, switches showing gaps when open, the tie dashed, transformers as glyphs, 600 home dots, depots, and a ⚠️ at Pole 23 when hazards exist.
  - Use the colour states from CLAUDE.md §10.
  - Clicking a transformer or fault selects it (callback prop).
- **Done when:** it renders the mock `GridView` with every state visible; `jac browse screenshot` looks right at 1280 px.

#### WP-C2 — Panels + poll loop (C)
- **Owns:** `ui_app.cl.jac`/`.impl.jac`, `components/FaultList.cl.jac`, `components/EventLog.cl.jac` · **Needs:** C0, B0 · **Skills:** `jac-cl-components`, `jac-cl-organization`, `jac-cl-js-interop` (polling).
- **Build:**
  - The top bar has counters, the clock, Start Storm, Reset and speed buttons (1×/5×/20×).
  - The **poll loop**: while running, `await tick(...)`, then refetch `get_grid`, `get_faults`, `get_events(since)`, then wait 1 s. There is never more than one tick in flight.
  - The ranked fault list has badges and an evidence list. The event log strip shows events newest first.
- **Done when:**
  - Against mocks, the controls call the right endpoints.
  - After B4, a real storm plays end to end **(13:00 checkpoint)**.

#### WP-C3 — Energiser (C)
- **Owns:** `grid.impl/energise.impl.jac` · **Needs:** B0, A1 · **Skills:** `jac-walker-patterns`, `jac-node-edge-patterns`.
- **Build:**
  - The flood fill described in §2.
  - Sets `Section.energised`, transformer power, and `Home.has_power`, respecting `fuse_ok` and `service_ok[street]`.
  - Runs after `start_storm`, every switching change and every repair. B4 calls it from `tick`.
- **Done when:**
  - After `apply_storm_truth()`: F1-B and F1-C are off (205 homes), T8 and T6 homes are off, Lake Road (15) is off, and everything else is on.

### Phase 2 (Tier 2)

#### WP-B5 — Field feedback: the agent changes its mind (B)
- **Owns:** `grid.impl/feedback.impl.jac`, `agents_feedback.jac`, `agents_feedback.test.jac` · **Needs:** B4 · **Skills:** `jac-by-llm`, `jac-walker-patterns`.
- **Build:**
  - `parse_crew_report(text, fault) -> CrewFinding by llm()` with full `sem`. The parameter can't be called `report`, a Jac keyword. `CrewFinding` is a local twin declared in `agents_feedback.jac`, copied into `gm_types.FaultUpdate` (CLAUDE.md §8.6).
  - The `CrewReport` walker visits the crew's assigned `FaultNode`, and the **FaultNode ability** applies the update: kind/device/street, `homes_affected`, status and confidence. Then re-rank.
  - Log a `mind_change` event in the CLAUDE.md §8.6 before → after format.
  - A crew report that says "restored" sets the physical truth back to ok (`fuse_ok` etc.), then runs the Energiser.
  - Fill in the `crew_report` endpoint.
- **Done when (MockLLM):**
  - Crew C's T9 report gives SERVICE_WIRE on Lake Road, 15 homes, confidence ≥ 0.8 (test 6).
  - The T8 "replaced" report gives RESTORED and the homes come back on.

#### WP-B6 — Explainer + noise handling (B)
- **Owns:** `agents_explain.jac` (+test), small additions in `agents_parse.jac`/`agents_group.jac` · **Needs:** B4 · **Skills:** `jac-by-llm`.
- **Build:**
  - `explain_fault(fault) -> str by llm()`, cached on the FaultNode and recomputed only when the fault changes. It's called when the operator selects a fault (through a new `explain` endpoint; **needs B's contract approval**).
  - Polish: duplicates are visibly logged, false reports are labelled "possible individual issue", and unlocatable complaints go to a callback list.
- **Done when:** selecting a fault shows a 2-sentence reason; noise appears in the log, not as faults.

#### WP-C4 — Dispatcher + crew movement (C)
- **Owns:** `grid.impl/dispatch.impl.jac`, `components/CrewPanel.cl.jac` · **Needs:** B4, C2 · **Skills:** `jac-walker-patterns`, `jac-cl-components`.
- **Build:**
  - CLAUDE.md §8.5: the highest-priority unassigned fault goes to the nearest idle crew (by the travel table).
  - Crews go TRAVELLING → ON_SITE when the ETA passes, then take the next fault directly.
  - A crew ON_SITE at a LINE_DOWN section marks it `work_zone=True` (needed by C7).
  - Crew icons animate between their position and the target on the map.
- **Done when:** test 14 passes (first task: Crew A or B to F1, ETA 8); crews visibly move.

#### WP-C5 — Crew report box, reasoning, mind-change highlight (C)
- **Owns:** `components/CrewReportBox.cl.jac`, FaultList/EventLog additions · **Needs:** C2, B5 · **Skills:** `jac-cl-components`.
- **Build:**
  - A crew picker and text box that send to `crew_report`.
  - **Preset buttons** with the four CLAUDE.md §6.4 sample reports, plus "Conductor repaired at pole 23, line restored" for F1.
  - The "Why?" panel shows the evidence and the explanation.
  - Mind-change: a 2 s highlight and an "Updated by crew report" badge on the fault card.
- **Done when:** the F4 twist plays live in the UI exactly as the demo script (CLAUDE.md §14 step 3).

#### WP-C6 — Customer page (C)
- **Owns:** `ui_customer.cl.jac` (+impl) · **Needs:** B4 (`submit_complaint`, `get_status`) · **Skills:** `jac-cl-components`, `jac-cl-routing`.
- **Build:**
  - Report an outage (consumer number + optional text) and look up status.
  - A simulated SMS panel that adds a message whenever the status text changes. Poll `get_status` every 3 s; it's a writer, see §2.
  - Copy note: "In deployment this would feed existing channels (1987 SMS / CEBCare)."
- **Done when:** a T5 home number shows "Fault found · Crew A assigned · ETA …" and later "Power restored".

#### WP-A4 — Jac Hammer test deploy (A) · 13:00–14:00
- **Owns:** deploy notes in README · **Needs:** `main` at the 13:00 checkpoint.
- **Build:**
  - Import the repo from GitHub and set `GEMINI_API_KEY` as a **project-level** env var.
  - **Check which Jac version Jac Hammer runs.** If it isn't 0.16.7, pin it (Settings → Jac version) and confirm `jac start` behaviour.
  - Make a sandbox deploy.
- **Done when:** a judge-reachable URL runs a storm. If it fails, write down why and keep the video as the primary demo.

#### WP-A5 — README write-up (A)
- **Owns:** `README.md` · **Needs:** — (fills in as features land) · **Skills:** none.
- **Build:**
  - Follow the CLAUDE.md §15 outline.
  - Include the AI-cost table from https://claude.ai/artifact/UzoGzXu8cxGHgt22MtAeFt, updated with the **measured** tokens per complaint from a real storm.
  - Disclose coding-agent use. Report the Jac % from GitHub's language bar.
  - List the limitations: no auth, fictional grid, parse cache.
- **Done when:** it's reviewed by B and C at 16:30.

### Phase 3 (Tier 3, cut at 15:00 if not working)

#### WP-C7 — Restorer + SafetyCheck + actions (C)
- **Owns:** `grid.impl/restore.impl.jac`, `grid.impl/safety.impl.jac`, `components/ActionsPanel.cl.jac`, `get_actions`/`apply_action` bodies (coordinate the file with B: add the bodies in `sim.jac` hooks or ask B to merge) · **Needs:** C3, C4 · **Skills:** `jac-walker-patterns`, `jac-node-edge-patterns`.
- **Build:**
  - CLAUDE.md §8.7–8.8. The **Switch node ability** refuses unsafe closing by setting `visitor.blocked_by` (and optionally `report`ing a reason). The inline `gate` in `grid.jac` then `disengage`s; C writes only the `step` body in `safety.impl.jac`.
  - The actions panel offers two plans: "Close TS1" alone (→ **BLOCKED** with the reason) and "Open SW2 then close TS1" (→ **SAFE**, 70 homes).
  - Apply runs the steps, then the Energiser, then T5 turns green.
- **Done when:** tests 12 and 13 pass, and the UI demo matches CLAUDE.md §14 step 4.

#### WP-B7 — Verifier (B)
- **Owns:** `grid.impl/verify.impl.jac` · **Needs:** B5 · **Skills:** `jac-walker-patterns`.
- **Build:**
  - After F1 is RESTORED, release `f5_followup_complaints()`.
  - If ≥ 3 non-duplicate complaints arrive within 5 sim-minutes downstream of a restored device → re-localise → new TX_FUSE at T4, with evidence "complaints continued after F1 repair".
- **Done when:** test 15 passes.

---

## 6. Jac gotchas collected from the skills (read before coding)

- **Calling style:** `def:pub` RPC takes **positional** args, and the caller's variable names must match the server's parameter names. Walker spawn takes **keyword** args (`root spawn get_faults()`), and results arrive in `result.reports`.
- **`.cl.jac` files:** `sv import from ..module { fn, Types }` and always `await` the call. In `main.jac`, use a plain `import`, never `sv import`. Import the obj types alongside the functions.
- **Restart rules:** HMR reloads only `.cl.jac`. Server changes need a server restart. After a node schema change, stop the server and delete `.jac/data/` (dev only).
- **Tests:** they share a persisted root, so run `jac clean --all --force` first. Count only the nodes you created.
- **byLLM:** `sem` not docstrings; LLM returns `obj`s; `-> T | None` lets the model say "not found"; typed returns auto-retry malformed output 3×; catch `RateLimitError` from `byllm.lib`.
- **Client entry and checks:** the client entry is lowercase `def:pub app()`. `len(x)`, not `x.length`.
- **UI checks:** `jac browse open localhost:<port>`, then `snapshot` / `click` / `screenshot`, to verify the UI from an agent session.
- **Graph traversal speed (measured 17 Oct):** never use `[n ->:Feeds:->]`, `[n <-:Feeds:<-]` or `[n -->[?:Type]]` on grid nodes. Each costs ~12 ms per node, and a full grid walk took 8–10 s. Use `children(n)` / `parents(n)` from `grid.jac` (0.13 s), and `visit children(here);` in walkers. Each walker **spawn** also costs ~0.2 s on the 600-home graph, so spawn once per batch, not per item (JAC_FINDINGS.md #12).

---

## 7. Checkpoint checklist

- **09:50**
  - ✅ Contracts frozen and on `main`.
  - ✅ Every endpoint returns mocks (now real bodies).
  - ✅ The smoke LLM test passes (17 Oct, 1 batched request: 5/6 hazards, the one miss is an ambiguous expectation, see §0.1).
  - ✅ The language bar shows Jac.
- **13:00**
  - ✅ Start Storm → complaints → F1–F4 on the map → ranked list → physical outages show (A2 complaints + C3 Energiser active).
  - 🟡 A3 acceptance tests partially run (all C3/C4/C7 and B5 tests pass).
- **15:00**
  - ✅ The F4 mind-change works live (B5 feedback loop + C5 UI presets & highlight).
  - ✅ Crews move autonomously with live ETAs and work zone safety marking (C4 Dispatcher).
  - ✅ Customer status works at `/customer` with bilingual reporting and SMS notifications (C6).
  - ✅ Tier 3 Restorer + SafetyCheck working (C7: ACT-1 blocked by work zone, ACT-2 safe via SW2 isolation).
- **15:30**
  - Freeze. Full demo dry-run, then record.
- **17:15**
  - Submitted: GitHub link, video, write-up, and every member has starred the Jac repo.

---

## 8. To change later (found 17 Oct, A3 review)

- **README test section:** it says "run the entire test pipeline with the built-in script" but lists the commands by hand. Point it at `jac script test` (defined in `jac.toml`), and add `tests/verifier_tests.jac` to that script once B7 is stable.
- **README line counts:** the "99.9% Jac, 27 files, 4,820 lines" table looks hand-written. Replace it with the real figure from GitHub's language bar before submitting.
- **README Verifier claim:** the README presents the Verifier as complete while B7 is still in progress. Confirm B7 works (test 15) before keeping it.
- **Test isolation:** run test files one per process (`jac script test`). A single `jac test -d tests/` shares one persisted graph, and a second session running `jac test` or `jac start` in the same checkout corrupts it. Use separate worktrees for parallel sessions.
- **HTTP-level acceptance run** (A3): still open.
