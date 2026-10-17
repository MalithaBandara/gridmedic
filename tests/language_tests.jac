"""Non-English complaint scenarios (WP-A3): Sinhala script, Sinhala in Latin
letters ("Singlish") and Tamil.

These check what the pipeline does with such text without a real model:
consumer numbers and pole landmarks found in the raw text, one LLM call per
distinct phrase, duplicates across languages. The MockLLM stands in for the
model's answer; whether Gemini reads each language correctly is checked live
by scripts/smoke_llm.jac. Known gaps (Tamil pole word, Lang.TA, Sinhala-script
pole landmark) are in tests_pending/language_gaps_tests.jac.

Tamil phrases need a check by a native speaker, like the Sinhala ones in
CLAUDE.md §6.3.
    jac clean --all --force; jac test tests/language_tests.jac -v
"""

import agents_parse;
import from byllm.lib { MockLLM }
import from agents_parse { LlmParsed, parse_batch, flag_duplicates, landmark_section }
import from gm_types { Complaint, Hazard, Lang }
import from grid_build { build_grid }

glob SI_NO_POWER: str = "විදුලිය නැහැ";
glob SI_NOISE: str = "ට්‍රාන්ස්ෆෝමරයෙන් සද්දයක් ආවා";    # has a zero-width joiner
glob SINGLISH_NO_POWER: str = "widuliya naha";
glob SINGLISH_POLE: str = "kanuwa 23 langa wire ekak bima watila";
glob MIXED_POLE: str = "Pole 23 langa wire eka watila, current naha";
glob TA_NO_POWER: str = "மின்சாரம் இல்லை";
glob TA_WIRE: str = "கம்பத்துக்கு அருகில் கம்பி கீழே விழுந்து கிடக்கிறது";

# The model's answer for one batch: item k answers text k.
def _answers(parsed: list[LlmParsed]) {
    batch = [LlmParsed(index=k, lang=p.lang, hazard=p.hazard, landmark=p.landmark) for (k, p) in enumerate(parsed)];
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": [batch]});
    agents_parse.reset_parse_stats();
}

def _c(cid: str, text: str, t: float = 1.0, consumer: str = "") -> Complaint {
    return Complaint(id=cid, text=text, time_min=t, consumer_no=consumer);
}

test "Sinhala, Singlish and Tamil complaints find the home from a number in the text" {
    build_grid();
    _answers([LlmParsed(index=0, lang=Lang.SI, hazard=Hazard.NONE, landmark=""), LlmParsed(index=0, lang=Lang.SI, hazard=Hazard.NONE, landmark=""), LlmParsed(index=0, lang=Lang.MIXED, hazard=Hazard.NONE, landmark="")]);
    si = _c("L001", "4512300017 " + SI_NO_POWER);
    sl = _c("L002", SINGLISH_NO_POWER + ", account 4512800005");
    ta = _c("L003", TA_NO_POWER + " 4512600010");
    parse_batch([si, sl, ta]);
    assert si.home_id == "H-T3-017", si.home_id;
    assert sl.home_id == "H-T8-005", sl.home_id;
    assert ta.home_id == "H-T6-010", ta.home_id;
    assert si.lang == Lang.SI and sl.lang == Lang.SI;
    assert agents_parse.LLM_CALLS == 1;
}

test "a Singlish 'kanuwa 23' complaint maps to Pole 23 on F1-B" {
    build_grid();
    _answers([LlmParsed(index=0, lang=Lang.SI, hazard=Hazard.WIRE_DOWN, landmark="")]);
    c = _c("L010", SINGLISH_POLE, consumer="4512400003");
    parse_batch([c]);
    assert c.hazard == Hazard.WIRE_DOWN;
    assert c.landmark == "kanuwa 23", c.landmark;
    assert landmark_section(c.text) == "F1-B";
}

test "mixed Sinhala-English 'Pole 23 langa' maps to F1-B" {
    build_grid();
    _answers([LlmParsed(index=0, lang=Lang.MIXED, hazard=Hazard.WIRE_DOWN, landmark="pole 23")]);
    c = _c("L011", MIXED_POLE, consumer="4512300040");
    parse_batch([c]);
    assert c.lang == Lang.MIXED and c.landmark == "pole 23";
    assert landmark_section(c.text) == "F1-B";
}

test "each distinct phrase is parsed once, whatever its script, then cached" {
    build_grid();
    _answers([LlmParsed(index=0, lang=Lang.SI, hazard=Hazard.NONE, landmark=""), LlmParsed(index=0, lang=Lang.SI, hazard=Hazard.TRANSFORMER_NOISE, landmark=""), LlmParsed(index=0, lang=Lang.SI, hazard=Hazard.NONE, landmark=""), LlmParsed(index=0, lang=Lang.MIXED, hazard=Hazard.WIRE_DOWN, landmark="")]);
    texts = [SI_NO_POWER, SI_NOISE, SINGLISH_NO_POWER, TA_WIRE];
    first = [_c(f"L1{k:02d}", t, consumer=f"45125000{k + 10}") for (k, t) in enumerate(texts + texts)];
    parse_batch(first);
    assert agents_parse.LLM_CALLS == 1, agents_parse.LLM_CALLS;
    noise = [c for c in first if c.text == SI_NOISE];
    assert len(noise) == 2 and all([c.hazard == Hazard.TRANSFORMER_NOISE for c in noise]);
    # The same phrases again: all from the cache, no call.
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": []});
    agents_parse.reset_parse_stats();
    again = [_c(f"L2{k:02d}", t, consumer=f"45125000{k + 30}") for (k, t) in enumerate(texts)];
    parse_batch(again);
    assert agents_parse.LLM_CALLS == 0 and agents_parse.CACHE_HITS == 4;
    assert [c.hazard for c in again] == [Hazard.NONE, Hazard.TRANSFORMER_NOISE, Hazard.NONE, Hazard.WIRE_DOWN];
}

test "a repeat in another language within 10 minutes is a duplicate" {
    first = _c("L301", SI_NO_POWER, t=1.0, consumer="4512900004");
    tamil = _c("L302", TA_NO_POWER, t=5.0, consumer="4512900004");
    english = _c("L303", "Still no power", t=12.0, consumer="4512900004");
    flag_duplicates([first, tamil, english], []);
    assert not first.is_duplicate;
    assert tamil.is_duplicate;
    assert not english.is_duplicate;    # 11 minutes after the last counted report
}
