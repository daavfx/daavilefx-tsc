# How ts-rust got here

This text was in the README before the first preview release (2026-10).

An early audit found 70 failing tests and measured the broad compiler
2.6–3.4x slower than Go for equivalent work.

Breadth is not the same as completion here. The first implementation phase
landed hundreds of commits across many compiler subsystems before the
parity harness was authoritative. A recovery audit then reduced the scope
to one measurable path. The later checker work expanded the scope again and
was suspended before cleanup and full verification were complete.
