"""GridMedic API: every endpoint is a walker:pub, served as POST /walker/<name>.

Contract (owned by Person B): names, inputs and report types are frozen.
Spawn from the client on root and read `result.reports`:
  - list endpoints report one item per element (reports: list[T])
  - single-value endpoints report exactly one value (read reports[0])

Bodies return mock data from api_mock.jac until WP-B4 swaps them for real ones.
"""

import from gm_types {
    Complaint,
    Fault,
    Crew,
    CrewTask,
    Action,
    CustomerStatus,
    Event,
    GridView,
    Ack,
    ActionResult
}
import from api_mock {
    mock_grid,
    mock_faults,
    mock_crews,
    mock_tasks,
    mock_complaints,
    mock_events,
    mock_actions,
    mock_status,
    mock_ack,
    mock_crew_report,
    mock_apply,
    mock_submit
}

# Nodes, edges, clock and counters for the diagram. reports[0]
walker:pub get_grid {
    has reports: list[GridView] = [];

    can run with Root entry {
        report mock_grid();
    }
}

# Starts the storm; complaints are released by tick. reports[0]
walker:pub start_storm {
    has speed: int = 1,
        reports: list[Ack] = [];

    can run with Root entry {
        report mock_ack(f"Storm started at {self.speed}x");
    }
}

# Advances the simulated clock: releases complaints, parses, localises,
# groups, ranks, moves crews. reports[0]
walker:pub tick {
    has minutes: float = 0.5,
        reports: list[Ack] = [];

    can run with Root entry {
        report mock_ack(f"Advanced {self.minutes} min");
    }
}

# Customer/operator submits one complaint. reports[0]
walker:pub submit_complaint {
    has text: str = "",
        consumer_no: str = "",
        reports: list[Complaint] = [];

    can run with Root entry {
        report mock_submit(self.text, self.consumer_no);
    }
}

# Complaints with time_min >= since_min, oldest first. One report each.
walker:pub get_complaints {
    has since_min: float = 0.0,
        reports: list[Complaint] = [];

    can run with Root entry {
        for c in mock_complaints(self.since_min) {
            report c;
        }
    }
}

# Faults ranked by priority, highest first. One report each.
walker:pub get_faults {
    has reports: list[Fault] = [];

    can run with Root entry {
        for f in mock_faults() {
            report f;
        }
    }
}

# All crews. One report each.
walker:pub get_crews {
    has reports: list[Crew] = [];

    can run with Root entry {
        for c in mock_crews() {
            report c;
        }
    }
}

# Active crew tasks. One report each.
walker:pub get_tasks {
    has reports: list[CrewTask] = [];

    can run with Root entry {
        for t in mock_tasks() {
            report t;
        }
    }
}

# A field crew's free-text report; returns the fault after the update. reports[0]
walker:pub crew_report {
    has crew_id: str = "",
        text: str = "",
        reports: list[Fault] = [];

    can run with Root entry {
        report mock_crew_report(self.crew_id);
    }
}

# Restoration actions with their safety result. One report each.
walker:pub get_actions {
    has reports: list[Action] = [];

    can run with Root entry {
        for a in mock_actions() {
            report a;
        }
    }
}

# Applies a restoration action if it is safe. reports[0]
walker:pub apply_action {
    has action_id: str = "",
        reports: list[ActionResult] = [];

    can run with Root entry {
        report mock_apply(self.action_id);
    }
}

# Event log entries with time_min >= since_min, oldest first. One report each.
walker:pub get_events {
    has since_min: float = 0.0,
        reports: list[Event] = [];

    can run with Root entry {
        for e in mock_events(self.since_min) {
            report e;
        }
    }
}

# Customer page status lookup. reports[0]
walker:pub get_status {
    has consumer_no: str = "",
        reports: list[CustomerStatus] = [];

    can run with Root entry {
        report mock_status(self.consumer_no);
    }
}

# Restores the initial grid and clears the storm (keeps ParseCache). reports[0]
walker:pub reset {
    has reports: list[Ack] = [];

    can run with Root entry {
        report mock_ack("Reset to normal grid");
    }
}
