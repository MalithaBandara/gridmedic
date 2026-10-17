"""Crew dispatch and status panel (WP-C4) - Minimalist Theme."""

sv import from ..gm_types { Crew }

def _crew_status_color(status: str) -> str {
    if status == "Travelling" {
        return "#38bdf8";
    }
    if status == "On site" {
        return "#10b981";
    }
    return "#94a3b8";
}

def:pub CrewPanel(crews: list[Crew]) -> JsxElement {
    return
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
                    {"Field Crews"}
                </h3>
                <span style={{"fontSize": "0.68rem", "color": "#64748b"}}>
                    {"Autonomous Dispatch"}
                </span>
            </div>
            <div style={{"display": "flex", "flexDirection": "column", "gap": "0.35rem"}}>
                {for c in crews {
                    <div
                        key={c.id}
                        style={{
                            "padding": "0.45rem 0.6rem",
                            "backgroundColor": "#131d31",
                            "borderRadius": "4px",
                            "border": "1px solid #1e293b",
                            "display": "flex",
                            "justifyContent": "space-between",
                            "alignItems": "center"
                        }}
                    >
                        <div>
                            <div style={{"fontWeight": "600", "fontSize": "0.78rem", "color": "#f1f5f9"}}>
                                {c.name or c.id}
                            </div>
                            <div style={{"fontSize": "0.68rem", "color": "#64748b", "marginTop": "0.1rem"}}>
                                {"Depot: " + c.depot_id + " · Sector: " + c.location_id}
                            </div>
                        </div>
                        <div style={{"textAlign": "right"}}>
                            <span
                                style={{
                                    "fontSize": "0.68rem",
                                    "fontWeight": "600",
                                    "color": _crew_status_color(c.status_label)
                                }}
                            >
                                {c.status_label}
                            </span>
                            {c.task_fault_id and (
                                <div style={{"fontSize": "0.68rem", "color": "#94a3b8", "marginTop": "0.15rem"}}>
                                    {c.task_fault_id + (" (ETA " + str(c.eta_min) + "m)" if c.eta_min > 0 else " (Arrived)")}
                                </div>
                            )}
                        </div>
                    </div>
                }}
            </div>
        </div>;
}
