"""Restoration actions and safety check panel (WP-C7) - Government Command Center Theme."""

sv import from ..gm_types { Action }

def _status_bg(safe: bool) -> str {
    if safe {
        return "rgba(16, 185, 129, 0.15)";
    }
    return "rgba(239, 68, 68, 0.15)";
}

def _status_color(safe: bool) -> str {
    if safe {
        return "#34d399";
    }
    return "#f87171";
}

def _status_border(safe: bool) -> str {
    if safe {
        return "1px solid rgba(16, 185, 129, 0.4)";
    }
    return "1px solid rgba(239, 68, 68, 0.4)";
}

def _status_text(safe: bool) -> str {
    if safe {
        return "CLEAR TO ENERGISE";
    }
    return "SAFETY INTERLOCK: BLOCKED";
}

def:pub ActionsPanel(
    actions: list[Action],
    onApply: any
) -> JsxElement {
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
                    <span style={{"fontSize": "0.8rem", "color": "#10b981"}}>{"⎇"}</span>
                    <h3 style={{"margin": "0", "fontSize": "0.82rem", "fontWeight": "700", "color": "#f8fafc", "letterSpacing": "0.04em", "textTransform": "uppercase"}}>
                        {"Inter-Feeder Tie Schedules (TS1)"}
                    </h3>
                </div>
                <span style={{"fontSize": "0.68rem", "color": "#10b981", "fontWeight": "600", "letterSpacing": "0.02em"}}>
                    {"Safety Interlock Verified"}
                </span>
            </div>
            <div style={{"display": "flex", "flexDirection": "column", "gap": "0.45rem"}}>
                {for a in actions {
                    <div
                        key={a.id}
                        style={{
                            "padding": "0.6rem 0.75rem",
                            "borderRadius": "6px",
                            "backgroundColor": "#131d31",
                            "border": _status_border(a.safe)
                        }}
                    >
                        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                            <span style={{"fontWeight": "700", "fontSize": "0.82rem", "color": "#f8fafc"}}>
                                {a.id + " (" + str(a.homes_restored) + " consumers restored)"}
                            </span>
                            <span
                                style={{
                                    "fontSize": "0.66rem",
                                    "padding": "0.15rem 0.45rem",
                                    "borderRadius": "4px",
                                    "backgroundColor": _status_bg(a.safe),
                                    "color": _status_color(a.safe),
                                    "border": _status_border(a.safe),
                                    "fontWeight": "700",
                                    "letterSpacing": "0.04em"
                                }}
                            >
                                {_status_text(a.safe)}
                            </span>
                        </div>
                        <div style={{"fontSize": "0.72rem", "color": "#94a3b8", "marginTop": "0.3rem", "lineHeight": "1.35"}}>
                            {a.reason}
                        </div>
                        {a.safe and (
                            <button
                                type="button"
                                onClick={lambda { onApply(a.id); }}
                                style={{
                                    "marginTop": "0.5rem",
                                    "width": "100%",
                                    "padding": "0.45rem 0.75rem",
                                    "backgroundColor": "#059669",
                                    "color": "white",
                                    "border": "none",
                                    "borderRadius": "4px",
                                    "fontSize": "0.75rem",
                                    "fontWeight": "700",
                                    "letterSpacing": "0.03em",
                                    "cursor": "pointer"
                                }}
                            >
                                {"Execute Switching Schedule (Apply)"}
                            </button>
                        )}
                    </div>
                }}
            </div>
        </div>;
}
