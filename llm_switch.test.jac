"""Mock/real language-model switch.

Mock mode must never reach Gemini and never write the persisted ParseCache. No Gemini
key is needed to run this file; any real call would fail loudly.
    jac clean --all --force; jac test llm_switch.test.jac -v
"""

import agents_parse;
import from gm_types { FaultKind, FaultStatus, Fault, Hazard, Lang }
import from grid { ParseCache }

import agents_feedback;
import from sim {
    storm_start, storm_tick, storm_reset, ranked_faults, explain, apply_crew_report
}

def _run(scenario: str, ticks: int) {
    set_mode("mock");
    agents_parse.reset_parse_stats();
    storm_start(5, False, scenario);
    for _ in range(ticks) {
        storm_tick(0.5);
    }
}

def _cache_size -> int {
    found = [root -->[?:ParseCache]];
    return len(found[0].entries) if found else 0;
}

test "the default is real, and anything but mock means real" {
    assert current_mode() == "real";
    assert set_mode("mock") == "mock" and is_mock();
    assert set_mode("bogus") == "real" and not is_mock();
}

test "mock parse reads the brief's hazards, languages and the pole landmark" {
    a = agents_parse.mock_parse("කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා");
    assert a.hazard == Hazard.WIRE_DOWN and a.lang == Lang.SI;
    assert agents_parse.mock_parse("ගිනි පුපුරු එනවා").hazard == Hazard.SPARKS;
    assert agents_parse.mock_parse("ට්‍රාන්ස්ෆෝමරයෙන් සද්දයක් ආවා").hazard == Hazard.TRANSFORMER_NOISE;
    assert agents_parse.mock_parse("විදුලිය නැහැ").hazard == Hazard.NONE;
    b = agents_parse.mock_parse("Wire fallen on the road near pole 23, sparks!");
    assert b.hazard == Hazard.SPARKS and b.landmark == "pole 23" and b.lang == Lang.EN;
    c = agents_parse.mock_parse("kanuwa 23 langa wire ekak bima watila");
    assert c.landmark == "pole 23" and c.hazard == Hazard.WIRE_DOWN;
    assert agents_parse.mock_parse("Power cut in our area, please send someone").hazard == Hazard.NONE;
}

test "mock crew finding turns the four sample reports into the expected updates" {
    t9 = Fault(id="F-A", kind=FaultKind.TX_FUSE, device_id="T9", homes_affected=75, confidence=0.4);
    f = agents_feedback.mock_crew_finding("T9 transformer is fine, fuses OK. Other streets have power. Overhead service line down on Lake Road.", t9);
    assert f.device_ok and f.new_kind == FaultKind.SERVICE_WIRE and f.street == "Lake Road" and not f.restored;
    f1 = Fault(id="F-B", kind=FaultKind.LINE_DOWN, device_id="F1-B", homes_affected=205);
    g = agents_feedback.mock_crew_finding("Conductor snapped at pole 23, area made safe. Repair needs ~90 min.", f1);
    assert g.new_kind == FaultKind.LINE_DOWN and g.repair_eta_min == 90 and not g.restored;
    t8 = Fault(id="F-C", kind=FaultKind.TX_FUSE, device_id="T8", homes_affected=40);
    h = agents_feedback.mock_crew_finding("T8 HT fuse blown, replaced. Supply restored.", t8);
    assert h.restored and h.new_kind == FaultKind.TX_FUSE;
    t6 = Fault(id="F-D", kind=FaultKind.TX_FUSE, device_id="T6", homes_affected=50);
    assert agents_feedback.mock_crew_finding("T6 fuse replaced, pump running.", t6).restored;
}

test "a mock storm finds F1-F4 with zero model calls and an untouched cache" {
    storm_reset();
    before: int = _cache_size();
    _run("storm", 42);
    assert agents_parse.LLM_CALLS == 0;
    assert _cache_size() == before;
    faults = ranked_faults();
    assert len(faults) == 4;
    f1 = [f for f in faults if f.device_id == "F1-B"];
    assert f1 and f1[0].kind == FaultKind.LINE_DOWN and f1[0].homes_affected == 205;
    assert f1[0].hazard != Hazard.NONE and faults[0].device_id == "F1-B";
    t9 = [f for f in faults if f.device_id == "T9"];
    assert t9 and t9[0].kind == FaultKind.TX_FUSE and t9[0].confidence < 0.6;
    set_mode("real");
}

test "in mock mode the crew report and the Why? panel make no model call either" {
    set_mode("mock");
    t9 = [f for f in ranked_faults() if f.device_id == "T9"];
    assert t9;
    done = apply_crew_report("CREW-C", "T9 transformer is fine, fuses OK. Other streets have power. Overhead service line down on Lake Road.");
    assert done.kind == FaultKind.SERVICE_WIRE and done.street == "Lake Road" and done.homes_affected == 15;
    e = explain(done.id);
    assert e.explanation != "" and e.explanation_key.startswith("mock:");
    set_mode("real");
}

test "blackout and island scenarios also run in mock mode without a model call" {
    storm_reset();
    _run("blackout", 36);
    assert agents_parse.LLM_CALLS == 0;
    assert len([f for f in ranked_faults() if f.kind == FaultKind.TRANSMISSION]) == 1;
    storm_reset();
    _run("island", 36);
    assert agents_parse.LLM_CALLS == 0;
    assert len([f for f in ranked_faults() if f.kind == FaultKind.TRANSMISSION]) == 1;
    set_mode("real");
}
