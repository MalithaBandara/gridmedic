# GridMedic

> *Walkers that trace every outage complaint back to its fault.*

**AI decision support for power-outage complaints.** GridMedic groups a utility's incoming outage reports into real faults, ranks them (hazards first), recommends crew dispatch, learns from crew field reports and suggests safe restoration steps. A human operator approves every action.

Built in [Jac](https://github.com/jaseci-labs/jac) for the **AI Hackathon 2026, powered by Jaseci Labs** (University of Moratuwa, 17 Oct 2026).

> 🚧 **Work in progress.** This README is filled in as features land during the hackathon. See [Status](#status) for what works today.

---

## The problem

Every outage produces a burst of complaints, and many of them describe the **same fault**. One blown transformer fuse can bring ~80 calls; one broken line section can bring hundreds. The hard part for a control room is turning those messages into a short list of real faults, deciding which to fix first, and acting safely.

This happens every day, and it becomes overwhelming during severe weather:

- In the May 2024 storms, the Ceylon Electricity Board (CEB) received **over 61,000 breakdown complaints in six days**, affecting **467,500+ users** ([Daily FT, 27 May 2024](https://ft.lk/news/Inclement-weather-causes-massive-power-outages-countrywide/56-762205)).
- In the May 2025 storms, CEB reported **29,015 breakdowns**, handled with limited staff and resources ([Ada Derana, 30 May 2025](https://www.adaderana.lk/news/109025/over-29000-electricity-breakdowns-reported-across-sri-lanka)).

Complaints arrive through the 1987 hotline, SMS (`BD <consumer number>`), the CEBCare app and the web portal, and are handled by area control centres and Electricity Consumer Service Centres, from which crews are dispatched ([CEB Supply Services Code](https://www.ceb.lk/front_img/img_reports/1532507262Supply_Services_Code_DD2.pdf)).

## What GridMedic does

1. **Understands messy complaints.** English and Sinhala free text and `BD` SMS are parsed into typed records: language, hazard (wire down, sparks, fire, transformer noise) and landmarks such as "near pole 23".
2. **Finds the real faults.** Walkers trace each complaint upstream through the grid. Transformers and line sections count their own reports, and the reports are grouped into faults: a line down, a blown transformer fuse or a single street's service wire.
3. **Ranks them.** Hazards first, then critical loads (hospital, water pump, schools, police station), then the number of homes affected and how long they have waited.
4. **Dispatches crews.** The highest-priority unassigned fault goes to the nearest idle crew.
5. **Changes its mind from field reports.** A crew's free-text report ("T9 is fine, service line down on Lake Road") updates the fault and the ranking, and the change is shown to the operator.
6. **Restores power safely.** It proposes switching plans, both closing the tie switch to the other feeder and starting a local microgrid (the hospital's diesel-and-battery backup, a neighbourhood solar-and-battery system). It checks capacity and battery time, and blocks any step that would energise or backfeed a section where a crew is working.
7. **Verifies fixes.** If complaints continue after a repair, it looks for a hidden second fault.

There are two views, served from one codebase:

- **Operator dashboard** (`/`): live grid map, consumer and critical-load counters, ranked faults with evidence ("Why?"), crews, event log, crew-report box, and a floating simulation controller (start, speed, reset).
- **Customer page** (`/customer`): report an outage, check status by consumer number, and see simulated SMS updates.

### What it is not

- It does **not** control real switches. A human approves every action.
- It does **not** connect to CEB systems or real data. The demo uses a **fictional grid** modelled on a realistic radial distribution layout.
- There is **no voice input**; complaints are text.
- It is not a replacement for a commercial Outage Management System. It is an AI decision layer that could sit on top of a utility's existing complaint channels.

## Agents

| Agent | What it does |
|---|---|
| **Complaint Parser** | `BD <number>` SMS parsed deterministically; free text parsed by `by llm()` in batches of ~10, cached by text |
| **Localiser** | Walker that walks upstream from a complaint's home; nodes tally their own reports |
| **Grouper** | Turns tallies into `LINE_DOWN`, `TX_FUSE` or `SERVICE_WIRE` faults with evidence and confidence |
| **Prioritiser** | `1000·hazard + 500·critical load + homes affected + 2·minutes waiting` |
| **Simulation pipeline** | Each tick of a simulated clock releases complaints, parses them, runs one Localiser for the batch, regroups faults and re-ranks them |
| **Energiser** | Walker that recomputes which sections, transformers and homes have power |
| **Dispatcher** | Assigns crews by travel time; crews move on a simulated clock |
| **Field Feedback** | `by llm()` reads crew reports and updates the fault ("agent changes its mind") |
| **Explainer** | `by llm()` explains in two sentences why a fault was identified and ranked; cached until the fault changes, with an evidence-based fallback if the LLM is unavailable |
| **Restorer + SafetyCheck** | Builds tie-switch and microgrid plans; switches refuse to close onto a crew's work zone, and a microgrid is only started once it is isolated from the faulted line |
| **Verifier** | Detects complaints that continue after a repair |

## How we used Jac

GridMedic is built around Jac **walkers**. The power grid is a graph of nodes, and each agent is a walker that moves through it: the Localiser walks upstream from a complaining home to the fault, the Energiser walks downstream to work out who has power, and the SafetyCheck walks a switching plan step by step and stops at the first unsafe one. The nodes do their own share of the work as walkers arrive: transformers count their own complaints and switches refuse to close onto a crew's work zone.

| Jac feature | Where it is used |
|---|---|
| Nodes and typed edges | The grid itself: substation, sections, switches, transformers, homes, microgrids; `Feeds` edges in power-flow direction |
| Walkers | Localiser, Energiser, Dispatcher, CrewReport, Restorer, SafetyCheck, Verifier |
| Node abilities | Transformers and sections tally their own complaints; switches guard their own safety; faults re-evaluate themselves from crew reports |
| `by llm()` with typed outputs | Complaint parsing, crew-report parsing, fault explanations |
| `sem` | Meanings of hazards, fault kinds, Sinhala phrases and landmarks, given to the model |
| Persistence under `root` | Grid, complaints, faults and crews persist with no database setup |
| `walker:pub` endpoints | The whole backend API |
| Client/server codespaces | Operator and customer UI in `.cl.jac`, calling the server with `sv import`, receiving typed objects |
| `flow` / `wait` | Overlapping the batched LLM parse calls |
| `visit`, `report`, `disengage` | Edge-filtered traversal, reporting findings, stopping at blocked switching steps |

> *The grid is a graph, and GridMedic's agents are walkers. They trace complaints upstream; every transformer counts its own reports and every switch guards its own safety. One language from the AI to the map.*

### What we learned about Jac along the way

- **Traversal speed matters on a 600-home graph.** Typed-edge filters such as `[n <-:Feeds:<-]` on our inherited node types cost about 12 ms per node, so one walk over the grid took 8–10 s. Plain `[n -->]` filtered with `isinstance` took 0.13 s for the same walk. All traversals use small `children()` / `parents()` helpers in `grid.jac`, and walkers `visit children(here)`.
- **Spawn once per batch.** Each walker spawn costs ~0.2 s on this graph, so the Localiser is spawned once per tick for the whole batch of new complaints: 109 complaints are localised in 0.4 s.
- **Nodes and walkers share one declaration file** (`grid.jac`) with bodies in `grid.impl/*.impl.jac`, which avoids circular imports and lets each teammate own separate implementation files.
- **`by llm()` output types are declared next to the function** and copied into the shared types.
- **Enums stored inside lists on a node come back as plain numbers.** Hazards read back from the complaint log compared unequal to `Hazard.WIRE_DOWN`, which silently dropped the line-down fault's hazard priority. The acceptance storm test caught it, and every read site now re-wraps the values (`fix_complaint`, `fix_parsed` in `gm_types.jac`).

## Demo data

A fictional two-feeder radial network around a "Moratuwa Grid Substation": two feeders, five line sections, 10 transformers and **600 consumers** on named streets, a normally-open tie switch between the feeders, two Consumer Service Centres and three crews.

Five priority facilities are shown on the map and boost a fault's priority: Lakeview General Hospital, the Reservoir Road Pumping Station, the Ward Place Police Station, and two schools.

Two microgrids can carry load when the main grid can't reach it:

- **MG-HOSP**, the hospital's diesel-and-battery backup on T3, which supplies the hospital only (about 240 minutes).
- **MG-RES**, a Bridge Road solar-and-battery system on T5, which can carry up to 80 homes (about 120 minutes).

The map shows each one's remaining battery.

The demo scenario is a storm, because that is when complaint volume peaks. Its hidden ground truth, which the agents must discover from ~300 complaints alone:

- a line down at Pole 23 (205 homes, including the hospital and a school, with sparks reported),
- two blown transformer fuses (one feeding the water pump),
- a service wire down on one street, first suspected as a transformer fuse until a crew corrects it,
- optionally, a second fault hidden behind the first.

The complaint stream mixes `BD` SMS, English and Sinhala text, and includes duplicates, false reports and landmark-only complaints.

## Running it

Requirements: Python ≥ 3.12 (to install the Jac compiler) and a Gemini API key.

```bash
pip install jaclang==0.16.7 jac-client==0.3.25 byllm==0.6.19
jac install
```

Set the environment (PowerShell shown):

```powershell
$env:GEMINI_API_KEY = "your-key"
$env:JAC_OPT_LEVEL = "0"   # avoids an llvmlite crash in jaclang 0.16.7
```

```bash
jac start --dev
```

Open http://localhost:8000 for the operator dashboard and http://localhost:8000/customer for the customer page; the API runs on port 8001. Restart the server after editing any `.jac` file.

Tests: stop the server, run `jac clean --all --force`, then `jac test`. Cleaning fails while a server holds the database, and the tests would then reuse its data. The LLM-backed functions use `MockLLM` in tests. The real-LLM check: `jac run scripts/smoke_llm.jac`.

The LLM is `gemini/gemini-3.5-flash-lite`, configured in `jac.toml`.

## Status

As of early afternoon on 17 Oct, a full storm runs end to end in the browser on the real 600-consumer grid:

1. Start Storm.
2. ~300 complaints are parsed and traced upstream.
3. Four ranked faults appear on a live map, each with a "Why?" explanation.
4. Crews are dispatched and move on the map.
5. A crew report corrects T9 to a Lake Road service wire.
6. Restoration plans (tie switch and microgrids) are safety-checked: the unsafe plan is blocked, and the safe one restores T5's 70 homes.

| Piece | State |
|---|---|
| Scaffold, Gemini config, LLM smoke script | ✅ done (live Gemini check not run yet) |
| Shared types (`gm_types.jac`), grid declarations (`grid.jac`) | ✅ done |
| Demo grid builder (600 consumers, streets, priority facilities) | ✅ done |
| Complaint parser (BD regex, batched `by llm()`, cache, duplicates) | ✅ done |
| Localiser and fault grouping | ✅ done |
| Prioritiser | ✅ done |
| Simulation pipeline and real API | ✅ done |
| Operator dashboard, live grid map, customer page (bilingual reports, simulated SMS) | ✅ done |
| Storm complaint generator (~300 complaints: BD SMS, English, Sinhala, duplicates, false reports) | ✅ done |
| Energiser (who has power), crew dispatch and movement | ✅ done |
| Crew-report feedback ("agent changes its mind") | ✅ done |
| Explainer and "Why?" panel | ✅ done |
| Restoration and safety check (tie switch, microgrids) | ✅ done |
| Acceptance tests | ✅ storm, noise, safety, dispatch, energise and microgrid suites in `tests/` |
| Verifier (hidden second fault) | 🟡 in progress (B7; its test 15 is `tests/verifier_tests.jac`) |
| Jac Hammer deploy | ⏳ planned |

**Language:** GitHub reports the repo as **99.9% Jac** (the rest is a 15-line CSS reset).

## Limitations and next steps

- Fictional grid and data; next step is real network data from a utility.
- No authentication: all endpoints are public and share one graph, so the operator and customer pages see the same state.
- Parse results are cached by complaint text, so replaying the demo makes almost no LLM calls; a new complaint is still parsed live.
- Future: GPS crew tracking, Sinhala voice input, integration with existing Outage Management Systems and complaint channels (1987 SMS, CEBCare).

## Use of coding agents

Coding agents (Claude Code) were used to write code during the hackathon, guided by the brief in `CLAUDE.md` and the work plan in `PLAN.md`. All code was written during the coding window.

## Team

- Malitha Bandara ([@MalithaBandara](https://github.com/MalithaBandara))
- Yasith Gurunayake ([@yasithgurunayake](https://github.com/yasithgurunayake))
- [@isinduheshan](https://github.com/isinduheshan)
