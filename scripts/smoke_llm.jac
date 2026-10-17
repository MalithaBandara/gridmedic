# Live Gemini smoke test: all six phrases in ONE batched typed by llm() call.
# Makes 1 real API call (byllm may retry malformed output). Run only when needed: jac run scripts/smoke_llm.jac
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
    has index: int = 0,
        lang: Lang = Lang.EN,
        hazard: Hazard = Hazard.NONE,
        landmark: str = "";
}
sem SmokeParsed.lang = "Language of the complaint text.";
sem SmokeParsed.hazard = "The most serious safety hazard the complaint mentions, or NONE.";
sem SmokeParsed.landmark = "A named location like 'pole 23' or 'near the temple', if mentioned; else empty.";

sem SmokeParsed.index = "Position of the complaint in the input list, starting at 0.";

def parse_texts(texts: list[str]) -> list[SmokeParsed] by llm();
sem parse_texts = "Parse power-outage complaints from Sri Lankan electricity customers (English or Sinhala). Return exactly one item per input, with its index.";
sem parse_texts.texts = "The complaint texts, in order.";

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
    texts: list[str] = [t for (t, h) in CASES];
    results = parse_texts(texts);
    print(f"got {len(results)} results for {len(CASES)} inputs");
    for p in results {
        if p.index < 0 or p.index >= len(CASES) { continue; }
        (text, expected) = CASES[p.index];
        ok: bool = p.hazard == expected;
        if ok { passed += 1; }
        mark: str = "OK  " if ok else "FAIL";
        print(f"{mark} {text} -> lang={p.lang.name} hazard={p.hazard.name} landmark='{p.landmark}' (want {expected.name})");
    }
    print(f"{passed}/{len(CASES)} hazards correct");
}
