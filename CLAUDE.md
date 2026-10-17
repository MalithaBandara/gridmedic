# GridMedic — Project Brief for Coding Agents

> Read this whole file before writing any code. It is the single source of truth for this project.
> If anything here conflicts with what the team tells you in chat, ask before proceeding.

---

## 0. Hackathon context (hard constraints)

- **Event:** AI Hackathon 2026, powered by Jaseci Labs — Saturday 17 Oct 2026, Measurements Laboratory, Dept. of Electrical Engineering, University of Moratuwa.
- **Coding window:** 09:00 – 17:30. **Submission deadline 17:30** (team target: submit by 17:15). Feature freeze at **15:30**.
- **Language rule:** the GitHub repo must be **≥ 80% Jac**. Do **not** create `.py`, `.js`, `.ts` source files. Python/npm libraries may be *imported* from Jac. Keep custom CSS minimal (Jac projects accept `.tsx`/`.css` files, but they count against the 80%).
  - **How the 80% is measured:** GitHub's language bar recognises `.jac` files as **Jac**. Only *programming* and *markup* files are counted: `.jac`, `.css`, `.html`, `.js`, `.tsx` and `.py` count, while Markdown, TOML and JSON don't.
  - Commit no generated output: keep `.jac/` (compiled client JS) and `node_modules/` in `.gitignore`.
  - Don't use `.gitattributes` to hide real code from the stats. That counts as misrepresenting the project.
- **Repo is checked:** all code must be written during the coding window. Brainstorming and tool setup before the day are fine. Commit small and often.
- **Submission (link shared on the day; late entries can't win):** GitHub link, demo video (recorded, no live Q&A), written description including how Jac/Jaseci was used, and **every team member stars github.com/jaseci-labs/jac**. Encouraged: host on **Jac Hammer** (jachammer.ai) for judges.
- **Eligibility:** every team member registers and checks in on the day; one project per team; misrepresenting the project means disqualification.
- **Judging criteria (equal weight assumed):** technical execution · excellent use of Jac & Jaseci · creativity & innovation · **depth of agentic behaviour** · impact & novelty · clear presentation & demo video.
- **Coding agents are allowed**; we disclose their use in the write-up.

---

## 1. Jac rules for you (the coding agent)

1. **Jac syntax changes often and your training data is unreliable for Jac.** All code snippets in this file are **approximate pseudocode**, so verify them before use. §1a lists the toolchain facts already checked for the Jac version we use.
   - **Load the matching `jac-*` skill before writing Jac for a topic, even if you think you know it.** Load `jac-core-cheatsheet` once per session.
   - Topic → skill:
     - graph: `jac-node-edge-patterns`, `jac-walker-patterns`
     - fields and types: `jac-has-fields`, `jac-types`
     - `walker:pub` / `def:pub` endpoints: `jac-sv-endpoints`
     - `main.jac` wiring and `sv import`: `jac-fullstack-patterns`
     - UI: `jac-cl-components`, `jac-cl-styling`, `jac-cl-routing`
     - npm graph libraries: `jac-npm-packages`
     - `by llm()` / `sem`: `jac-by-llm`
     - `flow` / `wait`: `jac-concurrency`
     - persistence: `jac-sv-persistence`
     - tests: `jac-testing`
     - build or check errors: `jac-debugging`
     - `jac.toml`: `jac-config`
   - If the skills aren't installed, `jac guide <skill-name>` prints the same guide.
2. Run `jac check <file>` before every commit. Fix all errors.
3. Serve the app with `jac start` (dev mode with hot reload: `jac start --dev`). `jac run file.jac` runs a single script. If `jac --help` disagrees with §1a, trust `jac --help` and tell the team.
   - Set `JAC_OPT_LEVEL=0` first, or `jac start` crashes on our install (§1a).
   - **Restart the server after every `.jac` edit, client files included.** Hot reload silently breaks walkers: they stop matching node types, and endpoints return empty results with no error.
4. Tests are Jac `test` blocks, run with `jac test`. Run `jac clean --all --force` first, because tests share a persisted graph.
   - **Unit tests** go in a `<module>.test.jac` annex beside the module it tests (e.g. `grid_build.test.jac`). It needs a same-named module, or it fails.
   - **Acceptance tests** go in `tests/*_tests.jac`.
   - **Never name a file `test_*.jac`**: the prefix clashes with Python's test import machinery.
   - Use `MockLLM` for anything that calls `by llm()`. The real-Gemini check lives in `scripts/smoke_llm.jac`.
   - No Python test files, because of the 80% Jac rule.
5. Never change `gm_types.jac` or endpoint signatures without explicit approval from Person B. Other code depends on them.
6. Prefer Jac-native features over hand-rolled equivalents (see §4). This is a judging criterion.
7. Ask for small, testable pieces. After each piece: run it, then commit.

---

## 1a. Verified Jac toolchain facts (checked 16 Oct 2026)

These replace the guesses elsewhere in this file. Language *syntax* still needs checking with the `jac-*` skills (§1, rule 1).

**There are two Jac release lines, and the whole team must use the same one:**

| | **pip line (our default: native Windows)** | Binary line |
|---|---|---|
| Version | `jaclang` 0.16.7 + plugins (last release June 2026) | v0.37.x / v0.34.x (still releasing) |
| Platforms | Windows, Linux, macOS (Python ≥ 3.12) | Linux, macOS; Windows only via WSL |
| Docs | `jac guide` (bundled) and docs.jaseci.org | jaclang.org/docs |
| Serve app | `jac start` / `jac start --dev` | `jac run` / `jac run --dev` |
| Scaffold | `jac create <name> --kind fullstack` | `jac create <name> --kind web-app` |
| LLM config | `[plugins.byllm.model]` | `[byllm.model]` |

When looking things up online, make sure the page matches our line. jaclang.org/docs describes the **binary** line.

Facts for the **pip line** (checked on Windows 11 with `jaclang` 0.16.7 and its bundled `jac guide`):

- **Install:**
  - `pip install jaclang==0.16.7 jac-client==0.3.25 byllm==0.6.19 jac-mcp==0.1.24` (these were verified to install together), then check `jac --version`.
  - This is the Jac **compiler**, which happens to be shipped through pip. The project code itself is Jac.
  - Use a venv with a **short path**: a deep path hits Windows' 260-character limit while installing.
- **Commands:**
  - `jac create gridmedic --kind fullstack` scaffolds the app (needs jac-client), then `jac install` installs the dependencies listed in `jac.toml`.
  - `jac start --dev` serves `main.jac` with hot reload; add `--port` to change the port. In dev mode the UI and the API run on separate ports: 8000 and 8001 by default. With `--port`, read the API port from the startup log.
  - **Set `JAC_OPT_LEVEL=0` before `jac start`** (`$env:JAC_OPT_LEVEL='0'` for one shell, or `setx JAC_OPT_LEVEL 0` permanently). jaclang 0.16.7 only requires `llvmlite>=0.43`, so pip installs llvmlite 0.50.0. Its native pass then crashes `jac start` with `create_pipeline_tuning_options() got an unexpected keyword argument 'size_level'`. `jac run` can print the same error and exit with code 1 even though the script ran. With the variable set, both run cleanly. Pinning `llvmlite<0.50` is an untested alternative.
  - `jac run file.jac` runs a script. `jac check`, `jac test`, `jac format`, `jac lint`. `jac run -e all file.jac` shows all diagnostics.
- **Agent tooling:**
  - The MCP server comes from jac-mcp. Add it to Claude Code with `claude mcp add jac -- jac mcp`.
  - `jac guide` lists the bundled guides, `jac guide <topic>` prints one, and `jac guide --export ~/.claude/skills` exports them as Agent Skills.
  - The most useful guides: `jac-fullstack-patterns`, `jac-sv-endpoints`, `jac-walker-patterns`, `jac-by-llm`, `jac-cl-components`.
- **LLM config (`jac.toml`):** `[plugins.byllm.model]` with `default_model = "..."`. Temperature and max_tokens go under `[plugins.byllm.call_params]`.
  - `llm` is a built-in name, so `by llm()` needs no import.
  - **We use Gemini 3.5 Flash-Lite:** `default_model = "gemini/gemini-3.5-flash-lite"`; the `gemini/` prefix is required. It has been stable since 21 Jul 2026, has a free tier, and supports structured output.
  - The key comes from the `GEMINI_API_KEY` env var. LiteLLM also accepts `GOOGLE_API_KEY`, which the bundled guide uses, but we standardise on `GEMINI_API_KEY`.
  - The installed LiteLLM (1.82.6) fetches an up-to-date model list at startup. It recognises `gemini-3.5-flash-lite` and forwards byLLM's JSON schema to it (checked offline on 16 Oct; the 09:00 smoke test is the live check).
  - LiteLLM also supports `groq/`, `openrouter/`, `mistral/` and `ollama/` model names, if we ever need a fallback (see §12).
  - `glob llm = Model(...)` overrides the model for one file only.
- **Client/server split:**
  - UI components go in `components/**/*.cl.jac`. Server modules are plain `.jac` (server is the default; `.sv.jac` is an optional marker).
  - `main.jac` imports server modules first, then holds the client section in a `cl { ... }` block.
  - Inside a `.cl.jac` file, call server code with **`sv import from ..module { ... }`**. A plain `import` to server code fails the build.
  - In `main.jac`, use plain `import` for server modules, **never** `sv import`.
- **Endpoints:** `walker:pub X` is served as `POST /walker/X`, and `def:pub f` as `POST /function/f`.
  - A function returns its value typed and hydrated, so return `gm_types.jac` objects directly instead of dicts.
  - A walker spawned from the client returns a result object; read `result.reports`.
- **Persistence:** anything reachable from `root` persists, by default in SQLite at `.jac/data/`. Generated client JS lives in `.jac/client/`, so add `.jac/` to `.gitignore`.
  - If the server returns 500 errors like "Invalid anchor id" after a node schema change: stop the server, delete `.jac/data/` (dev only), and restart.
- **Runtime traps found with a throwaway test app (16 Oct).** Each of these was run, not just read about. Most of them pass `jac check` and only fail at runtime. Details and test code are in JAC_FINDINGS.md.
  - **Restart after edits.** `jac start --dev` reloads server modules when any `.jac` file changes, and afterwards walkers stop matching node types: `get_grid` returned 0 nodes and nothing was found. A plain restart fixes it, and the data is kept.
  - **No module named `types`.** It's shadowed by Python's stdlib at runtime, hence `gm_types.jac` (§7).
  - **No circular imports between nodes and walkers.** A node ability that names a walker from another module fails at runtime with "partially initialized module". That's why every node and walker is declared in `grid.jac` (§7).
  - **`by llm()` output types must be local.** Every `obj` in a `by llm()` return type, including list items and fields of a wrapper obj, must be declared in the same module as the function. Otherwise byllm 0.6.19 crashes with `'str' object has no attribute 'fields'`, and MockLLM crashes too. Imported **enums** and imported **input** parameters are fine. Pattern: declare a local twin obj with the same fields plus `sem`, then copy its fields into the shared `gm_types` obj (§8).
  - **`flow` in a comprehension binds late.** `[flow f(x) for x in xs]` can run a later `x`, which gave wrong parse results and walkers starting at the wrong node. Launch each one through a helper, `def _launch(x: T) -> Future { return (flow f(x)) as Future; }`, then `futures = [_launch(x) for x in xs]; results = [(wait f) as R for f in futures];`. With that, 40 parallel walker spawns tallied 40/40.
  - **`disengage` only works inline.** Inside a node ability, or inside an `impl Walker.ability` block in an `.impl.jac` file, `jac check` rejects it with E2083. Keep walker abilities that `disengage` inline in the walker body in `grid.jac`. A node that must stop a walker sets a flag on `visitor`, and the walker checks it (§8.8). On each node the walker's ability runs **before** the node's.
  - **`report` is a keyword**, so it can't be a parameter name (E0013). Neither can `visit`, `spawn`, `flow`, `wait`, `node`, `edge` or `walker`.
  - **No graph references inside f-string braces.** `f"{len([n ->:Feeds:->])}"` is a parse error because the `:` is read as a format spec. Compute into a local first.
  - **Client code (`.cl.jac`):** `", ".join(xs)` passes `jac check` but throws in the browser, and Jac's own error screen also crashes, leaving a blank page. Render lists with a `{for ...}` slot instead. **Enums arrive as numbers** (`str(hazard)` shows `1`), so send display text from the server.
  - **Endpoints are registered only if referenced.** A `def:pub` that neither `main.jac` imports nor a `.cl.jac` file `sv import`s returns `NOT_FOUND`.
  - **Verified working:** node inheritance (`node Section(GridNode)`); typed edges with endpoint types (`edge Feeds: GridNode --> GridNode`); a walker entry on a base type firing for every subclass; `override def` on node methods; `report` from a node ability landing in the walker's `.reports`; `del node` on a server; persistence across restarts, including an in-place `list.append` on a node; typed nodes hydrated in the client; swapping in MockLLM from a test with `import agents_parse; agents_parse.llm = MockLLM(...)` (don't `del` it afterwards: the default `llm` is a module global).
- **Jac Hammer (docs.jachammer.ai):**
  - It may run the binary line by default. During the 13:00 test deploy, check which version it runs and pin it in Settings → Jac version if needed.
  - Import a project from GitHub (free on every plan). A repo with several `jac.toml` files asks which app to run.
  - **Sandbox deploy:** free plan allows 1, and it expires after 7 days. Permanent deploys need a paid plan.
  - Put `GEMINI_API_KEY` in a **project-level** environment variable. Global variables don't reach production deploys.
  - The Jac version is pinned in `jac.toml` (Settings → Jac version).

---

## 2. Product overview

### One-liner
**GridMedic sends walkers to trace every power-outage complaint back to its fault, turning a flood of reports into a short, ranked, safe action plan — and updates the plan as field crews report back.**
- It's for everyday outages. Storms are when complaint volume peaks, so the demo uses a storm scenario.

### The problem (verified facts — use these in UI copy and write-up)
- In May 2024 storms, the Ceylon Electricity Board (CEB) received **over 61,000 breakdown complaints in six days**, affecting **467,500+ users**. (Daily FT, 27 May 2024)
- In May 2025 storms, CEB reported **29,015 breakdowns**, handled with limited staff and resources. (Ada Derana, 30 May 2025)
- Complaints arrive via the **1987 hotline**, **SMS** (`BD <consumer number>`), the **CEBCare app** and web portal. They are handled by provincial/area **control centres** and **Electricity Consumer Service Centres (ECSCs)**, from which crews are dispatched.
- **Key insight:** many complaints come from the **same fault** (one blown transformer fuse → ~80 homes complain; one faulted line section → hundreds). The hard part is grouping complaints into real faults, ranking them, and acting safely.

### What GridMedic is
- **Decision support for a utility control-room operator.** It groups complaints into faults, ranks them (hazards first), recommends crew dispatch, learns from crew field reports, suggests safe restoration via tie switches, and verifies fixes.
- An **AI layer that can sit on top of any utility's existing complaint channels.**

### What GridMedic is NOT (state this honestly)
- It does **not** control real switches — a human approves every action.
- It does **not** connect to CEB systems or real data. The demo uses a **fictional grid** modelled on a realistic radial distribution layout.
- **No voice input** (Sinhala speech recognition is still unreliable; complaints are text).
- Not a replacement for commercial Outage Management Systems — it is an AI-native decision layer that understands messy multilingual complaints and self-corrects from field feedback.

### Users
1. **Operator** (main): control-room dashboard.
2. **Customer** (secondary, optional): report outage + see status updates.
3. **Crew** (simulated): reports typed into the operator dashboard's crew-report box.

---

## 3. Features and tiers

Build strictly in tier order. Do not start a higher tier until the lower tier works end to end.

| Tier | Feature | Owner |
|---|---|---|
| **T1** | Demo grid loaded as a Jac graph with x/y positions | A |
| **T1** | Storm scenario + complaint generator | A |
| **T1** | Complaint parsing (`by llm()` → typed `Complaint`, hazards, Sinhala) | B |
| **T1** | Fault localisation (upstream walkers, nodes tally complaints, group into `Fault`s) | B |
| **T1** | Prioritisation (hazard > critical load > homes affected) | B |
| **T1** | Operator dashboard: grid diagram, live complaint dots, fault zones, ranked list, Start Storm | C |
| **T2** | Crew dispatch (nearest idle crew, ETA from travel table), moving crew icons | C |
| **T2** | Field feedback: crew report → `by llm()` → fault updated → re-rank ("agent changes its mind") | B |
| **T2** | Duplicate & false-report handling | B |
| **T2** | Counters, event log, reasoning panel, crew-report box, speed control, reset | C |
| **T2** | Customer page: report outage + status lookup + simulated SMS updates | C |
| **T3** | Tie-switch restoration with capacity check | C |
| **T3** | Safety check: simulate each switching step; block if a crew work zone would be energised | C |
| **T3** | Verify & re-investigate: complaints continuing after a repair → hidden second fault | B |

---

## 4. Jac features we must showcase (judging: "excellent use of Jac")

| Jac feature | Where it is used |
|---|---|
| **Nodes & typed edges** | The grid itself; `Feeds` edges with `closed` state and capacity |
| **Walkers** | `Localiser` (upstream), `Energiser` (downstream power state), `Restorer` (alternative paths), `SafetyCheck`, `Dispatcher`, `Verifier` |
| **Node abilities (code that runs inside nodes on walker arrival)** | Transformers/Sections **tally their own complaints**; Switches **refuse unsafe closing**; Faults **re-evaluate themselves** from crew reports |
| **`by llm()` with typed outputs** | `parse_complaint -> Complaint`, `parse_crew_report -> FaultUpdate`, `explain_fault -> str` |
| **`sem`** | Precise meaning for hazards, fault kinds, Sinhala phrases, landmarks |
| **Persistence under `root`** | Grid, complaints, faults, crews persist automatically — no database setup |
| **Walkers as API endpoints (`walker:pub`)** | All backend endpoints (served as `POST /walker/<Name>`) |
| **Codespaces (client/server split)** | Operator dashboard + customer page in the same codebase: `.cl.jac` UI files and a `cl { }` block in `main.jac`. `sv import` gives compiler-generated RPC, and `gm_types.jac` objects arrive in the UI as typed instances |
| **Parallel walkers (`flow` / `wait`)** | Localising a burst of hundreds of complaints concurrently, and overlapping the batched LLM parse calls (T2 nice-to-have). Launch each `flow` through a helper function: a `flow` inside a comprehension binds late (§1a) |
| **Walker control (`visit`, `report`, `disengage`)** | Edge-filtered traversal, reporting findings, stopping at open switches / blocked steps |

**Pitch line:** *"The grid is a graph, and GridMedic's agents are walkers. They trace complaints upstream; every transformer counts its own reports and every switch guards its own safety. One language from the AI to the map."*

---

## 5. Domain model (power distribution basics — get these right)

- The network is **radial**: power flows one way, Substation → Feeder → Sections (separated by switches/reclosers) → Transformers → Homes.
- A fault on a section **de-energises that section and everything downstream** of it (until isolated and restored).
- **Switches/reclosers** separate sections. In our scenario, **SW1 is an auto-recloser**: when the fault on F1-B occurs, SW1 trips and locks out, so **F1-A stays energised** and F1-B + F1-C lose power.
- A **tie switch (TS1)** connects the end of Feeder 1 (section F1-C) to Feeder 2 (section F2-B). It is **normally open**. Closing it lets F2 supply F1-C, *only if* F1-C is first isolated from the faulted section (SW2 open) and F2 has capacity.
- **Safety rule:** a section where a crew is working (**work zone**) must never be connected to any energised source. Any switching step that would energise a work zone is **blocked**.
- **Transformer fuse blown:** only that transformer's homes lose power.
- **Service / LV street wire down:** only homes on one street under a transformer lose power (partial outage of that transformer).
- **Critical loads:** hospital (on T3), water pump (on T6), schools (on T1 and T5), police station (on T10) — prioritised. Tags in `Transformer.critical`: `HOSPITAL`, `WATER_PUMP`, `SCHOOL`, `POLICE`.

---

## 6. Demo dataset (Person A builds this at 09:30; everyone codes against it)

### 6.1 Grid topology

```
SUBSTATION SS1 "Moratuwa Grid Substation"   pos (200,300)

FEEDER F1 (from SS1) — capacity 700 homes
  F1-A (350,150) --SW1 [recloser, closed] (450,150)--> F1-B (550,150) --SW2 [closed] (650,150)--> F1-C (750,150)
  T1 on F1-A (320,90)  60 homes + SCHOOL   (streets: Railway Avenue 30, Galle Road 30)
  T2 on F1-A (380,90)  45 homes            (streets: Church Road 25, Market Street 20)
  T3 on F1-B (520,90)  80 homes + HOSPITAL (streets: Hospital Road 45, Pansala Road 35)
  T4 on F1-B (580,90)  55 homes            (streets: Old Mill Road 30, Canal Road 25)
  T5 on F1-C (750,90)  70 homes + SCHOOL   (streets: School Lane 40, Bridge Road 30)
  Landmark: "Pole 23" on F1-B at (560,150)

FEEDER F2 (from SS1) — capacity 700 homes
  F2-A (350,450) --SW3 [closed] (500,450)--> F2-B (650,450)
  T6  on F2-A (320,520) 50 homes + WATER_PUMP (streets: Reservoir Road 25, Pump House Road 25)
  T7  on F2-A (380,520) 65 homes              (streets: Beach Road 35, Fisheries Road 30)
  T8  on F2-B (620,520) 40 homes              (streets: Park Road 20, Kanatta Road 20)
  T9  on F2-B (680,520) 75 homes              (streets: Lake Road 15, Temple Road 30, Station Road 30)
  T10 on F2-B (740,520) 60 homes + POLICE     (streets: Ward Place 30, Factory Road 30)

TIE SWITCH TS1 (800,300): F1-C <-> F2-B, normally OPEN

Totals: F1 = 310 homes, F2 = 290 homes, all = 600 homes.

PRIORITY FACILITIES (Landmark nodes, Located on their section; not counted as homes):
  LM-HOSPITAL       "Lakeview General Hospital"      T3  / F1-B (500,60)
  LM-PUMP           "Reservoir Road Pumping Station" T6  / F2-A (300,550)
  LM-POLICE         "Ward Place Police Station"      T10 / F2-B (760,550)
  LM-SCHOOL-BRIDGE  "Bridge Road Maha Vidyalaya"     T5  / F1-C (770,60)
  LM-SCHOOL-RAILWAY "Railway Avenue Primary School"  T1  / F1-A (300,60)

DEPOTS (Electricity Consumer Service Centres):
  CSC-North (80,150): Crew A, Crew B
  CSC-South (80,450): Crew C

ZONES (shaded on diagram): "Area North (F1)" y 60–200, "Area South (F2)" y 400–560

TRAVEL TIMES (minutes):
  CSC-North → Area North 8 | CSC-North → Area South 18
  CSC-South → Area South 8 | CSC-South → Area North 18
  Area North ↔ Area South 15 | within same area 5
```

Homes: generate `Home` nodes per transformer, each with a unique 10-digit `consumer_no` (e.g. prefix by transformer: T3 homes `4512300001…`), a `street`, and an x/y offset clustered around the transformer.

**Built by `grid_build.jac` (WP-A1):** `build_grid()` creates all of the above under `root` and returns SS1; calling it again changes nothing. `reset_grid()` restores the normal state (switches normal, everything healthy, tallies, faults and logs cleared, crews idle) and keeps `ParseCache`. Homes are numbered street by street in the order listed, in rows of 10 dots 6 px apart, above their transformer on F1 and below it on F2. Crews are `CrewNode`s under `root`, each `Located` on its depot.
- The storm generator (A2) must keep F1's hazard complaints on Pole 23 / F1-B: a hazard landmark on another section triggers a line-down suspicion there (§8.2 step 2). The parser matches a facility landmark only by its full name.

### 6.2 Storm scenario — ground truth (agents must DISCOVER this; never read it directly)

| ID | Ground truth | Effect | What it demonstrates |
|---|---|---|---|
| **F1** | Line down on **F1-B at Pole 23**, wire on road, sparks. SW1 recloser locked out. | F1-B + F1-C de-energised → T3 (80 + hospital), T4 (55), T5 (70) = **205 homes** | Upstream grouping; **hazard priority**; restoration of T5 via TS1 after opening SW2; safety check |
| **F2** | **T8 fuse blown** | 40 homes | Simple transformer fault |
| **F3** | **T6 fuse blown** | 50 homes + **water pump** | Critical-load priority |
| **F4 (twist)** | **Service wire down on Lake Road** under T9 | Only Lake Road's 15 homes | Initially suspected as T9 fuse (low confidence) → crew reports "T9 fine, Lake Road service line down" → **agent changes its mind** |
| **F5 (optional, T3)** | **T4 fuse also blown** (hidden behind F1) | After F1 repaired, ~8 T4 homes keep complaining | Verifier detects a hidden second fault |

### 6.3 Complaint generator rules
- For each fault, 20–60% of affected homes report, spread over a simulated **20 minutes** (bursty: most in the first 8 minutes).
- Formats (mix):
  - SMS: `BD 4512300017` (consumer number only) — ~50%
  - English free text — ~30%: `No power since 7pm`, `Lights went off with a loud bang`, `Wire fallen on the road near pole 23, sparks!` (hazard), `Water pump area has no electricity`
  - Sinhala free text — ~20% (native speaker should verify wording):
    - `විදුලිය නැහැ` — "no electricity"
    - `රෑ 7 ඉඳන් කරන්ට් නැහැ` — "no current since 7 pm"
    - `කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා` — "a wire has fallen to the ground near the pole" (hazard)
    - `ගිනි පුපුරු එනවා` — "sparks are coming" (hazard)
    - `ට්‍රාන්ස්ෆෝමරයෙන් සද්දයක් ආවා` — "a sound came from the transformer"
- **Noise:** 5 duplicates (same consumer, within 10 min), 3 false reports (homes on T7 that actually have power), 2 complaints with no consumer number but a landmark ("near pole 23").
- At least 3 hazard complaints for F1 mentioning pole 23 / wire down / sparks.
- Output ~300 complaints total as `Complaint`-shaped records with `time_min` (0–20).

### 6.4 Crew report samples (for field feedback)
- Crew C at T9: `T9 transformer is fine, fuses OK. Other streets have power. Overhead service line down on Lake Road.` → F4 becomes `SERVICE_WIRE` on Lake Road, homes_affected 15.
- Crew A at Pole 23: `Conductor snapped at pole 23, area made safe. Repair needs ~90 min.` → F1 `CONFIRMED`, ETA repair 90.
- Crew B at T8: `T8 HT fuse blown, replaced. Supply restored.` → F2 `RESTORED`.
- Crew B at T6: `T6 fuse replaced, pump running.` → F3 `RESTORED`.

---

## 7. Shared types — `gm_types.jac` (owned by B; approximate syntax, verify)

> **⚠ Renamed from `types.jac`. Person B must approve this (§1 rule 5).** A module named `types` passes `jac check` but fails at runtime (`cannot import name 'Hazard' from 'types'`), because Python's built-in `types` module wins. This was verified on 16 Oct; see JAC_FINDINGS.md. If B prefers another name, replace `gm_types` everywhere in this file and in PLAN.md.
>
> **Field order (for B):** required fields must come before defaulted ones (E2004, skill `jac-has-fields`). As sketched, `Complaint` (`text`, `time_min`), `Fault` (`homes_affected`) and `CustomerStatus` (`status_text`) put a required field after a defaulted one, so reorder them, or give them defaults, when writing the file.

```jac
enum Hazard { NONE, WIRE_DOWN, SPARKS, FIRE, TRANSFORMER_NOISE }
enum FaultKind { LINE_DOWN, TX_FUSE, SERVICE_WIRE, BREAKER_TRIP, UNKNOWN }
enum FaultStatus { SUSPECTED, CONFIRMED, CREW_ASSIGNED, REPAIRING, RESTORED, CLOSED }
enum CrewStatus { IDLE, TRAVELLING, ON_SITE, DONE }
enum Lang { EN, SI, MIXED }

obj Complaint {
    has id: str, consumer_no: str = "", text: str, time_min: float,
        lang: Lang = Lang.EN, hazard: Hazard = Hazard.NONE,
        landmark: str = "", home_id: str = "", is_duplicate: bool = False;
}
obj Fault {
    has id: str, kind: FaultKind, device_id: str, street: str = "",
        homes_affected: int, critical_loads: list[str] = [],
        hazard: Hazard = Hazard.NONE, priority: int = 0,
        confidence: float = 0.5, status: FaultStatus = FaultStatus.SUSPECTED,
        evidence: list[str] = [], complaint_ids: list[str] = [];
}
obj FaultUpdate {   # parse_crew_report's local CrewFinding is copied into this (§8.6)
    has fault_id: str, device_ok: bool, new_kind: FaultKind,
        new_device_id: str = "", street: str = "", restored: bool = False,
        repair_eta_min: int = 0, note: str = "";
}
obj Crew { has id: str, depot_id: str, location_id: str, status: CrewStatus,
               task_fault_id: str = "", eta_min: int = 0; }
obj CrewTask { has crew_id: str, fault_id: str, eta_min: int; }
obj SwitchStep { has switch_id: str, action: str; }   # action: "open" | "close"
obj Action {
    has id: str, kind: str, steps: list[SwitchStep], homes_restored: int,
        safe: bool, reason: str;
}
obj CustomerStatus { has consumer_no: str, has_power: bool, fault_id: str = "",
                         status_text: str, eta_min: int = 0; }
```

### Graph model — `grid.jac` (approximate)

`grid.jac` declares **all** nodes, edges **and walkers**: fields, plus ability declarations like `can tally with Localiser entry;`. The bodies live in `grid.impl/<feature>.impl.jac`, which the compiler pairs automatically. That keeps node abilities on the nodes without circular imports (see §12 and PLAN.md §2). This was verified on 16 Oct. Splitting nodes and walkers across modules fails at runtime, even though `jac check` passes.
- **Exception:** a walker ability that uses `disengage` keeps its body **inline** in `grid.jac`, because inside an `impl` block `jac check` rejects `disengage` (E2083). Keep such abilities tiny: `SafetyCheck` gets a 3-line inline `gate`, and its real step logic stays in the impl file (§8.8).
- Declare `Feeds` with endpoint types on a shared base node, e.g. `node GridNode { has id: str = "", x: int = 0, y: int = 0; }` with `node Section(GridNode)` and so on, and `edge Feeds: GridNode --> GridNode { ... }`. Then `[here <-:Feeds:<-]` is typed, and one walker ability `with GridNode entry` fires on every kind of node. Parent defaults force child defaults, so give every field in the subclasses a default. PLAN.md WP-B0 adds the fields `Section.line_ok`, `Transformer.service_ok` and `Switch.locked_out`, plus the `SimState` and `ParseCache` nodes.

```jac
node Substation { has id: str, name: str, x: int, y: int; }
node Section    { has id: str, feeder: str, x: int, y: int, energised: bool = True,
                      work_zone: bool = False, reports: int = 0; }
node Switch     { has id: str, kind: str, closed: bool, normally_open: bool = False,
                      x: int, y: int; }        # kind: "recloser" | "switch" | "tie"
node Transformer{ has id: str, homes: int, x: int, y: int, fuse_ok: bool = True,
                      reports: int = 0, critical: list[str] = []; }
node Home       { has id: str, consumer_no: str, street: str, x: int, y: int,
                      has_power: bool = True, reported: bool = False; }
node Depot      { has id: str, name: str, x: int, y: int; }
node Landmark   { has id: str, name: str, section_id: str, x: int, y: int; }
node CrewNode   { has crew: Crew; }
node FaultNode  { has fault: Fault; }

edge Feeds   { has capacity: int = 0; }   # parent -> child, direction of power flow
edge Located {}                           # Landmark -> Section, Crew -> location
```

Edges follow **power-flow direction**: Substation → Section → Switch → Section …, Section → Transformer → Home. "Upstream" = reverse traversal `[<-:Feeds:<-]`.

---

## 8. Agents & algorithms

> **`sem`, not docstrings.** Describe every LLM-visible function, parameter, obj field and enum member with a `sem` statement. That text is the prompt the model sees. Triple-quoted docstrings are *not* used for this, and inside a body they fail with W0060 (skill: `jac-by-llm`).
> - `by llm()` returns `obj`s. Copy the fields into nodes to persist them.
> - **`by llm()` output objs are declared in the same module as the function**, including list items and wrapper fields. byllm 0.6.19 crashes on an output obj imported from `gm_types.jac` (§1a). Declare a local twin (e.g. `LlmParsed` in `agents_parse.jac`, `CrewFinding` in `agents_feedback.jac`) with the same fields and its own `sem`, then copy its fields into the shared obj. Enums and *input* parameters (`fault: Fault`) can come from `gm_types.jac`; both were verified. Put the enums' `sem` lines in `gm_types.jac`, next to the enums.
> - Walker bodies go in `grid.impl/*.impl.jac`, except abilities that `disengage` (§7). Pure logic goes in the `agents_*.jac` modules (§12).

### 8.1 Complaint Parser (B) — `agents_parse.jac`
```jac
# In gm_types.jac, next to the enum:
sem Hazard.WIRE_DOWN = "A power line or wire has fallen, is hanging low, or is on the road/ground";
sem Hazard.SPARKS = "Sparks, arcing, flashes, burning smell from lines or transformers";

# In agents_parse.jac. The LLM-facing twin of gm_types.ParsedText is declared HERE,
# because a by llm() output obj from another module crashes byllm (§8 note).
import from gm_types { Hazard, Lang, ParsedText }

obj LlmParsed {
    has index: int, lang: Lang = Lang.EN, hazard: Hazard = Hazard.NONE, landmark: str = "";
}
sem LlmParsed.index = "Position of the complaint in the input list, starting at 0.";
sem LlmParsed.landmark = "A named location like 'pole 23', 'near the temple', 'hospital road' if mentioned";
sem LlmParsed.lang = "Language of the text: Sinhala (SI), English (EN) or mixed";

# Batch: ~10 free-text complaints per call; results map back by `index` (PLAN.md WP-B1)
def parse_texts(texts: list[str]) -> list[LlmParsed] by llm();
sem parse_texts = "Parse power-outage complaints from Sri Lankan electricity customers (English or Sinhala). Return one item per input, with its index.";
sem parse_texts.texts = "The complaint texts, in order.";

# Single complaint, for submit_complaint from the customer page
def parse_one(raw: str) -> LlmParsed by llm();
sem parse_one = "Parse one power-outage complaint from a Sri Lankan electricity customer (English or Sinhala).";

# Copy into the shared type that ParseCache stores
def to_parsed_text(p: LlmParsed) -> ParsedText {
    return ParsedText(index=p.index, lang=p.lang, hazard=p.hazard, landmark=p.landmark);
}
```
- Parse results are cached by raw text in `ParseCache`, and the cache survives `reset` (§12, PLAN.md §2).
- If text matches `^BD\s*\d{10}$`, parse **deterministically** (no LLM call) — saves cost.
- Map `consumer_no` → `Home` node. If missing, map `landmark` via the Landmark table (e.g. "pole 23" → F1-B).
- Duplicate: same `consumer_no` within 10 minutes → `is_duplicate = True`, do not count again.

### 8.2 Localiser (B) — `grid.impl/localize.impl.jac` + grouping in `agents_group.jac`
Walker spawned per new (non-duplicate) complaint at its `Home`, walking **upstream**.
- **Node abilities (must be on the nodes, not the walker):**
  - `Home` on Localiser entry → `reported = True`.
  - `Transformer` on Localiser entry → `reports += 1`.
  - `Section` on Localiser entry → `reports += 1`.
- After each batch (or every simulated minute), run grouping:
  1. For each transformer compute `ratio = distinct reporting homes / homes`.
  2. For each section S: if **≥ 2 transformers in S's downstream subtree** have `ratio ≥ 0.2`, OR a hazard complaint's landmark maps to S → suspect **LINE_DOWN at the most upstream de-energised-looking section** whose subtree contains them. That fault explains all transformers downstream; remove them from further grouping.
  3. Remaining transformers: `ratio ≥ 0.3` → **TX_FUSE** at that transformer.
  4. Remaining transformers with `0.05 ≤ ratio < 0.3` and **≥ 60% of reports on one street** → initially **TX_FUSE with confidence 0.4** (this is intentional — the crew report later corrects it to SERVICE_WIRE). *(Alternative allowed: SERVICE_WIRE directly if confidence logic is implemented — but the demo twist requires the T9 case to start as TX_FUSE suspected.)*
  5. Isolated single reports where upstream shows no other reports → mark `possible false/individual issue`, no fault.
- `homes_affected` = all homes downstream of the faulted device (including non-reporters); for SERVICE_WIRE = homes on that street.
- `evidence` strings, e.g. `"62 of 205 homes downstream of F1-B reported"`, `"3 hazard reports mention pole 23"`.

### 8.3 Energiser (C) — `grid.impl/energise.impl.jac`
Walker from SS1 through **closed** switches; Sections/Transformers/Homes set `energised` / `has_power`. It follows `Feeds` edges in **both** directions, so the tie TS1 works either way. Re-run after every switching change or repair. A section with an active LINE_DOWN fault blocks propagation beyond it unless isolated & re-fed. It may read physical truth (`line_ok`, `fuse_ok`, `service_ok`); the discovery agents may not.

### 8.4 Prioritiser (B) — `agents_priority.jac`
```
priority = 1000 * (hazard != NONE)
         +  500 * (len(critical_loads) > 0)
         +        homes_affected
         +   2 *  minutes_since_first_report
```
Sort descending. Expose via `get_faults`.

### 8.5 Dispatcher (C) — `grid.impl/dispatch.impl.jac`
- Assign the highest-priority **unassigned** fault to the **idle crew with the lowest travel time** (travel table §6.1).
- Crew → `TRAVELLING`, `eta_min` from table; when simulated clock passes ETA → `ON_SITE`.
- After a fault is resolved, crew takes the next fault directly (does not return to depot) unless none remain.

### 8.6 Field Feedback (B) — `agents_feedback.jac` + `grid.impl/feedback.impl.jac`
```jac
# LLM-facing twin of gm_types.FaultUpdate, declared in agents_feedback.jac (§8 note).
obj CrewFinding {
    has fault_id: str, device_ok: bool, new_kind: FaultKind, new_device_id: str = "",
        street: str = "", restored: bool = False, repair_eta_min: int = 0, note: str = "";
}

# The parameter is `text`, not `report`, because `report` is a Jac keyword (E0013).
def parse_crew_report(text: str, fault: Fault) -> CrewFinding by llm();
sem parse_crew_report = "Interpret a field crew's report about a power fault and say what changed.";
sem parse_crew_report.text = "The crew's free-text field report.";
sem parse_crew_report.fault = "The fault the crew was sent to, as currently believed.";
```
- Copy the `CrewFinding` into a `gm_types.FaultUpdate` before applying it. For a single top-level obj, `-> gm_types.FaultUpdate by llm()` (module-qualified, after `import gm_types;`) also works, but the twin is the safer pattern.
- `FaultNode` ability on `CrewReport` walker entry applies the update: change kind/device/street, adjust `homes_affected`, status, confidence → re-run Prioritiser.
- Log a clear **before → after** event, e.g. `F4: TX_FUSE@T9 (conf 0.4) → SERVICE_WIRE@Lake Road (conf 0.9) — crew report`. The UI highlights this ("agent changed its mind").

### 8.7 Restorer (C, T3) — `grid.impl/restore.impl.jac`
For each de-energised section that does **not** contain an active fault:
1. Find a path from it to an energised feeder through a **normally-open tie switch** (TS1).
2. Build a switching plan: first **open** the switch isolating it from the faulted section (SW2), then **close** the tie (TS1).
3. Capacity check: receiving feeder homes + transferred homes ≤ 700.
4. Run `SafetyCheck` on the plan. If safe → offer `Action` with `homes_restored` (e.g. 70 homes on T5).

### 8.8 SafetyCheck (C, T3) — `grid.impl/safety.impl.jac`
Simulate each `SwitchStep` in order on a copy of switch states; after each step, compute which sections are connected to any source (SS1 via either feeder). If any `work_zone` section becomes energised → `safe = False`, `reason = "Step N energises work zone F1-B where Crew A is working"`.
- **Switch node ability** on SafetyCheck entry: refuse if closing it would connect a source to a work zone.
  - `disengage` isn't allowed inside a node ability (E2083). So the node sets a flag on the walker, e.g. `visitor.blocked_by = self.id`, and may `report` a reason; a `report` from a node ability lands in the walker's `.reports`.
  - The walker stops itself with a small **gate** ability declared **inline in `grid.jac`** (B writes it with the contract), next to its main step ability. C fills in the step's body in `grid.impl/safety.impl.jac`:
    ```jac
    walker SafetyCheck {
        has blocked_by: str = "", ...;
        can gate with GridNode entry {    # inline: disengage is rejected in impl blocks
            if self.blocked_by != "" { disengage; }
        }
        can step with GridNode entry;     # body in grid.impl/safety.impl.jac
    }
    ```
  - Abilities on the same node type fire in declaration order, and the gate's `disengage` stops the step. The walker's abilities run before the node's on each node, so the walker stops at its next step. Write the flag on the walker, not on the node. This was verified in a probe, and it passes `jac check`.
  - Verified in the test app: "closing SW1 would energise work zone SecB" was blocked, and an open switch further down correctly stopped the check.
- **Demo:** try "close TS1" *without* opening SW2 first → **BLOCKED**. Then the correct plan (open SW2, close TS1) → **SAFE**, T5's 70 homes turn green.

### 8.9 Verifier (B, T3) — `grid.impl/verify.impl.jac`
After a fault is marked RESTORED, if ≥ 3 new non-duplicate complaints arrive within 5 simulated minutes from homes downstream of that device → re-run localisation → create a new fault (F5: T4 fuse) with evidence `"complaints continued after F1 repair"`.

### 8.10 Explainer (B, T2) — `agents_explain.jac`
```jac
def explain_fault(fault: Fault) -> str by llm();
sem explain_fault = "Explain to a control-room operator, in 2 short sentences, why this fault was identified and ranked this way.";
sem explain_fault.fault = "The fault, with its evidence, priority and status.";
```
- Cache the explanation on the `FaultNode` and recompute it only when the fault changes.

---

## 9. API — walkers as endpoints (`api.jac`)

All are `walker:pub` (each is served as `POST /walker/<Name>`, and the client calls them through the compiler-generated bridge, with no hand-written fetch). C builds the UI against **mock data in exactly these shapes** until 13:00.

| Endpoint | Input | Returns |
|---|---|---|
| `get_grid` | — | nodes (id, type, x, y, state fields) + edges (from, to, closed) |
| `start_storm` | `speed: int` | ok; begins releasing scenario complaints by simulated clock |
| `tick` | `minutes: float` | advances simulated clock (complaints released, crews move) |
| `submit_complaint` | `text: str, consumer_no: str = ""` | `Complaint` |
| `get_complaints` | `since_min: float` | `list[Complaint]` |
| `get_faults` | — | ranked `list[Fault]` |
| `get_crews` | — | `list[Crew]` |
| `get_tasks` | — | `list[CrewTask]` |
| `crew_report` | `crew_id: str, text: str` | updated `Fault` |
| `get_actions` | — | `list[Action]` |
| `apply_action` | `action_id: str` | updated grid summary |
| `get_events` | `since_min: float` | event log entries `{time_min, kind, text}` |
| `get_status` | `consumer_no: str` | `CustomerStatus` |
| `reset` | — | ok; restores initial grid & clears storm |

Use a **simulated clock** (`clock_min`) stored in the graph; `tick` drives the simulation so the demo is deterministic and replayable.

---

## 10. Frontend spec (C) — `ui_app.cl.jac`, `ui_customer.cl.jac`

### Operator dashboard layout
- **Top bar:** title, storm clock, counters: *complaints received → faults found → homes without power → homes restored*; speed (1× / 5× / 20×); Start Storm; Reset.
- **Main (~70%):** schematic single-line-style grid diagram (SVG or a graph library from npm such as React Flow / Cytoscape — imported, not committed).
- **Right panel:** ranked faults (priority, kind, device, homes affected, badges ⚠️ hazard / 🏥 hospital / 💧 water pump, status, evidence), crew tasks (crew, fault, ETA, status), restoration actions with **Apply** + safety result.
- **Bottom strip:** event log + reasoning ("Why?") for the selected fault + crew-report box (select crew, type text, send).

### Visual states
| Element | States |
|---|---|
| Section/wire | energised (dark) · de-energised (grey) · faulted (red) · restored via tie (green) |
| Transformer | normal · suspected (orange) · confirmed fault (red) · restored (green) |
| Home dot | powered · unpowered · reported (pulsing) |
| Switch | closed (connected) · open (gap) · tie (dashed) |
| Crew | idle at depot · travelling (animated along edges) · on site |
| Hazard | ⚠️ icon at Pole 23 |
| Mind-change | brief highlight + "Updated by crew report" badge on the fault card |

### Customer page (T2)
- Report outage: consumer number + optional text → `submit_complaint`.
- Status: enter consumer number → `get_status` → e.g. *"Fault found · Crew A assigned · ETA 35 min"* / *"Power restored"*.
- Simulated SMS panel showing messages as status changes.
- Copy note: *"In deployment this would feed existing channels (1987 SMS / CEBCare)."*

---

## 11. Test cases (A writes; B/C make them pass)

| # | Given | Expect |
|---|---|---|
| 1 | Full storm, all complaints processed | Exactly faults for F1, F2, F3, F4 (F5 only if enabled) |
| 2 | F1 | kind `LINE_DOWN`, device `F1-B`, homes_affected `205`, hazard `WIRE_DOWN` or `SPARKS`, critical includes `HOSPITAL` |
| 3 | F2 | `TX_FUSE` at `T8`, homes 40 |
| 4 | F3 | `TX_FUSE` at `T6`, homes 50, critical includes `WATER_PUMP` |
| 5 | F4 before crew report | `TX_FUSE` at `T9`, confidence < 0.6 |
| 6 | F4 after Crew C report (§6.4) | `SERVICE_WIRE`, street `Lake Road`, homes 15, confidence ≥ 0.8 |
| 7 | Ranking | F1 first (hazard), F3 second (water pump), then by homes |
| 8 | Duplicates | 5 duplicates flagged, not double-counted |
| 9 | False reports | 3 T7 reports produce **no** fault |
| 10 | `BD 4512300017` | parsed without LLM, mapped to correct home |
| 11 | Sinhala `කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා` | hazard `WIRE_DOWN` |
| 12 | SafetyCheck: close TS1 with SW2 closed, crew at F1-B | `safe = False` |
| 13 | SafetyCheck: open SW2 then close TS1 | `safe = True`, homes_restored 70, F2 load 360 ≤ 700 |
| 14 | Dispatch | First task: nearest idle crew to F1 (Crew A or B from CSC-North, ETA 8) |
| 15 | Verifier (F5 enabled) | New fault at T4 after F1 restored |

---

## 12. Repository layout

Each file has exactly one owning work package. **PLAN.md §3 is the authoritative owner list**; this is the overview.

```
gridmedic/
  CLAUDE.md, PLAN.md      # brief + work plan
  README.md               # write-up (A)
  jac.toml                # project + byllm model config (A)
  main.jac                # entry: server imports + cl { } client mount (A, then C)
  gm_types.jac            # shared objs/enums — contract (B); renamed from types.jac, needs B's OK (§7)
  grid.jac                # ALL node/edge/walker declarations — contract (B)
  grid.impl/              # walker + node-ability bodies, one file per owner, auto-paired with grid.jac
    localize.impl.jac     #   Localiser + Home/Transformer/Section tally abilities (B)
    energise.impl.jac     #   Energiser (C)
    dispatch.impl.jac     #   Dispatcher + crew movement (C)
    feedback.impl.jac     #   CrewReport + FaultNode re-evaluate ability (B)
    restore.impl.jac      #   Restorer (C, T3)
    safety.impl.jac       #   SafetyCheck + Switch guard ability (C, T3)
    verify.impl.jac       #   Verifier (B, T3)
  grid_build.jac          # builds the §6.1 demo grid (A)
  grid_storm.jac          # ground truth + complaint generator (A)
  agents_parse.jac        # BD regex, batch by llm(), parse cache, duplicates (B)
  agents_group.jac        # groups complaints into Faults, §8.2 steps 1–5 (B)
  agents_priority.jac     # prioritiser (B)
  agents_feedback.jac     # parse_crew_report by llm() (B)
  agents_explain.jac      # explain_fault by llm() (B)
  sim.jac                 # SimState, start_storm / tick / reset pipeline, event log (B)
  api.jac                 # walker:pub endpoints (B); api_mock.jac holds mocks until real bodies land
  ui_app.cl.jac           # operator dashboard shell + poll loop (C)
  ui_customer.cl.jac      # customer page (C)
  components/*.cl.jac     # GridMap, FaultList, CrewPanel, EventLog, CrewReportBox, ActionsPanel (C)
  scripts/smoke_llm.jac   # real-Gemini check: typed obj + Sinhala hazards (A)
  tests/*_tests.jac       # §11 acceptance tests (A); unit tests in <module>.test.jac annexes
```
**Import rule:** `grid.jac` imports only `gm_types.jac`. Other modules may import `grid`, but `grid` never imports them, which keeps imports free of cycles. Orchestration lives in `sim.jac`.

At 09:00, scaffold with `jac create gridmedic --kind fullstack`, then run `jac install`, set `JAC_OPT_LEVEL=0` and run `jac start --dev`, then add these files. Separate files per owner avoid merge conflicts between parallel agents (PLAN.md §1.1).
- The scaffold creates its own `main.jac` and `jac.toml` (and may add `styles.css`, `AGENTS.md`, `README.md`). Merge those with this layout rather than keeping duplicates.
- Add `.jac/` and any frontend build or dependency folders to `.gitignore`.
- The UI files (`ui_*.cl.jac`) call server code with `sv import` (see §1a).

### LLM config (`jac.toml`)
```toml
[plugins.byllm.model]
default_model = "gemini/gemini-3.5-flash-lite"   # fastest, cheapest Gemini 3.5 model
```
- Set `GEMINI_API_KEY` in the environment, and never commit it.
- **Smoke test at 09:00:**
  - Run one `by llm()` call that returns a typed `obj`, to confirm structured output works live.
  - Parse the five Sinhala phrases from §6.3 and check the hazards come back right.
- Use deterministic parsing for `BD <number>` SMS to minimise LLM calls.

**Budget the LLM calls.** A storm has ~300 complaints. The `BD` SMS (~50%) skip the LLM, which leaves ~150 free-text ones.
- On the free tier, 3.5 Flash-Lite is reported at ~500 requests/day per Google project, plus a per-minute cap (check AI Studio for the key's real limits).
- Unbatched, that's only ~3 storm runs a day, and each storm takes 10+ minutes of real time.

1. **Batch the parsing (Person B's call):** parse ~10 complaints per call with `parse_texts(texts: list[str]) -> list[LlmParsed]` (§8.1). byLLM supports list returns, but only when the list's obj type is declared in the same module as the function; this was verified with MockLLM. `list[Complaint]` imported from `gm_types.jac` crashes.
   - That's ~15 calls per storm instead of ~150.
   - Keep the single-complaint `parse_complaint` for `submit_complaint` from the customer page.
2. **Cache by complaint text:** the storm scenario is fixed, so store parsed results keyed by the raw text and reuse them after `reset`.
   - A fresh storm is still parsed live.
   - Mention the cache in the write-up.
3. **One key per teammate** while developing: the free quota is per Google project.
4. **Billing for the demo:** enable billing on the AI Studio project used for the demo recording and Jac Hammer, and set a budget alert in Google Cloud.
   - Price: $0.30 per 1M input tokens and $2.50 per 1M output.
   - Our estimate: ~7 cents per *unbatched* storm (~150 calls × ~700 input / ~100 output tokens), so a few dollars covers the whole day.
5. **Optional fallback:** byLLM's `ModelPool` (from `byllm.lib`) with `strategy="fallback"` can try Gemini first and switch to a free Groq model (`groq/...`, `GROQ_API_KEY`) on errors.
   - Groq's open models are likely weaker at Sinhala, so test the §6.3 phrases before relying on one.
   - Check the `ModelPool` syntax in the `jac-by-llm` skill.

---

## 13. Team & timeline

| Person | Owns |
|---|---|
| **A** | Grid, storm data, test cases, demo script & video, README/write-up, 80% Jac check, submission. **Does not write feature code.** |
| **B** | `gm_types.jac` + endpoints contract, parser, localiser, prioritiser, field feedback, explainer, verifier |
| **C** | Frontend (operator + customer), integration, dispatcher, restoration, safety check |

**Before the day (setup only, no project code, nothing in the repo):** every laptop installs the **same** pip-line versions from §1a into a short-path venv, and `jac --version` must report 0.16.7. Also:
- Run a `hello.jac` in a scratch folder **outside** the repo.
- Install the VS Code "Jac Language Support" extension.
- Export the Jac guides as Claude Code skills: with the venv active, run `jac guide --export $HOME\.claude\skills`. Then start a **new** session and type `/jac` to check the `jac-*` skills are listed. Re-run the export after any Jac upgrade.
- Optional: add the MCP server with `claude mcp add jac -- jac mcp`. It isn't needed if the skills are installed.
- Set the Gemini API key: `setx GEMINI_API_KEY "your-key-here"` (applies to terminals opened afterwards).
- Run `setx JAC_OPT_LEVEL 0`. Without it, `jac start` crashes on this install (§1a).
- Create a Jac Hammer account.

| Time | Checkpoint |
|---|---|
| 08:00 | Every member registers and checks in |
| 09:00–09:30 | Commit CLAUDE.md, scaffold, `gm_types.jac`; first `.jac` push; check GitHub language bar; `by llm()` smoke test; everyone stars github.com/jaseci-labs/jac |
| 10:15 | A's real grid renders in C's diagram |
| **13:00** | **End to end: Start Storm → complaints → faults on map → ranked list** ⚠️ |
| 13:00–14:00 | Test deploy on Jac Hammer: import from GitHub, set `GEMINI_API_KEY` as a **project-level** env var, check which Jac version it runs (pin if needed), sandbox deploy |
| 15:00 | Crew report changes the plan live (F4 twist); restoration working or cut |
| **15:30** | **Feature freeze** — bug fixes only; A records video |
| 17:15 | Submitted |

Fallbacks: if restoration/safety not working by 15:00 → cut. If localiser late at 12:30 → C pauses UI polish to help B.

---

## 14. Demo video script (~2:30, captions on screen; no live Q&A)

1. **0:00–0:20 Problem:** "May 2024: 61,000 complaints in six days. Many come from the same fault." Start Storm — complaint dots flood in.
2. **0:20–0:50 Understand:** Sinhala + English complaints parsed; hazard at Pole 23 flagged; counter "300 complaints → 4 faults".
3. **0:50–1:30 Act:** ranked list (hazard first, water pump second); crews dispatched and moving; **Crew C report on T9 → fault changes to Lake Road service wire** (highlight the mind-change).
4. **1:30–2:00 Restore safely:** attempt TS1 without opening SW2 → **BLOCKED** by safety check; correct plan → T5's 70 homes turn green. Customer page shows "Power restored".
5. **2:00–2:25 Why Jac:** show code: walker tracing upstream, Transformer node tallying, Switch guarding, `by llm()` typed parse, one codebase.
6. **2:25–2:35 Close:** "From a flood of complaints to a safe, ranked action plan — in real time."

## 15. Write-up outline (README.md)
Problem (with sources) → What GridMedic does → Agents (list from §8) → **How we used Jac** (table from §4) → Demo data (fictional, realistic radial layout) → Limitations & next steps (real CEB network data, GPS crew tracking, Sinhala voice, integration with existing OMS) → Coding-agent use disclosed → Jac line-count percentage.

### Sources for the write-up
- Daily FT, 27 May 2024 — 61,000+ complaints, 467,500+ users: https://ft.lk/news/Inclement-weather-causes-massive-power-outages-countrywide/56-762205
- Ada Derana, 30 May 2025 — 29,015 breakdowns: https://www.adaderana.lk/news/109025/over-29000-electricity-breakdowns-reported-across-sri-lanka
- CEB Supply Services Code (control centres, ECSCs): https://www.ceb.lk/front_img/img_reports/1532507262Supply_Services_Code_DD2.pdf

---

## 16. Things to avoid
- Do not claim facts about how CEB currently assigns crews or that its systems are broken.
- Do not build voice input, real maps APIs, GPS tracking, or real CEB integration.
- Do not add features beyond the current tier before the lower tier works end to end.
- Do not create non-Jac source files.
- Do not trust "it works" — run the storm and the tests.
