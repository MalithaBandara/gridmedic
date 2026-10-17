"""GridMedic graph: every node, edge and walker, declared in one module.

Owned by Person B (contract). Node abilities name walkers and walkers name
nodes, so splitting them across modules is a circular import that only fails
at runtime. Bodies live in grid.impl/<feature>.impl.jac, one file per owner,
paired with this file by the compiler.

Edges follow power-flow direction: Substation -> Section -> Switch -> Section,
Section -> Transformer -> Home. "Upstream" is [<-:Feeds:<-].

Import rule: this module imports only gm_types. Others import grid, never the reverse.
"""

import from gm_types {
    Crew,
    Fault,
    FaultUpdate,
    FaultKind,
    FaultStatus,
    label_fault,
    ParsedText,
    Event,
    Complaint,
    SwitchStep,
    Action,
    GridNodeView,
    GridEdgeView
}

# ---------------------------------------------------------------- grid nodes
# Every grid node shares this base, so one `with GridNode entry` ability
# fires on all of them and Feeds traversals are typed. Parent defaults force
# child defaults: every subclass field has one.
node GridNode {
    has id: str = "",
        x: int = 0,
        y: int = 0,
        energised: bool = True;
}

# Power-flow edge (parent -> child). TS1 has one Feeds edge from each side.
edge Feeds: GridNode --> GridNode {
    has capacity: int = 0;
}

node Substation(GridNode) {
    has name: str = "";
}

node Section(GridNode) {
    has feeder: str = "",
        work_zone: bool = False,
        reports: int = 0,
        line_ok: bool = True;    # physical truth: only Energiser / crew sim may read

    can tally with Localiser entry;
}

# kind: "recloser" | "switch" | "tie"
node Switch(GridNode) {
    has kind: str = "switch",
        closed: bool = True,
        normally_open: bool = False,
        locked_out: bool = False;    # physical truth (SW1 lockout)

    can guard with SafetyCheck entry;
}

node Transformer(GridNode) {
    has homes: int = 0,
        feeder: str = "",
        reports: int = 0,
        critical: list[str] = [],
        fuse_ok: bool = True,                # physical truth
        service_ok: dict[str, bool] = {};    # physical truth, per street

    can tally with Localiser entry;
}

node Home(GridNode) {
    has consumer_no: str = "",
        street: str = "",
        transformer_id: str = "",
        has_power: bool = True,
        reported: bool = False;

    can mark with Localiser entry;
}

node Depot(GridNode) {
    has name: str = "";
}

node Landmark(GridNode) {
    has name: str = "",
        section_id: str = "";
}

# Landmark -> Section, CrewNode -> Depot it belongs to
edge Located {}

# ---------------------------------------------------------- operational state
node CrewNode {
    has crew: Crew;
}

node FaultNode {
    has fault: Fault;

    can reevaluate with CrewReport entry;
}

# Simulated clock and storm progress (one per root)
node SimState {
    has clock_min: float = 0.0,
        running: bool = False,
        speed: int = 1,
        next_complaint_idx: int = 0,
        next_fault_no: int = 1,
        next_complaint_no: int = 1,
        f5_enabled: bool = False;
}

# Parsed free-text keyed by raw text. Survives reset (LLM quota).
node ParseCache {
    has entries: dict[str, ParsedText] = {};
}

node EventLog {
    has events: list[Event] = [];
}

# Every received complaint, in arrival order
node ComplaintLog {
    has items: list[Complaint] = [];
}

# Restoration actions offered to the operator (C, WP-C7)
node ActionStore {
    has actions: list[Action] = [];
}

# ------------------------------------------------------------------- walkers
# Spawned at root with every new complaint's Home (or landmark Section) in
# `starts`: one spawn per batch, because each spawn costs ~0.2 s on the full
# grid. Walks upstream; nodes tally themselves.
walker Localiser {
    has complaint_id: str = "",
        path: list[str] = [],
        starts: list[GridNode] = [];

    can begin with Root entry;
    can climb with GridNode entry;
}

# Flood fill from SS1 through closed switches and healthy sections (C, WP-C3)
walker Energiser {
    has live: list[str] = [];

    can spread with GridNode entry;
}

# Spawned at root; assigns idle crews and moves them by the clock (C, WP-C4)
walker Dispatcher {
    has clock_min: float = 0.0,
        minutes: float = 0.0,
        assigned: list[str] = [];

    can run with Root entry;
}

# Spawned at root with an already-parsed update; FaultNodes apply it (B, WP-B5)
walker CrewReport {
    has crew_id: str = "",
        fault_id: str = "",
        text: str = "",
        update: FaultUpdate | None = None,
        homes: int = 0,    # new homes_affected computed by sim; 0 keeps the current count
        changed: bool = False,
        before: str = "",
        after: str = "",
        result: Fault | None = None;

    can find with Root entry;
}

# Spawned at root; builds tie-switch restoration actions (C, WP-C7)
walker Restorer {
    has actions: list[Action] = [];

    can plan with Root entry;
}

# Simulates a switching plan. Abilities that `disengage` must stay inline:
# jac check rejects disengage inside impl blocks and node abilities (E2083).
# Switch.guard sets visitor.blocked_by; the gate stops the walker next step.
walker SafetyCheck {
    has steps: list[SwitchStep] = [],
        step_index: int = 0,
        blocked_by: str = "",
        reason: str = "",
        safe: bool = True,
        visited: list[str] = [];

    can gate with GridNode entry {
        if self.blocked_by != "" {
            disengage;
        }
    }

    can step with GridNode entry;    # body in grid.impl/safety.impl.jac
}

# Spawned at root after a repair; looks for complaints that continue (B, WP-B7)
walker Verifier {
    has clock_min: float = 0.0,
        new_fault_ids: list[str] = [];

    can check with Root entry;
}

# Spawned at SS1; collects the node/edge views for get_grid (B, WP-B4)
walker Snapshot {
    has nodes: list[GridNodeView] = [],
        edges: list[GridEdgeView] = [],
        seen: list[str] = [];

    can collect with GridNode entry;
}

# ------------------------------------------------------- fast traversal helpers
# Use these instead of [n ->:Feeds:->], [n <-:Feeds:<-] or [n -->[?:GridNode]].
# On this runtime (jaclang 0.16.7) typed-edge and [?:Type] filters cost ~12 ms
# per node on the inherited GridNode types: a full grid walk took 8-10 s,
# against 0.13 s for plain [n -->] filtered with isinstance (measured 17 Oct).
# All grid-to-grid edges are Feeds; Landmark -> Section is a Located edge,
# so parents() drops Landmarks.

"""Downstream neighbours over Feeds (power-flow direction)."""
def children(n: GridNode) -> list[GridNode] {
    return [x for x in [n -->] if isinstance(x, GridNode)];
}

"""Upstream neighbours over Feeds (towards the substation)."""
def parents(n: GridNode) -> list[GridNode] {
    return [x for x in [n <--] if isinstance(x, GridNode) and not isinstance(x, Landmark)];
}
