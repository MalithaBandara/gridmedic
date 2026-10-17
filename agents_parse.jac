"""Complaint parser (WP-B1): turns raw complaint text into typed Complaint fields.

- `BD <10 digits>` SMS are parsed deterministically, with no LLM call.
- Free text goes to `parse_texts` in batches of 10; results are cached by raw
  text in the ParseCache node, which survives reset (free-tier LLM quota).
- consumer_no -> Home, landmark text -> Section, duplicate flagging.

The LLM output obj `LlmParsed` is declared HERE: byllm 0.6.19 crashes on an
output obj imported from another module (CLAUDE.md §1a).
"""

import re;
import from time { sleep }
import from concurrent.futures { Future }
import from byllm.lib { RateLimitError }
import from gm_types { Hazard, Lang, Complaint, ParsedText, Event, fix_parsed }
import from grid { GridNode, Substation, Section, Home, Landmark, Feeds, Located, ParseCache, EventLog, children, parents }

# ------------------------------------------------------------- LLM interface
obj LlmParsed {
    has index: int,
        lang: Lang = Lang.EN,
        hazard: Hazard = Hazard.NONE,
        landmark: str = "";
}

sem LlmParsed.index = "Position of the complaint in the input list, starting at 0. Copy it exactly.";
sem LlmParsed.lang = "Language of the text: SI for Sinhala (Sinhala script, or Sinhala words in Latin letters such as 'current na', 'kanuwa'), EN for English, MIXED for both.";
sem LlmParsed.hazard = "The most serious safety hazard the text describes, or NONE if it only reports a loss of power. Sinhala hints: 'වයරයක් බිම වැටිලා' / 'wire eka bima' = WIRE_DOWN; 'ගිනි පුපුරු' = SPARKS; 'ගින්නක්' / 'ගිනි ගන්නවා' = FIRE; 'සද්දයක්' or 'පිපිරුම' from a transformer = TRANSFORMER_NOISE. 'විදුලිය නැහැ' / 'කරන්ට් නැහැ' (no power) alone = NONE.";
sem LlmParsed.landmark = "A named place the customer mentions, normalised in English, e.g. 'pole 23', 'temple', 'hospital road'. 'කණුව' means pole. Empty if none.";

def parse_texts(texts: list[str]) -> list[LlmParsed] by llm();

sem parse_texts = "Parse power-outage complaints from Sri Lankan electricity customers, written in English or Sinhala. Return exactly one item per input text, with its index.";
sem parse_texts.texts = "The complaint texts, in order. Item i of the output describes texts[i].";

def parse_single(raw: str) -> LlmParsed by llm();

sem parse_single = "Parse one power-outage complaint from a Sri Lankan electricity customer (English or Sinhala). Use index 0.";
sem parse_single.raw = "The complaint text.";

# ------------------------------------------------------------------ settings
glob BD_RE: any = re.compile(r"(?i)^\s*BD\s*(\d{10})\s*$");
glob NUM_RE: any = re.compile(r"(?<!\d)(\d{10})(?!\d)");
glob BATCH_SIZE: int = 10;
glob MAX_PARALLEL: int = 3;           # concurrent LLM calls per wave (per-minute cap)
glob RETRY_WAIT_S: float = 2.0;
glob DUPLICATE_WINDOW_MIN: float = 10.0;

# Counters for the write-up and tests: real LLM calls made, cache hits, BD skips.
glob LLM_CALLS: int = 0;
glob CACHE_HITS: int = 0;
glob BD_SKIPS: int = 0;

# ---------------------------------------------------------------- public API
"""Parse a batch of raw complaints in place: BD regex, cache, batched LLM, location."""
def parse_batch(complaints: list[Complaint]) -> list[Complaint];

"""Parse one complaint (customer page submit_complaint)."""
def parse_one(c: Complaint) -> Complaint;

"""Flag repeats: same consumer_no within 10 simulated minutes of their last counted complaint."""
def flag_duplicates(new_items: list[Complaint], earlier: list[Complaint]) -> list[Complaint];

"""Section id a landmark text refers to ('near pole 23' -> 'F1-B'), or '' if unknown."""
def landmark_section(text: str) -> str;

"""The 10-digit consumer number of a `BD <number>` SMS, or '' if the text is not one."""
def bd_number(text: str) -> str;

def to_parsed_text(p: LlmParsed) -> ParsedText {
    return ParsedText(index=p.index, lang=p.lang, hazard=p.hazard, landmark=p.landmark);
}

def reset_parse_stats {
    global LLM_CALLS;
    global CACHE_HITS;
    global BD_SKIPS;
    LLM_CALLS = 0;
    CACHE_HITS = 0;
    BD_SKIPS = 0;
}

# ----------------------------------------------------------------- internals
def _cache -> ParseCache;
def _cache_key(text: str) -> str;
def _apply(c: Complaint, p: ParsedText);
def _fallback(index: int) -> ParsedText;
def _call_batch(texts: list[str]) -> list[LlmParsed];
def _call_single(raw: str) -> LlmParsed | None;
def _launch(texts: list[str]) -> Future;
def _parse_free_texts(texts: list[str]) -> dict[str, ParsedText];
def _grid_nodes -> list[GridNode];
def _homes_by_consumer -> dict[str, Home];
def _landmarks -> list[Landmark];
def _locate(c: Complaint, homes: dict[str, Home]);
def _log(kind: str, text: str, time_min: float);
