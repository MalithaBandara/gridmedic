"""Restoration actions and safety check panel (WP-C7)."""

sv import from ..gm_types { Action }

def _status_bg(safe: bool) -> str {
    if safe {
        return "#14532d";
    }
    return "#7f1d1d";
}

def _status_color(safe: bool) -> str {
    if safe {
        return "#86efac";
    }
    return "#fca5a5";
}

def _status_border(safe: bool) -> str {
    if safe {
        return "1px solid #10b981";
    }
    return "1px solid #ef4444";
}

def _status_text(safe: bool) -> str {
    if safe {
        return "SAFE";
    }
    return "BLOCKED";
}

def:pub ActionsPanel(
    actions: list[Action],
    onApply: any
) -> JsxElement {
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
                    {"Restoration Actions (Tie TS1)"}
                </h3>
                <span style={{"fontSize": "0.72rem", "color": "#94a3b8"}}>
                    {"SafetyCheck Verified"}
                </span>
            </div>
            <div style={{"display": "flex", "flexDirection": "column", "gap": "0.5rem"}}>
                {for a in actions {
                    <div
                        key={a.id}
                        style={{
                            "padding": "0.5rem 0.65rem",
                            "borderRadius": "6px",
                            "backgroundColor": "#0f172a",
                            "border": _status_border(a.safe)
                        }}
                    >
                        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                            <span style={{"fontWeight": "700", "fontSize": "0.8rem", "color": "#f8fafc"}}>
                                {a.id + " (" + str(a.homes_restored) + " consumers)"}
                            </span>
                            <span
                                style={{
                                    "fontSize": "0.7rem",
                                    "padding": "0.1rem 0.35rem",
                                    "borderRadius": "3px",
                                    "backgroundColor": _status_bg(a.safe),
                                    "color": _status_color(a.safe),
                                    "fontWeight": "bold"
                                }}
                            >
                                {_status_text(a.safe)}
                            </span>
                        </div>
                        <div style={{"fontSize": "0.75rem", "color": "#94a3b8", "marginTop": "0.25rem"}}>
                            {a.reason}
                        </div>
                        {a.safe and (
                            <button
                                type="button"
                                onClick={lambda { onApply(a.id); }}
                                style={{
                                    "marginTop": "0.45rem",
                                    "width": "100%",
                                    "padding": "0.35rem",
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
                }}
            </div>
        </div>;
}
