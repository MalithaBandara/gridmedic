# Live Gemini smoke test: one typed by llm() call per phrase.
# Makes 6 real API calls. Run only when needed: jac run scripts/smoke_llm.jac
# Needs GEMINI_API_KEY and JAC_OPT_LEVEL=0 in the environment.

enum Hazard { NONE, WIRE_DOWN, SPARKS, FIRE, TRANSFORMER_NOISE }
sem Hazard.NONE = "No danger mentioned, just a loss of power.";
sem Hazard.WIRE_DOWN = "A power line or wire has fallen, is hanging low, or is on the road/ground.";
sem Hazard.SPARKS = "Sparks, arcing, flashes, burning smell from lines or transformers.";
sem Hazard.FIRE = "Flames or a fire at a pole, line or transformer.";
sem Hazard.TRANSFORMER_NOISE = "A bang, buzz or loud sound from a transformer.";

enum Lang { EN, SI, MIXED }
sem Lang.EN = "English";
sem Lang.SI = "Sinhala";
sem Lang.MIXED = "A mix of Sinhala and English";

obj SmokeParsed {
    has lang: Lang = Lang.EN,
        hazard: Hazard = Hazard.NONE,
        landmark: str = "";
}
sem SmokeParsed.lang = "Language of the complaint text.";
sem SmokeParsed.hazard = "The most serious safety hazard the complaint mentions, or NONE.";
sem SmokeParsed.landmark = "A named location like 'pole 23' or 'near the temple', if mentioned; else empty.";

def parse_one(raw: str) -> SmokeParsed by llm();
sem parse_one = "Parse one power-outage complaint from a Sri Lankan electricity customer (English or Sinhala).";
sem parse_one.raw = "The complaint text.";

# (text, expected hazard) pairs from CLAUDE.md §6.3
glob CASES: list[tuple[str, Hazard]] = [
    ("Wire fallen on the road near pole 23, sparks!", Hazard.WIRE_DOWN),
    ("විදුලිය නැහැ", Hazard.NONE),
    ("රෑ 7 ඉඳන් කරන්ට් නැහැ", Hazard.NONE),
    ("කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා", Hazard.WIRE_DOWN),
    ("ගිනි පුපුරු එනවා", Hazard.SPARKS),
    ("ට්‍රාන්ස්ෆෝමරයෙන් සද්දයක් ආවා", Hazard.TRANSFORMER_NOISE)
];

with entry:__main__ {
    passed: int = 0;
    for (text, expected) in CASES {
        p = parse_one(text);
        ok: bool = p.hazard == expected;
        if ok { passed += 1; }
        mark: str = "OK  " if ok else "FAIL";
        print(f"{mark} {text} -> lang={p.lang.name} hazard={p.hazard.name} landmark='{p.landmark}' (want {expected.name})");
    }
    print(f"{passed}/{len(CASES)} hazards correct");
}
