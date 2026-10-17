"""GridMedic Customer Outage Portal."""

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
                "backgroundColor": "#0f172a",
                "color": "#f8fafc",
                "fontFamily": "system-ui, -apple-system, sans-serif",
                "padding": "2rem 1rem"
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
                        "borderBottom": "1px solid #334155"
                    }}
                >
                    <div>
                        <h1 style={{"margin": "0", "fontSize": "1.75rem", "color": "#38bdf8"}}>
                            GridMedic Customer Portal
                        </h1>
                        <p style={{"margin": "0.25rem 0 0 0", "color": "#94a3b8", "fontSize": "0.9rem"}}>
                            Ceylon Electricity Board · Outage Reporting & Verification
                        </p>
                    </div>
                    <Link
                        to="/"
                        style={{
                            "color": "#38bdf8",
                            "textDecoration": "none",
                            "padding": "0.5rem 1rem",
                            "borderRadius": "6px",
                            "backgroundColor": "#1e293b",
                            "border": "1px solid #334155",
                            "fontSize": "0.875rem"
                        }}
                    >
                        {"← Back to Control Room"}
                    </Link>
                </div>

                {#* Outage Status Check *#}
                <div
                    style={{
                        "backgroundColor": "#1e293b",
                        "borderRadius": "8px",
                        "padding": "1.5rem",
                        "marginBottom": "1.5rem",
                        "border": "1px solid #334155"
                    }}
                >
                    <h2 style={{"margin": "0 0 1rem 0", "fontSize": "1.25rem", "color": "#f8fafc"}}>
                        {"Check Power Status"}
                    </h2>
                    <div style={{"display": "flex", "gap": "0.75rem", "marginBottom": "1rem"}}>
                        <input
                            type="text"
                            value={consumer_input}
                            onChange={lambda e: ChangeEvent { consumer_input = e.target.value; }}
                            placeholder="Enter 10-digit Consumer No (e.g. 4512300017)"
                            style={{
                                "flex": "1",
                                "padding": "0.6rem 0.8rem",
                                "borderRadius": "6px",
                                "border": "1px solid #475569",
                                "backgroundColor": "#0f172a",
                                "color": "#f8fafc",
                                "fontSize": "0.95rem"
                            }}
                        />
                        <button
                            type="button"
                            onClick={checkStatus}
                            style={{
                                "padding": "0.6rem 1.25rem",
                                "backgroundColor": "#2563eb",
                                "color": "white",
                                "border": "none",
                                "borderRadius": "6px",
                                "cursor": "pointer",
                                "fontWeight": "bold"
                            }}
                        >
                            {"Check Status"}
                        </button>
                    </div>

                    {status_info and (
                        <div
                            style={{
                                "padding": "1rem",
                                "borderRadius": "6px",
                                "backgroundColor": "#0f172a",
                                "border": "1px solid " + ("#10b981" if status_info.has_power else "#ef4444")
                            }}
                        >
                            <div style={{"display": "flex", "alignItems": "center", "gap": "0.5rem", "marginBottom": "0.5rem"}}>
                                <span style={{"fontSize": "1.2rem"}}>
                                    {"⚡" if status_info.has_power else "⚠️"}
                                </span>
                                <strong>
                                    {"Power Active" if status_info.has_power else "Outage Detected"}
                                </strong>
                            </div>
                            <p style={{"margin": "0.25rem 0", "color": "#cbd5e1"}}>
                                {status_info.status_text}
                            </p>
                            {status_info.eta_min > 0 and (
                                <p style={{"margin": "0.25rem 0", "color": "#f59e0b", "fontSize": "0.85rem"}}>
                                    {f"Estimated Restoration: ~{status_info.eta_min} minutes"}
                                </p>
                            )}
                        </div>
                    )}
                </div>

                {#* Report Outage Form *#}
                <div
                    style={{
                        "backgroundColor": "#1e293b",
                        "borderRadius": "8px",
                        "padding": "1.5rem",
                        "marginBottom": "1.5rem",
                        "border": "1px solid #334155"
                    }}
                >
                    <h2 style={{"margin": "0 0 1rem 0", "fontSize": "1.25rem", "color": "#f8fafc"}}>
                        {"Report an Outage or Hazard"}
                    </h2>
                    <p style={{"margin": "0 0 1rem 0", "color": "#94a3b8", "fontSize": "0.85rem"}}>
                        {"Support for English & Sinhala (සිංහල). Mention landmarks, pole numbers, or hazards like sparks."}
                    </p>
                    <div style={{"marginBottom": "1rem"}}>
                        <textarea
                            value={report_text}
                            onChange={lambda e: ChangeEvent { report_text = e.target.value; }}
                            placeholder="Describe the issue (e.g., 'Wire fallen on the road near pole 23, sparks!' or 'විදුලිය නැහැ')"
                            rows={3}
                            style={{
                                "width": "100%",
                                "boxSizing": "border-box",
                                "padding": "0.6rem 0.8rem",
                                "borderRadius": "6px",
                                "border": "1px solid #475569",
                                "backgroundColor": "#0f172a",
                                "color": "#f8fafc",
                                "fontSize": "0.95rem"
                            }}
                        />
                    </div>
                    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                        <button
                            type="button"
                            onClick={sendComplaint}
                            style={{
                                "padding": "0.6rem 1.25rem",
                                "backgroundColor": "#16a34a",
                                "color": "white",
                                "border": "none",
                                "borderRadius": "6px",
                                "cursor": "pointer",
                                "fontWeight": "bold"
                            }}
                        >
                            {"Submit Report"}
                        </button>
                        {complaint_submitted and (
                            <span style={{"color": "#10b981", "fontSize": "0.9rem"}}>
                                {"✓ Report received and dispatched to AI triage."}
                            </span>
                        )}
                    </div>
                </div>

                {#* Simulated SMS Updates Panel *#}
                <div
                    style={{
                        "backgroundColor": "#1e293b",
                        "borderRadius": "8px",
                        "padding": "1.5rem",
                        "border": "1px solid #334155"
                    }}
                >
                    <h2 style={{"margin": "0 0 0.5rem 0", "fontSize": "1.25rem", "color": "#f8fafc"}}>
                        {"Simulated SMS Alerts (1987 / CEBCare)"}
                    </h2>
                    <p style={{"margin": "0 0 1rem 0", "color": "#94a3b8", "fontSize": "0.8rem"}}>
                        {"In production, these notifications are sent directly to customer phones upon status changes."}
                    </p>
                    <div style={{"display": "flex", "flexDirection": "column", "gap": "0.5rem"}}>
                        {[
                            <div
                                key={idx}
                                style={{
                                    "padding": "0.75rem",
                                    "borderRadius": "6px",
                                    "backgroundColor": "#0f172a",
                                    "border": "1px solid #334155",
                                    "fontSize": "0.85rem",
                                    "color": "#e2e8f0"
                                }}
                            >
                                <span style={{"color": "#38bdf8", "fontWeight": "bold", "marginRight": "0.5rem"}}>
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
