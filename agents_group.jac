"""Fault localisation and grouping (WP-B2, CLAUDE.md §8.2).

localise_all() spawns a Localiser per complaint; the nodes tally themselves.
group_faults() reads those tallies and turns them into FaultNodes under root.
It reads complaints and tallies only, never physical truth (line_ok,
fuse_ok, service_ok, locked_out) or the Energiser's power state.
"""

import from gm_types { Complaint, Fault, FaultKind, FaultStatus, Hazard, label_fault }
import from grid {
    GridNode,
    Feeds,
    Located,
    Section,
    Switch,
    Transformer,
    Home,
    Landmark,
    Localiser,
    FaultNode,
    SimState,
    ComplaintLog
}

# §8.2 thresholds (ratio = distinct reporting homes / homes)
glob HOT_RATIO: float = 0.2;           # step 2: a transformer that counts towards a line fault
glob DEAD_RATIO: float = 0.1;          # every transformer of a section this high: section looks dead
glob FUSE_RATIO: float = 0.3;          # step 3: transformer fuse
glob STREET_MIN_RATIO: float = 0.05;   # step 4: lower bound for the one-street case
glob STREET_SHARE: float = 0.6;        # step 4: share of reports on one street
glob STREET_CONFIDENCE: float = 0.4;   # step 4: deliberately low; a crew report corrects it

# The normal-configuration radial topology, read once per call.
obj GridIndex {
    has homes: dict[str, Home] = {},
        homes_by_consumer: dict[str, Home] = {},
        transformers: list[Transformer] = [],
        sections: list[Section] = [],                 # upstream first
        tx_of: dict[str, list[Transformer]] = {},     # section id -> its own transformers
        section_of: dict[str, str] = {},              # transformer id -> section id
        child_sections: dict[str, list[str]] = {},    # through normal (non-tie) switches
        parent_section: dict[str, str] = {},
        tx_homes: dict[str, list[Home]] = {},
        landmarks: list[Landmark] = [];
}

def build_index -> GridIndex;

"""Spawn a Localiser at the complaint's Home (or its landmark's Section). False if unlocatable or a duplicate."""
def localise(c: Complaint, idx: GridIndex) -> bool;

"""Localise a batch of parsed complaints. Returns how many were located."""
def localise_all(complaints: list[Complaint]) -> int;

"""§8.2 steps 1-5 over the current tallies; upserts FaultNodes and returns every current Fault.
With no argument, the complaints come from the ComplaintLog under root."""
def group_faults(complaints: list[Complaint] | None = None) -> list[Fault];

"""The faults the tallies point to right now, with empty ids. Pure: changes nothing."""
def find_candidates(idx: GridIndex, complaints: list[Complaint]) -> list[Fault];

"""Section id a landmark text refers to ('near pole 23' -> 'F1-B'), or ''."""
def landmark_section(idx: GridIndex, text: str) -> str;

def ratio(idx: GridIndex, t: Transformer) -> float;
def home_count(idx: GridIndex, t: Transformer) -> int;
def subtree_sections(idx: GridIndex, sid: str) -> list[str];
def looks_dead(idx: GridIndex, sid: str) -> bool;
