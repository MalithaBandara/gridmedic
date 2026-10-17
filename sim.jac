"""Simulation pipeline (WP-B4): the simulated clock and everything one tick does.

start_storm -> reset, apply ground truth, load the scenario complaints.
tick(minutes), in order:
  1. advance the clock          2. release due complaints
  3. parse_batch (LLM, cached)  4. Localiser per non-duplicate complaint
  5. group_faults               6. rank_faults
  7. Energiser + Dispatcher (C's walkers; no-ops until C3/C4 land)
  8. log events
reset -> normal grid, storm cleared, ParseCache kept.

Only this module orchestrates. grid.jac never imports it (no cycles).
"""

import from gm_types {
    Complaint,
    Fault,
    FaultStatus,
    Crew,
    CrewTask,
    CrewStatus,
    Action,
    CustomerStatus,
    Event,
    GridView,
    GridNodeView,
    GridEdgeView,
    Counters,
    Ack,
    ActionResult,
    label_complaint,
    label_fault,
    label_crew
}
import from grid {
    GridNode,
    Feeds,
    Substation,
    Section,
    Switch,
    Transformer,
    Home,
    Depot,
    Landmark,
    CrewNode,
    FaultNode,
    SimState,
    EventLog,
    ComplaintLog,
    ActionStore,
    Energiser,
    Dispatcher,
    Snapshot,
    children,
    parents
}
import from grid_build { build_grid, reset_grid }
import from grid_storm { generate_complaints, apply_storm_truth }
import from agents_parse { parse_batch, parse_one, flag_duplicates }
import from agents_group { localise_all, group_faults }
import from agents_priority { rank_fault_nodes, is_finished }

import threading;

# One lock for every endpoint that writes the graph: two tabs (or React
# StrictMode double effects) must not build the grid or tick concurrently.
glob LOCK = threading.RLock();

glob STORM_SEED: int = 17;
glob STORM_LENGTH_MIN: float = 20.0;

# The scenario is deterministic, so it is generated once per process.
glob _SCENARIO: list[Complaint] = [];

# ------------------------------------------------------------- state access
def sim_state -> SimState;
def event_log -> EventLog;
def complaint_log -> ComplaintLog;
def action_store -> ActionStore;
def ensure_grid -> Substation;
def log_event(kind: str, text: str, fault_id: str = "");
def clock -> float;

# ---------------------------------------------------------------- pipeline
def storm_start(speed: int) -> Ack;
def storm_tick(minutes: float) -> Ack;
def storm_reset -> Ack;
def process_complaints(new_items: list[Complaint]) -> int;
def submit(text: str, consumer_no: str) -> Complaint;
def run_energiser;
def run_dispatcher(minutes: float);

# ------------------------------------------------------------------- reads
def ranked_faults -> list[Fault];
def complaints_since(since_min: float) -> list[Complaint];
def events_since(since_min: float) -> list[Event];
def crews -> list[Crew];
def tasks -> list[CrewTask];
def actions -> list[Action];
def apply(action_id: str) -> ActionResult;
def counters -> Counters;
def grid_view -> GridView;
def customer_status(consumer_no: str) -> CustomerStatus;
def crew_fault(crew_id: str) -> Fault | None;

# ---------------------------------------------------------------- helpers
def _scenario -> list[Complaint];
def _copy(c: Complaint) -> Complaint;
def _clear_storm;
def _fault_key(f: Fault) -> str;
def _all_grid_nodes -> list[GridNode];
def _upstream_ids(h: Home) -> list[str];
