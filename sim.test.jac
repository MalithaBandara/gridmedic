"""Pipeline tests. LLM swapped for MockLLM; generic checks that hold for any
scenario. The exact F1-F4 expectations live in A3's tests/*_tests.jac."""

import agents_parse;
import from byllm.lib { MockLLM }
import from agents_parse { LlmParsed }
import from gm_types { Hazard, Lang }
import from grid { ParseCache }

def _mock_llm {
    # Same answer for every batch; enough outputs for several calls.
    item = LlmParsed(index=0, lang=Lang.EN, hazard=Hazard.WIRE_DOWN, landmark="pole 23");
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": [[item] for _ in range(40)] + [item for _ in range(10)]});
}

def _run_storm(ticks: int) {
    storm_start(5);
    for _ in range(ticks) {
        storm_tick(0.5);
    }
}

test "a full storm releases every complaint and finds ranked faults" {
    _mock_llm();
    _run_storm(42);
    st = sim_state();
    assert st.clock_min >= 20.0;
    assert st.next_complaint_idx == len(_scenario());
    assert len(complaint_log().items) == len(_scenario());
    faults = ranked_faults();
    assert len(faults) >= 1;
    pr: list[int] = [f.priority for f in faults];
    assert pr == sorted(pr, reverse=True);
    assert all([f.kind_label != "" for f in faults]);
    kinds: list[str] = [e.kind for e in event_log().events];
    assert "storm" in kinds and "fault_new" in kinds;
}

test "counters and grid view come from the graph" {
    v = grid_view();
    homes: int = len([n for n in v.nodes if n.kind == "home"]);
    assert homes == 600;
    assert len([n for n in v.nodes if n.kind == "depot"]) == 2;
    assert len([n for n in v.nodes if n.kind == "crew"]) == 3;
    assert len([e for e in v.edges if e.kind == "tie"]) == 2;
    assert v.counters.complaints == len(complaint_log().items);
    assert v.counters.faults == len(ranked_faults());
    assert len([n for n in v.nodes if n.status != "normal" and n.kind != "crew"]) >= 1;
}

test "customer status finds the fault above a home" {
    faulted = [f for f in ranked_faults() if f.device_id.startswith("T")];
    if faulted {
        n: int = int(faulted[0].device_id[1:]);
        consumer: str = "451" + str(20 + n) + "00001";
        s = customer_status(consumer);
        assert s.fault_id == faulted[0].id;
        assert "Fault found" in s.status_text;
    }
    assert "not found" in customer_status("0000000000").status_text;
    assert event_log().events[-1].kind == "status_checked";
}

test "submit_complaint parses, logs and counts a customer report" {
    before: int = len(complaint_log().items);
    c = submit("BD 4512100005", "");
    assert c.id.startswith("U") and c.home_id == "H-T1-005";
    assert len(complaint_log().items) == before + 1;
    again = submit("BD 4512100005", "");
    assert again.is_duplicate;
}

test "reset clears the storm but keeps the parse cache" {
    cached: int = len([root -->[?:ParseCache]][0].entries);
    storm_reset();
    assert len([root -->[?:FaultNode]]) == 0;
    assert len(complaint_log().items) == 0;
    assert sim_state().clock_min == 0.0 and not sim_state().running;
    assert len([root -->[?:ParseCache]][0].entries) == cached;
}

test "a replay after reset makes no LLM calls" {
    agents_parse.reset_parse_stats();
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": []});
    _run_storm(42);
    assert agents_parse.LLM_CALLS == 0;
    assert len(ranked_faults()) >= 1;
}
