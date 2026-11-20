# Đảo Đèn Lồng — Phase 4

- Engine: Godot 4.5.1, GDScript; Compatibility renderer; Python 3.9+ launcher.
- Requirements: `docs/spec/PRD-0.txt` and `docs/spec/Ticket-02.txt`; known gaps and provisional values: `docs/notes/phase-2.md`.
- Build: `python tools/manage.py build`; play: `python tools/manage.py play`.
- Verify: `python tools/manage.py test`. Exit nonzero means work is unfinished.
- Visual check: `python tools/manage.py capture` and `capture --capture-menu`.
- Gameplay belongs only in `src/simulation.gd`; GUI and CLI use this same model.
- Fixed 60 Hz. Distances use XZ; tick 0 is BEFORE inputs. Preserve edge buttons.
- Use `sim_tick` for gameplay clocks and `tick` for JSONL. Keep map geometry in `src/night_layout.gd`.
- Phase 3 rules and migration: `docs/notes/phase-3.md` and `CHANGELOG.md`.
- Fuel is stored in units of 1/60. Resolve decay and drain before input actions, and resolve dawn after all gameplay updates.
- Write new evidence to `docs/proof/phase-4/` and preserve earlier reports and screenshots.
- Measure with the commands in `game.contract.json`. Keep creative graphics disabled in the benchmark and keep the soak in one engine process.
- Export the Windows package with `python tools/manage.py package`; verify the executable from a directory without project source.
- Read tuning from contract; never duplicate gameplay numbers in a second model.
- Never alter saved output to make evidence pass; save real failing cases, then fix code.
- Keep inputs/scenarios and a request-to-proof table. Report unverified GUI/OS claims.
- Run verification hook `python tools/verify.py` before reporting completion.
- Use explicit types for expressions that access the dynamic simulation model;
  Godot cannot always infer them with `:=`. Execute new scripts to catch this.
- Preserve the lab guides and harness history. No invented later-phase tickets/tags.
- No API keys, external copyrighted characters/assets, fabricated token counts.
