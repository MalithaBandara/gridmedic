"""gridmedic - Entry Point.

Combines server-side API endpoints with the client-side UI router.
"""

import from api {
    get_grid,
    start_storm,
    tick,
    submit_complaint,
    get_complaints,
    get_faults,
    get_crews,
    get_tasks,
    crew_report,
    get_actions,
    apply_action,
    get_events,
    get_status,
    reset
}

# Client-side UI & Routing
cl {
    import "./global.css";
    import from "@jac/runtime" { Router, Routes, Route, Navigate }
    import from .ui_app { OperatorApp }
    import from .ui_customer { CustomerApp }

    def:pub app -> JsxElement {
        return <Router>
            <Routes>
                <Route path="/" element={<OperatorApp />} />
                <Route path="/customer" element={<CustomerApp />} />
                <Route path="*" element={<Navigate to="/" replace={True} />} />
            </Routes>
        </Router>;
    }
}
