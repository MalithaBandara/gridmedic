"""Island-wide blackout scenario: the national grid collapses (WP-A3 test scene).

Ground truth: supply into SS1 is lost upstream of TL1, so the physical effect
on our grid is the same as the TL1 blackout (apply_blackout_truth): every
feeder, transformer and home is dark, and only the microgrids can island.
What differs is the flood. About half the homes under every transformer
report within 15 minutes, many saying the whole country is dark, in English,
Sinhala script, Sinhala in Latin letters ("Singlish") and Tamil. The agents
must still name one fault upstream of SS1, not ten local ones, and send no
crews into the distribution grid.

Outage phase only: supply does not return during the scenario.
Same signatures as the other scenarios, so sim.jac can switch between them.
Tamil phrases need a check by a native speaker.
"""

import from random { Random }
import from gm_types { Complaint }
import from grid_build { TRANSFORMERS, consumer_no }

glob ISLAND_LENGTH_MIN: float = 15.0;
glob ISLAND_SEED: int = 31;
glob REPORT_SHARE_MIN: float = 0.4;
glob REPORT_SHARE_MAX: float = 0.6;
glob MEAN_GAP_MIN: float = 2.5;
glob DUPLICATES: int = 8;

# Share of each format, in order; the rest is Tamil.
glob BD_SHARE: float = 0.4;
glob EN_SHARE: float = 0.25;
glob SI_SHARE: float = 0.15;
glob SINGLISH_SHARE: float = 0.1;

# A small fixed phrase set, so a replay hits the ParseCache, not the LLM.
glob EN_TEXTS: list[str] = [
    "No power in the whole area",
    "Whole country is dark, is it an island-wide power cut?",
    "Power gone everywhere, the news says the whole island is off",
    "Is this an island-wide blackout? No electricity since morning"
];
glob SI_TEXTS: list[str] = [
    "මුළු රටේම විදුලිය නැහැ",
    "මුළු ප්‍රදේශයෙම විදුලිය නැහැ",
    "විදුලිය නැහැ"
];
glob SINGLISH_TEXTS: list[str] = [
    "mulu rate ma current naha",
    "hama thanama current naha",
    "widuliya naha"
];
glob TA_TEXTS: list[str] = [
    "நாடு முழுவதும் மின்சாரம் இல்லை",
    "எங்கும் மின்சாரம் இல்லை",
    "மின்சாரம் இல்லை"
];
# No consumer number and no landmark: unlocatable, must not create a fault.
glob UNLOCATABLE: list[tuple[str, float]] = [
    ("No power anywhere in Moratuwa, whole town is dark", 1.5),
    ("மொரட்டுவ முழுவதும் இருட்டாக இருக்கிறது", 3.2)
];

"""Every free-text phrase this scenario can send."""
def island_phrases -> list[str] {
    return EN_TEXTS + SI_TEXTS + SINGLISH_TEXTS + TA_TEXTS + [t for (t, _m) in UNLOCATABLE];
}

"""The flood for one seed, sorted by time, ids I0001..."""
def island_complaints(seed: int = ISLAND_SEED) -> list[Complaint] {
    rng = Random(seed);
    out: list[Complaint] = [];
    for (n, _sid, _x, _y, _critical, streets) in TRANSFORMERS {
        homes: int = sum([count for (_street, count) in streets]);
        share = rng.uniform(REPORT_SHARE_MIN, REPORT_SHARE_MAX);
        for i in rng.sample(list(range(1, homes + 1)), round(homes * share)) {
            cn = consumer_no(n, i);
            out.append(Complaint(id="", text=_text(rng, cn), consumer_no=cn, time_min=_time(rng)));
        }
    }
    # People try again: 8 senders repeat 1-6 minutes later.
    for c in rng.sample(out, DUPLICATES) {
        again = min(c.time_min + rng.uniform(1.0, 6.0), ISLAND_LENGTH_MIN - 0.1);
        out.append(Complaint(id="", text=c.text, consumer_no=c.consumer_no, time_min=_round(again)));
    }
    for (text, t) in UNLOCATABLE {
        out.append(Complaint(id="", text=text, time_min=t));
    }
    out = sorted(out, key=lambda c: Complaint : (c.time_min, c.consumer_no, c.text));
    for (k, c) in enumerate(out) {
        c.id = f"I{k + 1:04d}";
    }
    return out;
}

def _text(rng: Random, cn: str) -> str {
    r = rng.random();
    if r < BD_SHARE {
        return f"BD {cn}";
    }
    r -= BD_SHARE;
    if r < EN_SHARE {
        return rng.choice(EN_TEXTS);
    }
    r -= EN_SHARE;
    if r < SI_SHARE {
        return rng.choice(SI_TEXTS);
    }
    r -= SI_SHARE;
    if r < SINGLISH_SHARE {
        return rng.choice(SINGLISH_TEXTS);
    }
    return rng.choice(TA_TEXTS);
}

# Everyone notices at once: most reports land in the first 5 minutes.
def _time(rng: Random) -> float {
    return _round(min(rng.expovariate(1.0 / MEAN_GAP_MIN), ISLAND_LENGTH_MIN - 0.1));
}

def _round(t: float) -> float {
    return float(f"{t:.1f}");
}
