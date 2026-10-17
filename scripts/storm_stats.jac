"""Print the seed-17 storm's mix (dev aid for WP-A2): jac run scripts/storm_stats.jac"""

import from grid_storm { generate_complaints }

with entry {
    cs = generate_complaints(17);
    bd = len([c for c in cs if c.text.startswith("BD ")]);
    si = len([c for c in cs if any([ord(ch) > 0x0D80 and ord(ch) < 0x0DFF for ch in c.text])]);
    en = len(cs) - bd - si;
    early = len([c for c in cs if c.time_min < 8.0]);
    texts = sorted(set([c.text for c in cs if not c.text.startswith("BD ")]));
    print(f"total {len(cs)}: BD {bd}, English {en}, Sinhala {si}; before 8 min {early}; last {cs[-1].time_min}");
    print(f"distinct free texts {len(texts)}");
    for t in texts {
        print("  " + t);
    }
}
