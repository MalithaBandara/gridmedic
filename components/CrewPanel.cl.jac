"""Crew dispatch and status panel (WP-C4)."""

sv import from ..gm_types { Crew }

def:pub CrewPanel(crews: list[Crew]) -> JsxElement {
    return
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
                    {"Field Crews & Dispatch"}
                </h3>
                <span style={{"fontSize": "0.72rem", "color": "#94a3b8"}}>
                    {"Autonomous Dispatcher active"}
                </span>
            </div>
            <div style={{"display": "flex", "flexDirection": "column", "gap": "0.4rem"}}>
                {for c in crews {
                    <div
                        key={c.id}
                        style={{
                            "padding": "0.5rem 0.65rem",
                            "backgroundColor": "#0f172a",
                            "borderRadius": "6px",
                            "border": "1px solid " + ("#3b82f6" if c.status_label == "Travelling" else ("#10b981" if c.status_label == "On site" else "#1e293b")),
                            "display": "flex",
                            "justifyContent": "space-between",
                            "alignItems": "center"
                        }}
                    >
                        <div>
                            <div style={{"fontWeight": "600", "fontSize": "0.85rem", "color": "#f1f5f9"}}>
                                {c.name or c.id}
                            </div>
                            <div style={{"fontSize": "0.72rem", "color": "#94a3b8"}}>
                                {"Depot: " + c.depot_id + " · Loc: " + c.location_id}
                            </div>
                        </div>
                        <div style={{"textAlign": "right"}}>
                            <span
                                style={{
                                    "fontSize": "0.7rem",
                                    "fontWeight": "600",
                                    "padding": "0.15rem 0.4rem",
                                    "borderRadius": "4px",
                                    "backgroundColor": "#3b82f6" if c.status_label == "Travelling" else ("#10b981" if c.status_label == "On site" else "#64748b"),
                                    "color": "white"
                                }}
                            >
                                {c.status_label}
                            </span>
                            {c.task_fault_id and (
                                <div style={{"fontSize": "0.7rem", "color": "#38bdf8", "marginTop": "0.15rem", "fontWeight": "500"}}>
                                    {c.task_fault_id + (" (ETA " + str(c.eta_min) + "m)" if c.eta_min > 0 else " (Arrived)")}
                                </div>
                            )}
                        </div>
                    </div>
                }}
            </div>
        </div>;
}
