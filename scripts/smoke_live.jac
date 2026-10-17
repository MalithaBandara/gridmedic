# Minimal live Gemini pass over the paths MockLLM tests cannot prove.
# Expected real requests: ~5 = storm parse (2, from ~14 distinct texts) + 1 crew report
# + 1 explanation + 1 customer parse. byllm may retry malformed output.
# Run it from a COPY of the repo (own .jac/data), never beside a running dev server:
#   jac run scripts/smoke_live.jac
# Needs GEMINI_API_KEY and JAC_OPT_LEVEL=0.

import agents_parse;
import from agents_parse { bd_number }
import from grid_storm { generate_complaints }
import from gm_types { FaultKind, Hazard }
import from sim {
    storm_start, storm_tick, ranked_faults, apply_crew_report, explain, submit
}

with entry:__main__ {
    # Guard: refuse to start if the storm would need many requests.
    distinct: list[str] = [];
    for c in generate_complaints(17) {
        if bd_number(c.text) == "" and c.text not in distinct {
            distinct.append(c.text);
        }
    }
    est: int = (len(distinct) + 9) // 10;
    print(f"distinct free-text complaints: {len(distinct)} -> about {est} storm requests");
    if est > 3 {
        print("ABORT: more storm requests than expected, nothing was sent");
    } else {
        agents_parse.reset_parse_stats();
        storm_start(5);
        for _ in range(42) {
            storm_tick(0.5);
        }
        print(f"STORM: {agents_parse.LLM_CALLS} LLM calls, {agents_parse.CACHE_HITS} cache hits");
        faults = ranked_faults();
        for f in faults {
            print(f"  {f.id} {f.kind_label} @ {f.device_id} homes={f.homes_affected} hazard={f.hazard_label} conf={f.confidence} prio={f.priority}");
        }
        f1 = [f for f in faults if f.device_id == "F1-B"];
        if f1 {
            print(f"F1 hazard live: {'OK' if f1[0].hazard_label != 'NONE' and f1[0].hazard_label != '' else 'MISSING'}");

            r = apply_crew_report("CREW-A", "Conductor snapped at pole 23, area made safe. Repair needs ~90 min.");
            print(f"CREW REPORT: {r.id} {r.kind_label} status={r.status} eta={r.eta_min} note={r.change_note}");

            e = explain(f1[0].id);
            tag: str = "FALLBACK (LLM failed)" if e.explanation_key.startswith("fallback:") else "LIVE";
            print(f"EXPLAIN [{tag}]: {e.explanation}");
        } else {
            print("F1 not found, skipping crew report and explanation");
        }
        c = submit("අද උදේ ඉඳන් අපේ ගෙදර විදුලිය නෑ, මොකක්ද වුණේ", "4512700001");
        print(f"CUSTOMER: lang={c.lang.name} hazard={c.hazard.name} landmark='{c.landmark}'");
    }
}
