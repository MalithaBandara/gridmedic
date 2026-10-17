"""Pipeline tests. LLM swapped for MockLLM; generic checks that hold for any
scenario. The exact F1-F4 expectations live in A3's tests/*_tests.jac."""

import agents_parse;
import agents_feedback;
import agents_explain;
import from byllm.lib { MockLLM }
import from agents_parse { LlmParsed }
import from agents_feedback { CrewFinding }
import from gm_types { Hazard, Lang }
import from grid { ParseCache }

def _mock_llm {
    # Same answer for every batch, one item per text (batches hold up to 10
    # texts; unanswered texts fall back uncached); enough for several calls.
    item = LlmParsed(index=0, lang=Lang.EN, hazard=Hazard.WIRE_DOWN, landmark="pole 23");
    batch = [LlmParsed(index=k, lang=Lang.EN, hazard=Hazard.WIRE_DOWN, landmark="pole 23") for k in range(10)];
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": [batch for _ in range(40)] + [item for _ in range(10)]});
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

# ------------------------------------------------------- WP-B5 crew reports
def _crew_fixture {
    storm_start(1);
    root ++> FaultNode(fault=Fault(id="F1", kind=FaultKind.LINE_DOWN, device_id="F1-B", homes_affected=205, confidence=0.8));
    root ++> FaultNode(fault=Fault(id="F2", kind=FaultKind.TX_FUSE, device_id="T8", homes_affected=40, confidence=0.8));
    root ++> FaultNode(fault=Fault(id="F4", kind=FaultKind.TX_FUSE, device_id="T9", homes_affected=75, confidence=0.4));
}

def _mock_crew(f: CrewFinding) {
    agents_feedback.llm = MockLLM(model_name="mockllm", config={"outputs": [f]});
}

def _node(nid: str) -> any {
    for n in _all_grid_nodes() {
        if n.id == nid {
            return n;
        }
    }
    return None;
}

test "crew report turns the T9 fuse guess into a Lake Road service wire" {
    _crew_fixture();
    _mock_crew(CrewFinding(fault_id="F4", device_ok=True, new_kind=FaultKind.SERVICE_WIRE, street="Lake Road", note="Overhead service line down on Lake Road"));
    f = apply_crew_report("C", "T9 transformer is fine, fuses OK. Other streets have power. Overhead service line down on Lake Road.");
    assert f.id == "F4" and f.kind == FaultKind.SERVICE_WIRE and f.street == "Lake Road";
    assert f.homes_affected == 15 and f.confidence >= 0.8 and f.updated_by_crew;
    assert f.status == FaultStatus.CONFIRMED;
    assert f.change_note == "TX_FUSE@T9 (conf 0.4) -> SERVICE_WIRE@Lake Road (conf 0.9) - crew report";
    ev = [e for e in event_log().events if e.kind == "mind_change"];
    assert len(ev) == 1 and ev[0].fault_id == "F4" and "TX_FUSE@T9" in ev[0].text;
}

test "crew report confirms the line fault by landmark and sets the repair eta" {
    _crew_fixture();
    _mock_crew(CrewFinding(fault_id="F1", device_ok=False, new_kind=FaultKind.LINE_DOWN, repair_eta_min=90, note="Conductor snapped at pole 23"));
    f = apply_crew_report("A", "Conductor snapped at pole 23, area made safe. Repair needs ~90 min.");
    assert f.id == "F1" and f.status == FaultStatus.CONFIRMED and f.eta_min == 90;
    assert f.kind == FaultKind.LINE_DOWN and f.homes_affected == 205;
    assert len([e for e in event_log().events if e.kind == "mind_change"]) == 0;
}

test "a restored report puts the physical truth back to ok" {
    _crew_fixture();
    assert not _node("T8").fuse_ok;
    _mock_crew(CrewFinding(fault_id="F2", device_ok=False, new_kind=FaultKind.TX_FUSE, restored=True, note="Fuse replaced"));
    f = apply_crew_report("B", "T8 HT fuse blown, replaced. Supply restored.");
    assert f.id == "F2" and f.status == FaultStatus.RESTORED;
    assert _node("T8").fuse_ok;
    assert ranked_faults()[-1].id == "F2";
    assert len([e for e in event_log().events if e.kind == "restored"]) == 1;
}

test "a repaired line clears the recloser lockout" {
    _crew_fixture();
    assert not _node("F1-B").line_ok and _node("SW1").locked_out;
    _mock_crew(CrewFinding(fault_id="F1", device_ok=False, new_kind=FaultKind.LINE_DOWN, restored=True));
    apply_crew_report("A", "Conductor repaired at pole 23, line restored");
    assert _node("F1-B").line_ok and not _node("SW1").locked_out and _node("SW1").closed;
}

test "a report that matches no fault changes nothing" {
    _crew_fixture();
    _mock_crew(CrewFinding(fault_id="", device_ok=True, new_kind=FaultKind.UNKNOWN));
    f = apply_crew_report("C", "all quiet at the depot");
    assert f.id == "" and "does not match" in f.change_note;
    assert len([e for e in event_log().events if e.kind == "mind_change"]) == 0;
}

test "an LLM failure leaves the fault alone and logs parse_failed" {
    _crew_fixture();
    agents_feedback.llm = MockLLM(model_name="mockllm", config={"outputs": []});
    f = apply_crew_report("C", "T9 is fine, Lake Road line down");
    assert f.id == "F4" and f.kind == FaultKind.TX_FUSE and not f.updated_by_crew;
    assert len([e for e in event_log().events if e.kind == "parse_failed"]) == 1;
}

# ------------------------------------------------------- WP-B6 explanations
def _mock_explain(outputs: list) {
    agents_explain.llm = MockLLM(model_name="mockllm", config={"outputs": outputs});
}

test "explain caches the text and does not call the LLM again" {
    _crew_fixture();
    _mock_explain(["Complaints cluster under T8. Ranked by homes."]);
    a = explain("F2");
    assert a.explanation == "Complaints cluster under T8. Ranked by homes.";
    b = explain("F2");    # the mock has no output left: a second call would fail
    assert b.explanation == a.explanation;
    assert [e.kind for e in event_log().events].count("explain_failed") == 0;
}

test "explain recomputes after a crew report changes the fault" {
    _crew_fixture();
    _mock_explain(["First reading of T9.", "After the crew: a Lake Road wire."]);
    assert explain("F4").explanation == "First reading of T9.";
    _mock_crew(CrewFinding(fault_id="F4", device_ok=True, new_kind=FaultKind.SERVICE_WIRE, street="Lake Road", note="line down"));
    apply_crew_report("C", "T9 fine, Lake Road line down");
    _mock_explain(["After the crew: a Lake Road wire."]);
    assert explain("F4").explanation == "After the crew: a Lake Road wire.";
}

test "an LLM failure falls back to the evidence summary and is retried" {
    _crew_fixture();
    _mock_explain([]);
    a = explain("F1");
    assert "F1-B" in a.explanation and "205 homes" in a.explanation;
    assert [e.kind for e in event_log().events].count("explain_failed") == 1;
    explain("F1");
    assert [e.kind for e in event_log().events].count("explain_failed") == 1;    # logged once
    _mock_explain(["Real model text."]);
    assert explain("F1").explanation == "Real model text.";
}

test "explain on an unknown fault returns an empty fault" {
    _crew_fixture();
    assert explain("F99").id == "";
}
