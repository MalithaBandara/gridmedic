"""Transmission line acceptance tests: TL1 (132 kV) feeds SS1.

The blackout scenario trips TL1. Every home goes dark, and the agents must
work out from complaints alone that one TRANSMISSION fault at TL1 explains
all of them, not one line fault per feeder. The normal storm must never
blame the transmission line.
"""

import agents_parse;
import from byllm.lib { MockLLM }
import from agents_parse { LlmParsed }
import from gm_types { Hazard, Lang, FaultKind, Fault, GridNodeView }
import from sim {
    storm_start, storm_tick, storm_reset, ranked_faults, counters, grid_view,
    customer_status, actions
}

def _mock_llm {
    item = LlmParsed(index=0, lang=Lang.EN, hazard=Hazard.NONE, landmark="");
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": [[item] for _ in range(60)] + [item for _ in range(10)]});
}

def _node(view_id: str) -> GridNodeView {
    return [n for n in grid_view().nodes if n.id == view_id][0];
}

test "tripping TL1 blacks out the whole grid" {
    _mock_llm();
    storm_start(5, "blackout");
    assert not _node("TL1").energised;
    assert not _node("SS1").energised;
    assert counters().homes_off == 600;
    assert len([e for e in grid_view().edges if e.kind == "transmission"]) == 1;
}

test "complaints from every feeder are traced to one transmission fault" {
    for _ in range(26) {
        storm_tick(0.5);
    }
    faults: list[Fault] = ranked_faults();
    assert len(faults) == 1;
    f = faults[0];
    assert f.kind == FaultKind.TRANSMISSION and f.device_id == "TL1";
    assert f.kind_label == "Transmission line";
    assert f.homes_affected == 600;
    assert "HOSPITAL" in f.critical_loads and "WATER_PUMP" in f.critical_loads;
    assert _node("TL1").status != "normal";
}

test "every customer sees the transmission fault" {
    f = ranked_faults()[0];
    assert customer_status("4512700001").fault_id == f.id;    # T7 home 1, feeder 2
    assert customer_status("4512100001").fault_id == f.id;    # T1 home 1, feeder 1
}

test "the hospital microgrid can still island during the blackout" {
    safe = [a for a in actions() if a.id == "ACT-MG-HOSP-START"];
    assert len(safe) == 1 and safe[0].safe;
}

test "reset restores the transmission line" {
    storm_reset();
    assert _node("TL1").energised and _node("SS1").energised;
    assert counters().homes_off == 0;
}

test "the normal storm never blames the transmission line" {
    _mock_llm();
    storm_start(5);
    for _ in range(42) {
        storm_tick(0.5);
    }
    assert _node("TL1").energised;
    assert len(ranked_faults()) >= 1;
    assert len([f for f in ranked_faults() if f.kind == FaultKind.TRANSMISSION]) == 0;
}
