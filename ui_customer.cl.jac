"""GridMedic Customer Outage Portal - Ceylon Electricity Board Official Public Service Theme."""

import from "@jac/runtime" { Link }
sv import from api { submit_complaint, get_status }
sv import from gm_types { CustomerStatus, Complaint }

def:pub CustomerApp -> JsxElement {
    has consumer_input: str = "4512300017",
        report_text: str = "",
        status_info: CustomerStatus | None = None,
        status_checked: bool = False,
        complaint_submitted: bool = False,
        sms_messages: list[str] = [
            "CEB Alert (1987): Heavy lightning and storm activity reported in Moratuwa area. Teams are monitoring.",
            "CEB Alert: If experiencing sparking wires or fallen poles, please keep clear and report immediately."
        ];

    can with entry {
        checkStatus();
    }

    async def checkStatus -> None;
    async def sendComplaint -> None;

    return
        <div
            style={{
                "minHeight": "100vh",
                "backgroundColor": "#060911",
                "color": "#f8fafc",
                "fontFamily": "'Inter', system-ui, -apple-system, sans-serif",
                "padding": "2rem 1.25rem"
            }}
        >
            <div
                style={{
                    "maxWidth": "860px",
                    "margin": "0 auto"
                }}
            >
                {#* Official Institutional Header *#}
                <div
                    style={{
                        "display": "flex",
                        "justifyContent": "space-between",
                        "alignItems": "center",
                        "marginBottom": "2rem",
                        "paddingBottom": "1.25rem",
                        "borderBottom": "1px solid rgba(255, 255, 255, 0.08)",
                        "flexWrap": "wrap",
                        "gap": "1rem"
                    }}
                >
                    <div style={{"display": "flex", "alignItems": "center", "gap": "0.85rem"}}>
                        <div
                            style={{
                                "width": "42px",
                                "height": "42px",
                                "borderRadius": "8px",
                                "backgroundColor": "#0b1120",
                                "border": "1px solid rgba(56, 189, 248, 0.4)",
                                "display": "flex",
                                "alignItems": "center",
                                "justifyContent": "center",
                                "fontSize": "1.3rem"
                            }}
                        >
                            {"🏛️"}
                        </div>
                        <div>
                            <div style={{"fontSize": "0.75rem", "fontWeight": "700", "color": "#fbbf24", "letterSpacing": "0.06em", "textTransform": "uppercase"}}>
                                {"ශ්‍රී ලංකා විදුලිබල මණ්ඩලය · CEYLON ELECTRICITY BOARD"}
                            </div>
                            <h1 style={{"margin": "0.15rem 0 0 0", "fontSize": "1.45rem", "fontWeight": "800", "color": "#f8fafc", "letterSpacing": "0.01em"}}>
                                {"Public Outage Verification & Reporting Service"}
                            </h1>
                            <p style={{"margin": "0.15rem 0 0 0", "color": "#94a3b8", "fontSize": "0.78rem"}}>
                                {"Official Consumer Inquiry Portal · Moratuwa Distribution Sector"}
                            </p>
                        </div>
                    </div>
                    <Link
                        to="/"
                        style={{
                            "color": "#38bdf8",
                            "textDecoration": "none",
                            "padding": "0.5rem 1rem",
                            "borderRadius": "6px",
                            "backgroundColor": "#0b1120",
                            "border": "1px solid rgba(56, 189, 248, 0.4)",
                            "fontSize": "0.82rem",
                            "fontWeight": "600",
                            "display": "flex",
                            "alignItems": "center",
                            "gap": "0.4rem"
                        }}
                    >
                        {"← National Control Room"}
                    </Link>
                </div>

                {#* Outage Status Check Card *#}
                <div
                    style={{
                        "backgroundColor": "#0b1120",
                        "borderRadius": "8px",
                        "padding": "1.5rem",
                        "marginBottom": "1.5rem",
                        "border": "1px solid rgba(255, 255, 255, 0.08)"
                    }}
                >
                    <div style={{"display": "flex", "alignItems": "center", "gap": "0.45rem", "marginBottom": "0.5rem"}}>
                        <span style={{"color": "#38bdf8", "fontSize": "0.95rem"}}>{"🔍"}</span>
                        <h2 style={{"margin": "0", "fontSize": "1.1rem", "fontWeight": "700", "color": "#f8fafc"}}>
                            {"Real-time Power Status Verification"}
                        </h2>
                    </div>
                    <p style={{"margin": "0 0 1.1rem 0", "color": "#94a3b8", "fontSize": "0.82rem"}}>
                        {"Enter your 10-digit electricity consumer account number printed on your CEB monthly bill."}
                    </p>

                    <div style={{"display": "flex", "gap": "0.75rem", "marginBottom": "1rem"}}>
                        <input
                            type="text"
                            value={consumer_input}
                            onChange={lambda e: ChangeEvent { consumer_input = e.target.value; }}
                            placeholder="Enter 10-digit Consumer No (e.g. 4512300017)"
                            style={{
                                "flex": "1",
                                "padding": "0.65rem 0.9rem",
                                "borderRadius": "6px",
                                "border": "1px solid rgba(255, 255, 255, 0.15)",
                                "backgroundColor": "#10192e",
                                "color": "#f8fafc",
                                "fontSize": "0.95rem",
                                "fontFamily": "'JetBrains Mono', monospace"
                            }}
                        />
                        <button
                            type="button"
                            onClick={checkStatus}
                            style={{
                                "padding": "0.65rem 1.4rem",
                                "backgroundColor": "#0284c7",
                                "color": "white",
                                "border": "none",
                                "borderRadius": "6px",
                                "cursor": "pointer",
                                "fontWeight": "700",
                                "fontSize": "0.88rem"
                            }}
                        >
                            {"Check Status"}
                        </button>
                    </div>

                    {status_info and (
                        <div
                            style={{
                                "padding": "1.1rem",
                                "borderRadius": "6px",
                                "backgroundColor": "#10192e",
                                "border": "1px solid " + ("rgba(16, 185, 129, 0.4)" if status_info.has_power else "rgba(239, 68, 68, 0.4)")
                            }}
                        >
                            <div style={{"display": "flex", "alignItems": "center", "justifyContent": "space-between", "marginBottom": "0.5rem"}}>
                                <div style={{"display": "flex", "alignItems": "center", "gap": "0.5rem"}}>
                                    <span style={{"fontSize": "1.1rem"}}>
                                        {"⚡" if status_info.has_power else "⚠️"}
                                    </span>
                                    <strong style={{"fontSize": "0.95rem", "color": "#f8fafc"}}>
                                        {"Power Supply Normal" if status_info.has_power else "Power Interruption Active"}
                                    </strong>
                                </div>
                                <span
                                    style={{
                                        "fontSize": "0.68rem",
                                        "padding": "0.15rem 0.45rem",
                                        "borderRadius": "3px",
                                        "backgroundColor": "rgba(16, 185, 129, 0.15)" if status_info.has_power else "rgba(239, 68, 68, 0.15)",
                                        "color": "#86efac" if status_info.has_power else "#fca5a5",
                                        "border": "1px solid " + ("#10b981" if status_info.has_power else "#ef4444"),
                                        "fontWeight": "700",
                                        "letterSpacing": "0.04em"
                                    }}
                                >
                                    {"ONLINE TELEMETRY"}
                                </span>
                            </div>
                            <p style={{"margin": "0.35rem 0", "color": "#cbd5e1", "fontSize": "0.85rem", "lineHeight": "1.4"}}>
                                {status_info.status_text}
                            </p>
                            {status_info.eta_min > 0 and (
                                <p style={{"margin": "0.35rem 0 0 0", "color": "#fbbf24", "fontSize": "0.82rem", "fontWeight": "600"}}>
                                    {f"Estimated Restoration Time: ~{status_info.eta_min} minutes (Crews actively dispatched)"}
                                </p>
                            )}
                        </div>
                    )}
                </div>

                {#* Report Outage Form *#}
                <div
                    style={{
                        "backgroundColor": "#0b1120",
                        "borderRadius": "8px",
                        "padding": "1.5rem",
                        "marginBottom": "1.5rem",
                        "border": "1px solid rgba(255, 255, 255, 0.08)"
                    }}
                >
                    <div style={{"display": "flex", "alignItems": "center", "gap": "0.45rem", "marginBottom": "0.4rem"}}>
                        <span style={{"color": "#ef4444", "fontSize": "0.95rem"}}>{"📢"}</span>
                        <h2 style={{"margin": "0", "fontSize": "1.1rem", "fontWeight": "700", "color": "#f8fafc"}}>
                            {"Report Outage or Electrical Hazard"}
                        </h2>
                    </div>
                    <p style={{"margin": "0 0 1rem 0", "color": "#94a3b8", "fontSize": "0.82rem"}}>
                        {"Support for English & Sinhala (සිංහල). Mention nearby landmarks, road names, pole numbers, or hazards like sparks."}
                    </p>
                    <div style={{"marginBottom": "1rem"}}>
                        <textarea
                            value={report_text}
                            onChange={lambda e: ChangeEvent { report_text = e.target.value; }}
                            placeholder="Describe the issue (e.g., 'Wire fallen on the road near pole 23, sparks!' or 'විදුලිය නැහැ - Lake Road')"
                            rows={3}
                            style={{
                                "width": "100%",
                                "boxSizing": "border-box",
                                "padding": "0.65rem 0.9rem",
                                "borderRadius": "6px",
                                "border": "1px solid rgba(255, 255, 255, 0.15)",
                                "backgroundColor": "#10192e",
                                "color": "#f8fafc",
                                "fontSize": "0.9rem",
                                "lineHeight": "1.4"
                            }}
                        />
                    </div>
                    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "flexWrap": "wrap", "gap": "0.5rem"}}>
                        <button
                            type="button"
                            onClick={sendComplaint}
                            style={{
                                "padding": "0.6rem 1.4rem",
                                "backgroundColor": "#059669",
                                "color": "white",
                                "border": "none",
                                "borderRadius": "6px",
                                "cursor": "pointer",
                                "fontWeight": "700",
                                "fontSize": "0.85rem"
                            }}
                        >
                            {"Submit Report to Dispatch"}
                        </button>
                        {complaint_submitted and (
                            <span style={{"color": "#34d399", "fontSize": "0.85rem", "fontWeight": "600"}}>
                                {"✓ Incident report logged into AI triage & dispatch queue."}
                            </span>
                        )}
                    </div>
                </div>

                {#* Simulated SMS Updates Panel *#}
                <div
                    style={{
                        "backgroundColor": "#0b1120",
                        "borderRadius": "8px",
                        "padding": "1.5rem",
                        "border": "1px solid rgba(255, 255, 255, 0.08)"
                    }}
                >
                    <div style={{"display": "flex", "alignItems": "center", "gap": "0.45rem", "marginBottom": "0.4rem"}}>
                        <span style={{"color": "#38bdf8", "fontSize": "0.95rem"}}>{"📱"}</span>
                        <h2 style={{"margin": "0", "fontSize": "1.1rem", "fontWeight": "700", "color": "#f8fafc"}}>
                            {"CEBCare / 1987 Emergency SMS Broadcast Stream"}
                        </h2>
                    </div>
                    <p style={{"margin": "0 0 1rem 0", "color": "#94a3b8", "fontSize": "0.78rem"}}>
                        {"In production, telemetry status changes trigger real-time SMS broadcasts to affected consumer phones."}
                    </p>
                    <div style={{"display": "flex", "flexDirection": "column", "gap": "0.45rem"}}>
                        {[
                            <div
                                key={idx}
                                style={{
                                    "padding": "0.75rem 0.9rem",
                                    "borderRadius": "6px",
                                    "backgroundColor": "#10192e",
                                    "border": "1px solid rgba(255, 255, 255, 0.06)",
                                    "fontSize": "0.82rem",
                                    "color": "#cbd5e1"
                                }}
                            >
                                <span style={{"color": "#38bdf8", "fontWeight": "700", "marginRight": "0.5rem"}}>
                                    {"[CEB-ALERT]"}
                                </span>
                                {msg}
                            </div>
                            for (idx, msg) in enumerate(sms_messages)
                        ]}
                    </div>
                </div>
            </div>
        </div>;
}
