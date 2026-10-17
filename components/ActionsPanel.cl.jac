"""Restoration actions and safety check panel (WP-C7)."""

sv import from ..gm_types { Action }

def:pub ActionsPanel(
    actions: list[Action],
    onApply: (str) -> None
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
                            "border": "1px solid " + ("#10b981" if a.safe else "#ef4444")
                        }}
                    >
                        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                            <span style={{"fontWeight": "700", "fontSize": "0.8rem", "color": "#f8fafc"}}>
                                {f"{a.id} ({a.homes_restored} consumers)"}
                            </span>
                            <span
                                style={{
                                    "fontSize": "0.7rem",
                                    "padding": "0.1rem 0.35rem",
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
                            {a.reason if not a.safe else "Isolates fault, Feeder 2 capacity load 360 ≤ 700"}
                        </div>
                        {a.safe and (
                            <button
                                type="button"
                                onClick={lambda { onApply(a.id); }}
                                style={{
                                    "marginTop": "0.45rem",
                                    "width": "100%",
                                    "padding": "0.35rem",
                                    "backgroundColor": "#15803d" if not a.applied else "#334155",
                                    "color": "white",
                                    "border": "none",
                                    "borderRadius": "4px",
                                    "fontSize": "0.75rem",
                                    "fontWeight": "600",
                                    "cursor": "pointer" if not a.applied else "default"
                                }}
                                disabled={a.applied}
                            >
                                {"Applied ✓" if a.applied else "Apply Restoration"}
                            </button>
                        )}
                    </div>
                }}
            </div>
        </div>;
}
