"""Acceptance tests, tier 1 (WP-A3): CLAUDE.md §11 tests 1-5 and 7-11.

One full seed-17 storm runs through the real pipeline (sim.storm_start/tick):
parse, localise, group, rank. No LLM is called: the parse cache is preloaded
with what a correct model returns for each of the storm's fixed phrases, and
the model is a MockLLM with no outputs, so any call would fail loudly. The
real-Gemini check of the Sinhala hazards is scripts/smoke_llm.jac.

Run on a clean root:  jac clean --all --force; jac test -d tests -v
"""

import agents_parse;
import from byllm.lib { MockLLM }
import from gm_types { Complaint, Fault, FaultKind, Hazard, Lang, ParsedText }
import from grid { Transformer, ParseCache }
import from grid_build { build_grid, grid_nodes }
import from grid_storm { generate_complaints }
import from sim { storm_start, storm_tick, ranked_faults, complaint_log, sim_state }

glob STORM_TICKS: int = 42;    # 0.5 min each: past the 20-minute storm

# What a correct parse of each storm phrase is.
glob TRUE_PARSE: dict[str, ParsedText] = {
    "No power since 7pm": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.NONE, landmark=""),
    "No electricity at home": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.NONE, landmark=""),
    "Power cut in our area, please send someone": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.NONE, landmark=""),
    "Current gone since evening": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.NONE, landmark=""),
    "Lights went off with a loud bang": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.NONE, landmark=""),
    "Water pump area has no electricity": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.NONE, landmark=""),
    "Wire fallen on the road near pole 23, sparks!": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.WIRE_DOWN, landmark="pole 23"),
    "Live wire hanging low near pole 23": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.WIRE_DOWN, landmark="pole 23"),
    "Sparks coming from the line at pole 23": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.SPARKS, landmark="pole 23"),
    "Lines down near Pole 23, whole road is dark": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.WIRE_DOWN, landmark="pole 23"),
    "විදුලිය නැහැ": ParsedText(index=0, lang=Lang.SI, hazard=Hazard.NONE, landmark=""),
    "රෑ 7 ඉඳන් කරන්ට් නැහැ": ParsedText(index=0, lang=Lang.SI, hazard=Hazard.NONE, landmark=""),
    "කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා": ParsedText(index=0, lang=Lang.SI, hazard=Hazard.WIRE_DOWN, landmark=""),
    "ගිනි පුපුරු එනවා": ParsedText(index=0, lang=Lang.SI, hazard=Hazard.SPARKS, landmark=""),
    "ට්‍රාන්ස්ෆෝමරයෙන් සද්දයක් ආවා": ParsedText(index=0, lang=Lang.SI, hazard=Hazard.TRANSFORMER_NOISE, landmark="")
};

def _preload_cache {
    found = [root -->[?:ParseCache]];
    cache = found[0] if found else (root ++> ParseCache())[0] as ParseCache;
    entries: dict[str, ParsedText] = dict(cache.entries);
    for (text, p) in TRUE_PARSE.items() {
        entries[agents_parse._cache_key(text)] = p;
    }
    cache.entries = entries;
}

# Runs the storm once per test run; later tests read its results.
def _storm -> list[Fault] {
    st = sim_state();
    if not (st.clock_min >= 20.0 and len(complaint_log().items) > 0) {
        build_grid();
        _preload_cache();
        agents_parse.reset_parse_stats();
        agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": []});
        storm_start(5);
        for _ in range(STORM_TICKS) {
            storm_tick(0.5);
        }
    }
    return ranked_faults();
}

def _one(faults: list[Fault], kind: FaultKind, device: str) -> Fault {
    hits = [f for f in faults if f.kind == kind and f.device_id == device];
    assert len(hits) == 1, f"{kind} at {device}: {[(f.kind_label, f.device_id) for f in faults]}";
    return hits[0];
}

test "every free text in the storm has a known true parse" {
    texts = set([c.text for c in generate_complaints(17) if not c.text.startswith("BD ")]);
    missing = [t for t in texts if t not in TRUE_PARSE];
    assert missing == [], missing;
}

test "1: the full storm gives exactly the faults F1-F4" {
    faults = _storm();
    found = sorted([(f.kind_label, f.device_id) for f in faults]);
    assert len(faults) == 4, found;
    _one(faults, FaultKind.LINE_DOWN, "F1-B");
    _one(faults, FaultKind.TX_FUSE, "T8");
    _one(faults, FaultKind.TX_FUSE, "T6");
    _one(faults, FaultKind.TX_FUSE, "T9");
    assert agents_parse.LLM_CALLS == 0, agents_parse.LLM_CALLS;
}

test "2: F1 is a line down on F1-B, 205 homes, a hazard, the hospital" {
    f1 = _one(_storm(), FaultKind.LINE_DOWN, "F1-B");
    assert f1.homes_affected == 205, f1.homes_affected;
    assert f1.hazard in [Hazard.WIRE_DOWN, Hazard.SPARKS], f1.hazard;
    assert "HOSPITAL" in f1.critical_loads, f1.critical_loads;
    assert "SCHOOL" in f1.critical_loads, f1.critical_loads;
}

test "3: F2 is a T8 fuse, 40 homes" {
    f2 = _one(_storm(), FaultKind.TX_FUSE, "T8");
    assert f2.homes_affected == 40, f2.homes_affected;
}

test "4: F3 is a T6 fuse, 50 homes, the water pump" {
    f3 = _one(_storm(), FaultKind.TX_FUSE, "T6");
    assert f3.homes_affected == 50, f3.homes_affected;
    assert "WATER_PUMP" in f3.critical_loads, f3.critical_loads;
}

test "5: before any crew report F4 is a T9 fuse at low confidence" {
    f4 = _one(_storm(), FaultKind.TX_FUSE, "T9");
    assert f4.confidence < 0.6, f4.confidence;
}

test "7: ranking puts F1 first, F3 second, then by homes" {
    faults = _storm();
    order = [f.device_id for f in faults];
    assert order[0] == "F1-B", order;
    assert order[1] == "T6", order;
    rest = [f.homes_affected for f in faults[2:]];
    assert rest == sorted(rest, reverse=True), order;
}

test "8: 5 duplicates are flagged and not double-counted" {
    _storm();
    items = complaint_log().items;
    dups = [c for c in items if c.is_duplicate];
    assert len(dups) == 5, len(dups);
    # Each transformer counts each reporting home once.
    homes_by_tx: dict[str, set[str]] = {};
    for c in items {
        if not c.is_duplicate and c.home_id != "" {
            tid = c.home_id.split("-")[1];
            if tid not in homes_by_tx {
                homes_by_tx[tid] = set();
            }
            homes_by_tx[tid].add(c.home_id);
        }
    }
    for n in grid_nodes(build_grid()) {
        if isinstance(n, Transformer) {
            want = len(homes_by_tx.get(n.id, set()));
            assert n.reports == want, f"{n.id}: {n.reports} reports for {want} homes";
        }
    }
}

test "9: the 3 false reports from T7 make no fault" {
    faults = _storm();
    t7 = [c for c in complaint_log().items if c.home_id.startswith("H-T7-")];
    assert len(t7) == 3, len(t7);
    assert all([f.device_id not in ["T7", "F2-A"] for f in faults]), [f.device_id for f in faults];
}

test "10: BD 4512300017 parses without the LLM and maps to the T3 home" {
    build_grid();
    agents_parse.reset_parse_stats();
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": []});
    c = Complaint(id="X0001", text="BD 4512300017", time_min=0.0);
    agents_parse.parse_batch([c]);
    assert c.consumer_no == "4512300017";
    assert c.home_id == "H-T3-017", c.home_id;
    assert c.hazard == Hazard.NONE;
    assert agents_parse.LLM_CALLS == 0;
}

test "11: a Sinhala wire-down complaint carries the WIRE_DOWN hazard" {
    _storm();
    si = [c for c in complaint_log().items if c.text == "කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා"];
    assert len(si) >= 1;
    assert all([c.hazard == Hazard.WIRE_DOWN and c.lang == Lang.SI for c in si]);
    assert all([c.home_id.split("-")[1] in ["T3", "T4", "T5"] for c in si]);
}
