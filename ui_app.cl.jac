"""GridMedic Operator Dashboard - Shell and UI Layout."""

import from "@jac/runtime" { Link }
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
        selected_crew_id: str = "CREW-A",
        crew_report_text: str = "",
        action_message: str = "";

    can with entry {
        loadInitial();
    }

    async def loadInitial -> None;
    async def handleStartStorm -> None;
    async def handleReset -> None;
    async def handleTick -> None;
    async def handleSubmitCrewReport -> None;
    async def handleApplyAction(action_id: str) -> None;

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
                            {"Moratuwa Grid Substation (SS1) · 600 Homes"}
                        </div>
                    </div>

                    <div
                        style={{
                            "display": "flex",
                            "alignItems": "center",
                            "gap": "0.35rem",
                            "backgroundColor": "#1e293b",
                            "padding": "0.4rem 0.75rem",
                            "borderRadius": "6px",
                            "border": "1px solid #334155"
                        }}
                    >
                        <span style={{"color": "#94a3b8", "fontSize": "0.75rem", "textTransform": "uppercase"}}>
                            {"Storm Clock:"}
                        </span>
                        <span style={{"fontWeight": "700", "color": "#38bdf8", "fontFamily": "monospace", "fontSize": "1.05rem"}}>
                            {f"{clock_min:.1f} min"}
                        </span>
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
                            {"Homes Off"}
                        </div>
                        <div style={{"fontSize": "1.1rem", "fontWeight": "700", "color": "#ef4444"}}>
                            {counters.homes_off if counters else 0}
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

                {#* Controls & Links *#}
                <div style={{"display": "flex", "alignItems": "center", "gap": "0.5rem"}}>
                    {#* Speed Buttons *#}
                    <div style={{"display": "flex", "backgroundColor": "#1e293b", "borderRadius": "6px", "padding": "2px"}}>
                        {[
                            <button
                                key={s}
                                type="button"
                                onClick={lambda { speed = s; }}
                                style={{
                                    "padding": "0.3rem 0.6rem",
                                    "fontSize": "0.75rem",
                                    "borderRadius": "4px",
                                    "border": "none",
                                    "cursor": "pointer",
                                    "fontWeight": "600",
                                    "backgroundColor": "#0284c7" if speed == s else "transparent",
                                    "color": "#ffffff" if speed == s else "#94a3b8"
                                }}
                            >
                                {f"{s}×"}
                            </button>
                            for s in [1, 5, 20]
                        ]}
                    </div>

                    <button
                        type="button"
                        onClick={handleStartStorm}
                        style={{
                            "padding": "0.4rem 0.8rem",
                            "backgroundColor": "#16a34a",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "6px",
                            "fontSize": "0.8rem",
                            "fontWeight": "600",
                            "cursor": "pointer"
                        }}
                    >
                        {"▶ Start Storm"}
                    </button>

                    <button
                        type="button"
                        onClick={handleTick}
                        style={{
                            "padding": "0.4rem 0.8rem",
                            "backgroundColor": "#2563eb",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "6px",
                            "fontSize": "0.8rem",
                            "fontWeight": "600",
                            "cursor": "pointer"
                        }}
                    >
                        {"Step Tick"}
                    </button>

                    <button
                        type="button"
                        onClick={handleReset}
                        style={{
                            "padding": "0.4rem 0.8rem",
                            "backgroundColor": "#334155",
                            "color": "#e2e8f0",
                            "border": "none",
                            "borderRadius": "6px",
                            "fontSize": "0.8rem",
                            "fontWeight": "600",
                            "cursor": "pointer"
                        }}
                    >
                        {"Reset"}
                    </button>

                    <Link
                        to="/customer"
                        style={{
                            "marginLeft": "0.5rem",
                            "padding": "0.4rem 0.75rem",
                            "backgroundColor": "#1e293b",
                            "border": "1px solid #38bdf8",
                            "color": "#38bdf8",
                            "borderRadius": "6px",
                            "textDecoration": "none",
                            "fontSize": "0.8rem",
                            "fontWeight": "600"
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
                                <strong>{"AREA NORTH (Feeder 1 — 310 Homes)"}</strong>
                                <div>{"SS1 → F1-A [SW1] F1-B [SW2] F1-C · T1, T2, T3 (Hospital), T4, T5"}</div>
                            </div>

                            <div
                                style={{
                                    "padding": "0.4rem 0.8rem",
                                    "backgroundColor": "rgba(220, 38, 38, 0.15)",
                                    "border": "1px solid #ef4444",
                                    "borderRadius": "6px",
                                    "fontSize": "0.75rem",
                                    "color": "#fca5a5"
                                }}
                            >
                                <strong>{"⚠️ HAZARD AT POLE 23 (F1-B)"}</strong>
                                <div>{"Line down on road · Sparks reported · SW1 Lockout"}</div>
                            </div>
                        </div>

                        {#* Schematic Visual representation *#}
                        <div style={{"textAlign": "center", "padding": "2rem 0"}}>
                            <svg width="100%" height="260" viewBox="0 0 900 260" style={{"display": "block", "margin": "0 auto"}}>
                                {#* Substation SS1 *#}
                                <rect x="30" y="90" width="90" height="70" rx="6" fill="#1e293b" stroke="#38bdf8" strokeWidth="2"/>
                                <text x="75" y="125" fill="#f8fafc" fontSize="12" fontWeight="bold" textAnchor="middle">{"SS1"}</text>
                                <text x="75" y="142" fill="#94a3b8" fontSize="9" textAnchor="middle">{"Substation"}</text>

                                {#* Feeder 1 Line (North) *#}
                                <line x1="120" y1="110" x2="260" y2="60" stroke="#10b981" strokeWidth="4"/>
                                <line x1="260" y1="60" x2="350" y2="60" stroke="#ef4444" strokeWidth="4" strokeDasharray="6,3"/>
                                <line x1="350" y1="60" x2="520" y2="60" stroke="#ef4444" strokeWidth="4"/>
                                <line x1="520" y1="60" x2="700" y2="60" stroke="#64748b" strokeWidth="4"/>

                                {#* Feeder 1 Nodes *#}
                                <circle cx="260" cy="60" r="14" fill="#1e293b" stroke="#10b981" strokeWidth="2"/>
                                <text x="260" y="64" fill="#f8fafc" fontSize="10" textAnchor="middle">{"F1-A"}</text>

                                <rect x="335" y="48" width="30" height="24" rx="4" fill="#ef4444" stroke="#fca5a5"/>
                                <text x="350" y="64" fill="#fff" fontSize="9" fontWeight="bold" textAnchor="middle">{"SW1"}</text>

                                <circle cx="435" cy="60" r="14" fill="#450a0a" stroke="#ef4444" strokeWidth="2"/>
                                <text x="435" y="64" fill="#fca5a5" fontSize="10" textAnchor="middle">{"F1-B"}</text>

                                <rect x="505" y="48" width="30" height="24" rx="4" fill="#334155" stroke="#94a3b8"/>
                                <text x="520" y="64" fill="#fff" fontSize="9" textAnchor="middle">{"SW2"}</text>

                                <circle cx="610" cy="60" r="14" fill="#1e293b" stroke="#64748b" strokeWidth="2"/>
                                <text x="610" y="64" fill="#94a3b8" fontSize="10" textAnchor="middle">{"F1-C"}</text>

                                {#* Feeder 2 Line (South) *#}
                                <line x1="120" y1="140" x2="260" y2="190" stroke="#10b981" strokeWidth="4"/>
                                <line x1="260" y1="190" x2="435" y2="190" stroke="#10b981" strokeWidth="4"/>
                                <line x1="435" y1="190" x2="610" y2="190" stroke="#10b981" strokeWidth="4"/>

                                {#* Feeder 2 Nodes *#}
                                <circle cx="260" cy="190" r="14" fill="#1e293b" stroke="#10b981" strokeWidth="2"/>
                                <text x="260" y="194" fill="#f8fafc" fontSize="10" textAnchor="middle">{"F2-A"}</text>

                                <rect x="335" y="178" width="30" height="24" rx="4" fill="#1e293b" stroke="#10b981"/>
                                <text x="350" y="194" fill="#10b981" fontSize="9" textAnchor="middle">{"SW3"}</text>

                                <circle cx="435" cy="190" r="14" fill="#1e293b" stroke="#10b981" strokeWidth="2"/>
                                <text x="435" y="194" fill="#f8fafc" fontSize="10" textAnchor="middle">{"F2-B"}</text>

                                {#* Tie Switch TS1 *#}
                                <line x1="610" y1="60" x2="720" y2="125" stroke="#38bdf8" strokeWidth="2" strokeDasharray="4,4"/>
                                <line x1="610" y1="190" x2="720" y2="125" stroke="#38bdf8" strokeWidth="2" strokeDasharray="4,4"/>
                                <rect x="705" y="113" width="30" height="24" rx="4" fill="#0f172a" stroke="#38bdf8" strokeDasharray="3,2"/>
                                <text x="720" y="129" fill="#38bdf8" fontSize="9" fontWeight="bold" textAnchor="middle">{"TS1"}</text>

                                {#* Key Annotations *#}
                                <text x="435" y="38" fill="#f87171" fontSize="11" fontWeight="bold" textAnchor="middle">{"⚠️ Pole 23 Down"}</text>
                                <text x="260" y="222" fill="#94a3b8" fontSize="9" textAnchor="middle">{"T6 (Pump) / T7"}</text>
                                <text x="435" y="222" fill="#94a3b8" fontSize="9" textAnchor="middle">{"T8 (Fuse) / T9 / T10"}</text>
                            </svg>
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
                            <span><strong>{"AREA SOUTH (Feeder 2 — 290 Homes):"}</strong>{" SS1 → F2-A [SW3] F2-B · T6 (Water Pump), T7, T8, T9, T10"}</span>
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
                                            {f"{f.homes_affected} homes"}
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

                    {#* 2. Crew Tasks Panel *#}
                    <div
                        style={{
                            "backgroundColor": "#1e293b",
                            "borderRadius": "8px",
                            "padding": "0.85rem",
                            "border": "1px solid #334155"
                        }}
                    >
                        <h3 style={{"margin": "0 0 0.5rem 0", "fontSize": "0.95rem", "color": "#f8fafc"}}>
                            {"Field Crews & Dispatch"}
                        </h3>
                        <div style={{"display": "flex", "flexDirection": "column", "gap": "0.4rem"}}>
                            {[
                                <div
                                    key={c.id}
                                    style={{
                                        "display": "flex",
                                        "justifyContent": "space-between",
                                        "alignItems": "center",
                                        "padding": "0.4rem 0.6rem",
                                        "backgroundColor": "#0f172a",
                                        "borderRadius": "6px",
                                        "fontSize": "0.8rem"
                                    }}
                                >
                                    <div>
                                        <span style={{"fontWeight": "700", "color": "#e2e8f0"}}>{c.name}</span>
                                        <span style={{"color": "#94a3b8", "marginLeft": "0.4rem"}}>
                                            {f"({c.depot_id})"}
                                        </span>
                                    </div>
                                    <div style={{"display": "flex", "alignItems": "center", "gap": "0.4rem"}}>
                                        <span style={{"color": "#38bdf8", "fontSize": "0.75rem"}}>
                                            {c.task_fault_id}
                                        </span>
                                        <span
                                            style={{
                                                "fontSize": "0.7rem",
                                                "padding": "0.15rem 0.35rem",
                                                "borderRadius": "3px",
                                                "backgroundColor": "#1e3a8a" if c.status_label == "Travelling" else "#14532d",
                                                "color": "white"
                                            }}
                                        >
                                            {c.status_label}
                                        </span>
                                    </div>
                                </div>
                                for c in crews
                            ]}
                        </div>
                    </div>

                    {#* 3. Restoration Plans & Safety Check *#}
                    <div
                        style={{
                            "backgroundColor": "#1e293b",
                            "borderRadius": "8px",
                            "padding": "0.85rem",
                            "border": "1px solid #334155"
                        }}
                    >
                        <h3 style={{"margin": "0 0 0.5rem 0", "fontSize": "0.95rem", "color": "#f8fafc"}}>
                            {"Restoration Actions (Tie TS1)"}
                        </h3>
                        <div style={{"display": "flex", "flexDirection": "column", "gap": "0.5rem"}}>
                            {[
                                <div
                                    key={a.id}
                                    style={{
                                        "padding": "0.5rem",
                                        "borderRadius": "6px",
                                        "backgroundColor": "#0f172a",
                                        "border": "1px solid " + ("#10b981" if a.safe else "#ef4444")
                                    }}
                                >
                                    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                                        <span style={{"fontWeight": "700", "fontSize": "0.8rem", "color": "#f8fafc"}}>
                                            {f"{a.id} ({a.homes_restored} homes)"}
                                        </span>
                                        <span
                                            style={{
                                                "fontSize": "0.7rem",
                                                "padding": "0.1rem 0.3rem",
                                                "borderRadius": "3px",
                                                "backgroundColor": "#14532d" if a.safe else "#7f1d1d",
                                                "color": "#86efac" if a.safe else "#fca5a5",
                                                "fontWeight": "bold"
                                            }}
                                        >
                                            {"SAFE" if a.safe else "BLOCKED"}
                                        </span>
                                    </div>
                                    <div style={{"fontSize": "0.75rem", "color": "#94a3b8", "marginTop": "0.25rem"}}>
                                        {a.reason}
                                    </div>
                                    {a.safe and (
                                        <button
                                            type="button"
                                            onClick={lambda { handleApplyAction(a.id); }}
                                            style={{
                                                "marginTop": "0.4rem",
                                                "width": "100%",
                                                "padding": "0.3rem",
                                                "backgroundColor": "#15803d",
                                                "color": "white",
                                                "border": "none",
                                                "borderRadius": "4px",
                                                "fontSize": "0.75rem",
                                                "fontWeight": "600",
                                                "cursor": "pointer"
                                            }}
                                        >
                                            {"Apply Restoration"}
                                        </button>
                                    )}
                                </div>
                                for a in actions
                            ]}
                        </div>
                    </div>
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
        </div>;
}
