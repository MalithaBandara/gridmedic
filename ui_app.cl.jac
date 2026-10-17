"""GridMedic Operator Dashboard - National Grid Control Room Theme."""

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
    async def handleStartBlackout -> None;
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
                "backgroundColor": "#060911",
                "color": "#f8fafc",
                "fontFamily": "'Inter', system-ui, -apple-system, sans-serif",
                "display": "flex",
                "flexDirection": "column"
            }}
        >
            {#* TOP BAR - GOVERNMENT UTILITY EXECUTIVE HEADER *#}
            <header
                style={{
                    "display": "flex",
                    "justifyContent": "space-between",
                    "alignItems": "center",
                    "padding": "0.65rem 1.25rem",
                    "backgroundColor": "#0b1120",
                    "borderBottom": "1px solid rgba(255, 255, 255, 0.08)",
                    "flexWrap": "wrap",
                    "gap": "0.75rem"
                }}
            >
                {#* Institutional Identity & Sector Telemetry *#}
                <div style={{"display": "flex", "alignItems": "center", "gap": "1rem"}}>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "0.75rem"}}>
                        <div
                            style={{
                                "width": "34px",
                                "height": "34px",
                                "borderRadius": "6px",
                                "backgroundColor": "#0f172a",
                                "border": "1px solid rgba(56, 189, 248, 0.4)",
                                "display": "flex",
                                "alignItems": "center",
                                "justifyContent": "center",
                                "fontSize": "1.1rem"
                            }}
                        >
                            {"⚡"}
                        </div>
                        <div>
                            <div style={{"display": "flex", "alignItems": "center", "gap": "0.5rem"}}>
                                <span style={{"fontSize": "1.1rem", "fontWeight": "800", "color": "#f8fafc", "letterSpacing": "0.02em"}}>
                                    {"CEYLON ELECTRICITY BOARD"}
                                </span>
                                <span
                                    style={{
                                        "fontSize": "0.62rem",
                                        "padding": "0.15rem 0.4rem",
                                        "backgroundColor": "#0369a1",
                                        "color": "white",
                                        "borderRadius": "4px",
                                        "fontWeight": "700",
                                        "letterSpacing": "0.06em"
                                    }}
                                >
                                    {"NATIONAL GRID CONTROL"}
                                </span>
                            </div>
                            <div style={{"display": "flex", "alignItems": "center", "gap": "0.5rem", "fontSize": "0.72rem", "color": "#94a3b8", "marginTop": "0.1rem"}}>
                                <span>{"Moratuwa Area (SS1) · 11kV Radial Distribution · 600 Consumers"}</span>
                                <span style={{"color": "#475569"}}>{"|"}</span>
                                <span style={{"display": "inline-flex", "alignItems": "center", "gap": "0.3rem"}}>
                                    <span
                                        style={{
                                            "width": "6px",
                                            "height": "6px",
                                            "borderRadius": "50%",
                                            "backgroundColor": "#ef4444" if running else "#10b981",
                                            "display": "inline-block"
                                        }}
                                    />
                                    <span style={{"color": "#fca5a5" if running else "#86efac", "fontWeight": "600"}}>
                                        {"STORM CONTINGENCY ACTIVE" if running else "SCADA TELEMETRY: NORMAL"}
                                    </span>
                                </span>
                            </div>
                        </div>
                    </div>
                </div>

                {#* Minimalist Telemetry KPI Cards *#}
                <div style={{"display": "flex", "alignItems": "center", "gap": "0.5rem", "flexWrap": "wrap"}}>
                    <div
                        style={{
                            "backgroundColor": "#10192e",
                            "padding": "0.4rem 0.75rem",
                            "borderRadius": "6px",
                            "border": "1px solid rgba(255, 255, 255, 0.08)",
                            "minWidth": "85px",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.62rem", "color": "#94a3b8", "textTransform": "uppercase", "letterSpacing": "0.05em", "fontWeight": "600"}}>
                            {"Complaints"}
                        </div>
                        <div style={{"fontSize": "1.15rem", "fontWeight": "800", "color": "#f8fafc", "marginTop": "0.1rem"}}>
                            {counters.complaints if counters else 0}
                        </div>
                    </div>

                    <div
                        style={{
                            "backgroundColor": "#10192e",
                            "padding": "0.4rem 0.75rem",
                            "borderRadius": "6px",
                            "border": "1px solid rgba(255, 255, 255, 0.08)",
                            "minWidth": "85px",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.62rem", "color": "#94a3b8", "textTransform": "uppercase", "letterSpacing": "0.05em", "fontWeight": "600"}}>
                            {"Faults"}
                        </div>
                        <div style={{"fontSize": "1.15rem", "fontWeight": "800", "color": "#f59e0b", "marginTop": "0.1rem"}}>
                            {counters.faults if counters else 0}
                        </div>
                    </div>

                    <div
                        style={{
                            "backgroundColor": "#10192e",
                            "padding": "0.4rem 0.75rem",
                            "borderRadius": "6px",
                            "border": "1px solid rgba(239, 68, 68, 0.35)",
                            "minWidth": "95px",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.62rem", "color": "#fca5a5", "textTransform": "uppercase", "letterSpacing": "0.05em", "fontWeight": "600"}}>
                            {"Consumers Off"}
                        </div>
                        <div style={{"fontSize": "1.15rem", "fontWeight": "800", "color": "#ef4444", "marginTop": "0.1rem"}}>
                            {counters.homes_off if counters else 0}
                        </div>
                    </div>

                    {#* Critical Infrastructure Indicator Card *#}
                    <div
                        style={{
                            "backgroundColor": "#10192e",
                            "padding": "0.4rem 0.75rem",
                            "borderRadius": "6px",
                            "border": "1px solid rgba(168, 85, 247, 0.35)",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.62rem", "color": "#d8b4fe", "textTransform": "uppercase", "letterSpacing": "0.05em", "fontWeight": "600"}}>
                            {"Critical Loads"}
                        </div>
                        <div style={{"display": "flex", "alignItems": "center", "justifyContent": "center", "gap": "0.35rem", "marginTop": "0.2rem"}}>
                            <span
                                style={{
                                    "fontSize": "0.68rem",
                                    "padding": "0.15rem 0.4rem",
                                    "borderRadius": "3px",
                                    "backgroundColor": "#581c87",
                                    "color": "#fdf4ff",
                                    "fontWeight": "700"
                                }}
                            >
                                {"🏥 Hospital (T3)"}
                            </span>
                            <span
                                style={{
                                    "fontSize": "0.68rem",
                                    "padding": "0.15rem 0.4rem",
                                    "borderRadius": "3px",
                                    "backgroundColor": "#1e3a8a",
                                    "color": "#bfdbfe",
                                    "fontWeight": "700"
                                }}
                            >
                                {"💧 Pump (T6)"}
                            </span>
                        </div>
                    </div>

                    <div
                        style={{
                            "backgroundColor": "#10192e",
                            "padding": "0.4rem 0.75rem",
                            "borderRadius": "6px",
                            "border": "1px solid rgba(16, 185, 129, 0.35)",
                            "minWidth": "85px",
                            "textAlign": "center"
                        }}
                    >
                        <div style={{"fontSize": "0.62rem", "color": "#86efac", "textTransform": "uppercase", "letterSpacing": "0.05em", "fontWeight": "600"}}>
                            {"Restored"}
                        </div>
                        <div style={{"fontSize": "1.15rem", "fontWeight": "800", "color": "#10b981", "marginTop": "0.1rem"}}>
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
                            "backgroundColor": "transparent",
                            "border": "1px solid rgba(56, 189, 248, 0.5)",
                            "color": "#38bdf8",
                            "borderRadius": "6px",
                            "textDecoration": "none",
                            "fontSize": "0.78rem",
                            "fontWeight": "600",
                            "letterSpacing": "0.02em",
                            "display": "flex",
                            "alignItems": "center",
                            "gap": "0.35rem"
                        }}
                    >
                        {"Public Inquiry Portal ↗"}
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
                        "backgroundColor": "#070c16",
                        "borderRight": "1px solid rgba(255, 255, 255, 0.08)",
                        "padding": "0.85rem 1rem",
                        "overflow": "auto"
                    }}
                >
                    <div
                        style={{
                            "display": "flex",
                            "justifyContent": "space-between",
                            "alignItems": "center",
                            "marginBottom": "0.65rem"
                        }}
                    >
                        <div style={{"display": "flex", "alignItems": "center", "gap": "0.5rem"}}>
                            <span style={{"color": "#38bdf8", "fontSize": "0.9rem"}}>{"⎇"}</span>
                            <h2 style={{"margin": "0", "fontSize": "0.88rem", "color": "#e2e8f0", "fontWeight": "700", "letterSpacing": "0.04em", "textTransform": "uppercase"}}>
                                {"11kV Radial Distribution Schematic — Moratuwa Substation (SS1)"}
                            </h2>
                        </div>
                        <div style={{"display": "flex", "gap": "0.85rem", "fontSize": "0.72rem", "fontWeight": "600"}}>
                            <span style={{"color": "#10b981"}}>{"● Energised (Normal)"}</span>
                            <span style={{"color": "#ef4444"}}>{"● Fault Interrupted"}</span>
                            <span style={{"color": "#f59e0b"}}>{"● Suspected Fuse"}</span>
                            <span style={{"color": "#38bdf8"}}>{"● Restored via Tie TS1"}</span>
                        </div>
                    </div>

                    {#* SVG Schematic Preview / Container *#}
                    <div
                        style={{
                            "flex": "1",
                            "minHeight": "420px",
                            "backgroundColor": "#090f1d",
                            "borderRadius": "8px",
                            "border": "1px solid rgba(255, 255, 255, 0.08)",
                            "position": "relative",
                            "overflow": "hidden",
                            "display": "flex",
                            "flexDirection": "column",
                            "justifyContent": "space-between",
                            "padding": "0.85rem"
                        }}
                    >
                        {#* Diagram Header & Zones overlay *#}
                        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "flex-start", "gap": "0.5rem"}}>
                            <div
                                style={{
                                    "padding": "0.35rem 0.65rem",
                                    "backgroundColor": "rgba(2, 132, 199, 0.12)",
                                    "border": "1px solid rgba(56, 189, 248, 0.3)",
                                    "borderRadius": "4px",
                                    "fontSize": "0.72rem",
                                    "color": "#93c5fd"
                                }}
                            >
                                <strong>{"AREA NORTH · Feeder 1 (310 Consumers · Hospital)"}</strong>
                                <div style={{"fontSize": "0.68rem", "color": "#60a5fa", "marginTop": "0.1rem"}}>
                                    {"SS1 → F1-A [SW1 Auto-Recloser] F1-B [SW2] F1-C · Transformers T1-T5"}
                                </div>
                            </div>

                            <div
                                style={{
                                    "padding": "0.35rem 0.65rem",
                                    "display": "block" if len(hazard_faults) > 0 else "none",
                                    "backgroundColor": "rgba(220, 38, 38, 0.18)",
                                    "border": "1px solid #ef4444",
                                    "borderRadius": "4px",
                                    "fontSize": "0.72rem",
                                    "color": "#fca5a5"
                                }}
                            >
                                <strong>{f"⚠️ PUBLIC SAFETY HAZARD: {hazard_faults[0].hazard_label.upper()} AT {hazard_faults[0].device_id}" if len(hazard_faults) > 0 else ""}</strong>
                                <div style={{"fontSize": "0.68rem", "marginTop": "0.1rem"}}>
                                    {f"{hazard_faults[0].kind_label} · {hazard_faults[0].homes_affected} homes · {hazard_faults[0].status_label}" if len(hazard_faults) > 0 else ""}
                                </div>
                            </div>
                        </div>

                        {#* Schematic Visual representation: live from get_grid *#}
                        <div style={{"textAlign": "center", "padding": "0.25rem 0"}}>
                            <GridMap grid={grid} />
                        </div>

                        {#* Feeder 2 Zone footer *#}
                        <div
                            style={{
                                "padding": "0.35rem 0.65rem",
                                "backgroundColor": "rgba(16, 185, 129, 0.1)",
                                "border": "1px solid rgba(16, 185, 129, 0.3)",
                                "borderRadius": "4px",
                                "fontSize": "0.72rem",
                                "color": "#a7f3d0",
                                "display": "flex",
                                "justifyContent": "space-between"
                            }}
                        >
                            <span><strong>{"AREA SOUTH · Feeder 2 (290 Consumers · Water Pump):"}</strong>{" SS1 → F2-A [SW3] F2-B · Transformers T6-T10"}</span>
                            <span style={{"fontWeight": "700"}}>{"TS1 Inter-Feeder Tie Capacity: 700 Consumers Max"}</span>
                        </div>
                    </div>
                </main>

                {#* RIGHT ~30%: RANKED FAULTS, CREWS, ACTIONS *#}
                <aside
                    style={{
                        "flex": "3",
                        "display": "flex",
                        "flexDirection": "column",
                        "backgroundColor": "#0b1120",
                        "padding": "0.85rem",
                        "overflowY": "auto",
                        "gap": "0.75rem",
                        "minWidth": "320px"
                    }}
                >
                    {#* 1. Ranked Faults Panel (Incident Registry) *#}
                    <div
                        style={{
                            "backgroundColor": "#0f172a",
                            "borderRadius": "8px",
                            "padding": "0.85rem",
                            "border": "1px solid rgba(255, 255, 255, 0.08)"
                        }}
                    >
                        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "0.6rem"}}>
                            <div style={{"display": "flex", "alignItems": "center", "gap": "0.4rem"}}>
                                <span style={{"fontSize": "0.8rem", "color": "#f59e0b"}}>{"⚠️"}</span>
                                <h3 style={{"margin": "0", "fontSize": "0.82rem", "fontWeight": "700", "color": "#f8fafc", "letterSpacing": "0.04em", "textTransform": "uppercase"}}>
                                    {"Incident Queue (Ranked Faults)"}
                                </h3>
                            </div>
                            <span style={{"fontSize": "0.68rem", "color": "#94a3b8"}}>
                                {f"{len(faults)} identified"}
                            </span>
                        </div>

                        <div style={{"display": "flex", "flexDirection": "column", "gap": "0.45rem"}}>
                            {[
                                <div
                                    key={f.id}
                                    onClick={lambda { _sel["id"] = f.id; selected_fault_id = f.id; }}
                                    style={{
                                        "padding": "0.6rem 0.7rem",
                                        "borderRadius": "6px",
                                        "cursor": "pointer",
                                        "backgroundColor": "#172338" if selected_fault_id == f.id else "#10192e",
                                        "border": "1px solid " + ("#38bdf8" if selected_fault_id == f.id else "rgba(255, 255, 255, 0.06)")
                                    }}
                                >
                                    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "flex-start"}}>
                                        <div>
                                            <span style={{"fontWeight": "700", "fontSize": "0.82rem", "color": "#f8fafc"}}>
                                                {f"{f.id} · {f.kind_label} @ {f.device_id}"}
                                            </span>
                                            {f.street != "" and (
                                                <span style={{"fontSize": "0.72rem", "color": "#94a3b8", "marginLeft": "0.3rem"}}>
                                                    {f"({f.street})"}
                                                </span>
                                            )}
                                        </div>
                                        <span
                                            style={{
                                                "fontSize": "0.68rem",
                                                "fontWeight": "800",
                                                "padding": "0.15rem 0.35rem",
                                                "borderRadius": "3px",
                                                "backgroundColor": "#0284c7",
                                                "color": "white"
                                            }}
                                        >
                                            {f"P:{f.priority}"}
                                        </span>
                                    </div>

                                    <div style={{"display": "flex", "gap": "0.3rem", "marginTop": "0.35rem", "flexWrap": "wrap"}}>
                                        {f.hazard_label != "" and (
                                            <span style={{"fontSize": "0.65rem", "padding": "0.1rem 0.35rem", "borderRadius": "3px", "backgroundColor": "rgba(220, 38, 38, 0.25)", "border": "1px solid #ef4444", "color": "#fca5a5", "fontWeight": "700"}}>
                                                {f"⚠️ {f.hazard_label}"}
                                            </span>
                                        )}
                                        {len(f.critical_loads) > 0 and (
                                            <span style={{"fontSize": "0.65rem", "padding": "0.1rem 0.35rem", "borderRadius": "3px", "backgroundColor": "rgba(168, 85, 247, 0.25)", "border": "1px solid #a855f7", "color": "#e9d5ff", "fontWeight": "700"}}>
                                                {f"🏥 {f.critical_loads[0]}"}
                                            </span>
                                        )}
                                        <span style={{"fontSize": "0.65rem", "padding": "0.1rem 0.35rem", "borderRadius": "3px", "backgroundColor": "#1e293b", "color": "#94a3b8"}}>
                                            {f"{f.homes_affected} consumers"}
                                        </span>
                                        <span style={{"fontSize": "0.65rem", "padding": "0.1rem 0.35rem", "borderRadius": "3px", "backgroundColor": "rgba(16, 185, 129, 0.15)", "color": "#86efac", "fontWeight": "600"}}>
                                            {f.status_label}
                                        </span>
                                        {f.updated_by_crew and (
                                            <span style={{"fontSize": "0.65rem", "padding": "0.1rem 0.35rem", "borderRadius": "3px", "backgroundColor": "rgba(217, 119, 6, 0.25)", "border": "1px solid #d97706", "color": "#fef08a", "fontWeight": "700"}}>
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
                    "backgroundColor": "#090d16",
                    "borderTop": "1px solid rgba(255, 255, 255, 0.08)",
                    "height": "190px",
                    "overflow": "hidden"
                }}
            >
                {#* Left 60%: Live SCADA Dispatch Stream *#}
                <div
                    style={{
                        "flex": "6",
                        "padding": "0.75rem 1rem",
                        "borderRight": "1px solid rgba(255, 255, 255, 0.08)",
                        "overflowY": "auto"
                    }}
                >
                    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "0.4rem"}}>
                        <span style={{"fontSize": "0.72rem", "fontWeight": "700", "color": "#94a3b8", "letterSpacing": "0.05em", "textTransform": "uppercase"}}>
                            {"Operational Telemetry & Event Audit Trail"}
                        </span>
                        <span style={{"fontSize": "0.68rem", "color": "#64748b"}}>
                            {"Real-time UTC+05:30"}
                        </span>
                    </div>
                    <div style={{"display": "flex", "flexDirection": "column", "gap": "0.25rem"}}>
                        {[
                            <div key={idx} style={{"fontSize": "0.72rem", "color": "#cbd5e1", "fontFamily": "'JetBrains Mono', monospace", "display": "flex", "alignItems": "center", "gap": "0.5rem"}}>
                                <span style={{"color": "#38bdf8", "fontWeight": "600"}}>{f"[{e.time_min:.1f}m]"}</span>
                                <span
                                    style={{
                                        "color": "#f59e0b" if e.kind == "hazard" else ("#10b981" if e.kind == "restored" else "#94a3b8"),
                                        "fontWeight": "600"
                                    }}
                                >
                                    {f"<{e.kind.upper()}>"}
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
                        "padding": "0.75rem 1rem",
                        "display": "flex",
                        "flexDirection": "column",
                        "justifyContent": "space-between",
                        "overflowY": "auto"
                    }}
                >
                    {#* Why Reasoning *#}
                    <div style={{"marginBottom": "0.4rem"}}>
                        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "0.2rem"}}>
                            <span style={{"fontSize": "0.72rem", "fontWeight": "700", "color": "#38bdf8", "letterSpacing": "0.04em", "textTransform": "uppercase"}}>
                                {"Incident Diagnostics (Why?)"}
                            </span>
                            <span style={{"fontSize": "0.7rem", "color": "#94a3b8"}}>
                                {f"Active Target: {selected_fault_id if selected_fault_id != '' else 'None'}"}
                            </span>
                        </div>
                        {for sf in selected_faults {
                            <div key={sf.id} style={{"fontSize": "0.72rem", "color": "#cbd5e1", "marginTop": "0.2rem"}}>
                                <div style={{"color": "#f8fafc", "fontWeight": "700"}}>
                                    {f"{sf.kind_label} @ {sf.device_id} · {sf.homes_affected} consumers · confidence {sf.confidence:.1f} · priority {sf.priority}"}
                                </div>
                                {sf.street and <div style={{"color": "#94a3b8"}}>{"Street: " + sf.street}</div>}
                                {sf.change_note and <div style={{"color": "#fbbf24", "fontWeight": "600"}}>{"Updated by crew report: " + sf.change_note}</div>}
                                {why_text and why_id == sf.id and <div style={{"fontStyle": "italic", "color": "#38bdf8", "marginTop": "0.15rem"}}>{why_text}</div>}
                                {for (k, ev) in enumerate(sf.evidence) {
                                    <div key={str(k)} style={{"color": "#94a3b8", "marginTop": "0.1rem"}}>{"• " + ev}</div>
                                }}
                            </div>
                        }}
                    </div>

                    {#* Crew Report Input *#}
                    <div>
                        <div style={{"display": "flex", "gap": "0.4rem", "marginBottom": "0.3rem"}}>
                            <select
                                value={selected_crew_id}
                                onChange={lambda e: ChangeEvent { selected_crew_id = e.target.value; }}
                                style={{
                                    "backgroundColor": "#10192e",
                                    "color": "#f8fafc",
                                    "border": "1px solid rgba(255, 255, 255, 0.15)",
                                    "borderRadius": "4px",
                                    "fontSize": "0.72rem",
                                    "padding": "0.25rem"
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
                                    "backgroundColor": "#10192e",
                                    "color": "#f8fafc",
                                    "border": "1px solid rgba(255, 255, 255, 0.15)",
                                    "borderRadius": "4px",
                                    "fontSize": "0.72rem",
                                    "padding": "0.25rem 0.5rem"
                                }}
                            />

                            <button
                                type="button"
                                onClick={handleSubmitCrewReport}
                                style={{
                                    "backgroundColor": "#0284c7",
                                    "color": "white",
                                    "border": "none",
                                    "borderRadius": "4px",
                                    "fontSize": "0.72rem",
                                    "padding": "0.25rem 0.65rem",
                                    "fontWeight": "700",
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
                                    "padding": "0.15rem 0.4rem",
                                    "backgroundColor": "#1e293b",
                                    "color": "#cbd5e1",
                                    "border": "1px solid rgba(255, 255, 255, 0.08)",
                                    "borderRadius": "3px",
                                    "cursor": "pointer",
                                    "fontWeight": "600"
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
                                    "padding": "0.15rem 0.4rem",
                                    "backgroundColor": "#1e293b",
                                    "color": "#cbd5e1",
                                    "border": "1px solid rgba(255, 255, 255, 0.08)",
                                    "borderRadius": "3px",
                                    "cursor": "pointer",
                                    "fontWeight": "600"
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
                        "backgroundColor": "#0b1120",
                        "border": "1px solid rgba(56, 189, 248, 0.4)",
                        "borderRadius": "8px",
                        "boxShadow": "0 10px 25px -5px rgba(0, 0, 0, 0.8)",
                        "padding": "0.45rem 0.75rem",
                        "display": "flex",
                        "alignItems": "center",
                        "gap": "0.5rem"
                    }}
                >
                    <div style={{"display": "flex", "alignItems": "center", "gap": "0.35rem"}}>
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
                            "backgroundColor": "#0284c7",
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
                            "backgroundColor": "#1e293b",
                            "color": "#38bdf8",
                            "border": "1px solid rgba(56, 189, 248, 0.4)",
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
                        "backgroundColor": "#0b1120",
                        "border": "1px solid rgba(56, 189, 248, 0.4)",
                        "borderRadius": "10px",
                        "boxShadow": "0 20px 45px rgba(0, 0, 0, 0.85)",
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
                            "backgroundColor": "#10192e",
                            "borderBottom": "1px solid rgba(255, 255, 255, 0.08)"
                        }}
                    >
                        <div style={{"display": "flex", "alignItems": "center", "gap": "0.4rem"}}>
                            <span style={{"color": "#38bdf8", "fontSize": "1rem"}}>{"⚡"}</span>
                            <div>
                                <div style={{"fontWeight": "800", "fontSize": "0.85rem", "color": "#f8fafc", "letterSpacing": "0.03em"}}>
                                    {"Simulation Engine"}
                                </div>
                                <div style={{"fontSize": "0.68rem", "color": "#94a3b8"}}>
                                    {"Contingency Drill & Scenario Injection"}
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
                                    "backgroundColor": "#1e293b",
                                    "color": "#e2e8f0",
                                    "border": "none",
                                    "borderRadius": "4px",
                                    "fontSize": "0.72rem",
                                    "fontWeight": "600",
                                    "cursor": "pointer"
                                }}
                            >
                                {"— Minimize"}
                            </button>
                        </div>
                    </div>

                    {#* Popup Body *#}
                    <div style={{"padding": "1rem", "display": "flex", "flexDirection": "column", "gap": "0.85rem"}}>
                        {#* Status & Clock *#}
                        <div
                            style={{
                                "display": "flex",
                                "justifyContent": "space-between",
                                "alignItems": "center",
                                "padding": "0.55rem 0.75rem",
                                "backgroundColor": "#131d31",
                                "borderRadius": "6px",
                                "border": "1px solid rgba(255, 255, 255, 0.08)"
                            }}
                        >
                            <div>
                                <div style={{"fontSize": "0.65rem", "color": "#94a3b8", "textTransform": "uppercase", "letterSpacing": "0.05em", "fontWeight": "600"}}>
                                    {"Simulation Clock"}
                                </div>
                                <div style={{"fontSize": "1.2rem", "fontWeight": "800", "color": "#38bdf8", "fontFamily": "'JetBrains Mono', monospace"}}>
                                    {f"{clock_min:.1f} min"}
                                </div>
                            </div>
                            <span
                                style={{
                                    "fontSize": "0.72rem",
                                    "padding": "0.25rem 0.55rem",
                                    "borderRadius": "4px",
                                    "backgroundColor": "rgba(16, 185, 129, 0.15)" if running else "rgba(100, 116, 139, 0.2)",
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
                                            "fontSize": "0.78rem",
                                            "borderRadius": "5px",
                                            "border": "1px solid " + ("#38bdf8" if speed == s else "rgba(255, 255, 255, 0.08)"),
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

                        {#* Optional hidden second fault (F5) *#}
                        <label style={{"display": "flex", "alignItems": "center", "gap": "0.4rem", "fontSize": "0.72rem", "color": "#94a3b8", "margin": "0.35rem 0", "cursor": "pointer"}}>
                            <input
                                type="checkbox"
                                checked={f5_on}
                                onChange={lambda e: ChangeEvent { f5_on = e.target.checked; }}
                            />
                            {"Hide a second fault (T4 fuse) behind F1 for the verifier"}
                        </label>

                        {#* Primary Action Buttons *#}
                        <div style={{"display": "flex", "gap": "0.5rem"}}>
                            <button
                                type="button"
                                onClick={handleStartStorm}
                                style={{
                                    "flex": "1",
                                    "padding": "0.55rem",
                                    "backgroundColor": "#ea580c" if running else "#059669",
                                    "color": "white",
                                    "border": "none",
                                    "borderRadius": "6px",
                                    "fontSize": "0.82rem",
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
                                    "backgroundColor": "#0284c7",
                                    "color": "white",
                                    "border": "none",
                                    "borderRadius": "6px",
                                    "fontSize": "0.82rem",
                                    "fontWeight": "700",
                                    "cursor": "pointer"
                                }}
                            >
                                {"⏭ Step Tick"}
                            </button>
                        </div>

                        <button
                            type="button"
                            onClick={handleStartBlackout}
                            style={{
                                "width": "100%",
                                "padding": "0.45rem",
                                "backgroundColor": "#7c2d12",
                                "color": "white",
                                "border": "none",
                                "borderRadius": "6px",
                                "fontSize": "0.8rem",
                                "fontWeight": "700",
                                "cursor": "pointer"
                            }}
                        >
                            {"⚡ Start Blackout (transmission line trip)"}
                        </button>

                        {#* Reset Button *#}
                        <button
                            type="button"
                            onClick={handleReset}
                            style={{
                                "width": "100%",
                                "padding": "0.45rem",
                                "backgroundColor": "rgba(239, 68, 68, 0.1)",
                                "color": "#f87171",
                                "border": "1px solid rgba(239, 68, 68, 0.35)",
                                "borderRadius": "6px",
                                "fontSize": "0.75rem",
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
