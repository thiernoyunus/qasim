# Companion sprite inventory

The selectable companions are Qasim, Hana, Nur, Ahmed, and Safa. Each one uses the same pose names and the same runtime rules.

| Sprite | Runtime use |
| --- | --- |
| `idle` | Default companion, sitting, and idle wandering |
| `typing` | Calm focus session while the user is on task |
| `angry` | Nudge, notes, fire, and preview states |
| `switch-up` / `switch-down` | Lights escalation; `flipSwitch` picks `down` once the lights are off or the switch is pressed |
| `sleep` | Idle-life sleep and the quiet break activity |
| `qiyam` | Prayer step 1; also the adhkar break pose |
| `ruku` | Prayer step 2: a distinct forward bow with a straight back |
| `sujud` | Prayer step 3: forehead and hands down, hips raised |

Prayer cycles `qiyam → ruku → sujud` every 2.4 seconds while the prayer mat is visible. Quran breaks use `idle` (Qasim has a dedicated `qasim-quran`); rest breaks use `sleep`.

## Where the files live

- `Qasim/Resources/Assets.xcassets/<companion>-<pose>.imageset/` — the copy the app ships. This is the only art that goes into the build.
- `Art/<Companion>/<companion>-<pose>.png` — source masters kept outside the app folder, used by the scripts in `scripts/`. They are not bundled, so they don't add to the app's size.

When you add or change a sprite, update both copies (the scripts in `scripts/` already do this).
