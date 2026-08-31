# Companion sprite inventory

The selectable companion set is Qasim, Hana, and Nur. Each one uses the same eight pose names and the same runtime rules.

| Sprite | Runtime use |
| --- | --- |
| `idle` | Default companion, sitting, and idle wandering |
| `typing` | Calm focus session while the user is on task |
| `angry` | Nudge, notes, fire, and preview states |
| `switch` | Lights escalation; `flipSwitch` maps to this filename |
| `sleep` | Idle-life sleep and the quiet break activity |
| `qiyam` | Prayer step 1; also the adhkar break pose |
| `ruku` | Prayer step 2: a distinct forward bow with a straight back |
| `sujud` | Prayer step 3: forehead and hands down, hips raised |

Prayer cycles `qiyam → ruku → sujud` every 2.4 seconds while the prayer mat is visible. Quran breaks use `idle`; rest breaks use `sleep`.

All three selectable companions have matching files in both locations:

- `Qasim/Resources/Art/<companion>-<pose>.png`
- `Qasim/Resources/Assets.xcassets/<companion>-<pose>.imageset/<companion>-<pose>.png`

Qasim, Pip, and Moss were removed from the selectable set. Their old source art is retained only as unused rollback material; it is no longer reachable from the app or its companion enum.
