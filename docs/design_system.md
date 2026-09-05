# Task Empire visual system — foundation

The visual direction is a calm civic workshop rather than a generic analytics
dashboard: dark forest surfaces suggest the city and governance, parchment
surfaces keep planning readable, and restrained gold marks rewards and primary
actions.

This is a working implementation baseline. Production typography, icons,
motion, and final asset composition still require explicit design review before
release.

## Palette

| Token | Value | Role |
| --- | --- | --- |
| `forest950` | `#0E2924` | navigation and deepest surfaces |
| `forest900` | `#153B33` | hero surfaces |
| `forest700` | `#286B58` | primary controls |
| `forest500` | `#3F9373` | focus and supporting accents |
| `mint200` | `#BFE6D4` | selected and positive surfaces |
| `gold600` | `#C78A24` | reward text and secondary accent |
| `gold400` | `#F0BD5B` | primary reward highlight |
| `parchment` | `#F5F0E4` | application background |
| `paper` | `#FFFDF8` | cards, dialogs, sheets |
| `ink` | `#17221F` | primary text |
| `mutedInk` | `#65716C` | supporting text |
| `danger` | `#B64E42` | errors and invalid placement |

## Layout tokens

- Spacing scale: 4, 8, 12, 16, 24, 32, 48 px.
- Control radius: 16 px.
- Card radius: 24 px.
- Hero radius: 28 px.
- Modal sheet radius: 30 px at the top edge.
- Standard content width: 980–1120 px depending on the screen.
- Desktop navigation changes to a rail at 900 px.

## Type hierarchy

- Screen and section headings use heavy weight and slightly negative tracking.
- Labels use strong weight and restrained uppercase tracking.
- Body copy stays neutral and high-contrast; metadata uses `mutedInk`.
- Currency and XP values use tabular-looking, bold numerals where possible.

## Components

- Hero cards explain the purpose of a screen and show only its primary metric.
- Task cards keep completion as the largest immediate action; edit/delete stay
  in a secondary menu.
- City chrome floats above the scene and disappears from the user's attention
  outside edit mode.
- Bottom sheets contain focused creation or construction flows.
- Green placement means locally valid; red always explains the blocking rule.

## Motion

- Quick feedback: 180 ms.
- Standard state transition: 280 ms.
- Motion must clarify selection, completion, placement, and mode changes. Avoid
  continuous decorative animation that competes with the task list or city.

The corresponding Flutter tokens live in `lib/core/theme/app_theme.dart`.
