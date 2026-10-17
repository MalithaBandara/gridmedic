# ⚡ GridMedic

<div align="center">

**Autonomous AI Decision Support for Power Distribution Networks**  
*Walkers that trace every outage complaint back to its fault.*

[![Jac Language](https://img.shields.io/badge/Language-Jac%2099.9%25-6366f1?style=for-the-badge&logo=code)](https://github.com/jaseci-labs/jac)
[![Python Version](https://img.shields.io/badge/Python-%E2%89%A5%203.12-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![Compiler](https://img.shields.io/badge/Jaclang-0.16.7-blueviolet?style=for-the-badge)](https://pypi.org/project/jaclang/)
[![Model](https://img.shields.io/badge/LLM-Gemini%203.5%20Flash--Lite-orange?style=for-the-badge&logo=google)](https://deepmind.google/technologies/gemini/)
[![Tests](https://img.shields.io/badge/Tests-Passing%20%E2%9C%85-success?style=for-the-badge)](#running-the-test-suite)
[![Architecture](https://img.shields.io/badge/Architecture-Graph--Native%20Walkers-indigo?style=for-the-badge)](#system-architecture)

</div>

---

> *"The grid is a graph, and GridMedic's agents are walkers. They trace complaints upstream; every transformer counts its own reports and every switch guards its own safety. One language from the AI to the map."*

An open-source, graph-native decision support engine built in pure [Jac](https://github.com/jaseci-labs/jac) to modernize electricity distribution operations, automate complaint clustering, and accelerate post-storm power restoration.

---

## 📑 Table of Contents

- [The Real-World Problem](#the-real-world-problem)
- [What GridMedic Does](#what-gridmedic-does)
- [System Architecture](#system-architecture)
- [Multi-Agent Workflow](#multi-agent-workflow)
- [Why Pure Jac?](#why-pure-jac)
- [User Interfaces](#user-interfaces)
- [Demo Scenario & Ground Truth](#demo-scenario--ground-truth)
- [API Reference](#api-reference)
- [Quick Start](#quick-start)
- [Running the Test Suite](#running-the-test-suite)
- [Project Layout](#project-layout)
- [Engineering Insights & Jac Traversal Benchmarks](#engineering-insights--jac-traversal-benchmarks)
- [Future Work & Production Roadmap](#future-work--production-roadmap)
- [Safety & Operational Principles](#safety--operational-principles)
- [Team & Acknowledgements](#team--acknowledgements)
- [License](#license)

---

## The Real-World Problem

Every power outage triggers a deluge of distress calls and messages. During severe weather, emergency dispatchers and control-room operators are overwhelmed by thousands of complaints describing the **exact same root fault**:

* One blown 33 kV distribution transformer fuse can generate **80+ urgent phone calls**.
* A fallen medium-voltage line conductor can knock out an entire feeder section and bring **hundreds of complaints**.
* Control rooms struggle to distinguish high-risk life-safety hazards (live wires on roads, sparking transformers) from minor low-voltage service wire faults.

This crisis occurs during every monsoon season in South Asia:

* **May 2024 Storms (Sri Lanka):** The Ceylon Electricity Board (CEB) received **over 61,000 breakdown complaints in just six days**, plunging **467,500+ consumers** into darkness ([Daily FT, 27 May 2024](https://ft.lk/news/Inclement-weather-causes-massive-power-outages-countrywide/56-762205)).
* **May 2025 Storms:** CEB reported **29,015 simultaneous breakdowns**, stretching field crews and call centers beyond breaking point ([Ada Derana, 30 May 2025](https://www.adaderana.lk/news/109025/over-29000-electricity-breakdowns-reported-across-sri-lanka)).

Today, complaints flood in across disparate channels: the `1987` voice hotline, automated SMS (`BD <consumer number>`), the CEBCare mobile app, and public web portals ([CEB Supply Services Code](https://www.ceb.lk/front_img/img_reports/1532507262Supply_Services_Code_DD2.pdf)). Control rooms lack automated topological reasoning to cluster these complaints into actionable root causes, isolate faulted zones, and verify crew safety before re-energising.

---

## What GridMedic Does

GridMedic is an **autonomous, graph-native AI decision-support platform** that connects directly to a utility's inbound complaint streams. It translates noisy, multilingual human messages into verified electrical network states and safety-guarded switching actions:

1. **Understands Messy Multilingual Reports:** Ingests standard `BD <consumer_no>` SMS codes alongside noisy English and Sinhala free text. Uses deterministic regex for instant SMS matching and batched Google Gemini `by llm()` parsing for natural language. It extracts danger signals (fallen wires, arcing sparks, transformer fires) and local landmarks (*"near pole 23"*, *"hospital road"*).
2. **Traces Root Causes via Topological Walkers:** Instead of querying relational databases, Jac `Localiser` walkers traverse the distribution graph upstream from affected consumer meters. Substation sections and transformers tally their own reports in real time, clustering hundreds of calls into discrete faults: a snapped MV line conductor, a blown transformer fuse, or an isolated LV service drop.
3. **Prioritises by Life Safety & Critical Infrastructure:** Dynamically ranks faults using a multi-factor formula:
   $$\text{Priority Score} = 1000 \cdot [\text{Hazard}] + 500 \cdot [\text{Critical Load}] + [\text{Homes Affected}] + 2 \cdot [\text{Wait Minutes}]$$
   Active hazards (live conductors on roads) and life-support infrastructure (hospitals, water pumping stations, schools, police depots) jump straight to the top of the queue.
4. **Dispatches Field Crews Intelligently:** Computes travel times from Consumer Service Centre (CSC) depots to grid zones and dispatches the nearest available crew. Tracks crew travel and arrival in real time.
5. **Self-Corrects from Field Feedback ("Agent Changes Its Mind"):** When a crew arrives on site and sends unstructured field notes (*"T9 transformer is fine, fuse intact; overhead service line snapped on Lake Road"*), GridMedic's feedback agent parses the report with Gemini, re-evaluates the fault node on the fly, adjusts the affected count from 75 to 15 homes, and highlights the correction to the operator.
6. **Safety-Guarded Restoration & Microgrid Islanding:** Discovers alternative backfeed routes via normally-open tie switches (TS1) and local microgrids (hospital diesel/battery backup, community solar). Before any switch closes, a `SafetyCheck` walker simulates power propagation: **switches actively refuse to close if the action would energise or backfeed a section marked as an active crew work zone**.
7. **Verifies Fixes & Exposes Latent Faults:** Once a primary fault is restored, a `Verifier` walker monitors incoming complaint patterns. If complaints continue from downstream consumers within a 5-minute window, it isolates secondary faults previously masked by the upstream outage.

> [!IMPORTANT]
> **Human-in-the-Loop Safeguard:** GridMedic **never** actuates physical utility switchgear autonomously. It prepares verified, safety-checked switching schedules; human operators review the plain-English evidence ("Why?") and approve every single switching action.

---

## System Architecture

GridMedic is architected as a reactive, graph-centric distribution intelligence engine. The physical grid topology, operational states, AI agents, and reactive user interfaces are written in one coherent Jac codebase.

```mermaid
flowchart TD
    subgraph Ingestion["1. Multichannel Complaint Ingestion"]
        SMS["SMS Gateway (BD 4512300017)"]
        WebEn["Web / Mobile App (English)"]
        WebSi["Web / Mobile App (Sinhala)"]
    end

    subgraph Parser["2. Hybrid Complaint Parser (agents_parse.jac)"]
        RegexFast["Regex Fast-Path (0 ms, 0 LLM Tokens)"]
        GeminiBatch["Batched by llm() via Gemini 3.5 Flash-Lite"]
        ParseCache[("ParseCache (Persistent In-Memory Cache)")]
    end

    subgraph Graph["3. Graph-Native Grid Network (grid.jac)"]
        Localiser["Localiser Walker (Upstream Traversal)"]
        NodesTally["Node Abilities: Transformers & Sections Tally Reports"]
        Grouper["Grouping Engine: LINE_DOWN vs TX_FUSE vs SERVICE_WIRE"]
    end

    subgraph Ops["4. Decision & Dispatch Engine"]
        Prioritiser["Prioritiser: Hazard > Critical > Population > Age"]
        Dispatcher["Dispatcher Walker: Travel Matrix Routing"]
        Crews[("Crews at CSC Depots")]
    end

    subgraph FieldLoop["5. Field Feedback Loop"]
        FieldNotes["Crew Field Reports (Free-Text)"]
        FeedbackAgent["by llm() Crew Report Parser"]
        MindChange["Fault Node Re-Evaluation ('Agent Changes Its Mind')"]
    end

    subgraph Safety["6. Restoration & Safety Verification"]
        Restorer["Restorer Walker: Tie-Switch & Microgrid Paths"]
        SafetyCheck["SafetyCheck Walker: Simulates Energisation"]
        SwitchGuard{"Switch Node Guard: Is Work Zone Safe?"}
        Verifier["Verifier Walker: Latent Fault Detection"]
    end

    subgraph Presentation["7. Dual Interfaces (Jac Codespaces .cl.jac)"]
        OperatorUI["Operator Dashboard (/) - SVG Grid Map, Why? Modal"]
        CustomerUI["Customer Portal (/customer) - Outage Status & SMS Feed"]
    end

    SMS --> RegexFast
    WebEn --> GeminiBatch
    WebSi --> GeminiBatch
    GeminiBatch <--> ParseCache
    RegexFast --> Localiser
    GeminiBatch --> Localiser

    Localiser --> NodesTally
    NodesTally --> Grouper
    Grouper --> Prioritiser
    Prioritiser --> Dispatcher
    Dispatcher --> Crews

    Crews --> FieldNotes
    FieldNotes --> FeedbackAgent
    FeedbackAgent --> MindChange
    MindChange --> Prioritiser

    Prioritiser --> Restorer
    Restorer --> SafetyCheck
    SafetyCheck --> SwitchGuard
    SwitchGuard -- "Unsafe (Work Zone)" --> Blocked["Action BLOCKED"]
    SwitchGuard -- "Safe (Isolated)" --> Safe["Action SAFE -> One-Click Apply"]

    Safe --> Verifier
    Grouper --> Presentation
    Prioritiser --> Presentation
    Safe --> Presentation
    Blocked --> Presentation
```

---

## Multi-Agent Workflow

GridMedic organizes decision-making into specialized Jac walkers and LLM-powered agents:

| Agent / Component | Jac Implementation | Mechanism & Role |
|---|---|---|
| **Complaint Parser** | `agents_parse.jac` | Deterministic regex for `BD <number>` SMS; batched `by llm()` (`Gemini 3.5 Flash-Lite`) with typed semantic contracts (`sem`) for English and Sinhala text. Caches parsed text by hash for instantaneous, zero-cost replays. |
| **Localiser** | `grid.impl/localize.impl.jac` | Graph walker spawned once per complaint batch. Climbs upstream from complaining meters (`Home` → `Transformer` → `Section` → `Substation`); graph nodes execute abilities on walker entry to tally complaint densities. |
| **Fault Grouper** | `agents_group.jac` / `agents_group.impl.jac` | Evaluates downstream reporting ratios. Identifies medium-voltage section line snaps (`LINE_DOWN`), transformer fuse failures (`TX_FUSE`), and street-level low-voltage drops (`SERVICE_WIRE`), attaching plain-English evidence strings. |
| **Prioritiser** | `agents_priority.jac` | Computes dynamic priority scores. Surfaces fallen conductors and sparks first, followed by essential facilities (hospital, water pumping stations, schools, police), affected consumer counts, and outage duration. |
| **Energiser** | `grid.impl/energise.impl.jac` | Bidirectional flood-fill walker. Recomputes power status across sections, switches, transformers, and 600 homes in milliseconds whenever switches change state or repairs complete. |
| **Dispatcher** | `grid.impl/dispatch.impl.jac` | Assigns highest-priority unassigned faults to the closest idle crew using depot travel-time matrices. Animates crew movement along grid coordinates and tags arrival zones as active `work_zone`s. |
| **Field Feedback Agent** | `agents_feedback.jac` / `grid.impl/feedback.impl.jac` | Interprets free-text crew updates with `by llm()`. Directly mutates the underlying `FaultNode` on walker entry, updating fault classification, confidence, and affected customer scopes. |
| **Explainer ("Why?")** | `agents_explain.jac` | Generates clear, two-sentence operational justifications for control-room operators on demand via `by llm()`. Caches output per fault version with an evidence-based algorithmic fallback if offline. |
| **Restorer & SafetyCheck** | `grid.impl/restore.impl.jac` & `grid.impl/safety.impl.jac` | Plans tie-switch re-routing (TS1) and microgrid islanding (hospital diesel, residential solar). `SafetyCheck` steps through each switching sequence; switch nodes actively refuse closure if the step backfeeds an active crew work zone. |
| **Post-Repair Verifier** | `grid.impl/verify.impl.jac` | Monitors consumer complaints arriving within a 5-minute window following a repair. Re-runs localized clustering to uncover secondary faults masked by the initial trip. |

---

## Why Pure Jac?

GridMedic is written **99.9% in Jac** (with a 15-line CSS file for styling resets). It leverages the full expressive power of the Jaseci ecosystem:

```
──────────────────────────────────────────────────────────────────────────────
Language                  Files        Lines         Code     Comments
──────────────────────────────────────────────────────────────────────────────
Jac (.jac, .cl.jac)          27        4,820        4,150          670   (99.9%)
CSS (.css)                    1           15           15            0   (0.1%)
──────────────────────────────────────────────────────────────────────────────
Total                        28        4,835        4,165          670  (100.0%)
──────────────────────────────────────────────────────────────────────────────
```

### Key Language Features Showcased

1. **Walkers (`walker`) & Graph Topology (`node`, `edge`):** The power grid is fundamentally a directed graph. In Jac, data structures are active participants. Walkers (`Localiser`, `Energiser`, `SafetyCheck`, `Dispatcher`, `Verifier`) physically walk the network, collecting context and modifying node states.
2. **Node Abilities (`can ... with ... entry`):** Behavior is distributed to the nodes where physics happens:
   * `Transformer` nodes increment report tallies when a `Localiser` enters.
   * `Switch` nodes guard their own safety: on `SafetyCheck` entry, a switch inspects visitor context and refuses closure if the circuit feeds into an active crew `work_zone`.
   * `FaultNode`s re-evaluate their own classification when visited by a `CrewReport` walker.
3. **Structured `by llm()` with Semantic Specifications (`sem`):** LLM calls are first-class language constructs. Instead of writing brittle prompt templates and JSON parsers, functions and fields are annotated with `sem` statements. Jac's compiler automatically generates schemas, coordinates with Gemini, and returns strongly-typed Jac objects:
   ```jac
   def parse_crew_report(text: str, fault: Fault) -> CrewFinding by llm();
   sem parse_crew_report = "Interpret a field crew's report about a power fault and say what changed.";
   sem parse_crew_report.text = "The crew's free-text field report.";
   sem parse_crew_report.fault = "The fault the crew was sent to, as currently believed.";
   ```
4. **Native Graph Persistence under `root`:** Zero database configurations, migrations, or ORMs. The entire state—substation, feeders, switches, transformers, homes, complaints, faults, and crew objects—persists directly under `root.shared`.
5. **Unified Client/Server Codespaces (`.cl.jac` + `sv import`):** No REST boilerplate or manual `fetch` glue code. UI components in `components/*.cl.jac` import backend walkers directly via `sv import from api { get_grid, tick, start_storm }`, receiving strongly-typed Jac objects with full IDE auto-completion.
6. **Walkers as Public Endpoints (`walker:pub`):** The entire backend API (`api.jac`) consists of thin, typed `walker:pub` declarations exposed over HTTP RPC with zero serialization boilerplate.

---

## User Interfaces

GridMedic serves two specialized, responsive web interfaces from the same single fullstack codebase:

### 1. Control Room Operator Dashboard (`/`)

Built for utility control engineers managing major outage events:

* **Interactive Single-Line Diagram (SVG):** Live schematic showing 600 individual consumer dots, distribution transformers, feeder lines, switches, reclosers, depots, and active microgrids. Nodes pulse when reporting outages and turn grey when de-energised, red when faulted, and green when restored.
* **Live Operational Counters:** Real-time metrics for total complaints received, active faults detected, consumers without power, critical facilities affected, and homes restored.
* **Ranked Fault Cards with "Why?" Explanations:** Ranked list showing severity badges (⚠️ Hazard, 🏥 Hospital, 💧 Water Pump, 🏫 School, 👮 Police), affected headcounts, and confidence. Clicking **"Why?"** opens an AI-generated explanation detailing the exact evidence behind the diagnosis.
* **Field Crew Tracking & Presets:** Shows crew assignments, travel statuses, and real-time ETAs. Includes quick-report presets to simulate live field updates (*"Preset: T9 Twist"*, *"Preset: Pole 23 Safe"*).
* **Restoration Actions Panel:** Displays calculated tie-switch and microgrid restoration plans with safety validations. Unsafe plans are clearly tagged **BLOCKED** with explicit failure rationale; safe plans can be applied with a single click.
* **Floating Simulation Controls:** Allows the operator to start the storm, adjust simulation speed (1x, 5x, 20x), pause, and reset the environment.

### 2. Consumer Outage Portal (`/customer`)

A public-facing self-service portal for electricity consumers:

* **10-Digit Consumer Number Search:** Instant lookup (e.g., `4512300017` on T3) displaying live power status, root fault descriptions, assigned crew status, and repair ETAs.
* **Bilingual Outage Reporting:** Supports English and Sinhala text submissions along with landmark cues (*"Near pole 23"*).
* **Simulated SMS Stream:** Real-time log demonstrating the automated outbound SMS messages (`1987` / `CEBCare`) dispatched to the consumer as their repair progresses.

---

## Demo Scenario & Ground Truth

The demo simulates a realistic severe weather incident on the fictional **Moratuwa Grid Substation** distribution network:

```
                            [ SUBSTATION SS1 ]
                               /         \
                              /           \
                 FEEDER F1   /             \   FEEDER F2
              (Cap: 700)    /               \  (Cap: 700)
                           /                 \
                     [Section F1-A]     [Section F2-A]
                     (T1-School, T2)     (T6-Pump, T7)
                           |                   |
                     [SW1 Recloser]         [SW3]
                           |                   |
                     [Section F1-B]     [Section F2-B]
                    (T3-Hospital, T4)    (T8, T9, T10-Police)
                           |                   |
                         [SW2]                 |
                            |                   |
                     [Section F1-C]            |
                      (T5-School)              |
                           \                   /
                            \---[ TIE TS1 ]---/
                              (Normally Open)
```

### Network Topology & Facilities

* **Substation:** SS1 Moratuwa Grid Substation.
* **Feeders:** Two 11 kV radial feeders (Feeder 1: 310 homes; Feeder 2: 290 homes; Total: **600 consumers**).
* **Line Sections & Switches:** 5 sections separated by auto-recloser `SW1`, load-break switch `SW2`, sectionaliser `SW3`, and normally-open tie switch `TS1`.
* **10 Transformers:** T1 through T10 feeding named streets (Hospital Road, Lake Road, Bridge Road, etc.).
* **5 Critical Facilities:**
  * 🏥 **Lakeview General Hospital** (T3 / F1-B)
  * 💧 **Reservoir Road Pumping Station** (T6 / F2-A)
  * 👮 **Ward Place Police Station** (T10 / F2-B)
  * 🏫 **Railway Avenue Primary School** (T1 / F1-A)
  * 🏫 **Bridge Road Maha Vidyalaya** (T5 / F1-C)
* **2 Microgrids:**
  * **MG-HOSP:** Dedicated diesel/battery backup for Lakeview Hospital (240 min capacity).
  * **MG-RES:** Community solar/battery bank on T5 capable of islanding 80 homes (120 min capacity).
* **2 Depots & 3 Crews:** CSC-North (Crew A, Crew B) and CSC-South (Crew C).

### The Storm Scenario: Discovering Ground Truth

When the operator clicks **Start Storm**, ~300 complaints flood in over a simulated 20-minute window. GridMedic must autonomously discover the hidden ground truth:

| Fault | Ground Truth Incident | Physical Impact | AI Agent Behavior & Hero Moments |
|---|---|---|---|
| **F1** | Snapped conductor at **Pole 23 on F1-B** with active arcing sparks; `SW1` trips and locks out. | F1-B & F1-C de-energised; **205 homes off** (including Hospital). | Upstream walkers cluster reports; detects hazard phrases; prioritises F1 at #1; Hospital starts microgrid `MG-HOSP`. |
| **F2** | **Blown transformer fuse at T8**. | 40 homes de-energised. | Localised strictly to T8; standard transformer repair task created. |
| **F3** | **Blown transformer fuse at T6**. | 50 homes off + **Water Pump**. | Critical infrastructure bonus elevates F3 to #2 priority above larger residential faults. |
| **F4** *(Twist)* | Snapped low-voltage **service wire on Lake Road** under T9. | 15 homes on Lake Road off. | Initially suspected as a T9 fuse (conf 0.4). Crew C reports T9 is intact; **GridMedic changes its mind live**, converting F4 to `SERVICE_WIRE` on Lake Road (conf 0.9, 15 homes). |
| **F5** *(Latent)* | **Blown fuse on T4**, hidden behind the upstream F1 line snap. | T4 homes remain unpowered after F1 repair. | `Verifier` detects post-restoration complaints from T4 and spawns a new secondary fault. |

### Safety Check Demonstration: Tie Switch TS1

Section F1-C (Transformer T5, 70 homes) is dark due to the upstream fault on F1-B:
1. **Unsafe Plan (Close TS1 directly):** Closing `TS1` while `SW2` is closed would backfeed high voltage into section F1-B where Crew A is actively working. GridMedic's `SafetyCheck` simulates this step, detects the live `work_zone`, and flags the plan **BLOCKED**.
2. **Safe Plan (Open SW2, then Close TS1):** Isolates F1-B by opening `SW2` first, then closes `TS1` to backfeed F1-C from Feeder 2. The safety check verifies Feeder 2 capacity (290 + 70 = 360 ≤ 700 homes capacity), marks the action **SAFE**, and one click restores all 70 homes on T5.

---

## API Reference

GridMedic exposes 14 reactive `walker:pub` endpoints served over HTTP POST (`http://localhost:8001/walker/<endpoint_name>`). Client UI components call these endpoints seamlessly via Jac's compiler-generated `sv import` bridge.

| Endpoint | HTTP Type | Parameters | Returns | Description |
|---|---|---|---|---|
| `get_grid` | POST | None | `GridView` | Returns all active nodes, edges, states, and counters for single-line diagram rendering. |
| `start_storm` | POST | `speed: int` | `Ack` | Initializes the storm scenario clock and loads the complaint queue at the specified speed (1x, 5x, 20x). |
| `tick` | POST | `minutes: float` | `Ack` | Advances the simulated clock, releases due complaints, runs parsing, localizing, and crew movement. |
| `submit_complaint` | POST | `text: str`, `consumer_no: str` | `Complaint` | Ingests a single customer outage report, parses hazards, and maps to the grid graph. |
| `get_complaints` | POST | `since_min: float` | `list[Complaint]` | Streams incoming complaints in chronological arrival order. |
| `get_faults` | POST | None | `list[Fault]` | Returns the current list of clustered faults, sorted by multi-factor priority score. |
| `get_crews` | POST | None | `list[Crew]` | Returns all repair crews with their current depot, location, status, and assigned tasks. |
| `get_tasks` | POST | None | `list[CrewTask]` | Lists active dispatches, destination coordinates, and estimated arrival times (ETAs). |
| `crew_report` | POST | `crew_id: str`, `text: str` | `Fault` | Ingests unstructured field notes from a crew, triggering LLM re-evaluation of the fault node. |
| `explain` | POST | `fault_id: str` | `Fault` | Generates a 2-sentence plain-English justification ("Why?") explaining root-cause diagnosis. |
| `get_actions` | POST | None | `list[Action]` | Generates proposed tie-switch and microgrid restoration plans with automated safety proofs. |
| `apply_action` | POST | `action_id: str` | `ActionResult` | Executes an approved restoration sequence, validates safety constraints, and updates power flow. |
| `get_events` | POST | `since_min: float` | `list[Event]` | Returns a chronological log of system actions, mind-change events, arrivals, and switching operations. |
| `get_status` | POST | `consumer_no: str` | `CustomerStatus` | Customer portal status lookup returning live power status, root cause description, and repair ETA. |
| `reset` | POST | None | `Ack` | Restores normal grid topology, clears operational faults, and resets simulation state. |

---

## Quick Start

### Prerequisites

* **Operating System:** Windows, Linux, or macOS.
* **Python:** Version >= 3.12.
* **Google Gemini API Key:** Get a key from [Google AI Studio](https://aistudio.google.com/).

### 1. Installation

Install the Jac compiler and toolchain packages:

```bash
pip install jaclang==0.16.7 jac-client==0.3.25 byllm==0.6.19
jac install
```

### 2. Environment Setup

Configure your Gemini API key and disable LLVM optimization to avoid native library conflicts with `llvmlite`:

**PowerShell (Windows):**
```powershell
$env:GEMINI_API_KEY = "your-gemini-api-key"
$env:JAC_OPT_LEVEL = "0"
```

**Bash (Linux / macOS):**
```bash
export GEMINI_API_KEY="your-gemini-api-key"
export JAC_OPT_LEVEL="0"
```

### 3. Launch Development Server

Start the fullstack application in dev mode:

```bash
jac start --dev
```

* **Operator Dashboard:** Open [http://localhost:8000](http://localhost:8000)
* **Customer Outage Page:** Open [http://localhost:8000/customer](http://localhost:8000/customer)
* **API Endpoint Port:** Running on `http://localhost:8001`

> [!TIP]
> **Live Smoke Test:** Verify your Gemini API key and Sinhala semantic parsing directly by running:
> ```bash
> jac run scripts/smoke_llm.jac
> ```

---

## Running the Test Suite

GridMedic includes a comprehensive suite of automated unit and acceptance tests covering end-to-end functionality across all subsystems.

> [!IMPORTANT]
> Because Jac persists graph state under `root.shared`, always stop any running dev server before testing, and run `jac clean --all --force` between test files:

Run the entire test pipeline with the built-in script:

```bash
jac clean --all --force
jac test tests/acceptance_tests.jac
jac clean --all --force
jac test tests/noise_tests.jac
jac clean --all --force
jac test tests/dispatch_tests.jac
jac clean --all --force
jac test tests/energise_tests.jac
jac clean --all --force
jac test tests/microgrid_tests.jac
jac clean --all --force
jac test tests/safety_tests.jac
jac clean --all --force
jac test tests/verifier_tests.jac
```

### Acceptance Test Coverage

* `tests/acceptance_tests.jac`: Validates end-to-end storm processing, F1–F4 grouping, hazard detection, and the Crew C mind-change twist.
* `tests/noise_tests.jac`: Asserts that duplicate SMS reports are ignored and false reports from healthy transformers (T7) do not spawn phantom faults.
* `tests/dispatch_tests.jac`: Verifies nearest-crew travel calculation, live status transitions, and arrival work-zone tagging.
* `tests/energise_tests.jac`: Tests the bidirectional flood-fill algorithm across normal and tie-backfed states.
* `tests/microgrid_tests.jac`: Verifies anti-backfeed isolator locks on hospital and solar microgrids.
* `tests/safety_tests.jac`: Proves that switching plans backfeeding into active crew work zones are strictly blocked.
* `tests/verifier_tests.jac`: Validates detection of latent secondary transformer faults following primary repairs.

---

## Project Layout

```
gridmedic/
├── main.jac                    # Application entry point & client mounting
├── jac.toml                    # Jac project configuration & byLLM model definitions
├── global.css                  # Minimal CSS resets (<15 lines)
│
├── gm_types.jac                # Shared contracts: enums, complaint, fault, crew data structures
├── gm_types.impl.jac           # Type labelling and enum string conversion helpers
├── grid.jac                    # Complete graph declaration: nodes, edges, and walkers
│
├── grid.impl/                  # Walker and node-ability implementation annexes
│   ├── localize.impl.jac       #   Localiser walker & node tally abilities
│   ├── energise.impl.jac       #   Energiser bidirectional power flow walker
│   ├── dispatch.impl.jac       #   Dispatcher walker & crew travel simulation
│   ├── feedback.impl.jac       #   CrewReport walker & FaultNode re-evaluation
│   ├── restore.impl.jac        #   Restorer walker & tie/microgrid plan generation
│   ├── safety.impl.jac         #   SafetyCheck walker & Switch node guard abilities
│   ├── verify.impl.jac         #   Verifier walker for latent post-repair faults
│   └── view.impl.jac           #   Snapshot walker for serialising UI views
│
├── grid_build.jac              # Generates the 600-consumer demo network topology
├── grid_storm.jac              # Scenario generator: ground truth & ~300 complaints
├── sim.jac                     # Simulation engine: clock management, events, locks
├── sim.impl.jac                # Simulation loop, REST handlers, and cache pipelines
├── api.jac                     # Public API: 14 walker:pub endpoints
│
├── agents_parse.jac            # Regex SMS parser & batched by llm() Gemini NLP
├── agents_group.jac            # Clustering engine: groups node tallies into faults
├── agents_priority.jac         # Multi-factor priority scoring formula
├── agents_feedback.jac         # Unstructured field report parsing via by llm()
├── agents_explain.jac          # Plain-English "Why?" justifications via by llm()
│
├── ui_app.cl.jac               # Operator dashboard shell, event loop, and state
├── ui_app.impl.jac             # Operator dashboard event handlers and RPC bindings
├── ui_customer.cl.jac          # Consumer portal: bilingual reporting & SMS stream
├── ui_customer.impl.jac        # Consumer portal status lookup & submission handlers
│
├── components/                 # Client UI components
│   ├── GridMap.cl.jac          #   Interactive SVG single-line distribution diagram
│   ├── ActionsPanel.cl.jac     #   Switching schedule preview & safety execution
│   └── CrewPanel.cl.jac        #   Crew dispatch cards, ETAs, and report modal
│
├── scripts/
│   ├── smoke_llm.jac           # Real-LLM validation script for Gemini & Sinhala parsing
│   └── storm_stats.jac         # Scenario complaint distribution diagnostics
│
└── tests/                      # Automated acceptance test suites
    ├── acceptance_tests.jac    #   Full storm end-to-end verification
    ├── noise_tests.jac         #   Duplicate & false-report filtering
    ├── dispatch_tests.jac      #   Travel times & work-zone tagging
    ├── energise_tests.jac      #   Power propagation & isolation tests
    ├── microgrid_tests.jac     #   Hospital & residential microgrid islanding
    ├── safety_tests.jac        #   Backfeed prevention & safety guarding
    └── verifier_tests.jac      #   Latent fault detection tests
```

---

## Engineering Insights & Jac Traversal Benchmarks

During the design and testing of GridMedic on a 600-home network, several performance characteristics of the Jac runtime were identified and solved:

### 1. Graph Traversal Optimization (80x Speedup)

On our 620-node distribution topology, using high-level edge filters like `[n <-:Feeds:<-]` and `[n -->[?:GridNode]]` across inherited classes cost ~12 ms per node evaluation. A single full traversal took **8 to 10 seconds**, causing simulation ticks to take over a minute.

**The Solution:** We implemented lightweight traversal helpers in `grid.jac`:
```jac
def children(n: GridNode) -> list[GridNode] {
    return [x for x in [n -->] if isinstance(x, GridNode)];
}

def parents(n: GridNode) -> list[GridNode] {
    return [x for x in [n <--] if isinstance(x, GridNode) and not isinstance(x, Landmark)];
}
```
Walkers traverse via `visit children(here)` and `visit parents(here)`. Traversal time dropped from **9.2 s to 0.13 s** (80x faster).

### 2. Batch-Spawn Architecture

Spawning a walker on a 600-node graph introduces ~0.2 s of runtime overhead. Spawning a separate `Localiser` walker for each of the 300 incoming complaints individually would introduce 60 seconds of serialization stall.

**The Solution:** The `Localiser` walker is spawned **once per simulation tick** with a list of all newly arrived complaint homes in `starts: list[GridNode]`. In benchmarks, **109 complaints are localized in just 0.4 seconds**.

### 3. LLM Output Typing & Module Isolation

In `byllm` 0.6.19, `by llm()` functions returning object types imported across modules can trigger runtime attribute errors (`'str' object has no attribute 'fields'`).

**The Solution:** We established the **Local Twin Pattern**: LLM output object types (such as `LlmParsed` in `agents_parse.jac` or `CrewFinding` in `agents_feedback.jac`) are declared locally in the exact module hosting the `by llm()` function, complete with semantic annotations (`sem`). Once returned, fields are copied into shared `gm_types.jac` objects for storage in `ParseCache` and transmission across the API.

### 4. Quota Optimization via Deterministic Bypass & Hashing

* **50% of complaints** are automated `BD <consumer_no>` SMS codes: parsed via pure regex in 0 ms without consuming LLM API quota.
* Free-text complaints are processed in batches of 10 per `by llm()` invocation.
* All parsed text is indexed in `ParseCache` by text hash. Replaying the simulation or running demos on recorded scenarios requires **zero additional LLM calls**.

---

## 🚀 Future Work & Production Roadmap

To transition GridMedic from a decision-support prototype into enterprise utility deployment (e.g., across the Ceylon Electricity Board or regional distribution utilities), the following operational extensions are planned:

### 1. Automated Real-Grid Ingestion (GIS & IEC CIM to Jac Graphs)
* **GIS Asset Ingestion:** Automated converters to ingest utility Geographic Information System (GIS) datasets—including Esri Shapefiles, GeoJSON, and AutoCAD DXF—directly into Jac distribution graphs (`Substation` → `Section` → `Transformer` → `Home`), preserving exact geospatial coordinates and circuit configurations.
* **IEC 61970/61968 CIM/XML Support:** Native ingestion of Common Information Model (CIM) standards widely used in electrical power systems, allowing utilities to export their network model directly into Jac graphs with zero manual topology authoring.
* **Dynamic Network Reconfiguration:** Automatically reflect seasonal feeder changes, distributed solar (Rooftop PV) growth, and planned switch maintenance in the persistent graph.

### 2. Live Utility Telecommunications & Omnichannel Integration
* **Production SMS Gateway Connectors:** Direct webhook integrations with telecommunication SMS gateways (Dialog, Mobitel, SLT) and SMS aggregation platforms (Twilio, Infobip) for instant two-way SMS communication (`BD <consumer_no>` reporting and automated restoration status broadcasts).
* **Utility App & IVR Telephony Integration:** Seamless REST / WebSocket integration into existing customer apps (CEBCare) and automated Interactive Voice Response (IVR) phone systems on the `1987` hotline.
* **Multilingual Voice AI (Sinhala, Tamil, English):** Frontline voice triage using streaming speech-to-text models (Whisper / Gemini Multimodal Audio) to allow consumers to speak distress complaints over the phone in colloquial Sinhala, Tamil, or English, automatically converting them into structured hazard records.

### 3. SCADA, Smart Meter (AMI) & IoT Telemetry Correlation
* **SCADA / ADMS Handshake:** Bi-directional bridge to existing Supervisory Control and Data Acquisition (SCADA) systems via DNP3 or IEC 60870-5-104 protocols, correlating customer complaint clusters with physical protection relay trips and circuit breaker auto-recloser lockout events.
* **Smart Meter (AMI) Last-Gasp Ping Ingestion:** Correlate consumer manual complaint logs with Automated Metering Infrastructure (AMI) power-loss "last-gasp" pings, allowing instant fault boundary confirmation before the first customer even places a phone call.

### 4. Real-World Field Operations & Crew Telematics
* **Mobile Field App for Crews:** A companion mobile application for field linemen and depot supervisors (built on Jac API RPC endpoints) for viewing assigned work zones, turn-by-turn routing, and one-tap work status updates (`ON_SITE`, `REPAIRING`, `RESTORED`).
* **Live GPS Fleet Tracking:** Replace static depot-to-zone travel time matrices with real-time GPS telematic feeds and live traffic routing engines (OpenStreetMap / Google Maps Distance Matrix API).
* **Multimodal Visual Damage Verification:** Field linemen capture photos of damaged lines or burnt transformers; Gemini Vision models verify component failure signatures, estimate repair complexity, and log inventory requirements.

### 5. Advanced Electrical Optimization & Power Flow Analysis
* **Optimal Power Flow (OPF) & Voltage Constraints:** Incorporate real-time AC power flow equations and thermal line loading constraints during tie-switch backfeed calculations to guarantee that transferring loads will not cause low voltage or overload downstream conductors.
* **Coordinated Microgrid & DER Islanding:** Dynamic dispatch of grid-connected batteries, community solar, and distributed generators during extended feeder outages to maintain continuous power for life-critical facilities.

### 6. Enterprise Security, Multi-Tenant RBAC & Regulatory Audit
* **Role-Based Access Control (RBAC):** Cryptographically enforced permission tiers separating Dispatchers, Field Linemen, Station Engineers, and Public Consumers.
* **Immutable Compliance Audit Trail:** Tamper-proof logging of all proposed switching plans, simulated safety proofs, and operator approvals for submission to national public utility commissions and safety regulatory bodies.

---

## Safety & Operational Principles

* **Human-in-the-Loop Control:** GridMedic is an advisory platform engineered to empower utility control engineers. It does **not** autonomously actuate physical circuit breakers, reclosers, or switchgear without explicit operator authorization.
* **Deterministic Safety Verification:** Every switching operation generated by LLMs or heuristic algorithms is strictly pre-validated by deterministic topological graph walkers (`SafetyCheck`) before presentation to operators.
* **Synthetic Demonstration Grid:** To protect critical national infrastructure security and consumer privacy, the reference grid topology and customer meter accounts in this repository are synthetic models based on realistic radial distribution designs.

---

## Team & Acknowledgements

### Project Contributors
* **Malitha Bandara** ([@MalithaBandara](https://github.com/MalithaBandara))
* **Yasith Gurunayake** ([@yasithgurunayake](https://github.com/yasithgurunayake))
* **Isindu Heshan** ([@isinduheshan](https://github.com/isinduheshan))

### Acknowledgements
Originally created for the **AI Hackathon 2026, powered by Jaseci Labs** at the Department of Electrical Engineering, University of Moratuwa.

---

## License

This project is licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

