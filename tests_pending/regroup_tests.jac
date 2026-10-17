"""Regrouping gap found while writing tests/field_tests.jac (WP-A3), for B.

When the parser cannot flag hazards (the LLM is down: every free text falls
back to "no hazard"), F1 is found from the tallies a minute or so later than
from the Pole 23 reports. Before that, the Dispatcher sends crews to early
TX_FUSE guesses at T4 / T5. Once LINE_DOWN at F1-B explains those
transformers, the guesses stay, because group_faults only drops guesses with
no crew. The same cleanup group_faults now does for a TRANSMISSION fault
(drop the guesses it explains; the Dispatcher recalls the crew) is needed for
LINE_DOWN, for the transformers under the faulted section.
    jac clean --all --force; jac test tests_pending/regroup_tests.jac -v
"""

import agents_parse;
import from byllm.lib { MockLLM }
import from gm_types { FaultKind }
import from grid_build { build_grid }
import from sim { storm_start, storm_tick, ranked_faults }

# Expected to fail until group_faults drops the guesses a LINE_DOWN explains.
test "without hazard parses the storm still ends with exactly F1-F4" {
    build_grid();
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": []});
    storm_start(5);
    for _ in range(42) {
        storm_tick(0.5);
    }
    found = sorted([(f.kind_label, f.device_id) for f in ranked_faults()]);
    under_f1 = [f for f in ranked_faults() if f.kind == FaultKind.TX_FUSE and f.device_id in ["T3", "T4", "T5"]];
    assert under_f1 == [], found;
    assert len(ranked_faults()) == 4, found;
}
