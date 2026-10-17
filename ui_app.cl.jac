"""GridMedic Operator Dashboard - Shell and UI Layout."""

import from "@jac/runtime" { Link }
import from react { useEffect }
import from .components.GridMap { GridMap }
import from .components.CrewPanel { CrewPanel }
import from .components.ActionsPanel { ActionsPanel }
sv import from api {
    get_grid,
    get_faults,
    get_events,
    get_crews,
    get_actions,
    start_storm,
    tick,
    reset,
    crew_report,
    explain,
    apply_action
}
sv import from gm_types {
    GridView,
    Counters,
    Fault,
    Event,
    Crew,
    Action,
    ActionResult,
    Ack
}

# Auto-tick guard. Module state (not reactive), so the 1 s interval never
# starts a tick while the previous one is still running.
glob _poll: dict = {"busy": False};

def:pub OperatorApp -> JsxElement {
    has grid: GridView | None = None,
        counters: Counters | None = None,
        faults: list[Fault] = [],
        events: list[Event] = [],
        crews: list[Crew] = [],
        actions: list[Action] = [],
        clock_min: float = 0.0,
        speed: int = 1,
        running: bool = False,
        selected_fault_id: str = "",
        why_text: str = "",
        selected_crew_id: str = "CREW-A",
        crew_report_text: str = "",
        action_message: str = "",
        sim_panel_open: bool = True,
        sim_minimized: bool = False;

    can with entry {
        loadInitial();
    }

    async def loadInitial -> None;
    async def handleStartStorm -> None;
    async def handleReset -> None;
    async def handleTick -> None;
    async def handleSubmitCrewReport -> None;
    async def handleApplyAction(action_id: str) -> None;
    async def loadExplanation -> None;
    async def pollTick -> None;

    # While a storm runs, advance the simulated clock about once a second
    # (0.5 sim-min x speed per tick). Restarts when running or speed changes.
    useEffect(lambda {
        timer: float = 0.0;
        if running {
            timer = setInterval(lambda { if not _poll["busy"] { pollTick(); } }, 1000) as float;
        }
        return lambda { if timer { clearInterval(timer); } };
    }, [running, speed]);

    hazard_faults: list[Fault] = [f for f in faults if f.hazard_label != "" and f.status_label != "Restored" and f.status_label != "Closed"];
    selected_faults: list[Fault] = [f for f in faults if f.id == selected_fault_id];

    # Ask for the 2-sentence reason when a fault is selected, and again when a
    # crew report changes it (the server caches it until the fault changes).
    sel_note: str = selected_faults[0].change_note if len(selected_faults) > 0 else "";
    useEffect(lambda {
        if selected_fault_id {
            loadExplanation();
        }
    }, [selected_fault_id, sel_note]);

    return
        <div
            style={{
                "minHeight": "100vh",
                "backgroundColor": "#090d16",
                "color": "#f8fafc",
                "fontFamily": "system-ui, -apple-system, sans-serif",
                "display": "flex",
                "flexDirection": "column"
            }}
        >
            {#* TOP BAR *#}
            <header
                style={{
                    "display": "flex",
                    "justifyContent": "space-between",
                    "alignItems": "center",
                    "padding": "0.75rem 1.25rem",
                    "backgroundColor": "#0f172a",
                    "borderBottom": "1px solid #1e293b",
                    "flexWrap": "wrap",
                    "gap": "0.75rem"
                }}
            >
                {#* Title & Clock *#}
                <div style={{"display": "flex", "alignItems": "center", "gap": "1rem"}}>
                    <div>
                        <div style={{"display": "flex", "alignItems": "center", "gap": "0.5rem"}}>
                            <span style={{"fontSize": "1.3rem", "fontWeight": "800", "color": "#38bdf8"}}>
                                {"GridMedic"}
                            </span>
                            <span
                                style={{
                                    "fontSize": "0.65rem",
                                    "padding": "0.2rem 0.45rem",
                                    "backgroundColor": "#0369a1",
                                    "borderRadius": "4px",
                                    "fontWeight": "600",
                                    "letterSpacing": "0.05em"
                                }}
                            >
                                {"CONTROL ROOM"}
                            </span>
                        </div>
                        <div style={{"fontSize": "0.75rem", "color": "#94a3b8"}}>
                            {"Moratuwa Grid Substation (SS1) · 600 Consumers"}
                        </div>
                    </div>
                </div>

                {#* Counters *#}
                <div style={{"display": "flex", "alignItems": "center", "gap": "0.6rem", "flexWrap": "wrap"}}>
                    <div
                        style={{
                            "backgroundColor": "#1e293b",
                            "padding": "0.35rem 0.75rem",
                            "borderRadius": "6px",
                            "border": "1px solid #334155",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.65rem", "color": "#94a3b8", "textTransform": "uppercase"}}>
                            {"Complaints"}
                        </div>
                        <div style={{"fontSize": "1.1rem", "fontWeight": "700", "color": "#f8fafc"}}>
                            {counters.complaints if counters else 0}
                        </div>
                    </div>

                    <div
                        style={{
                            "backgroundColor": "#1e293b",
                            "padding": "0.35rem 0.75rem",
                            "borderRadius": "6px",
                            "border": "1px solid #334155",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.65rem", "color": "#94a3b8", "textTransform": "uppercase"}}>
                            {"Faults"}
                        </div>
                        <div style={{"fontSize": "1.1rem", "fontWeight": "700", "color": "#f59e0b"}}>
                            {counters.faults if counters else 0}
                        </div>
                    </div>

                    <div
                        style={{
                            "backgroundColor": "#1e293b",
                            "padding": "0.35rem 0.75rem",
                            "borderRadius": "6px",
                            "border": "1px solid #ef4444",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.65rem", "color": "#fca5a5", "textTransform": "uppercase"}}>
                            {"Consumers Off"}
                        </div>
                        <div style={{"fontSize": "1.1rem", "fontWeight": "700", "color": "#ef4444"}}>
                            {counters.homes_off if counters else 0}
                        </div>
                    </div>

                    {#* Critical Infrastructure Indicator Card *#}
                    <div
                        style={{
                            "backgroundColor": "#2e1065",
                            "padding": "0.35rem 0.75rem",
                            "borderRadius": "6px",
                            "border": "1px solid #a855f7",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.65rem", "color": "#d8b4fe", "textTransform": "uppercase", "fontWeight": "600"}}>
                            {"Critical Loads"}
                        </div>
                        <div style={{"display": "flex", "alignItems": "center", "justifyContent": "center", "gap": "0.35rem", "marginTop": "2px"}}>
                            <span
                                style={{
                                    "fontSize": "0.72rem",
                                    "padding": "0.1rem 0.35rem",
                                    "borderRadius": "3px",
                                    "backgroundColor": "#701a75",
                                    "color": "#fdf4ff",
                                    "fontWeight": "700"
                                }}
                            >
                                {"🏥 Hospital"}
                            </span>
                            <span
                                style={{
                                    "fontSize": "0.72rem",
                                    "padding": "0.1rem 0.35rem",
                                    "borderRadius": "3px",
                                    "backgroundColor": "#1e3a8a",
                                    "color": "#bfdbfe",
                                    "fontWeight": "700"
                                }}
                            >
                                {"💧 Pump"}
                            </span>
                        </div>
                    </div>

                    <div
                        style={{
                            "backgroundColor": "#1e293b",
                            "padding": "0.35rem 0.75rem",
                            "borderRadius": "6px",
                            "border": "1px solid #10b981",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.65rem", "color": "#86efac", "textTransform": "uppercase"}}>
                            {"Restored"}
                        </div>
                        <div style={{"fontSize": "1.1rem", "fontWeight": "700", "color": "#10b981"}}>
                            {counters.homes_restored if counters else 0}
                        </div>
                    </div>
                </div>

                {#* Portal Navigation *#}
                <div style={{"display": "flex", "alignItems": "center"}}>
                    <Link
                        to="/customer"
                        style={{
                            "padding": "0.45rem 0.85rem",
                            "backgroundColor": "#1e293b",
                            "border": "1px solid #38bdf8",
                            "color": "#38bdf8",
                            "borderRadius": "6px",
                            "textDecoration": "none",
                            "fontSize": "0.8rem",
                            "fontWeight": "600",
                            "display": "flex",
                            "alignItems": "center",
                            "gap": "0.35rem"
                        }}
                    >
                        {"Customer Portal ↗"}
                    </Link>
                </div>
            </header>

            {#* MAIN WORKSPACE (70% Diagram / 30% Right Panel) *#}
            <div
                style={{
                    "display": "flex",
                    "flex": "1",
                    "overflow": "hidden",
                    "minHeight": "0"
                }}
            >
                {#* LEFT ~70%: GRID MAP CONTAINER *#}
                <main
                    style={{
                        "flex": "7",
                        "display": "flex",
                        "flexDirection": "column",
                        "backgroundColor": "#0b1322",
                        "borderRight": "1px solid #1e293b",
                        "padding": "1rem",
                        "overflow": "auto"
                    }}
                >
                    <div
                        style={{
                            "display": "flex",
                            "justifyContent": "space-between",
                            "alignItems": "center",
                            "marginBottom": "0.75rem"
                        }}
                    >
                        <h2 style={{"margin": "0", "fontSize": "1rem", "color": "#e2e8f0", "fontWeight": "600"}}>
                            {"Radial Distribution Schematic (Moratuwa Substation SS1)"}
                        </h2>
                        <div style={{"display": "flex", "gap": "0.75rem", "fontSize": "0.75rem"}}>
                            <span style={{"color": "#10b981"}}>{"● Energised"}</span>
                            <span style={{"color": "#ef4444"}}>{"● Faulted / Outage"}</span>
                            <span style={{"color": "#f59e0b"}}>{"● Suspected Fuse"}</span>
                            <span style={{"color": "#38bdf8"}}>{"● Restored via Tie"}</span>
                        </div>
                    </div>

                    {#* SVG Schematic Preview / Container *#}
                    <div
                        style={{
                            "flex": "1",
                            "minHeight": "420px",
                            "backgroundColor": "#070c16",
                            "borderRadius": "8px",
                            "border": "1px solid #1e293b",
                            "position": "relative",
                            "overflow": "hidden",
                            "display": "flex",
                            "flexDirection": "column",
                            "justifyContent": "space-between",
                            "padding": "1rem"
                        }}
                    >
                        {#* Diagram Header & Zones overlay *#}
                        <div style={{"display": "flex", "justifyContent": "space-between"}}>
                            <div
                                style={{
                                    "padding": "0.4rem 0.8rem",
                                    "backgroundColor": "rgba(30, 58, 138, 0.25)",
                                    "border": "1px dashed #3b82f6",
                                    "borderRadius": "6px",
                                    "fontSize": "0.75rem",
                                    "color": "#93c5fd"
                                }}
                            >
                                <strong>{"AREA NORTH (Feeder 1 — 310 Consumers · Hospital)"}</strong>
                                <div>{"SS1 → F1-A [SW1] F1-B [SW2] F1-C · T1, T2, T3 (Hospital), T4, T5"}</div>
                            </div>

                            <div
                                style={{
                                    "padding": "0.4rem 0.8rem",
                                    "display": "block" if len(hazard_faults) > 0 else "none",
                                    "backgroundColor": "rgba(220, 38, 38, 0.15)",
                                    "border": "1px solid #ef4444",
                                    "borderRadius": "6px",
                                    "fontSize": "0.75rem",
                                    "color": "#fca5a5"
                                }}
                            >
                                <strong>{f"⚠️ HAZARD: {hazard_faults[0].hazard_label.upper()} AT {hazard_faults[0].device_id}" if len(hazard_faults) > 0 else ""}</strong>
                                <div>{f"{hazard_faults[0].kind_label} · {hazard_faults[0].homes_affected} homes · {hazard_faults[0].status_label}" if len(hazard_faults) > 0 else ""}</div>
                            </div>
                        </div>

                        {#* Schematic Visual representation: live from get_grid *#}
                        <div style={{"textAlign": "center", "padding": "0.5rem 0"}}>
                            <GridMap grid={grid} />
                        </div>

                        {#* Feeder 2 Zone footer *#}
                        <div
                            style={{
                                "padding": "0.4rem 0.8rem",
                                "backgroundColor": "rgba(16, 185, 129, 0.15)",
                                "border": "1px dashed #10b981",
                                "borderRadius": "6px",
                                "fontSize": "0.75rem",
                                "color": "#a7f3d0",
                                "display": "flex",
                                "justifyContent": "space-between"
                            }}
                        >
                            <span><strong>{"AREA SOUTH (Feeder 2 — 290 Consumers · Water Pump):"}</strong>{" SS1 → F2-A [SW3] F2-B · T6 (Water Pump), T7, T8, T9, T10"}</span>
                            <span>{"TS1 Tie Capacity: 700 Max"}</span>
                        </div>
                    </div>
                </main>

                {#* RIGHT ~30%: RANKED FAULTS, CREWS, ACTIONS *#}
                <aside
                    style={{
                        "flex": "3",
                        "display": "flex",
                        "flexDirection": "column",
                        "backgroundColor": "#0f172a",
                        "padding": "1rem",
                        "overflowY": "auto",
                        "gap": "1rem",
                        "minWidth": "320px"
                    }}
                >
                    {#* 1. Ranked Faults Panel *#}
                    <div
                        style={{
                            "backgroundColor": "#1e293b",
                            "borderRadius": "8px",
                            "padding": "0.85rem",
                            "border": "1px solid #334155"
                        }}
                    >
                        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "0.5rem"}}>
                            <h3 style={{"margin": "0", "fontSize": "0.95rem", "color": "#f8fafc"}}>
                                {"Ranked Faults"}
                            </h3>
                            <span style={{"fontSize": "0.75rem", "color": "#94a3b8"}}>
                                {f"{len(faults)} identified"}
                            </span>
                        </div>

                        <div style={{"display": "flex", "flexDirection": "column", "gap": "0.5rem"}}>
                            {[
                                <div
                                    key={f.id}
                                    onClick={lambda { selected_fault_id = f.id; }}
                                    style={{
                                        "padding": "0.6rem",
                                        "borderRadius": "6px",
                                        "cursor": "pointer",
                                        "backgroundColor": "#0f172a" if selected_fault_id == f.id else "#182234",
                                        "border": "1px solid " + ("#38bdf8" if selected_fault_id == f.id else "#334155")
                                    }}
                                >
                                    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "flex-start"}}>
                                        <div>
                                            <span style={{"fontWeight": "700", "fontSize": "0.85rem", "color": "#f8fafc"}}>
                                                {f"{f.id} · {f.kind_label} @ {f.device_id}"}
                                            </span>
                                            {f.street != "" and (
                                                <span style={{"fontSize": "0.75rem", "color": "#94a3b8", "marginLeft": "0.3rem"}}>
                                                    {f"({f.street})"}
                                                </span>
                                            )}
                                        </div>
                                        <span
                                            style={{
                                                "fontSize": "0.7rem",
                                                "fontWeight": "700",
                                                "padding": "0.15rem 0.35rem",
                                                "borderRadius": "4px",
                                                "backgroundColor": "#0284c7",
                                                "color": "white"
                                            }}
                                        >
                                            {f"P:{f.priority}"}
                                        </span>
                                    </div>

                                    <div style={{"display": "flex", "gap": "0.35rem", "marginTop": "0.35rem", "flexWrap": "wrap"}}>
                                        {f.hazard_label != "" and (
                                            <span style={{"fontSize": "0.65rem", "padding": "0.1rem 0.3rem", "borderRadius": "3px", "backgroundColor": "#7f1d1d", "color": "#fca5a5"}}>
                                                {f"⚠️ {f.hazard_label}"}
                                            </span>
                                        )}
                                        {len(f.critical_loads) > 0 and (
                                            <span style={{"fontSize": "0.65rem", "padding": "0.1rem 0.3rem", "borderRadius": "3px", "backgroundColor": "#581c87", "color": "#d8b4fe"}}>
                                                {f"🏥 {f.critical_loads[0]}"}
                                            </span>
                                        )}
                                        <span style={{"fontSize": "0.65rem", "padding": "0.1rem 0.3rem", "borderRadius": "3px", "backgroundColor": "#1e293b", "color": "#94a3b8"}}>
                                            {f"{f.homes_affected} consumers"}
                                        </span>
                                        <span style={{"fontSize": "0.65rem", "padding": "0.1rem 0.3rem", "borderRadius": "3px", "backgroundColor": "#14532d", "color": "#86efac"}}>
                                            {f.status_label}
                                        </span>
                                        {f.updated_by_crew and (
                                            <span style={{"fontSize": "0.65rem", "padding": "0.1rem 0.3rem", "borderRadius": "3px", "backgroundColor": "#854d0e", "color": "#fef08a"}}>
                                                {"Mind-changed ↺"}
                                            </span>
                                        )}
                                    </div>
                                </div>
                                for f in faults
                            ]}
                        </div>
                    </div>

                    {#* 2. Crew Tasks Panel (WP-C4) *#}
                    <CrewPanel crews={crews} />

                    {#* 3. Restoration Plans & Safety Check (WP-C7) *#}
                    <ActionsPanel actions={actions} onApply={handleApplyAction} />
                </aside>
            </div>

            {#* BOTTOM STRIP: EVENT LOG & WHY REASONING & CREW REPORT BOX *#}
            <footer
                style={{
                    "display": "flex",
                    "backgroundColor": "#0f172a",
                    "borderTop": "1px solid #1e293b",
                    "height": "180px",
                    "overflow": "hidden"
                }}
            >
                {#* Left 60%: Live Event Stream *#}
                <div
                    style={{
                        "flex": "6",
                        "padding": "0.75rem",
                        "borderRight": "1px solid #1e293b",
                        "overflowY": "auto"
                    }}
                >
                    <div style={{"fontSize": "0.75rem", "fontWeight": "700", "color": "#94a3b8", "marginBottom": "0.4rem"}}>
                        {"LIVE EVENT STREAM"}
                    </div>
                    <div style={{"display": "flex", "flexDirection": "column", "gap": "0.25rem"}}>
                        {[
                            <div key={idx} style={{"fontSize": "0.75rem", "color": "#cbd5e1", "fontFamily": "monospace"}}>
                                <span style={{"color": "#38bdf8"}}>{f"[{e.time_min:.1f}m]"}</span>
                                <span style={{"color": "#f59e0b", "margin": "0 0.4rem"}}>
                                    {f"<{e.kind}>"}
                                </span>
                                <span>{e.text}</span>
                            </div>
                            for (idx, e) in enumerate(events)
                        ]}
                    </div>
                </div>

                {#* Right 40%: Selected Fault Reason & Crew Report Box *#}
                <div
                    style={{
                        "flex": "4",
                        "padding": "0.75rem",
                        "display": "flex",
                        "flexDirection": "column",
                        "justifyContent": "space-between",
                        "overflowY": "auto"
                    }}
                >
                    {#* Why Reasoning *#}
                    <div style={{"marginBottom": "0.5rem"}}>
                        <div style={{"fontSize": "0.75rem", "fontWeight": "700", "color": "#38bdf8", "marginBottom": "0.2rem"}}>
                            {"REASONING & EVIDENCE (Why?)"}
                        </div>
                        <div style={{"fontSize": "0.75rem", "color": "#94a3b8"}}>
                            {f"Selected fault: {selected_fault_id if selected_fault_id != '' else 'None'}"}
                        </div>
                        {for sf in selected_faults {
                            <div key={sf.id} style={{"fontSize": "0.75rem", "color": "#cbd5e1", "marginTop": "0.25rem"}}>
                                <div style={{"color": "#f8fafc", "fontWeight": "600"}}>
                                    {f"{sf.kind_label} @ {sf.device_id} · {sf.homes_affected} homes · confidence {sf.confidence:.1f} · priority {sf.priority}"}
                                </div>
                                {sf.street and <div>{"Street: " + sf.street}</div>}
                                {sf.change_note and <div style={{"color": "#fbbf24"}}>{"Updated by crew report: " + sf.change_note}</div>}
                                {why_text and <div style={{"fontStyle": "italic"}}>{why_text}</div>}
                                {for (k, ev) in enumerate(sf.evidence) {
                                    <div key={str(k)}>{"• " + ev}</div>
                                }}
                            </div>
                        }}
                    </div>

                    {#* Crew Report Input *#}
                    <div>
                        <div style={{"display": "flex", "gap": "0.5rem", "marginBottom": "0.3rem"}}>
                            <select
                                value={selected_crew_id}
                                onChange={lambda e: ChangeEvent { selected_crew_id = e.target.value; }}
                                style={{
                                    "backgroundColor": "#1e293b",
                                    "color": "#f8fafc",
                                    "border": "1px solid #334155",
                                    "borderRadius": "4px",
                                    "fontSize": "0.75rem",
                                    "padding": "0.2rem"
                                }}
                            >
                                <option value="CREW-A">{"Crew A"}</option>
                                <option value="CREW-B">{"Crew B"}</option>
                                <option value="CREW-C">{"Crew C"}</option>
                            </select>

                            <input
                                type="text"
                                value={crew_report_text}
                                onChange={lambda e: ChangeEvent { crew_report_text = e.target.value; }}
                                placeholder="Field report (e.g. 'T9 fuses OK, Lake Road wire down')"
                                style={{
                                    "flex": "1",
                                    "backgroundColor": "#1e293b",
                                    "color": "#f8fafc",
                                    "border": "1px solid #334155",
                                    "borderRadius": "4px",
                                    "fontSize": "0.75rem",
                                    "padding": "0.2rem 0.4rem"
                                }}
                            />

                            <button
                                type="button"
                                onClick={handleSubmitCrewReport}
                                style={{
                                    "backgroundColor": "#2563eb",
                                    "color": "white",
                                    "border": "none",
                                    "borderRadius": "4px",
                                    "fontSize": "0.75rem",
                                    "padding": "0.2rem 0.6rem",
                                    "fontWeight": "600",
                                    "cursor": "pointer"
                                }}
                            >
                                {"Submit"}
                            </button>
                        </div>

                        {#* Presets *#}
                        <div style={{"display": "flex", "gap": "0.4rem"}}>
                            <button
                                type="button"
                                onClick={lambda {
                                    crew_report_text = "T9 transformer fine, fuses OK. Overhead service line down on Lake Road.";
                                    selected_crew_id = "CREW-C";
                                }}
                                style={{
                                    "fontSize": "0.65rem",
                                    "padding": "0.15rem 0.35rem",
                                    "backgroundColor": "#334155",
                                    "color": "#cbd5e1",
                                    "border": "none",
                                    "borderRadius": "3px",
                                    "cursor": "pointer"
                                }}
                            >
                                {"Preset: T9 Twist"}
                            </button>
                            <button
                                type="button"
                                onClick={lambda {
                                    crew_report_text = "Conductor repaired at pole 23, area made safe. Line restored.";
                                    selected_crew_id = "CREW-A";
                                }}
                                style={{
                                    "fontSize": "0.65rem",
                                    "padding": "0.15rem 0.35rem",
                                    "backgroundColor": "#334155",
                                    "color": "#cbd5e1",
                                    "border": "none",
                                    "borderRadius": "3px",
                                    "cursor": "pointer"
                                }}
                            >
                                {"Preset: Pole 23 Safe"}
                            </button>
                        </div>
                    </div>
                </div>
            </footer>

            {#* FLOATING SIMULATION CONTROLLER (MINIMIZABLE POPUP) *#}
            {sim_panel_open and sim_minimized and (
                <div
                    style={{
                        "position": "fixed",
                        "bottom": "1.25rem",
                        "right": "1.25rem",
                        "zIndex": "1000",
                        "backgroundColor": "#0f172a",
                        "border": "1px solid #0284c7",
                        "borderRadius": "8px",
                        "boxShadow": "0 10px 25px -5px rgba(0, 0, 0, 0.7)",
                        "padding": "0.45rem 0.75rem",
                        "display": "flex",
                        "alignItems": "center",
                        "gap": "0.5rem"
                    }}
                >
                    <div style={{"display": "flex", "alignItems": "center", "gap": "0.3rem"}}>
                        <span style={{"color": "#38bdf8", "fontSize": "0.85rem"}}>{"⚡"}</span>
                        <span style={{"fontSize": "0.75rem", "fontWeight": "700", "color": "#f8fafc"}}>
                            {f"Sim: {clock_min:.1f}m"}
                        </span>
                        <span
                            style={{
                                "fontSize": "0.65rem",
                                "padding": "0.1rem 0.35rem",
                                "borderRadius": "3px",
                                "backgroundColor": "#1e3a8a",
                                "color": "#93c5fd",
                                "fontWeight": "600"
                            }}
                        >
                            {f"{speed}×"}
                        </span>
                    </div>

                    <button
                        type="button"
                        onClick={handleStartStorm}
                        style={{
                            "padding": "0.25rem 0.55rem",
                            "backgroundColor": "#ea580c" if running else "#16a34a",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "4px",
                            "fontSize": "0.75rem",
                            "fontWeight": "600",
                            "cursor": "pointer"
                        }}
                    >
                        {"⏸ Pause" if running else "▶ Run"}
                    </button>

                    <button
                        type="button"
                        onClick={handleTick}
                        style={{
                            "padding": "0.25rem 0.55rem",
                            "backgroundColor": "#2563eb",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "4px",
                            "fontSize": "0.75rem",
                            "fontWeight": "600",
                            "cursor": "pointer"
                        }}
                    >
                        {"⏭ Step"}
                    </button>

                    <button
                        id="sim-dock-settings-btn"
                        type="button"
                        onClick={lambda { sim_minimized = False; }}
                        title="Expand Simulation Settings"
                        style={{
                            "padding": "0.25rem 0.55rem",
                            "backgroundColor": "#0284c7",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "4px",
                            "fontSize": "0.75rem",
                            "fontWeight": "600",
                            "cursor": "pointer"
                        }}
                    >
                        {"▲ Expand"}
                    </button>
                </div>
            )}

            {sim_panel_open and (not sim_minimized) and (
                <div
                    style={{
                        "position": "fixed",
                        "bottom": "1.25rem",
                        "right": "1.25rem",
                        "zIndex": "1000",
                        "width": "350px",
                        "maxWidth": "calc(100vw - 2.5rem)",
                        "backgroundColor": "#0f172a",
                        "border": "1px solid #38bdf8",
                        "borderRadius": "12px",
                        "boxShadow": "0 20px 40px rgba(0, 0, 0, 0.8)",
                        "overflow": "hidden"
                    }}
                >
                    {#* Popup Header *#}
                    <div
                        style={{
                            "display": "flex",
                            "justifyContent": "space-between",
                            "alignItems": "center",
                            "padding": "0.75rem 1rem",
                            "backgroundColor": "#1e293b",
                            "borderBottom": "1px solid #334155"
                        }}
                    >
                        <div style={{"display": "flex", "alignItems": "center", "gap": "0.4rem"}}>
                            <span style={{"color": "#38bdf8", "fontSize": "1.1rem"}}>{"⚡"}</span>
                            <div>
                                <div style={{"fontWeight": "700", "fontSize": "0.85rem", "color": "#f8fafc"}}>
                                    {"Simulation Settings"}
                                </div>
                                <div style={{"fontSize": "0.68rem", "color": "#94a3b8"}}>
                                    {"Scenario Injection & Time Controls"}
                                </div>
                            </div>
                        </div>

                        <div style={{"display": "flex", "alignItems": "center"}}>
                            <button
                                type="button"
                                onClick={lambda { sim_minimized = True; }}
                                title="Minimize to Dock"
                                style={{
                                    "padding": "0.25rem 0.6rem",
                                    "backgroundColor": "#334155",
                                    "color": "#e2e8f0",
                                    "border": "none",
                                    "borderRadius": "4px",
                                    "fontSize": "0.75rem",
                                    "fontWeight": "600",
                                    "cursor": "pointer"
                                }}
                            >
                                {"— Minimize"}
                            </button>
                        </div>
                    </div>

                    {#* Popup Body *#}
                    <div style={{"padding": "1rem", "display": "flex", "flexDirection": "column", "gap": "0.9rem"}}>
                        {#* Status & Clock *#}
                        <div
                            style={{
                                "display": "flex",
                                "justifyContent": "space-between",
                                "alignItems": "center",
                                "padding": "0.5rem 0.75rem",
                                "backgroundColor": "#182234",
                                "borderRadius": "6px",
                                "border": "1px solid #334155"
                            }}
                        >
                            <div>
                                <div style={{"fontSize": "0.65rem", "color": "#94a3b8", "textTransform": "uppercase"}}>
                                    {"Simulation Clock"}
                                </div>
                                <div style={{"fontSize": "1.2rem", "fontWeight": "800", "color": "#38bdf8", "fontFamily": "monospace"}}>
                                    {f"{clock_min:.1f} min"}
                                </div>
                            </div>
                            <span
                                style={{
                                    "fontSize": "0.75rem",
                                    "padding": "0.25rem 0.55rem",
                                    "borderRadius": "4px",
                                    "backgroundColor": "#14532d" if running else "#334155",
                                    "color": "#86efac" if running else "#94a3b8",
                                    "fontWeight": "700"
                                }}
                            >
                                {"● Active" if running else "⏸ Paused"}
                            </span>
                        </div>

                        {#* Speed Selector *#}
                        <div>
                            <div style={{"fontSize": "0.72rem", "fontWeight": "600", "color": "#cbd5e1", "marginBottom": "0.35rem"}}>
                                {"Simulation Speed"}
                            </div>
                            <div style={{"display": "flex", "gap": "0.4rem"}}>
                                {[
                                    <button
                                        key={s}
                                        type="button"
                                        onClick={lambda { speed = s; }}
                                        style={{
                                            "flex": "1",
                                            "padding": "0.4rem",
                                            "fontSize": "0.8rem",
                                            "borderRadius": "6px",
                                            "border": "1px solid " + ("#38bdf8" if speed == s else "#334155"),
                                            "cursor": "pointer",
                                            "fontWeight": "700",
                                            "backgroundColor": "#0284c7" if speed == s else "#1e293b",
                                            "color": "#ffffff" if speed == s else "#94a3b8"
                                        }}
                                    >
                                        {f"{s}×"}
                                    </button>
                                    for s in [1, 5, 20]
                                ]}
                            </div>
                        </div>

                        {#* Primary Action Buttons *#}
                        <div style={{"display": "flex", "gap": "0.5rem"}}>
                            <button
                                type="button"
                                onClick={handleStartStorm}
                                style={{
                                    "flex": "1",
                                    "padding": "0.55rem",
                                    "backgroundColor": "#ea580c" if running else "#16a34a",
                                    "color": "white",
                                    "border": "none",
                                    "borderRadius": "6px",
                                    "fontSize": "0.85rem",
                                    "fontWeight": "700",
                                    "cursor": "pointer"
                                }}
                            >
                                {("⏸ Pause Storm" if running else "▶ Start Storm")}
                            </button>

                            <button
                                type="button"
                                onClick={handleTick}
                                style={{
                                    "flex": "1",
                                    "padding": "0.55rem",
                                    "backgroundColor": "#2563eb",
                                    "color": "white",
                                    "border": "none",
                                    "borderRadius": "6px",
                                    "fontSize": "0.85rem",
                                    "fontWeight": "700",
                                    "cursor": "pointer"
                                }}
                            >
                                {"⏭ Step Tick"}
                            </button>
                        </div>

                        {#* Reset Button *#}
                        <button
                            type="button"
                            onClick={handleReset}
                            style={{
                                "width": "100%",
                                "padding": "0.45rem",
                                "backgroundColor": "#1e293b",
                                "color": "#f87171",
                                "border": "1px solid #7f1d1d",
                                "borderRadius": "6px",
                                "fontSize": "0.78rem",
                                "fontWeight": "600",
                                "cursor": "pointer"
                            }}
                        >
                            {"↺ Reset Scenario to Minute 0"}
                        </button>
                    </div>
                </div>
            )}
        </div>;
}
