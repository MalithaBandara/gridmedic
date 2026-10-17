"""Parser unit tests. No real LLM: the module's `llm` is swapped for MockLLM."""

import agents_parse;
import from byllm.lib { MockLLM }
import from grid { Feeds, Located, Transformer }

def _fixture {
    if [root -->[?:Substation]] {
        return;
    }
    ss = Substation(id="SS1", name="Moratuwa Grid Substation", x=200, y=300);
    sec = Section(id="F1-B", feeder="F1", x=550, y=150);
    tx = Transformer(id="T3", homes=80, feeder="F1", x=520, y=90, critical=["HOSPITAL"]);
    root ++> ss;
    ss +>:Feeds:+> sec;
    sec +>:Feeds:+> tx;
    for i in [17, 18, 42] {
        tx +>:Feeds:+> Home(id=f"H-T3-{i:03d}", consumer_no=f"45123{i:05d}", street="Hospital Road", transformer_id="T3");
    }
    lm = Landmark(id="POLE-23", name="Pole 23", section_id="F1-B", x=560, y=150);
    root ++> lm;
    lm +>:Located:+> sec;
}

def _mock(outputs: list) {
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": outputs});
}

test "BD SMS parses without the LLM and maps to the T3 home" {
    _fixture();
    reset_parse_stats();
    _mock([]);
    c = Complaint(id="C0001", text="BD 4512300017", time_min=0.5);
    parse_batch([c]);
    assert c.consumer_no == "4512300017";
    assert c.home_id == "H-T3-017";
    assert c.hazard == Hazard.NONE;
    assert agents_parse.LLM_CALLS == 0;
    assert agents_parse.BD_SKIPS == 1;
    assert bd_number("bd4512300017") == "4512300017";
    assert bd_number("BD 451230001") == "";
}

test "free text is batched once per distinct text and cached" {
    _fixture();
    reset_parse_stats();
    _mock([[
        LlmParsed(index=0, lang=Lang.SI, hazard=Hazard.WIRE_DOWN, landmark="pole"),
        LlmParsed(index=1, lang=Lang.EN, hazard=Hazard.NONE)
    ]]);
    a = Complaint(id="C0002", text="කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා", time_min=1.0, consumer_no="4512300018");
    b = Complaint(id="C0003", text="No power since 7pm", time_min=1.2, consumer_no="4512300042");
    a2 = Complaint(id="C0004", text="  කණුව ළඟ වයරයක් බිම වැටිලා   තියෙනවා ", time_min=1.5, consumer_no="4512300017");
    parse_batch([a, b, a2]);
    assert agents_parse.LLM_CALLS == 1;
    assert a.lang == Lang.SI and a.hazard == Hazard.WIRE_DOWN;
    assert a2.hazard == Hazard.WIRE_DOWN;
    assert b.lang == Lang.EN and b.hazard == Hazard.NONE;
    assert a.home_id == "H-T3-018";
    assert len([root -->[?:ParseCache]]) == 1;
}

test "cache hit path makes no LLM call" {
    reset_parse_stats();
    _mock([]);
    c = Complaint(id="C0005", text="No power since 7pm", time_min=3.0);
    parse_batch([c]);
    assert agents_parse.LLM_CALLS == 0;
    assert agents_parse.CACHE_HITS == 1;
    assert c.lang == Lang.EN;
}

test "LLM failure falls back without crashing and logs an event" {
    reset_parse_stats();
    _mock([]);    # no outputs left: the mock call raises
    c = Complaint(id="C0006", text="Lights went off with a loud bang", time_min=4.0);
    parse_batch([c]);
    assert c.lang == Lang.MIXED and c.hazard == Hazard.NONE;
    logs = [root -->[?:EventLog]];
    assert logs and any([e.kind == "parse_failed" for e in logs[0].events]);
    assert "Lights went off with a loud bang" not in [root -->[?:ParseCache]][0].entries;
}

test "landmark-only complaint maps to its section" {
    _fixture();
    assert landmark_section("Wire fallen on the road near pole 23, sparks!") == "F1-B";
    assert landmark_section("near Pole No. 23") == "F1-B";
    assert landmark_section("pole 230") == "";
    assert landmark_section("near the temple") == "";
}

test "duplicates: same consumer within 10 minutes" {
    first = Complaint(id="D1", text="BD 4512300017", time_min=1.0, consumer_no="4512300017");
    dup = Complaint(id="D2", text="still no power", time_min=6.0, consumer_no="4512300017");
    later = Complaint(id="D3", text="BD 4512300017", time_min=12.5, consumer_no="4512300017");
    other = Complaint(id="D4", text="BD 4512300018", time_min=6.0, consumer_no="4512300018");
    nonum = Complaint(id="D5", text="near pole 23", time_min=6.0);
    flag_duplicates([first], []);
    flag_duplicates([dup, other, nonum], [first]);
    flag_duplicates([later], [first, dup, other]);
    assert not first.is_duplicate;
    assert dup.is_duplicate;
    assert not later.is_duplicate;
    assert not other.is_duplicate;
    assert not nonum.is_duplicate;
}

test "parse_one uses the single-text LLM call and caches it" {
    _fixture();
    reset_parse_stats();
    _mock([LlmParsed(index=0, lang=Lang.EN, hazard=Hazard.SPARKS)]);
    c = parse_one(Complaint(id="C0100", text="Sparks from the line near my house 4512300042", time_min=9.0));
    assert c.hazard == Hazard.SPARKS;
    assert c.consumer_no == "4512300042" and c.home_id == "H-T3-042";
    assert agents_parse.LLM_CALLS == 1;
    _mock([]);
    again = parse_one(Complaint(id="C0101", text="Sparks from the line near my house 4512300042", time_min=9.5));
    assert again.hazard == Hazard.SPARKS;
    assert agents_parse.LLM_CALLS == 1;
}
