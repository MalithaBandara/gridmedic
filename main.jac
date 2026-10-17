"""gridmedic - Entry Point.

Combines server-side endpoints with the client-side UI.
"""

import from endpoints { Message, PostMessage, ListMessages }

# GridMedic API (walker:pub endpoints, contract owned by B). Importing them
# here registers them even before a .cl.jac file sv-imports them.
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

# Client-side UI
cl {
    import from .frontend { app as ClientApp }

    def:pub app -> JsxElement {
        return <ClientApp/>;
    }
}
