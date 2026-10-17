"""Crew dispatch and status panel (WP-C4) - Government Command Center Theme."""

sv import from ..gm_types { Crew }

def _crew_status_bg(status: str) -> str {
    if status == "Travelling" {
        return "rgba(2, 132, 199, 0.2)";
    }
    if status == "On site" {
        return "rgba(16, 185, 129, 0.2)";
    }
    return "rgba(100, 116, 139, 0.15)";
}

def _crew_status_color(status: str) -> str {
    if status == "Travelling" {
        return "#38bdf8";
    }
    if status == "On site" {
        return "#34d399";
    }
    return "#94a3b8";
}

def _crew_status_border(status: str) -> str {
    if status == "Travelling" {
        return "1px solid rgba(56, 189, 248, 0.4)";
    }
    if status == "On site" {
        return "1px solid rgba(52, 211, 153, 0.4)";
    }
    return "1px solid rgba(255, 255, 255, 0.08)";
}

def:pub CrewPanel(crews: list[Crew]) -> JsxElement {
    return
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
                    <span style={{"fontSize": "0.8rem", "color": "#38bdf8"}}>{"⛟"}</span>
                    <h3 style={{"margin": "0", "fontSize": "0.82rem", "fontWeight": "700", "color": "#f8fafc", "letterSpacing": "0.04em", "textTransform": "uppercase"}}>
                        {"Field Response Units"}
                    </h3>
                </div>
                <span style={{"fontSize": "0.68rem", "color": "#64748b", "letterSpacing": "0.02em"}}>
                    {"Autonomous Engine Active"}
                </span>
            </div>
            <div style={{"display": "flex", "flexDirection": "column", "gap": "0.45rem"}}>
                {for c in crews {
                    <div
                        key={c.id}
                        style={{
                            "padding": "0.55rem 0.7rem",
                            "backgroundColor": "#131d31",
                            "borderRadius": "6px",
                            "border": _crew_status_border(c.status_label),
                            "display": "flex",
                            "justifyContent": "space-between",
                            "alignItems": "center"
                        }}
                    >
                        <div>
                            <div style={{"fontWeight": "700", "fontSize": "0.82rem", "color": "#f1f5f9", "display": "flex", "alignItems": "center", "gap": "0.35rem"}}>
                                <span>{c.name or c.id}</span>
                            </div>
                            <div style={{"fontSize": "0.7rem", "color": "#94a3b8", "marginTop": "0.1rem"}}>
                                {"Depot: " + c.depot_id + " · Sector: " + c.location_id}
                            </div>
                        </div>
                        <div style={{"textAlign": "right"}}>
                            <span
                                style={{
                                    "fontSize": "0.68rem",
                                    "fontWeight": "700",
                                    "padding": "0.15rem 0.45rem",
                                    "borderRadius": "4px",
                                    "backgroundColor": _crew_status_bg(c.status_label),
                                    "color": _crew_status_color(c.status_label),
                                    "border": _crew_status_border(c.status_label),
                                    "letterSpacing": "0.03em",
                                    "textTransform": "uppercase"
                                }}
                            >
                                {c.status_label}
                            </span>
                            {c.task_fault_id and (
                                <div style={{"fontSize": "0.7rem", "color": "#38bdf8", "marginTop": "0.2rem", "fontWeight": "600"}}>
                                    {c.task_fault_id + (" (ETA " + str(c.eta_min) + "m)" if c.eta_min > 0 else " (Arrived)")}
                                </div>
                            )}
                        </div>
                    </div>
                }}
            </div>
        </div>;
}
