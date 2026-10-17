"""GridMedic Operator Dashboard - Minimalist Control Room."""

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

# The operator's chosen fault. The 1 s poll keeps calling a loadInitial whose
# closure still sees the old (empty) selection and would reset it to the first
# fault every tick, so the choice lives here, outside any render.
glob _sel: dict = {"id": ""};

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
        f5_on: bool = False,
        scenario: str = "storm",
        why_text: str = "",
        why_id: str = "",    # fault the text was written for: slow replies must not show under another fault
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
    scenario_label: str = "Storm" if scenario == "storm" else ("Blackout" if scenario == "blackout" else "Island Collapse");

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
            {#* CLEAN MINIMALIST HEADER *#}
            <header
                style={{
                    "display": "flex",
                    "justifyContent": "space-between",
                    "alignItems": "center",
                    "padding": "0.6rem 1.25rem",
                    "backgroundColor": "#0b0f19",
                    "borderBottom": "1px solid #1e293b",
                    "flexWrap": "wrap",
                    "gap": "0.75rem"
                }}
            >
                {#* Project Branding & Subtitle *#}
                <div style={{"display": "flex", "alignItems": "center", "gap": "0.75rem"}}>
                    <div>
                        <div style={{"display": "flex", "alignItems": "center", "gap": "0.5rem"}}>
                            <span style={{"fontSize": "1.25rem", "fontWeight": "800", "color": "#f8fafc", "letterSpacing": "-0.01em"}}>
                                {"GridMedic"}
                            </span>
                            <span
                                style={{
                                    "fontSize": "0.65rem",
                                    "padding": "0.15rem 0.4rem",
                                    "backgroundColor": "#1e293b",
                                    "color": "#94a3b8",
                                    "borderRadius": "3px",
                                    "fontWeight": "600",
                                    "letterSpacing": "0.04em"
                                }}
                            >
                                {"CONTROL ROOM"}
                            </span>
                        </div>
                        <div style={{"fontSize": "0.72rem", "color": "#64748b", "marginTop": "0.1rem"}}>
                            {"Moratuwa (SS1) · 11kV Radial Network · 600 Consumers"}
                        </div>
                    </div>
                </div>

                {#* Clean Minimalist Telemetry Stats (No loud, conflicting colors) *#}
                <div style={{"display": "flex", "alignItems": "center", "gap": "0.5rem", "flexWrap": "wrap"}}>
                    <div
                        style={{
                            "backgroundColor": "#0f172a",
                            "padding": "0.35rem 0.75rem",
                            "borderRadius": "5px",
                            "border": "1px solid #1e293b",
                            "minWidth": "80px",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.62rem", "color": "#64748b", "textTransform": "uppercase", "letterSpacing": "0.04em"}}>
                            {"Complaints"}
                        </div>
                        <div style={{"fontSize": "1.1rem", "fontWeight": "700", "color": "#f8fafc", "marginTop": "0.05rem"}}>
                            {counters.complaints if counters else 0}
                        </div>
                    </div>

                    <div
                        style={{
                            "backgroundColor": "#0f172a",
                            "padding": "0.35rem 0.75rem",
                            "borderRadius": "5px",
                            "border": "1px solid #1e293b",
                            "minWidth": "80px",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.62rem", "color": "#64748b", "textTransform": "uppercase", "letterSpacing": "0.04em"}}>
                            {"Faults"}
                        </div>
                        <div style={{"fontSize": "1.1rem", "fontWeight": "700", "color": "#f59e0b" if counters and counters.faults > 0 else "#f8fafc", "marginTop": "0.05rem"}}>
                            {counters.faults if counters else 0}
                        </div>
                    </div>

                    <div
                        style={{
                            "backgroundColor": "#0f172a",
                            "padding": "0.35rem 0.75rem",
                            "borderRadius": "5px",
                            "border": "1px solid " + ("rgba(239, 68, 68, 0.4)" if counters and counters.homes_off > 0 else "#1e293b"),
                            "minWidth": "90px",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.62rem", "color": "#f87171" if counters and counters.homes_off > 0 else "#64748b", "textTransform": "uppercase", "letterSpacing": "0.04em"}}>
                            {"Consumers Off"}
                        </div>
                        <div style={{"fontSize": "1.1rem", "fontWeight": "700", "color": "#ef4444" if counters and counters.homes_off > 0 else "#f8fafc", "marginTop": "0.05rem"}}>
                            {counters.homes_off if counters else 0}
                        </div>
                    </div>

                    <div
                        style={{
                            "backgroundColor": "#0f172a",
                            "padding": "0.35rem 0.75rem",
                            "borderRadius": "5px",
                            "border": "1px solid #1e293b",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.62rem", "color": "#64748b", "textTransform": "uppercase", "letterSpacing": "0.04em"}}>
                            {"Critical Loads"}
                        </div>
                        <div style={{"fontSize": "0.75rem", "fontWeight": "600", "color": "#cbd5e1", "marginTop": "0.15rem"}}>
                            {"Hospital (T3) · Pump (T6)"}
                        </div>
                    </div>

                    <div
                        style={{
                            "backgroundColor": "#0f172a",
                            "padding": "0.35rem 0.75rem",
                            "borderRadius": "5px",
                            "border": "1px solid #1e293b",
                            "minWidth": "80px",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.62rem", "color": "#64748b", "textTransform": "uppercase", "letterSpacing": "0.04em"}}>
                            {"Restored"}
                        </div>
                        <div style={{"fontSize": "1.1rem", "fontWeight": "700", "color": "#10b981" if counters and counters.homes_restored > 0 else "#f8fafc", "marginTop": "0.05rem"}}>
                            {counters.homes_restored if counters else 0}
                        </div>
                    </div>
                </div>

                {#* Portal Link *#}
                <div style={{"display": "flex", "alignItems": "center"}}>
                    <Link
                        to="/customer"
                        style={{
                            "padding": "0.4rem 0.75rem",
                            "backgroundColor": "transparent",
                            "border": "1px solid #334155",
                            "color": "#cbd5e1",
                            "borderRadius": "5px",
                            "textDecoration": "none",
                            "fontSize": "0.75rem",
                            "fontWeight": "600",
                            "display": "flex",
                            "alignItems": "center",
                            "gap": "0.3rem"
                        }}
                    >
                        {"Customer Portal"}
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
                        "backgroundColor": "#070c14",
                        "borderRight": "1px solid #1e293b",
                        "padding": "0.75rem 1rem",
                        "overflow": "auto"
                    }}
                >
                    <div
                        style={{
                            "display": "flex",
                            "justifyContent": "space-between",
                            "alignItems": "center",
                            "marginBottom": "0.5rem"
                        }}
                    >
                        <h2 style={{"margin": "0", "fontSize": "0.85rem", "color": "#cbd5e1", "fontWeight": "600"}}>
                            {"Distribution Network Schematic (SS1)"}
                        </h2>
                        <div style={{"display": "flex", "gap": "0.85rem", "fontSize": "0.72rem"}}>
                            <span style={{"color": "#10b981"}}>{"Normal"}</span>
                            <span style={{"color": "#ef4444"}}>{"Outage"}</span>
                            <span style={{"color": "#f59e0b"}}>{"Suspected"}</span>
                            <span style={{"color": "#64748b"}}>{"Tie Line"}</span>
                        </div>
                    </div>

                    {#* SVG Schematic Container (Clean, unobstructed) *#}
                    <div
                        style={{
                            "flex": "1",
                            "minHeight": "420px",
                            "backgroundColor": "#090d16",
                            "borderRadius": "6px",
                            "border": "1px solid #1e293b",
                            "position": "relative",
                            "overflow": "hidden",
                            "display": "flex",
                            "flexDirection": "column",
                            "justifyContent": "center",
                            "padding": "0.5rem"
                        }}
                    >
                        {#* Alert banner only if a real public hazard is active *#}
                        {len(hazard_faults) > 0 and (
                            <div
                                style={{
                                    "position": "absolute",
                                    "top": "0.75rem",
                                    "right": "0.75rem",
                                    "padding": "0.35rem 0.65rem",
                                    "backgroundColor": "rgba(220, 38, 38, 0.15)",
                                    "border": "1px solid #ef4444",
                                    "borderRadius": "4px",
                                    "fontSize": "0.72rem",
                                    "color": "#fca5a5"
                                }}
                            >
                                <strong>{f"HAZARD: {hazard_faults[0].hazard_label.upper()} AT {hazard_faults[0].device_id}"}</strong>
                                <span>{f" · {hazard_faults[0].homes_affected} homes affected"}</span>
                            </div>
                        )}

                        <div style={{"textAlign": "center"}}>
                            <GridMap grid={grid} />
                        </div>
                    </div>
                </main>

                {#* RIGHT ~30%: RANKED FAULTS, CREWS, ACTIONS *#}
                <aside
                    style={{
                        "flex": "3",
                        "display": "flex",
                        "flexDirection": "column",
                        "backgroundColor": "#0b0f19",
                        "padding": "0.75rem",
                        "overflowY": "auto",
                        "gap": "0.6rem",
                        "minWidth": "310px"
                    }}
                >
                    {#* 1. Ranked Faults Panel *#}
                    <div
                        style={{
                            "backgroundColor": "#0f172a",
                            "borderRadius": "6px",
                            "padding": "0.75rem",
                            "border": "1px solid #1e293b"
                        }}
                    >
                        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "0.5rem"}}>
                            <h3 style={{"margin": "0", "fontSize": "0.78rem", "fontWeight": "600", "color": "#f8fafc", "letterSpacing": "0.03em", "textTransform": "uppercase"}}>
                                {"Ranked Faults"}
                            </h3>
                            <span style={{"fontSize": "0.68rem", "color": "#64748b"}}>
                                {f"{len(faults)} identified"}
                            </span>
                        </div>

                        <div style={{"display": "flex", "flexDirection": "column", "gap": "0.35rem"}}>
                            {for f in faults {
                                <div
                                    key={f.id}
                                    onClick={lambda { _sel["id"] = f.id; selected_fault_id = f.id; }}
                                    style={{
                                        "padding": "0.5rem 0.65rem",
                                        "borderRadius": "4px",
                                        "cursor": "pointer",
                                        "backgroundColor": "#131d31" if selected_fault_id == f.id else "#090d16",
                                        "border": "1px solid " + ("#475569" if selected_fault_id == f.id else "#1e293b")
                                    }}
                                >
                                    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "flex-start"}}>
                                        <div>
                                            <span style={{"fontWeight": "600", "fontSize": "0.78rem", "color": "#f8fafc"}}>
                                                {f"{f.id} · {f.kind_label} @ {f.device_id}"}
                                            </span>
                                            {f.street != "" and (
                                                <span style={{"fontSize": "0.7rem", "color": "#64748b", "marginLeft": "0.25rem"}}>
                                                    {f"({f.street})"}
                                                </span>
                                            )}
                                        </div>
                                        <span
                                            style={{
                                                "fontSize": "0.68rem",
                                                "fontWeight": "600",
                                                "color": "#94a3b8"
                                            }}
                                        >
                                            {f"P:{f.priority}"}
                                        </span>
                                    </div>

                                    <div style={{"display": "flex", "gap": "0.3rem", "marginTop": "0.3rem", "flexWrap": "wrap"}}>
                                        {f.hazard_label != "" and (
                                            <span style={{"fontSize": "0.65rem", "color": "#ef4444", "fontWeight": "600"}}>
                                                {f"[{f.hazard_label}]"}
                                            </span>
                                        )}
                                        {len(f.critical_loads) > 0 and (
                                            <span style={{"fontSize": "0.65rem", "color": "#cbd5e1"}}>
                                                {f"• {f.critical_loads[0]}"}
                                            </span>
                                        )}
                                        <span style={{"fontSize": "0.65rem", "color": "#64748b"}}>
                                            {f"• {f.homes_affected} homes"}
                                        </span>
                                        <span style={{"fontSize": "0.65rem", "color": "#94a3b8"}}>
                                            {f"• {f.status_label}"}
                                        </span>
                                        {f.updated_by_crew and (
                                            <span style={{"fontSize": "0.65rem", "color": "#f59e0b", "fontWeight": "600"}}>
                                                {"• Revised"}
                                            </span>
                                        )}
                                    </div>
                                </div>
                            }}
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
                    "backgroundColor": "#0b0f19",
                    "borderTop": "1px solid #1e293b",
                    "height": "180px",
                    "overflow": "hidden"
                }}
            >
                {#* Left 60%: Live Event Stream *#}
                <div
                    style={{
                        "flex": "6",
                        "padding": "0.65rem 1rem",
                        "borderRight": "1px solid #1e293b",
                        "overflowY": "auto"
                    }}
                >
                    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "0.35rem"}}>
                        <span style={{"fontSize": "0.72rem", "fontWeight": "600", "color": "#64748b", "letterSpacing": "0.04em", "textTransform": "uppercase"}}>
                            {"Operational Event Log"}
                        </span>
                    </div>
                    <div style={{"display": "flex", "flexDirection": "column", "gap": "0.2rem"}}>
                        {for (idx, e) in enumerate(events) {
                            <div key={idx} style={{"fontSize": "0.72rem", "color": "#94a3b8", "fontFamily": "monospace", "display": "flex", "alignItems": "center", "gap": "0.4rem"}}>
                                <span style={{"color": "#64748b"}}>{f"[{e.time_min:.1f}m]"}</span>
                                <span style={{"color": "#cbd5e1"}}>
                                    {f"<{e.kind}>"}
                                </span>
                                <span>{e.text}</span>
                            </div>
                        }}
                    </div>
                </div>

                {#* Right 40%: Selected Fault Reason & Crew Report Box *#}
                <div
                    style={{
                        "flex": "4",
                        "padding": "0.65rem 1rem",
                        "display": "flex",
                        "flexDirection": "column",
                        "justifyContent": "space-between",
                        "overflowY": "auto"
                    }}
                >
                    {#* Why Reasoning *#}
                    <div style={{"marginBottom": "0.35rem"}}>
                        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "0.2rem"}}>
                            <span style={{"fontSize": "0.72rem", "fontWeight": "600", "color": "#cbd5e1", "letterSpacing": "0.03em", "textTransform": "uppercase"}}>
                                {"Diagnostics (Why?)"}
                            </span>
                            <span style={{"fontSize": "0.68rem", "color": "#64748b"}}>
                                {f"Target: {selected_fault_id if selected_fault_id != '' else 'None'}"}
                            </span>
                        </div>
                        {for sf in selected_faults {
                            <div key={sf.id} style={{"fontSize": "0.72rem", "color": "#94a3b8", "marginTop": "0.15rem"}}>
                                <div style={{"color": "#f8fafc", "fontWeight": "600"}}>
                                    {f"{sf.kind_label} @ {sf.device_id} · {sf.homes_affected} homes · priority {sf.priority}"}
                                </div>
                                {sf.street and <div>{"Street: " + sf.street}</div>}
                                {sf.change_note and <div style={{"color": "#f59e0b"}}>{"Updated by crew report: " + sf.change_note}</div>}
                                {why_text and why_id == sf.id and <div style={{"fontStyle": "italic", "color": "#cbd5e1", "marginTop": "0.1rem"}}>{why_text}</div>}
                                {for (k, ev) in enumerate(sf.evidence) {
                                    <div key={str(k)} style={{"color": "#64748b", "marginTop": "0.05rem"}}>{"• " + ev}</div>
                                }}
                            </div>
                        }}
                    </div>

                    {#* Crew Report Input *#}
                    <div>
                        <div style={{"display": "flex", "gap": "0.4rem", "marginBottom": "0.25rem"}}>
                            <select
                                value={selected_crew_id}
                                onChange={lambda e: ChangeEvent { selected_crew_id = e.target.value; }}
                                style={{
                                    "backgroundColor": "#0f172a",
                                    "color": "#f8fafc",
                                    "border": "1px solid #334155",
                                    "borderRadius": "4px",
                                    "fontSize": "0.72rem",
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
                                    "backgroundColor": "#0f172a",
                                    "color": "#f8fafc",
                                    "border": "1px solid #334155",
                                    "borderRadius": "4px",
                                    "fontSize": "0.72rem",
                                    "padding": "0.2rem 0.45rem"
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
                                    "fontSize": "0.72rem",
                                    "padding": "0.2rem 0.6rem",
                                    "fontWeight": "600",
                                    "cursor": "pointer"
                                }}
                            >
                                {"Submit"}
                            </button>
                        </div>

                        {#* Presets *#}
                        <div style={{"display": "flex", "gap": "0.35rem"}}>
                            <button
                                type="button"
                                onClick={lambda {
                                    crew_report_text = "T9 transformer fine, fuses OK. Overhead service line down on Lake Road.";
                                    selected_crew_id = "CREW-C";
                                }}
                                style={{
                                    "fontSize": "0.65rem",
                                    "padding": "0.15rem 0.35rem",
                                    "backgroundColor": "#1e293b",
                                    "color": "#94a3b8",
                                    "border": "1px solid #334155",
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
                                    "backgroundColor": "#1e293b",
                                    "color": "#94a3b8",
                                    "border": "1px solid #334155",
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
                        "bottom": "1rem",
                        "right": "1rem",
                        "zIndex": "1000",
                        "backgroundColor": "#0f172a",
                        "border": "1px solid #334155",
                        "borderRadius": "6px",
                        "boxShadow": "0 8px 20px rgba(0, 0, 0, 0.6)",
                        "padding": "0.4rem 0.65rem",
                        "display": "flex",
                        "alignItems": "center",
                        "gap": "0.5rem"
                    }}
                >
                    <div style={{"display": "flex", "alignItems": "center", "gap": "0.3rem"}}>
                        <span style={{"fontSize": "0.75rem", "fontWeight": "600", "color": "#f8fafc"}}>
                            {f"Sim: {clock_min:.1f}m"}
                        </span>
                        <span style={{"fontSize": "0.65rem", "color": "#94a3b8"}}>
                            {f"({speed}×)"}
                        </span>
                    </div>

                    <button
                        type="button"
                        onClick={handleStartStorm}
                        style={{
                            "padding": "0.2rem 0.5rem",
                            "backgroundColor": "#ea580c" if running else "#16a34a",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "3px",
                            "fontSize": "0.72rem",
                            "fontWeight": "600",
                            "cursor": "pointer"
                        }}
                    >
                        {"Pause" if running else "Run"}
                    </button>

                    <button
                        type="button"
                        onClick={handleTick}
                        style={{
                            "padding": "0.2rem 0.5rem",
                            "backgroundColor": "#2563eb",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "3px",
                            "fontSize": "0.72rem",
                            "fontWeight": "600",
                            "cursor": "pointer"
                        }}
                    >
                        {"Step"}
                    </button>

                    <button
                        id="sim-dock-settings-btn"
                        type="button"
                        onClick={lambda { sim_minimized = False; }}
                        title="Expand Simulation Controls"
                        style={{
                            "display": "flex",
                            "alignItems": "center",
                            "justifyContent": "center",
                            "width": "26px",
                            "height": "24px",
                            "padding": "0",
                            "backgroundColor": "#1e293b",
                            "color": "#cbd5e1",
                            "border": "1px solid #334155",
                            "borderRadius": "3px",
                            "cursor": "pointer"
                        }}
                    >
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" style={{"display": "block"}}>
                            <polyline points="18 15 12 9 6 15" />
                        </svg>
                    </button>
                </div>
            )}

            {sim_panel_open and (not sim_minimized) and (
                <div
                    style={{
                        "position": "fixed",
                        "bottom": "1rem",
                        "right": "1rem",
                        "zIndex": "1000",
                        "width": "320px",
                        "maxWidth": "calc(100vw - 2rem)",
                        "backgroundColor": "#0f172a",
                        "border": "1px solid #334155",
                        "borderRadius": "8px",
                        "boxShadow": "0 15px 35px rgba(0, 0, 0, 0.7)",
                        "overflow": "hidden"
                    }}
                >
                    {#* Popup Header *#}
                    <div
                        style={{
                            "display": "flex",
                            "justifyContent": "space-between",
                            "alignItems": "center",
                            "padding": "0.6rem 0.85rem",
                            "backgroundColor": "#131d31",
                            "borderBottom": "1px solid #1e293b"
                        }}
                    >
                        <div style={{"fontWeight": "700", "fontSize": "0.82rem", "color": "#f8fafc"}}>
                            {"Simulation Controls"}
                        </div>

                        <button
                            type="button"
                            onClick={lambda { sim_minimized = True; }}
                            title="Minimize"
                            style={{
                                "display": "flex",
                                "alignItems": "center",
                                "justifyContent": "center",
                                "width": "24px",
                                "height": "24px",
                                "padding": "0",
                                "backgroundColor": "transparent",
                                "color": "#94a3b8",
                                "border": "1px solid #334155",
                                "borderRadius": "3px",
                                "cursor": "pointer"
                            }}
                        >
                            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" style={{"display": "block"}}>
                                <line x1="4" y1="12" x2="20" y2="12" />
                            </svg>
                        </button>
                    </div>

                    {#* Popup Body *#}
                    <div style={{"padding": "0.85rem", "display": "flex", "flexDirection": "column", "gap": "0.75rem"}}>
                        {#* Status & Clock *#}
                        <div
                            style={{
                                "display": "flex",
                                "justifyContent": "space-between",
                                "alignItems": "center",
                                "padding": "0.45rem 0.65rem",
                                "backgroundColor": "#090d16",
                                "borderRadius": "4px",
                                "border": "1px solid #1e293b"
                            }}
                        >
                            <div>
                                <div style={{"fontSize": "0.62rem", "color": "#64748b", "textTransform": "uppercase"}}>
                                    {"Clock"}
                                </div>
                                <div style={{"fontSize": "1.1rem", "fontWeight": "700", "color": "#f8fafc", "fontFamily": "monospace"}}>
                                    {f"{clock_min:.1f} min"}
                                </div>
                            </div>
                            <span
                                style={{
                                    "fontSize": "0.7rem",
                                    "color": "#10b981" if running else "#94a3b8",
                                    "fontWeight": "600"
                                }}
                            >
                                {"Active" if running else "Paused"}
                            </span>
                        </div>

                        {#* Scenario Selector: takes effect on the next start *#}
                        <div>
                            <div style={{"fontSize": "0.68rem", "color": "#94a3b8", "marginBottom": "0.25rem"}}>
                                {"Scenario"}
                            </div>
                            <div style={{"display": "flex", "flexDirection": "column", "gap": "0.3rem"}}>
                                {for (sid, slabel, sdesc) in [
                                    ("storm", "Storm", "4 faults: line down, 2 fuses, a service wire"),
                                    ("blackout", "TL1 Blackout", "Transmission line trips, whole grid dark"),
                                    ("island", "Island-wide Collapse", "National grid down, multilingual flood")
                                ] {
                                    <button
                                        key={sid}
                                        type="button"
                                        onClick={lambda { scenario = sid; }}
                                        style={{
                                            "textAlign": "left",
                                            "padding": "0.35rem 0.5rem",
                                            "borderRadius": "4px",
                                            "border": "1px solid " + ("#475569" if scenario == sid else "#1e293b"),
                                            "cursor": "pointer",
                                            "backgroundColor": "#1e293b" if scenario == sid else "#090d16",
                                            "color": "#f8fafc" if scenario == sid else "#64748b"
                                        }}
                                    >
                                        <div style={{"fontSize": "0.75rem", "fontWeight": "600"}}>{slabel}</div>
                                        <div style={{"fontSize": "0.62rem", "opacity": "0.8"}}>{sdesc}</div>
                                    </button>
                                }}
                            </div>
                        </div>

                        {#* Speed Selector *#}
                        <div>
                            <div style={{"fontSize": "0.68rem", "color": "#94a3b8", "marginBottom": "0.25rem"}}>
                                {"Speed"}
                            </div>
                            <div style={{"display": "flex", "gap": "0.35rem"}}>
                                {for s in [1, 5, 20] {
                                    <button
                                        key={s}
                                        type="button"
                                        onClick={lambda { speed = s; }}
                                        style={{
                                            "flex": "1",
                                            "padding": "0.3rem",
                                            "fontSize": "0.75rem",
                                            "borderRadius": "4px",
                                            "border": "1px solid " + ("#475569" if speed == s else "#1e293b"),
                                            "cursor": "pointer",
                                            "fontWeight": "600",
                                            "backgroundColor": "#1e293b" if speed == s else "#090d16",
                                            "color": "#f8fafc" if speed == s else "#64748b"
                                        }}
                                    >
                                        {f"{s}×"}
                                    </button>
                                }}
                            </div>
                        </div>

                        {#* Optional hidden second fault (F5): only the storm has one *#}
                        {if scenario == "storm" {
                            <label key="f5-toggle" style={{"display": "flex", "alignItems": "center", "gap": "0.35rem", "fontSize": "0.7rem", "color": "#64748b", "cursor": "pointer"}}>
                                <input
                                    type="checkbox"
                                    checked={f5_on}
                                    onChange={lambda e: ChangeEvent { f5_on = e.target.checked; }}
                                />
                                {"Hide secondary fault (T4 fuse) for verifier"}
                            </label>
                        }}

                        {#* Primary Action Buttons *#}
                        <div style={{"display": "flex", "gap": "0.4rem"}}>
                            <button
                                type="button"
                                onClick={handleStartStorm}
                                style={{
                                    "flex": "1",
                                    "padding": "0.45rem",
                                    "backgroundColor": "#ea580c" if running else "#16a34a",
                                    "color": "white",
                                    "border": "none",
                                    "borderRadius": "4px",
                                    "fontSize": "0.78rem",
                                    "fontWeight": "600",
                                    "cursor": "pointer"
                                }}
                            >
                                {("Pause" if running else "Start " + scenario_label)}
                            </button>

                            <button
                                type="button"
                                onClick={handleTick}
                                style={{
                                    "flex": "1",
                                    "padding": "0.45rem",
                                    "backgroundColor": "#2563eb",
                                    "color": "white",
                                    "border": "none",
                                    "borderRadius": "4px",
                                    "fontSize": "0.78rem",
                                    "fontWeight": "600",
                                    "cursor": "pointer"
                                }}
                            >
                                {"Step Tick"}
                            </button>
                        </div>

                        {#* Reset Button *#}
                        <button
                            type="button"
                            onClick={handleReset}
                            style={{
                                "width": "100%",
                                "padding": "0.35rem",
                                "backgroundColor": "transparent",
                                "color": "#ef4444",
                                "border": "1px solid #7f1d1d",
                                "borderRadius": "4px",
                                "fontSize": "0.72rem",
                                "fontWeight": "600",
                                "cursor": "pointer"
                            }}
                        >
                            {"Reset Grid"}
                        </button>
                    </div>
                </div>
            )}
        </div>;
}
