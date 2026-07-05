# Design tokens — extracted from `Turtle Turning Pages.dc.html` (2026-07-05)

Extraction method: unpacked the bundler manifest/template, split the canvas into
`screens/<anchor>.html`, and derived semantic roles from component usage frequency.

## Fonts
- Display: **Young Serif** (titles, book spines)
- UI/body: **Schibsted Grotesk** (everything else)

## Core palette (semantic)

| Token | Hex | Role (observed usage) |
|---|---|---|
| bg | `#FAF5E9` | Screen background |
| surface | `#FFFCF4` | Cards, bubbles, secondary buttons |
| line | `#E8E2CE` | Borders everywhere |
| ink | `#20291F` | Primary text; dark (Apple) button bg |
| ink2 | `#5F6A5C` | Secondary text; "Requested" status |
| ink3 | `#939C8D` | Muted text, timestamps, footers |
| green | `#2F5240` | PRIMARY: buttons, links, "Accepted", turtle shell |
| greenDeep | `#24382B` | Dark green details, swapped status |
| greenTint | `#E8EEDF` | Green chip backgrounds |
| honey | `#F6E7C8` | Points badge bg, system pills, condition chips, "In trade" overlay |
| honeyDeep | `#96621C` | Text on honey |
| honeyAccent | `#D9952F` | Notification dots, avatar accents |
| terracotta | `#C05F37` | Destructive: Cancel, "Cancelled", unread badges (white text) |
| terracottaTint | `#FBF1EA` | Cancel button background |
| neutralTint | `#F0EADB` | Neutral chip backgrounds |
| sage | `#8FA783` / `#7E9469` | Piri illustration greens only |
| shadow | `rgba(36,56,43,0.07–0.2)` | Card/button shadows |

Canvas body behind the phone frames is `#ECE6D6` (mock chrome — do not ship, like `ios-frame.jsx`).

## Key component recipes (from mocks)

- **Primary button**: bg green, fg `#FAF5E9`, weight 800, radius 13–14, padding 14
- **Auth dark button** (`#3a`): bg ink, fg `#FAF5E9`, radius 13
- **Secondary button/chip**: bg surface, border line, fg green or ink, radius 999 (chips) / 12–13
- **Points badge** (`#1a`): bg honey, fg honeyDeep, radius 999, weight 700, "N pts"
- **System message pill** (`#2d`): centered, bg honey, fg honeyDeep, radius 999, 11px/800
- **Sent bubble**: bg green, fg `#F5F0E1`, radius `16 16 5 16`
- **Received bubble**: bg surface, border line, radius `16 16 16 5`
- **Unread badge**: bg terracotta, fg white, radius 999, 9.5–10px/800
- **Cancel button** (`#2c`): bg terracottaTint, fg terracotta, weight 800, radius 10
- **"In trade" overlay chip** (`#1h`): bg honey, fg honeyDeep, weight 800, radius 999
- **Condition chip** (`#2a`): bg honey, fg honeyDeep, radius 999
- **Status text colors**: requested ink2 · accepted green · swapped greenDeep · cancelled/declined terracotta · expired ink3

## Book cover placeholder palette (7)

| Key | Cover | Text |
|---|---|---|
| honey | `#D9952F` | `#3A2A0E` |
| plum | `#7A5A68` | `#F2E9EC` |
| slate | `#5C7186` | `#F0F2EC` |
| deepGreen | `#24382B` | `#EDE6D2` |
| forest | `#2F5240` | `#F2EBD8` |
| terracotta | `#C05F37` | `#FBEEDF` |
| brick | `#8A4A3B` | `#F6E7D4` |

Covers render title in Young Serif on the cover color.
