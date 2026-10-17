"""Island-wide blackout acceptance tests: the national grid collapses.

Every home is dark and about half of them complain within 15 minutes, in
English, Sinhala script, Singlish and Tamil, many saying the whole country is
off. From the complaints alone the agents must name ONE fault upstream of SS1
(TRANSMISSION at TL1), not a fault per transformer or feeder, tell every
customer about it, and keep crews out of the distribution grid.

No LLM is called: the parse cache is preloaded with the true parse of every
scenario phrase (no hazards; Tamil is MIXED until gm_types has Lang.TA).
    jac clean --all --force; jac test tests/island_blackout_tests.jac -v
"""

import agents_parse;
import from byllm.lib { MockLLM }
import from gm_types { Fault, FaultKind, Hazard, Lang, ParsedText, GridNodeView }
import from grid { ParseCache }
import from grid_build { build_grid }
import from scenario_island {
    island_complaints,
    EN_TEXTS,
    SI_TEXTS,
    SINGLISH_TEXTS,
    TA_TEXTS,
    UNLOCATABLE,
    ISLAND_LENGTH_MIN
}
import from sim {
    storm_start,
    storm_tick,
    storm_reset,
    ranked_faults,
    counters,
    grid_view,
    customer_status,
    actions,
    tasks,
    complaint_log,
    event_log,
    sim_state,
    _active_scenario
}

glob TICK_MIN: float = 0.5;

def _true_parse -> dict[str, ParsedText] {
    out: dict[str, ParsedText] = {};
    for t in EN_TEXTS + [UNLOCATABLE[0][0]] {
        out[t] = ParsedText(index=0, lang=Lang.EN, hazard=Hazard.NONE, landmark="");
    }
    for t in SI_TEXTS + SINGLISH_TEXTS {
        out[t] = ParsedText(index=0, lang=Lang.SI, hazard=Hazard.NONE, landmark="");
    }
    for t in TA_TEXTS + [UNLOCATABLE[1][0]] {
        out[t] = ParsedText(index=0, lang=Lang.MIXED, hazard=Hazard.NONE, landmark="");
    }
    return out;
}

def _start {
    build_grid();
    found = [root -->[?:ParseCache]];
    cache = found[0] if found else (root ++> ParseCache())[0] as ParseCache;
    entries: dict[str, ParsedText] = dict(cache.entries);
    for (text, p) in _true_parse().items() {
        entries[agents_parse._cache_key(text)] = p;
    }
    cache.entries = entries;
    agents_parse.reset_parse_stats();
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": []});
    storm_start(5, scenario="island");
}

# Plays the whole flood once; later tests read the result.
def _flood -> list[Fault] {
    while sim_state().running and sim_state().clock_min < ISLAND_LENGTH_MIN + TICK_MIN {
        storm_tick(TICK_MIN);
    }
    return ranked_faults();
}

def _node(view_id: str) -> GridNodeView {
    return [n for n in grid_view().nodes if n.id == view_id][0];
}

test "the collapse blacks out all 600 homes and both feeders" {
    _start();
    assert counters().homes_off == 600, counters().homes_off;
    assert not _node("TL1").energised and not _node("SS1").energised;
    assert not _node("F1-A").energised and not _node("F2-A").energised;
    assert event_log().events[0].text.startswith("Island-wide blackout");
    assert _active_scenario() == "island";
}

test "the whole flood arrives, from every transformer, in five formats" {
    _flood();
    items = complaint_log().items;
    assert len(items) == len(island_complaints()) and len(items) >= 250, len(items);
    txs = set([c.home_id.split("-")[1] for c in items if c.home_id != ""]);
    assert len(txs) == 10, sorted(txs);
    texts = set([c.text for c in items]);
    assert any([t.startswith("BD ") for t in texts]);
    for group in [EN_TEXTS, SI_TEXTS, SINGLISH_TEXTS, TA_TEXTS] {
        assert any([t in texts for t in group]), group;
    }
}

test "one transmission fault at TL1 explains all 600 homes" {
    faults = _flood();
    assert len(faults) == 1, [(f.kind_label, f.device_id) for f in faults];
    f = faults[0];
    assert f.kind == FaultKind.TRANSMISSION and f.device_id == "TL1", (f.kind_label, f.device_id);
    assert f.homes_affected == 600, f.homes_affected;
    for load in ["HOSPITAL", "WATER_PUMP", "SCHOOL", "POLICE"] {
        assert load in f.critical_loads, f.critical_loads;
    }
    assert f.hazard == Hazard.NONE;
}

test "the flood costs no LLM calls" {
    _flood();
    assert agents_parse.LLM_CALLS == 0, agents_parse.LLM_CALLS;
    langs = set([c.lang for c in complaint_log().items if not c.text.startswith("BD ")]);
    assert langs == set([Lang.EN, Lang.SI, Lang.MIXED]), langs;
}

test "repeats are duplicates and unlocatable reports make no fault" {
    _flood();
    items = complaint_log().items;
    assert len([c for c in items if c.is_duplicate]) == 8;
    lost = [c for c in items if c.consumer_no == ""];
    assert len(lost) == 2 and all([c.home_id == "" for c in lost]);
    assert len(ranked_faults()) == 1;
}

test "a customer under every transformer is told about the TL1 fault" {
    f = _flood()[0];
    for n in range(1, 11) {
        consumer = "451" + str(20 + n) + "00001";
        s = customer_status(consumer);
        assert s.fault_id == f.id, f"T{n}: {s.fault_id} {s.status_text}";
        assert not s.has_power;
    }
}

# Holds trivially until WP-C4 builds the Dispatcher; after that it checks the
# Dispatcher skips a TRANSMISSION fault, which no distribution crew can fix.
test "no crews are sent into the distribution grid" {
    _flood();
    assert tasks() == [], [(t.crew_id, t.fault_id) for t in tasks()];
}

test "the hospital microgrid can island while the country is dark" {
    _flood();
    start = [a for a in actions() if a.id == "ACT-MG-HOSP-START"];
    assert len(start) == 1 and start[0].safe, [(a.id, a.safe) for a in actions()];
}

test "reset ends the island blackout" {
    storm_reset();
    assert _node("TL1").energised and _node("SS1").energised;
    assert counters().homes_off == 0;
    assert _active_scenario() == "storm";
}
