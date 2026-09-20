# Inspector card redesign

Scope: existing Lychee native inspector only, established near-black/warm-white identity; compact follow summary, Shift detail card, equal rounded action buttons. Behavior/attribution preserved. Previous request and screenshot establish direction; no unrelated design-world replacement.

Pre-edit budget: 7 Frames unchanged, <=48 Regions (old 24; two rounded surfaces add 14, structured detail labels/divider add 6). Lazy creation only; no added timers, OnUpdate or source reads. Reuse existing pointer and analysis lifecycle. Static pointer10000 stays <128 KiB; lifecycle100 allocation <1 MiB, retained growth <64 KiB. Existing Theme rounded media reused, no assets. Native actual rendering pending; offline layout/state checks and full contracts required.

Results: full contract and wowdoc validation pass. Lifecycle fixture: 7 Frames/44 Regions, initial retained 40.8 KiB; 100 cycles 2–3 ms, 520.7 KiB allocation, 1.1 KiB retained growth. Previous card: 7/24, 25.0 KiB; added fixed texture/label cost replaces block hover and separates details. Pointer10000 7 ms, 0.0 KiB allocation/no source reads/no redundant setters. No change to source attribution, cursor follow, Shift freeze or combat/disable lifecycle. Tests cover hidden summary actions, visible frozen detail actions, hover/leave and disabled parent state; existing shared UI/performance tests remain green.

Preview PNG is a code-drawn layout schematic at specified sizes, visually inspected once, not a client screenshot or proof of native font rasterization. Actual client appearance and protected-frame interactions remain pending. Versioned SetMaxLines evidence and validation stored alongside this record; existing rounded-corner texture is reused.
