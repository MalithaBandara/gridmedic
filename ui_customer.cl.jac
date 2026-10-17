"""GridMedic Customer Outage Portal - Minimalist Public Service Theme."""

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
            "GridMedic Outage Advisory: High wind and storm activity detected in Moratuwa sector. Automated restoration active.",
            "GridMedic Advisory: If encountering fallen conductors or damaged infrastructure, maintain a safe distance and report immediately."
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
                "backgroundColor": "#090d16",
                "color": "#f8fafc",
                "fontFamily": "system-ui, -apple-system, sans-serif",
                "padding": "2rem 1.25rem"
            }}
        >
            <div
                style={{
                    "maxWidth": "800px",
                    "margin": "0 auto"
                }}
            >
                {#* Navigation Bar *#}
                <div
                    style={{
                        "display": "flex",
                        "justifyContent": "space-between",
                        "alignItems": "center",
                        "marginBottom": "2rem",
                        "paddingBottom": "1rem",
                        "borderBottom": "1px solid #1e293b",
                        "flexWrap": "wrap",
                        "gap": "1rem"
                    }}
                >
                    <div>
                        <h1 style={{"margin": "0", "fontSize": "1.5rem", "fontWeight": "800", "color": "#f8fafc", "letterSpacing": "-0.01em"}}>
                            {"GridMedic Customer Portal"}
                        </h1>
                        <p style={{"margin": "0.25rem 0 0 0", "color": "#64748b", "fontSize": "0.82rem"}}>
                            {"Public Outage Verification & Reporting · Moratuwa Sector"}
                        </p>
                    </div>
                    <Link
                        to="/"
                        style={{
                            "color": "#cbd5e1",
                            "textDecoration": "none",
                            "padding": "0.45rem 0.85rem",
                            "borderRadius": "5px",
                            "backgroundColor": "#0f172a",
                            "border": "1px solid #334155",
                            "fontSize": "0.8rem",
                            "fontWeight": "600"
                        }}
                    >
                        {"< Back to Control Room"}
                    </Link>
                </div>

                {#* Outage Status Check *#}
                <div
                    style={{
                        "backgroundColor": "#0f172a",
                        "borderRadius": "6px",
                        "padding": "1.25rem",
                        "marginBottom": "1.25rem",
                        "border": "1px solid #1e293b"
                    }}
                >
                    <h2 style={{"margin": "0 0 0.4rem 0", "fontSize": "1.05rem", "fontWeight": "700", "color": "#f8fafc"}}>
                        {"Check Power Status"}
                    </h2>
                    <p style={{"margin": "0 0 1rem 0", "color": "#64748b", "fontSize": "0.8rem"}}>
                        {"Enter your 10-digit electricity consumer account number."}
                    </p>

                    <div style={{"display": "flex", "gap": "0.6rem", "marginBottom": "1rem"}}>
                        <input
                            type="text"
                            value={consumer_input}
                            onChange={lambda e: ChangeEvent { consumer_input = e.target.value; }}
                            placeholder="Enter 10-digit Consumer No (e.g. 4512300017)"
                            style={{
                                "flex": "1",
                                "padding": "0.55rem 0.8rem",
                                "borderRadius": "5px",
                                "border": "1px solid #334155",
                                "backgroundColor": "#090d16",
                                "color": "#f8fafc",
                                "fontSize": "0.9rem",
                                "fontFamily": "monospace"
                            }}
                        />
                        <button
                            type="button"
                            onClick={checkStatus}
                            style={{
                                "padding": "0.55rem 1.1rem",
                                "backgroundColor": "#2563eb",
                                "color": "white",
                                "border": "none",
                                "borderRadius": "5px",
                                "cursor": "pointer",
                                "fontWeight": "600",
                                "fontSize": "0.82rem"
                            }}
                        >
                            {"Check Status"}
                        </button>
                    </div>

                    {status_info and (
                        <div
                            style={{
                                "padding": "0.9rem",
                                "borderRadius": "5px",
                                "backgroundColor": "#090d16",
                                "border": "1px solid " + ("rgba(16, 185, 129, 0.4)" if status_info.has_power else "rgba(239, 68, 68, 0.4)")
                            }}
                        >
                            <div style={{"display": "flex", "alignItems": "center", "justifyContent": "space-between", "marginBottom": "0.4rem"}}>
                                <div style={{"display": "flex", "alignItems": "center", "gap": "0.55rem"}}>
                                    <span
                                        style={{
                                            "display": "inline-block",
                                            "width": "8px",
                                            "height": "8px",
                                            "borderRadius": "50%",
                                            "backgroundColor": "#10b981" if status_info.has_power else "#ef4444"
                                        }}
                                    />
                                    <strong style={{"fontSize": "0.9rem", "color": "#f8fafc"}}>
                                        {"Power Normal" if status_info.has_power else "Outage Active"}
                                    </strong>
                                </div>
                                <span
                                    style={{
                                        "fontSize": "0.65rem",
                                        "padding": "0.1rem 0.4rem",
                                        "borderRadius": "3px",
                                        "backgroundColor": "#1e293b",
                                        "color": "#10b981" if status_info.has_power else "#ef4444",
                                        "fontWeight": "600"
                                    }}
                                >
                                    {"TELEMETRY"}
                                </span>
                            </div>
                            <p style={{"margin": "0.25rem 0", "color": "#cbd5e1", "fontSize": "0.82rem"}}>
                                {status_info.status_text}
                            </p>
                            {status_info.eta_min > 0 and (
                                <p style={{"margin": "0.25rem 0 0 0", "color": "#f59e0b", "fontSize": "0.8rem"}}>
                                    {f"Estimated Restoration: ~{status_info.eta_min} minutes"}
                                </p>
                            )}
                        </div>
                    )}
                </div>

                {#* Report Outage Form *#}
                <div
                    style={{
                        "backgroundColor": "#0f172a",
                        "borderRadius": "6px",
                        "padding": "1.25rem",
                        "marginBottom": "1.25rem",
                        "border": "1px solid #1e293b"
                    }}
                >
                    <h2 style={{"margin": "0 0 0.35rem 0", "fontSize": "1.05rem", "fontWeight": "700", "color": "#f8fafc"}}>
                        {"Report an Outage or Hazard"}
                    </h2>
                    <p style={{"margin": "0 0 0.85rem 0", "color": "#64748b", "fontSize": "0.8rem"}}>
                        {"Support for English & Sinhala (සිංහල). Mention landmarks, pole numbers, or hazards."}
                    </p>
                    <div style={{"marginBottom": "0.85rem"}}>
                        <textarea
                            value={report_text}
                            onChange={lambda e: ChangeEvent { report_text = e.target.value; }}
                            placeholder="Describe the issue (e.g., 'Wire fallen on the road near pole 23, sparks!' or 'විදුලිය නැහැ')"
                            rows={3}
                            style={{
                                "width": "100%",
                                "boxSizing": "border-box",
                                "padding": "0.55rem 0.75rem",
                                "borderRadius": "5px",
                                "border": "1px solid #334155",
                                "backgroundColor": "#090d16",
                                "color": "#f8fafc",
                                "fontSize": "0.88rem"
                            }}
                        />
                    </div>
                    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                        <button
                            type="button"
                            onClick={sendComplaint}
                            style={{
                                "padding": "0.5rem 1.1rem",
                                "backgroundColor": "#16a34a",
                                "color": "white",
                                "border": "none",
                                "borderRadius": "5px",
                                "cursor": "pointer",
                                "fontWeight": "600",
                                "fontSize": "0.82rem"
                            }}
                        >
                            {"Submit Report"}
                        </button>
                        {complaint_submitted and (
                            <span style={{"color": "#10b981", "fontSize": "0.82rem"}}>
                                {"Report received and logged."}
                            </span>
                        )}
                    </div>
                </div>

                {#* Automated Notifications Panel *#}
                <div
                    style={{
                        "backgroundColor": "#0f172a",
                        "borderRadius": "6px",
                        "padding": "1.25rem",
                        "border": "1px solid #1e293b"
                    }}
                >
                    <h2 style={{"margin": "0 0 0.35rem 0", "fontSize": "1.05rem", "fontWeight": "700", "color": "#f8fafc"}}>
                        {"Automated Outage Notifications"}
                    </h2>
                    <p style={{"margin": "0 0 0.85rem 0", "color": "#64748b", "fontSize": "0.78rem"}}>
                        {"Real-time consumer alerts and restoration notifications."}
                    </p>
                    <div style={{"display": "flex", "flexDirection": "column", "gap": "0.35rem"}}>
                        {[
                            <div
                                key={idx}
                                style={{
                                    "padding": "0.6rem 0.75rem",
                                    "borderRadius": "5px",
                                    "backgroundColor": "#090d16",
                                    "border": "1px solid #1e293b",
                                    "fontSize": "0.8rem",
                                    "color": "#cbd5e1"
                                }}
                            >
                                <span style={{"color": "#64748b", "marginRight": "0.4rem"}}>
                                    {"[SMS]"}
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
