"""WP-A2 tests: the storm follows CLAUDE.md §6.2-6.3. No LLM involved.

Run after a clean (tests share one persisted root):
    jac clean --all --force; jac test grid_storm.jac
"""

import from gm_types { Complaint }
import from grid { Section, Switch, Transformer, Home }
import from grid_build { build_grid, reset_grid, grid_nodes, consumer_no, TRANSFORMERS }

def _storm -> list[Complaint] {
    return generate_complaints(17);
}

def _tx_of(cn: str) -> int {
    return int(cn[3:5]) - 20;
}

def _is_sinhala(text: str) -> bool {
    return any([ord(ch) > 0x0D80 and ord(ch) < 0x0DFF for ch in text]);
}

def _homes_of(n: int) -> int {
    for (m, _sid, _x, _y, _critical, streets) in TRANSFORMERS {
        if m == n {
            return sum([count for (_street, count) in streets]);
        }
    }
    return 0;
}

test "the same seed gives the same storm, another seed a different one" {
    a = [(c.id, c.text, c.consumer_no, c.time_min) for c in generate_complaints(17)];
    b = [(c.id, c.text, c.consumer_no, c.time_min) for c in generate_complaints(17)];
    other = [(c.id, c.text, c.consumer_no, c.time_min) for c in generate_complaints(18)];
    assert a == b;
    assert a != other;
}

test "ids run C0001 upwards in time order, all inside the 20 minutes" {
    cs = _storm();
    assert [c.id for c in cs] == [f"C{k + 1:04d}" for k in range(len(cs))];
    times = [c.time_min for c in cs];
    assert times == sorted(times);
    assert all([t >= 0.0 and t < 20.0 for t in times]);
    early = len([t for t in times if t < 8.0]);
    assert early > len(cs) * 0.6, f"{early} of {len(cs)} before 8 min";
}

test "format mix is about half BD SMS, a third English, a fifth Sinhala" {
    cs = _storm();
    bd = len([c for c in cs if c.text.startswith("BD ")]);
    si = len([c for c in cs if _is_sinhala(c.text)]);
    en = len(cs) - bd - si;
    assert bd > len(cs) * 0.4 and bd < len(cs) * 0.6, bd;
    assert en > len(cs) * 0.2 and en < len(cs) * 0.4, en;
    assert si > len(cs) * 0.1 and si < len(cs) * 0.3, si;
}

test "every BD SMS carries its own valid consumer number" {
    for c in _storm() {
        if c.text.startswith("BD ") {
            num = c.text[3:];
            assert num == c.consumer_no, c.text;
            assert len(num) == 10 and num.isdigit();
            n = _tx_of(num);
            i = int(num[5:]);
            assert n >= 1 and n <= 10 and i >= 1 and i <= _homes_of(n), num;
        }
    }
}

test "each fault's affected homes report at 20-60 percent" {
    cs = [c for c in _storm() if c.consumer_no != ""];
    reporters: dict[int, set[str]] = {};
    for c in cs {
        n = _tx_of(c.consumer_no);
        if n not in reporters {
            reporters[n] = set();
        }
        reporters[n].add(c.consumer_no);
    }
    f1 = len(reporters[3]) + len(reporters[4]) + len(reporters[5]);
    assert f1 >= 0.2 * 205 and f1 <= 0.6 * 205, f1;
    assert len(reporters[8]) >= 8 and len(reporters[8]) <= 24;
    assert len(reporters[6]) >= 10 and len(reporters[6]) <= 30;
    # F4: only Lake Road (T9 homes 1-15) reports
    t9 = [int(cn[5:]) for cn in reporters[9]];
    assert all([i <= 15 for i in t9]) and len(t9) >= 3 and len(t9) <= 9, t9;
    # Homes no fault touches never report, except T7's false reports
    for n in [1, 2, 10] {
        assert n not in reporters, n;
    }
}

test "noise: 5 duplicates, 3 false T7 reports, 2 landmark-only" {
    cs = _storm();
    last: dict[str, float] = {};
    dups = 0;
    for c in cs {
        if c.consumer_no != "" {
            if c.consumer_no in last and c.time_min - last[c.consumer_no] <= 10.0 {
                dups += 1;
            }
            last[c.consumer_no] = c.time_min;
        }
    }
    assert dups == 5, dups;
    t7 = [c for c in cs if c.consumer_no != "" and _tx_of(c.consumer_no) == 7];
    assert len(t7) == 3;
    no_number = [c for c in cs if c.consumer_no == ""];
    assert len(no_number) == 2;
    assert all(["pole 23" in c.text.lower() for c in no_number]);
}

test "at least 3 F1 hazards mention pole 23 and hazards stay on F1" {
    cs = _storm();
    pole = [c for c in cs if "pole 23" in c.text.lower() and c.consumer_no != ""];
    assert len(pole) >= 3;
    assert all([_tx_of(c.consumer_no) in [3, 4, 5] for c in pole]);
    hazard_si = ["කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා", "ගිනි පුපුරු එනවා", "ට්‍රාන්ස්ෆෝමරයෙන් සද්දයක් ආවා"];
    for c in cs {
        if c.text in hazard_si or "bang" in c.text {
            assert _tx_of(c.consumer_no) in [3, 4, 5], c.text;
        }
    }
    assert any([c.text == "කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා" for c in cs]);
}

test "free text uses a small phrase set, so the parse cache stays cheap" {
    texts = set([c.text for c in _storm() if not c.text.startswith("BD ")]);
    assert len(texts) <= 20, len(texts);
}

test "apply_storm_truth sets the §6.2 damage, and T4 only with F5" {
    reset_grid();
    apply_storm_truth(False);
    ids: dict[str, any] = {};
    for n in grid_nodes(build_grid()) {
        ids[n.id] = n;
    }
    assert not ids["F1-B"].line_ok and ids["F1-A"].line_ok and ids["F1-C"].line_ok;
    assert not ids["SW1"].closed and ids["SW1"].locked_out;
    assert ids["SW2"].closed and not ids["TS1"].closed;
    assert not ids["T8"].fuse_ok and not ids["T6"].fuse_ok and ids["T4"].fuse_ok;
    assert ids["T9"].service_ok == {"Lake Road": False, "Temple Road": True, "Station Road": True};
    apply_storm_truth(True);
    assert not ids["T4"].fuse_ok;
    reset_grid();
    assert ids["F1-B"].line_ok and ids["T4"].fuse_ok and ids["SW1"].closed;
}

test "F5 follow-ups: 8 T4 SMS after the given minute" {
    fu = f5_followup_complaints(30.0);
    assert len(fu) == 8;
    assert all([c.time_min >= 30.0 and _tx_of(c.consumer_no) == 4 for c in fu]);
    assert all([c.text == f"BD {c.consumer_no}" for c in fu]);
    assert len(set([c.id for c in fu])) == 8;
    assert fu[0].consumer_no == consumer_no(4, 3);
}
