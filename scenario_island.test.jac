"""Island-wide blackout scenario: the complaint flood is shaped as designed.

    jac clean --all --force; jac test scenario_island.jac
"""

import from gm_types { Complaint }
import from grid_build { TRANSFORMERS }

def _flood -> list[Complaint] {
    return island_complaints();
}

def _script(text: str) -> str {
    if text.startswith("BD ") {
        return "bd";
    }
    if any([ord(ch) >= 0x0D80 and ord(ch) <= 0x0DFF for ch in text]) {
        return "sinhala";
    }
    if any([ord(ch) >= 0x0B80 and ord(ch) <= 0x0BFF for ch in text]) {
        return "tamil";
    }
    return "singlish" if text in SINGLISH_TEXTS else "english";
}

test "the same seed gives the same flood, another seed a different one" {
    a = [(c.id, c.text, c.consumer_no, c.time_min) for c in island_complaints(31)];
    assert a == [(c.id, c.text, c.consumer_no, c.time_min) for c in island_complaints(31)];
    assert a != [(c.id, c.text, c.consumer_no, c.time_min) for c in island_complaints(32)];
}

test "40-60 percent of the homes under every transformer report" {
    reporters: dict[int, set[str]] = {};
    for c in _flood() {
        if c.consumer_no {
            n = int(c.consumer_no[3:5]) - 20;
            if n not in reporters {
                reporters[n] = set();
            }
            reporters[n].add(c.consumer_no);
        }
    }
    for (n, _sid, _x, _y, _critical, streets) in TRANSFORMERS {
        homes = sum([count for (_street, count) in streets]);
        got = len(reporters.get(n, set()));
        assert got >= 0.4 * homes - 1 and got <= 0.6 * homes + 1, f"T{n}: {got} of {homes}";
    }
    assert len(_flood()) >= 250, len(_flood());
}

test "all inside 15 minutes, most in the first 5, ids in time order" {
    cs = _flood();
    times = [c.time_min for c in cs];
    assert times == sorted(times);
    assert all([t >= 0.0 and t < 15.0 for t in times]);
    assert len([t for t in times if t < 5.0]) > len(cs) * 0.75;
    assert [c.id for c in cs] == [f"I{k + 1:04d}" for k in range(len(cs))];
}

test "five formats: BD SMS, English, Sinhala, Singlish and Tamil" {
    counts: dict[str, int] = {};
    for c in _flood() {
        s = _script(c.text);
        counts[s] = counts.get(s, 0) + 1;
    }
    total = len(_flood());
    assert sorted(counts.keys()) == ["bd", "english", "singlish", "sinhala", "tamil"], counts;
    assert counts["bd"] > total * 0.3 and counts["bd"] < total * 0.5, counts;
    for k in ["sinhala", "singlish", "tamil"] {
        assert counts[k] > total * 0.05, counts;
    }
}

test "8 repeats within the window, 2 unlocatable reports, no hazard words" {
    cs = _flood();
    last: dict[str, float] = {};
    repeats = 0;
    for c in cs {
        if c.consumer_no {
            if c.consumer_no in last and c.time_min - last[c.consumer_no] <= 10.0 {
                repeats += 1;
            }
            last[c.consumer_no] = c.time_min;
        }
    }
    assert repeats == 8, repeats;
    assert len([c for c in cs if c.consumer_no == ""]) == 2;
    for t in island_phrases() {
        low = t.lower();
        assert not any([w in low for w in ["wire", "spark", "fire", "pole", "bang"]]), t;
    }
}
