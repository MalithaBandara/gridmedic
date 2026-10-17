"""PLACEHOLDER storm, so the app runs end to end until WP-A2 lands.

Person A's grid_storm.jac (WP-A2) replaces this file: when it lands, change
the `import from scenario_placeholder` line in sim.jac to `grid_storm` and
delete this file. Same signatures as WP-A2 (see PLAN.md). The grid itself
now comes from grid_build.jac (WP-A1).

The storm here is a small, BD-SMS-heavy subset of CLAUDE.md §6.2-6.3:
F1 line down (T3, T4, T5), F2 T8 fuse, F3 T6 fuse, F4 Lake Road under T9,
3 false reports from T7, 5 duplicates, 2 landmark-only complaints.
"""

import from random { Random }
import from gm_types { Complaint }
import from grid { GridNode, Substation, Section, Switch, Transformer, children }

def consumer_no(tx: str, i: int) -> str {
    return "451" + str(20 + int(tx[1:])) + f"{i:05d}";
}

def _all_nodes -> list[GridNode] {
    seen: set[str] = set();
    out: list[GridNode] = [];
    q: list[GridNode] = [s for s in [root -->[?:Substation]]];
    while q {
        n = q.pop(0);
        if n.id in seen {
            continue;
        }
        seen.add(n.id);
        out.append(n);
        q.extend(children(n));
    }
    return out;
}


def apply_storm_truth(f5: bool = False) {
    for n in _all_nodes() {
        if isinstance(n, Section) and n.id == "F1-B" {
            n.line_ok = False;
        } elif isinstance(n, Switch) and n.id == "SW1" {
            n.closed = False;
            n.locked_out = True;
        } elif isinstance(n, Transformer) {
            if n.id in ["T8", "T6"] or (f5 and n.id == "T4") {
                n.fuse_ok = False;
            }
            if n.id == "T9" {
                cut: dict[str, bool] = dict(n.service_ok);
                cut["Lake Road"] = False;
                n.service_ok = cut;
            }
        }
    }
}

# Bursty: most reports in the first 8 minutes.
def _time(rng: Random, start: float) -> float {
    t: float = start + rng.expovariate(1.0 / 3.0);
    return float(f"{min(t, 19.9):.1f}");
}

def generate_complaints(seed: int = 17) -> list[Complaint] {
    rng = Random(seed);
    out: list[Complaint] = [];
    # (transformer, homes that can report, share reporting, first report min)
    groups: list[tuple[str, list[int], float, float]] = [
        ("T3", list(range(1, 81)), 0.4, 0.3),
        ("T4", list(range(1, 56)), 0.4, 0.4),
        ("T5", list(range(1, 71)), 0.35, 0.5),
        ("T8", list(range(1, 41)), 0.45, 1.0),
        ("T6", list(range(1, 51)), 0.4, 1.2),
        ("T9", list(range(1, 16)), 0.5, 2.0)
    ];
    for (tx, homes, share, start) in groups {
        picked: list[int] = rng.sample(homes, max(1, int(len(homes) * share)));
        for i in picked {
            cn: str = consumer_no(tx, i);
            out.append(Complaint(id="", text=f"BD {cn}", consumer_no=cn, time_min=_time(rng, start)));
        }
    }
    # 3 false reports from T7 (those homes still have power)
    for i in [5, 22, 41] {
        cn = consumer_no("T7", i);
        out.append(Complaint(id="", text=f"BD {cn}", consumer_no=cn, time_min=float(4 + i % 7)));
    }
    # 5 duplicates: the same consumer again within 10 minutes
    firsts: list[Complaint] = [c for c in out if c.consumer_no.startswith("45123")][:5];
    for c in firsts {
        out.append(Complaint(id="", text=c.text, consumer_no=c.consumer_no, time_min=float(f"{min(c.time_min + 4.0, 19.9):.1f}")));
    }
    # 2 landmark-only complaints (no consumer number)
    out.append(Complaint(id="", text="Wire fallen on the road near pole 23, sparks!", time_min=0.8));
    out.append(Complaint(id="", text="Wire down near Pole 23", time_min=2.6));
    out = sorted(out, key=lambda c: Complaint : c.time_min);
    for (k, c) in enumerate(out) {
        c.id = f"C{k + 1:04d}";
    }
    return out;
}

def f5_followup_complaints(start_min: float) -> list[Complaint] {
    out: list[Complaint] = [];
    for (k, i) in enumerate([3, 9, 14, 20, 27, 33, 41, 50]) {
        cn = consumer_no("T4", i);
        out.append(Complaint(id=f"C9{k + 1:03d}", text=f"BD {cn}", consumer_no=cn, time_min=start_min + k * 0.6));
    }
    return out;
}
