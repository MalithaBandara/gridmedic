"""Blackout scenario: the 132 kV transmission line TL1 into SS1 trips.

Ground truth: TL1 line_ok = False, so every feeder, transformer and home is
dark (the microgrids can still island). The agents only see the complaints:
reports from homes under every transformer, which the grouping escalates to
a single TRANSMISSION fault at TL1.

Same signatures as the storm scenario, so sim.jac can switch between them.
"""

import from random { Random }
import from gm_types { Complaint }
import from grid { TransmissionLine }
import from grid_build { TRANSFORMERS, consumer_no }

glob BLACKOUT_LENGTH_MIN: float = 12.0;

# Few distinct texts, so a replay hits the ParseCache instead of the LLM.
glob TEXTS: list[str] = [
    "No power in the whole area",
    "Entire town is dark, even the street lights are off",
    "Power cut everywhere, neighbours also have no electricity",
    "මුළු ප්‍රදේශයෙම විදුලිය නැහැ"
];

def apply_blackout_truth {
    for tl in [root -->[?:TransmissionLine]] {
        tl.line_ok = False;
    }
}

"""~25-40% of the homes under every transformer report within 12 minutes,
mostly early; ~70% are BD SMS, the rest free text. 4 duplicates."""
def blackout_complaints(seed: int = 23) -> list[Complaint] {
    rng = Random(seed);
    out: list[Complaint] = [];
    n: int = 1;
    for (tx, _sid, _x, _y, _critical, streets) in TRANSFORMERS {
        homes: int = sum([count for (_street, count) in streets]);
        picked = rng.sample(list(range(1, homes + 1)), int(homes * rng.uniform(0.25, 0.4)));
        for i in picked {
            cno = consumer_no(tx, i);
            delay: float = rng.expovariate(1 / 3.0);
            t: float = float(f"{min(BLACKOUT_LENGTH_MIN, delay):.2f}");
            text = f"BD {cno}" if rng.random() < 0.7 else rng.choice(TEXTS);
            out.append(Complaint(id=f"B{n:04d}", text=text, time_min=t, consumer_no=cno));
            n += 1;
        }
    }
    for c in rng.sample(out, 4) {
        out.append(Complaint(id=f"B{n:04d}", text=f"BD {c.consumer_no}", time_min=min(BLACKOUT_LENGTH_MIN, c.time_min + 3.0), consumer_no=c.consumer_no));
        n += 1;
    }
    return out;
}
