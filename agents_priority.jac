"""Prioritiser (WP-B3): ranks faults, hazards first (CLAUDE.md §8.4).

priority = 1000 * (hazard != NONE)
         +  500 * (has critical loads)
         +        homes_affected
         +    2 * minutes since first report

Finished faults (RESTORED, CLOSED) sink to the bottom whatever their score.
Ties keep a stable order: earlier first report, then id.
"""

import from gm_types { Fault, FaultStatus, Hazard, label_fault }
import from grid { FaultNode }

glob HAZARD_WEIGHT: int = 1000;
glob CRITICAL_WEIGHT: int = 500;
glob AGE_WEIGHT: int = 2;

def priority_of(f: Fault, clock_min: float) -> int {
    score: int = f.homes_affected;
    if f.hazard != Hazard.NONE {
        score += HAZARD_WEIGHT;
    }
    if len(f.critical_loads) > 0 {
        score += CRITICAL_WEIGHT;
    }
    age: float = max(0.0, clock_min - f.first_report_min);
    score += AGE_WEIGHT * int(age);
    return score;
}

def is_finished(f: Fault) -> bool {
    return f.status == FaultStatus.RESTORED or f.status == FaultStatus.CLOSED;
}

def _rank_key(f: Fault) -> tuple[int, int, float, str] {
    return (1 if is_finished(f) else 0, -f.priority, f.first_report_min, f.id);
}

"""Score, label and sort faults (highest priority first). Mutates each Fault's priority."""
def rank_faults(faults: list[Fault], clock_min: float) -> list[Fault] {
    for f in faults {
        f.priority = priority_of(f, clock_min);
        label_fault(f);
    }
    return sorted(faults, key=_rank_key);
}

"""Re-score every FaultNode under root and return the ranked faults."""
def rank_fault_nodes(clock_min: float) -> list[Fault] {
    nodes = [root -->[?:FaultNode]];
    faults: list[Fault] = [fn.fault for fn in nodes];
    ranked = rank_faults(faults, clock_min);
    for fn in nodes {
        fn.fault = fn.fault;    # reassign so the nested priority change persists
    }
    return ranked;
}
