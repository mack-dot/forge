# Isolation mode of the airlock engine (review 2026-11-20, defect D1)

What this is: a design for a shipped isolation mode of `forge-airlock`. The engine runs as a
service user behind per-tenant Unix sockets. Its pinned files sit under a root-owned prefix. Its WAL
gets a keyed MAC. See [DESIGN.md](DESIGN.md).

Why: in the shipped SDK flow the engine is a child process of the agent, under the agent's own OS
user. The agent chooses the engine, and the WAL chain is unkeyed. So every rule holds only against
a buggy caller, not a hostile one. Section 0 of the design checks this against the code on
`33055a59`.

Status: NOT started. Documents only. No code, no script, no setup file. No step that needs `sudo`
was run. Every owner step is text. `end_to_end=false`. Nothing here is a proof. M1-B stays OPEN.
Records: `unsure.md` U894 to U896. The owner decides the scope and the budget (design section 7).
