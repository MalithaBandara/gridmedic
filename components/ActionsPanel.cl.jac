"""Restoration actions and safety check panel (WP-C7) - Minimalist Theme."""

sv import from ..gm_types { Action }

def _status_color(safe: bool) -> str {
    if safe {
        return "#10b981";
    }
    return "#ef4444";
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
                "backgroundColor": "#0f172a",
                "borderRadius": "6px",
                "padding": "0.75rem",
                "border": "1px solid #1e293b"
            }}
        >
            <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "0.5rem"}}>
                <h3 style={{"margin": "0", "fontSize": "0.78rem", "fontWeight": "600", "color": "#f8fafc", "letterSpacing": "0.03em", "textTransform": "uppercase"}}>
                    {"Tie Restoration (TS1)"}
                </h3>
                <span style={{"fontSize": "0.68rem", "color": "#64748b"}}>
                    {"Safety Verified"}
                </span>
            </div>
            <div style={{"display": "flex", "flexDirection": "column", "gap": "0.4rem"}}>
                {for a in actions {
                    <div
                        key={a.id}
                        style={{
                            "padding": "0.5rem 0.65rem",
                            "borderRadius": "4px",
                            "backgroundColor": "#131d31",
                            "border": "1px solid " + ("rgba(16, 185, 129, 0.3)" if a.safe else "rgba(239, 68, 68, 0.3)")
                        }}
                    >
                        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                            <span style={{"fontWeight": "600", "fontSize": "0.78rem", "color": "#f8fafc"}}>
                                {a.id + " (" + str(a.homes_restored) + " homes)"}
                            </span>
                            <span
                                style={{
                                    "fontSize": "0.68rem",
                                    "color": _status_color(a.safe),
                                    "fontWeight": "700"
                                }}
                            >
                                {_status_text(a.safe)}
                            </span>
                        </div>
                        <div style={{"fontSize": "0.7rem", "color": "#94a3b8", "marginTop": "0.2rem", "lineHeight": "1.3"}}>
                            {a.reason}
                        </div>
                        {a.safe and (
                            <button
                                type="button"
                                onClick={lambda { onApply(a.id); }}
                                style={{
                                    "marginTop": "0.4rem",
                                    "width": "100%",
                                    "padding": "0.35rem 0.6rem",
                                    "backgroundColor": "#059669",
                                    "color": "white",
                                    "border": "none",
                                    "borderRadius": "4px",
                                    "fontSize": "0.72rem",
                                    "fontWeight": "600",
                                    "cursor": "pointer"
                                }}
                            >
                                {"Apply Plan"}
                            </button>
                        )}
                    </div>
                }}
            </div>
        </div>;
}
