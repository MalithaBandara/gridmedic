"""Non-English gaps found while writing tests/language_tests.jac (WP-A3).

All three are in B's files; each test says what would make it pass.
    jac clean --all --force; jac test tests_pending/language_gaps_tests.jac -v
"""

import agents_parse;
import from byllm.lib { MockLLM }
import from agents_parse { LlmParsed, parse_batch, landmark_section }
import from gm_types { Complaint, Hazard, Lang }
import from grid_build { build_grid }

# Expected to fail until agents_parse._locate's landmark regex includes the
# Sinhala word: today it is (pole|kanuwa), so "කණුව 23" matches the Pole 23
# landmark but is saved as an empty landmark, and the hazard maps nowhere.
test "a Sinhala-script 'කණුව 23' complaint keeps its pole landmark" {
    build_grid();
    batch = [LlmParsed(index=0, lang=Lang.SI, hazard=Hazard.WIRE_DOWN, landmark="")];
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": [batch]});
    c = Complaint(id="G001", text="කණුව 23 ළඟ වයරයක් බිම වැටිලා", time_min=1.0, consumer_no="4512400007");
    parse_batch([c]);
    assert landmark_section(c.text) == "F1-B";
    assert c.landmark != "", "landmark text not saved";
}

# Expected to fail until the pole pattern (agents_parse.landmark_section and
# agents_group._matched_landmark) knows the Tamil word for pole (கம்பம்),
# with the number before or after it.
test "a Tamil 'pole 23' complaint maps to F1-B" {
    build_grid();
    assert landmark_section("23 ஆம் கம்பம் அருகே கம்பி விழுந்துள்ளது") == "F1-B";
    assert landmark_section("கம்பம் 23 அருகே மின்சாரம் இல்லை") == "F1-B";
}

# Expected to fail until gm_types adds Lang.TA (contract change, needs B), and
# the parser's sem mentions Tamil.
test "Tamil has its own language value" {
    assert "TA" in [m.name for m in Lang];
}
