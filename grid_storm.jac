"""Storm scenario (WP-A2): ground truth and the complaint generator (CLAUDE.md §6.2-6.3).

Ground truth lives in _TRUTH. Only apply_storm_truth() (physical state for the
Energiser) reads it; the discovery agents must find the faults from complaints.

generate_complaints(seed) returns the storm's raw complaints: id, text,
consumer_no and time_min only (the parser fills the rest), sorted by time.
- Each fault's affected homes report at a fixed share inside 20-60%.
- Formats: ~50% "BD <number>" SMS, ~30% English, ~20% Sinhala. Free text keeps
  its consumer_no (app / web channel, PLAN.md §2.1).
- Hazard texts appear only on F1 and point at Pole 23, so a hazard landmark
  never suggests a line down on another section (§8.2 step 2).
- Noise: 5 duplicates, 3 false reports from T7 (still powered), 2 landmark-only.
- Bursty: each fault starts in its first 2 minutes, then exponential with a
  3-minute mean, so most reports land in the first 8 minutes.

At 20-60% of the 310 affected homes the storm has ~180 complaints, not the
~300 CLAUDE.md §6.3 estimates; the free text uses a small fixed phrase set, so
the parse cache needs only a handful of LLM calls per storm.
"""

import from random { Random }
import from gm_types { Complaint }
import from grid { Substation, Section, Switch, Transformer }
import from grid_build { TRANSFORMERS, consumer_no, grid_nodes }

glob STORM_MINUTES: float = 20.0;
glob MEAN_GAP_MIN: float = 3.0;
glob BD_SHARE: float = 0.5;
glob ENGLISH_SHARE: float = 0.3;     # the rest is Sinhala

# Ground truth: id, kind, device, transformers affected, street ("" = all),
# share of affected homes that report, first report minute. Agents never read it.
glob _TRUTH: list[tuple[str, str, str, list[int], str, float, float]] = [
    ("F1", "LINE_DOWN", "F1-B", [3, 4, 5], "", 0.5, 0.3),
    ("F2", "TX_FUSE", "T8", [8], "", 0.5, 1.0),
    ("F3", "TX_FUSE", "T6", [6], "", 0.5, 1.2),
    ("F4", "SERVICE_WIRE", "T9", [9], "Lake Road", 0.6, 2.0)
];
# F5 (optional): T4 fuse hidden behind F1; shows up after F1's repair.
glob _F5_HOMES: list[int] = [3, 9, 14, 20, 27, 33, 41, 50];
glob _FALSE_T7: list[int] = [5, 22, 41];

glob EN_PLAIN: list[str] = [
    "No power since 7pm",
    "No electricity at home",
    "Power cut in our area, please send someone",
    "Current gone since evening"
];
glob SI_PLAIN: list[str] = ["විදුලිය නැහැ", "රෑ 7 ඉඳන් කරන්ට් නැහැ"];
# F1 only: hazards (Pole 23) and the sounds of a line coming down.
glob EN_F1_HAZARD: list[str] = [
    "Wire fallen on the road near pole 23, sparks!",
    "Live wire hanging low near pole 23",
    "Sparks coming from the line at pole 23"
];
glob EN_F1_EXTRA: list[str] = ["Lights went off with a loud bang"];
glob SI_F1: list[str] = [
    "කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා",
    "ගිනි පුපුරු එනවා",
    "ට්‍රාන්ස්ෆෝමරයෙන් සද්දයක් ආවා"
];
glob EN_PUMP: str = "Water pump area has no electricity";
glob LANDMARK_ONLY: list[tuple[str, float]] = [
    ("Wire fallen on the road near pole 23, sparks!", 0.8),
    ("Lines down near Pole 23, whole road is dark", 2.6)
];

"""Set the storm's physical damage on the grid (call after reset_grid)."""
def apply_storm_truth(f5: bool = False) {
    ss = [s for s in [root -->[?:Substation]]];
    if not ss {
        return;
    }
    for n in grid_nodes(ss[0]) {
        if isinstance(n, Section) and n.id == "F1-B" {
            n.line_ok = False;
        } elif isinstance(n, Switch) and n.id == "SW1" {
            # The recloser trips on the F1-B fault and locks out.
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

def _complaint_order(c: Complaint) -> tuple[float, str, str] {
    return (c.time_min, c.consumer_no, c.text);
}

"""The storm's raw complaints for one seed, sorted by time, ids C0001..."""
def generate_complaints(seed: int = 17) -> list[Complaint] {
    rng = Random(seed);
    out: list[Complaint] = [];
    for (fid, _kind, _device, txs, street, share, start) in _TRUTH {
        homes: list[tuple[int, int]] = _affected(txs, street);
        picked = rng.sample(homes, max(1, round(len(homes) * share)));
        for (k, home) in enumerate(picked) {
            cn = consumer_no(home[0], home[1]);
            t = _time(rng, start);
            if fid == "F1" and k < len(EN_F1_HAZARD) {
                # The first F1 reporters see the wire come down at Pole 23.
                out.append(Complaint(id="", text=EN_F1_HAZARD[k], consumer_no=cn, time_min=t));
                continue;
            }
            out.append(Complaint(id="", text=_text(rng, fid, cn, k), consumer_no=cn, time_min=t));
        }
    }
    # False reports: T7 homes that actually still have power.
    for i in _FALSE_T7 {
        cn = consumer_no(7, i);
        out.append(Complaint(id="", text=f"BD {cn}", consumer_no=cn, time_min=float(4 + i % 7)));
    }
    # Duplicates: 5 SMS senders text again 2-8 minutes later.
    sms = [c for c in out if c.text.startswith("BD ") and not c.consumer_no.startswith("45127")];
    for c in rng.sample(sms, 5) {
        again = min(c.time_min + rng.uniform(2.0, 8.0), STORM_MINUTES - 0.1);
        out.append(Complaint(id="", text=c.text, consumer_no=c.consumer_no, time_min=_round(again)));
    }
    for (text, t) in LANDMARK_ONLY {
        out.append(Complaint(id="", text=text, time_min=t));
    }
    out = sorted(out, key=_complaint_order);
    for (k, c) in enumerate(out) {
        c.id = f"C{k + 1:04d}";
    }
    return out;
}

"""F5: complaints that keep coming from T4 after F1's repair (start_min)."""
def f5_followup_complaints(start_min: float) -> list[Complaint] {
    out: list[Complaint] = [];
    for (k, i) in enumerate(_F5_HOMES) {
        cn = consumer_no(4, i);
        out.append(Complaint(id=f"C9{k + 1:03d}", text=f"BD {cn}", consumer_no=cn, time_min=start_min + k * 0.6));
    }
    return out;
}

# (transformer n, home i) for every home a fault cuts off, in numbering order.
def _affected(txs: list[int], street: str) -> list[tuple[int, int]] {
    out: list[tuple[int, int]] = [];
    for (n, _sid, _x, _y, _critical, streets) in TRANSFORMERS {
        if n not in txs {
            continue;
        }
        i = 1;
        for (name, count) in streets {
            for _j in range(count) {
                if street == "" or name == street {
                    out.append((n, i));
                }
                i += 1;
            }
        }
    }
    return out;
}

def _text(rng: Random, fid: str, cn: str, k: int) -> str {
    r = rng.random();
    if r < BD_SHARE {
        return f"BD {cn}";
    }
    if r < BD_SHARE + ENGLISH_SHARE {
        if fid == "F3" and k % 3 == 0 {
            return EN_PUMP;
        }
        pool = EN_PLAIN + EN_F1_EXTRA if fid == "F1" else EN_PLAIN;
        return rng.choice(pool);
    }
    return rng.choice(SI_F1 + SI_PLAIN if fid == "F1" else SI_PLAIN);
}

def _time(rng: Random, start: float) -> float {
    return _round(min(start + rng.expovariate(1.0 / MEAN_GAP_MIN), STORM_MINUTES - 0.1));
}

def _round(t: float) -> float {
    return float(f"{t:.1f}");
}
