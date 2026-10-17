"""GridMedic API: every endpoint is a walker:pub, served as POST /walker/<name>.

Contract (owned by Person B): names, inputs and report types are frozen.
Spawn from the client on root and read `result.reports`:
  - list endpoints report one item per element (reports: list[T])
  - single-value endpoints report exactly one value (read reports[0])

All logic lives in sim.jac; these walkers are the thin public surface.
"""

import from gm_types {
    Complaint,
    Fault,
    FaultKind,
    Crew,
    CrewTask,
    Action,
    CustomerStatus,
    Event,
    GridView,
    Ack,
    ActionResult,
    label_fault
}
import sim;

# Nodes, edges, clock and counters for the diagram. reports[0]
walker:pub get_grid {
    has reports: list[GridView] = [];

    can run with Root entry {
        with sim.LOCK {
            report sim.grid_view();
        }
    }
}

# Starts a scenario; complaints are released by tick. reports[0]
# scenario: "storm" (default, F1-F4) or "blackout" (transmission line TL1 trips)
walker:pub start_storm {
    has speed: int = 1,
        f5: bool = False,    # also hide a T4 fuse behind F1 (the verifier finds it after the repair)
        scenario: str = "storm",
        reports: list[Ack] = [];

    can run with Root entry {
        with sim.LOCK {
            report sim.storm_start(self.speed, self.f5, self.scenario);
        }
    }
}

# Advances the simulated clock: releases complaints, parses, localises,
# groups, ranks, moves crews. reports[0]
walker:pub tick {
    has minutes: float = 0.5,
        reports: list[Ack] = [];

    can run with Root entry {
        with sim.LOCK {
            report sim.storm_tick(self.minutes);
        }
    }
}

# Customer/operator submits one complaint. reports[0]
walker:pub submit_complaint {
    has text: str = "",
        consumer_no: str = "",
        reports: list[Complaint] = [];

    can run with Root entry {
        with sim.LOCK {
            report sim.submit(self.text, self.consumer_no);
        }
    }
}

# Complaints with time_min >= since_min, oldest first. One report each.
walker:pub get_complaints {
    has since_min: float = 0.0,
        reports: list[Complaint] = [];

    can run with Root entry {
        for c in sim.complaints_since(self.since_min) {
            report c;
        }
    }
}

# Faults ranked by priority, highest first. One report each.
walker:pub get_faults {
    has reports: list[Fault] = [];

    can run with Root entry {
        for f in sim.ranked_faults() {
            report f;
        }
    }
}

# All crews. One report each.
walker:pub get_crews {
    has reports: list[Crew] = [];

    can run with Root entry {
        for c in sim.crews() {
            report c;
        }
    }
}

# Active crew tasks. One report each.
walker:pub get_tasks {
    has reports: list[CrewTask] = [];

    can run with Root entry {
        for t in sim.tasks() {
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
        with sim.LOCK {
            report sim.apply_crew_report(self.crew_id, self.text);
        }
    }
}

# Why a fault was found and ranked: reports[0] is the fault with `explanation`
# filled (2 sentences; cached until the fault changes). Added in WP-B6.
walker:pub explain {
    has fault_id: str = "",
        reports: list[Fault] = [];

    can run with Root entry {
        with sim.LOCK {
            report sim.explain(self.fault_id);
        }
    }
}

# Restoration actions with their safety result. One report each.
walker:pub get_actions {
    has reports: list[Action] = [];

    can run with Root entry {
        for a in sim.actions() {
            report a;
        }
    }
}

# Applies a restoration action if it is safe. reports[0]
walker:pub apply_action {
    has action_id: str = "",
        reports: list[ActionResult] = [];

    can run with Root entry {
        with sim.LOCK {
            report sim.apply(self.action_id);
        }
    }
}

# Event log entries with time_min >= since_min, oldest first. One report each.
walker:pub get_events {
    has since_min: float = 0.0,
        reports: list[Event] = [];

    can run with Root entry {
        for e in sim.events_since(self.since_min) {
            report e;
        }
    }
}

# Customer page status lookup. Logs a status_checked event (a writer). reports[0]
walker:pub get_status {
    has consumer_no: str = "",
        reports: list[CustomerStatus] = [];

    can run with Root entry {
        with sim.LOCK {
            report sim.customer_status(self.consumer_no);
        }
    }
}

# Restores the initial grid and clears the storm (keeps ParseCache). reports[0]
walker:pub reset {
    has reports: list[Ack] = [];

    can run with Root entry {
        with sim.LOCK {
            report sim.storm_reset();
        }
    }
}
