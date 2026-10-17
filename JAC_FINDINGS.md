# Jac findings from the GridLab test app (16 Oct 2026)

Before the hackathon, we built a throwaway test app at `C:\jacsandbox\gridlab`, outside this folder, to see how Jac really behaves. It ran on the pip line: `jaclang` 0.16.7, `byllm` 0.6.19, `jac-client` 0.3.25. Every item below was **run**, not just looked up. Several of them pass `jac check` and then fail at runtime.

> Don't copy GridLab code into the GridMedic repo. Write the project code fresh during the coding window. Use these findings and the patterns below, not the files.

## Things that will break the plan in CLAUDE.md

| # | Finding | Effect on GridMedic | Fix |
|---|---|---|---|
| 1 | A module named **`types.jac`** passes `jac check`, then fails at runtime: `cannot import name 'Hazard' from 'types'`. Python's stdlib `types` module wins. | §7 and §12 plan a `types.jac` | Name it something else, e.g. `gm_types.jac` |
| 2 | **Circular import:** node abilities in `grid_model.jac` name walkers from `agents_*.jac`, and those walkers import the nodes. `jac check` passes, `jac run` fails with "partially initialized module". | §4 node abilities + §12 file split | Declare nodes **and** walkers in one module. Put the ability bodies in a `grid_model.impl/` folder with one `*.impl.jac` file per feature or owner; the compiler pairs them automatically. Verified in GridLab (`grid.jac` + `grid.impl/`). |
| 3 | **`by llm()` crashes** when its return type is imported **by name** from another module: `'str' object has no attribute 'fields'`. This also happens with MockLLM. | `parse_complaint -> Complaint`, `parse_crew_report -> FaultUpdate`, and the planned batches of ~10 complaints per call | **Best:** declare the LLM output objs, including any batch wrapper or `list[...]`, in the **same module** as the `by llm()` function, then copy the results into the shared types. Verified: local `list[Parsed]`, a local wrapper `{ items: list[Parsed] }`, and a local obj with an **imported enum** field all work. A single obj can also be written module-qualified (`-> gm_types.Complaint`), but `list[gm_types.X]` still fails, and so does a local subclass of a shared obj. |
| 4 | **`disengage` inside a node ability** (and inside an `impl Walker.ability` block in an annex file) fails `jac check` with E2083, although it runs. | §8.8 "Switch refuses: report + disengage" | The node sets a flag on `visitor`, and the walker checks the flag and disengages at its next step. Abilities that `disengage` stay inline in the walker body. |
| 5 | **`[flow f(x) for x in xs]` binds `x` late**, so a worker can run with a later item. Parsing gave wrong results, and parallel walker spawns started at the wrong node (one home got 28 hits, most got 0). | §4 parallel localising | Launch through a helper: `def _launch(x: T) -> Future { return (flow f(x)) as Future; }`, then `[_launch(x) for x in xs]`. With this, 40 parallel walker spawns tallied 40/40. |
| 6 | **`jac start` fails** with `Native compilation failed: create_pipeline_tuning_options() got an unexpected keyword argument 'size_level'`. jaclang 0.16.7 only pins `llvmlite>=0.43`, and pip installs 0.50.0. | Every laptop, and possibly Jac Hammer | **Verified:** `$env:JAC_OPT_LEVEL='0'` before `jac start` gets past it; the server then starts and works. Untested alternative: pin `llvmlite<0.50` in the venv. |
| 7 | **`jac start --dev` breaks after any `.jac` edit**, including a client-only `.cl.jac` file. The watcher reloads the server modules, and afterwards walkers stop matching node types: `get_grid` returns 0 nodes, Find finds nothing, and reset can't recover. No error is printed. | Everyone's dev loop tomorrow | **Restart `jac start` after every edit.** A plain restart fixes it, and the data is kept. Don't trust results from a server that has hot-reloaded. |
| 8 | **`", ".join(xs)` in client code** passes `jac check`, then throws `'str' object has no attribute 'join'` in the browser. Jac's own error screen also crashes (`undefined.message`), so the page goes blank. | UI code | In `.cl.jac`, render lists with a `{for (i, x) in enumerate(xs) { <span key=...>...</span> }}` slot instead of `str.join`. Check the browser console whenever the page goes blank. |
| 9 | **An endpoint that nothing imports returns `NOT_FOUND`** (`Function 'x' not found`), even though it's `def:pub`. | New endpoints | Import it in `main.jac`, or `sv import` it from a `.cl.jac` file. |
| 10 | **Enums arrive in the client as their numeric value**: `str(c.hazard)` showed `1`, not `NONE`. | Hazard badges in the UI | Send display text from the server (for example a `hazard_label: str` field), or compare against the enum imported through `sv import`. |
| 11 | **Graph references can't go inside f-string braces:** `f"{len([n ->:Feeds:->])}"` is a parse error, because the `:` is read as a format spec. | Evidence strings in §8.2 | Compute into a local first, then interpolate it. |
| 12 | **Typed-edge and `[?:Type]` filters are ~80× slower on our grid** (found 17 Oct, WP-B4). `[n ->:Feeds:->]`, `[n <-:Feeds:<-]` and `[n -->[?:GridNode]]` cost ~12 ms per node on the inherited `GridNode` types: one walk over the 620-node grid took 8–10 s, and a storm tick 30–120 s. Plain `[n -->]` filtered with `isinstance` in a comprehension took 0.13 s for the same walk. | Every grid traversal: Localiser, Energiser, Snapshot, SafetyCheck, lookups | **Use `children(n)` / `parents(n)` from `grid.jac`** (plain `[n -->]` / `[n <--]` + `isinstance`; `parents` drops Landmarks). In walkers: `visit children(here);` / `visit parents(here);`. `[root -->[?:FaultNode]]` on root's few children is fine. Read edge fields with `[edge n -->]`, which is fast. |

## Confirmed working (patterns to reuse)

- **Node inheritance and typed edges:** `node Section(GridNode)` works. With `edge Feeds: GridNode --> GridNode { has capacity: int = 0; }`, `[self <-:Feeds:<-]` is typed `GridNode`. A walker's `can x with GridNode entry` fires on every subclass.
- **Upstream walk:** `visit [<-:Feeds:<-];` from a Home gave `[home, TB1, SecB, SW1, SecA, SS]`.
- **Node abilities:** `can tally with Localiser entry { self.reports += 1; }` on the node, with `visitor` for the walker. On each node, the walker's ability runs **first**, then the node's.
- **`report` from a node ability** lands in the walker's `.reports`.
- **Energiser as node abilities:** each node computes `energised` from its parents and `passes_power()` (overridden on Switch and Transformer with `override def`). A breadth-first walk from the substation evaluates parents before children.
- **`by llm()` routing:** `default_model = "gemini/gemini-3.5-flash-lite"` under `[plugins.byllm.model]` routes to Gemini. With no key you get `AuthenticationError: GeminiException`. `claude-haiku-5-5` also routed correctly, to Anthropic.
- **Mocking the LLM in tests:** `import ai;` then `ai.llm = MockLLM(model_name="mockllm", config={"outputs": [obj]})`. This replaces the model that module's `by llm()` uses. Don't `del` it: the ambient `llm` is a module global.
- **Tests:** `tests/*_tests.jac` with no-dot imports, run with `jac test -d tests -v`. Spawn walkers in tests with `root spawn report_outage(text=...)`, then read `.reports[0]`.
- **Deleting nodes:** `del n` on a node, even as a loop variable, removes it from the graph. A rebuild doesn't stack a second grid. Verified both in `jac test` and on a freshly started server.
- **Persistence:** after a server restart, node fields (`reported`, `reports`) and an in-place `log.lines.append(...)` on a node under `root` were all still there. No save call is needed.
- **Endpoints over HTTP:** `POST /function/<name>` with a JSON body of named parameters, and `POST /walker/<name>` with its `has` fields. Both return the envelope `{"ok", "data": {"result" | "reports"}}`. In dev mode the API is on port **8001** and the UI on **8000**.
- **Client calling server:** `sv import from api { fn, Type }` in a `.cl.jac` file. Typed objects and **nodes** (e.g. `list[Home]`) arrive hydrated with dot access. Name local variables after the server's parameter names (`switch_id`, `section_id`, `on`) before calling.
- **Concurrent requests:** 4 parallel `get_grid` calls were fine.
- **Client component annex:** `async def handler -> None;` stubs in `frontend.cl.jac`, with bodies in `frontend.impl.jac` (`impl app.handler -> None { ... }`).
- **Not yet verified: a real LLM call.** No `GEMINI_API_KEY` was set. Routing to Anthropic is confirmed, and so is the mocked typed output. Still to check with a key: Sinhala parsing quality and whether the `sem` strings reach the prompt through the module-qualified return type.
- **Check-only warnings you can ignore:** SVG tags such as `<line>`, `<g>`, `<circle>` and `<text>` trigger W1050/W2001. `flow`/`wait` expressions trigger W1051. Use `<strong>`, not `<b>`.

## Added later on 16 Oct, while updating CLAUDE.md and PLAN.md

- **`by llm()` output rule, fully mapped:**
  - Fails: an output obj imported by name from another module; `list[...]` of one, by name or module-qualified; a local wrapper obj whose field holds one; a local subclass of one.
  - Works: output objs declared locally, including `list[Local]` and local wrappers; local objs with **imported enum** fields; imported objs as **input** parameters; a single top-level module-qualified obj.
- **`report` is a keyword:** `def parse_crew_report(report: str, ...)` fails with E0013, so name the parameter `text`.
- **Inline gate pattern:** a walker with an inline `can gate with GridNode entry { if self.blocked_by != "" { disengage; } }` declared before `can step with GridNode entry;` (body in an `.impl.jac` file). The gate stops the step, and it passes `jac check`.
- **`jac run` and llvmlite too:** with an `.impl/` folder, `jac run` printed the `size_level` native-compile error and exited with code 1 even though the script ran. `JAC_OPT_LEVEL=0` gives a clean exit 0.
