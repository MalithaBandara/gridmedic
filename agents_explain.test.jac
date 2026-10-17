"""WP-B6 unit tests: the cache key and the no-LLM fallback. The cached flow is in sim.test.jac."""

import agents_explain;
import from byllm.lib { MockLLM }
import from gm_types { FaultStatus, label_fault }

def _fault -> Fault {
    return label_fault(Fault(
        id="F1", kind=FaultKind.LINE_DOWN, device_id="F1-B", homes_affected=205,
        hazard=Hazard.WIRE_DOWN, critical_loads=["HOSPITAL"], priority=1745, confidence=0.95,
        evidence=["102 of 205 homes downstream of F1-B reported", "83 hazard reports mention Pole 23"]
    ));
}

test "the key ignores priority and age but not real changes" {
    a = _fault();
    k = fault_key(a);
    a.priority = 99;
    assert fault_key(a) == k;
    b = _fault();
    b.evidence = b.evidence + ["a new clue"];
    assert fault_key(b) != k;
    c = _fault();
    c.kind = FaultKind.SERVICE_WIRE;
    assert fault_key(c) != k;
    d = _fault();
    d.status = FaultStatus.CONFIRMED;
    assert fault_key(d) != k;
}

test "the fallback names the device, evidence, hazard, critical load and homes" {
    t = fallback_explanation(_fault());
    assert "F1-B" in t and "102 of 205" in t;
    assert "hazard" in t and "HOSPITAL" in t and "205 homes" in t;
    f = _fault();
    f.updated_by_crew = True;
    assert "crew report" in fallback_explanation(f);
}

test "explain_fault returns the model's text" {
    agents_explain.llm = MockLLM(model_name="mockllm", config={"outputs": ["Wire reports at pole 23. Ranked first for the hospital."]});
    assert explain_fault(_fault()).startswith("Wire reports");
}
