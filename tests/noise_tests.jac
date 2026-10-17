"""Acceptance tests 8 and 9 (CLAUDE.md §11), checked through the sim pipeline.

8: the 5 duplicates are flagged and not double-counted.
9: the 3 false reports from T7 (which has power) produce no fault.
Offline like acceptance_tests.jac: the ParseCache is preloaded and no LLM is called.
Run after `jac clean --all --force`, with no dev server running.
"""

import agents_parse;
import from byllm.lib { MockLLM }
import from gm_types { Hazard, Lang, FaultKind, ParsedText }
import from grid_storm { generate_complaints }
import from sim { storm_start, storm_tick, ranked_faults, complaint_log }

def _preload {
    entries: dict[str, ParsedText] = {};
    for c in generate_complaints(17) {
        if c.text.startswith("BD") {
            continue;
        }
        low = c.text.lower();
        haz = Hazard.NONE;
        if "spark" in low or "ගිනි පුපුරු" in low {
            haz = Hazard.SPARKS;
        } elif "wire" in low or "වයර" in low {
            haz = Hazard.WIRE_DOWN;
        }
        lm = "pole 23" if ("pole" in low or "කණුව" in low) else "";
        entries[agents_parse._cache_key(c.text)] = ParsedText(index=0, lang=Lang.EN, hazard=haz, landmark=lm);
    }
    agents_parse._cache().entries = entries;
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": []});
    agents_parse.reset_parse_stats();
}

def _run_storm {
    if len(complaint_log().items) > 100 {
        return;
    }
    _preload();
    storm_start(5);
    for _ in range(42) {
        storm_tick(0.5);
    }
}

def _t7_numbers -> list[str] {
    return [c.consumer_no for c in generate_complaints(17) if c.consumer_no.startswith("45127")];
}

test "five duplicates are flagged and not counted twice (test 8)" {
    _run_storm();
    items = complaint_log().items;
    dups = [c for c in items if c.is_duplicate];
    assert len(dups) == 5, len(dups);
    for d in dups {
        firsts = [c for c in items if c.consumer_no == d.consumer_no and not c.is_duplicate];
        assert len(firsts) == 1, d.consumer_no;
        assert firsts[0].time_min <= d.time_min;
        assert d.time_min - firsts[0].time_min <= 10.0;
    }
    # Every non-duplicate complaint with a number is distinct
    nums = [c.consumer_no for c in items if c.consumer_no != "" and not c.is_duplicate];
    assert len(nums) == len(set(nums));
}

test "false reports from T7 create no fault (test 9)" {
    _run_storm();
    t7 = _t7_numbers();
    assert len(t7) == 3, len(t7);
    seen = [c for c in complaint_log().items if c.consumer_no in t7];
    assert len(seen) == 3;
    faults = ranked_faults();
    assert len(faults) == 4;
    for f in faults {
        assert f.device_id != "T7";
        assert f.device_id in ["F1-B", "T6", "T8", "T9"], f.device_id;
    }
}
