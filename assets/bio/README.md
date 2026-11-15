# Replaceable biology artwork

Drop a PNG or SVG with one of these names in this folder and the game uses it in place of the
procedural drawing. No code change is needed; the simulation models never touch artwork.
(`scripts/shared/art.gd` does the lookup.)

| File name (`.png` or `.svg`) | Used for | Drawn size in the scene (design px) |
| --- | --- | --- |
| `platelet` | Resting platelet | about 14 x 10 |
| `platelet_active` | Activated / attached platelet | about 18 x 18 |
| `red_blood_cell` | Red blood cell | about 26 x 18 |
| `pancreas` | Pancreas | about 150 x 70 |
| `liver` | Liver | about 170 x 95 |
| `muscle` | Body tissue (muscle) | about 190 x 70 |
| `glucose` | Glucose particle | about 16 x 16 |
| `insulin` | Insulin particle | about 16 x 16 |
| `glucagon` | Glucagon particle | about 16 x 16 |

Artwork is stretched to the listed box, so keep roughly that aspect ratio. Use a transparent background.
