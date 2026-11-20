# AutoG brand

**Name:** AutoG. **Tagline:** Accelerometry, automated.

## The mark

A G made of two arrows: a three-quarter ring that ends in an arrowhead (the processing loop,
coming out) and a crossbar arrow pointing in (the data going in). Flat colour, no gradient.

Geometry, on a 128 x 128 grid: ring centre (64, 64), mid radius 37, weight 18, from the right-hand
middle clockwise to the top; both arrowheads are 45-degree triangles, 36 across and 18 deep; the
crossbar has the ring's weight. Keep these proportions; do not stretch, outline or add effects.
It must stay readable in one colour and at 16 pixels.

## Colours (Signal palette)

| Name | Hex | Use |
|---|---|---|
| Navy | `#10204A` | header, icon tile, ring on light backgrounds |
| Electric blue | `#2F6BFF` | crossbar arrow, buttons, active tab, progress bars |
| Cream | `#F3EFE4` | ring and text on navy |

An alternative print palette (Heritage: navy, vermilion `#E4572E`, cream) was shown and not chosen.

## Interface style (0.8.0+)

The user asked for a modern look: icons, pills, gradients. Rules:

- **Shapes:** cards with 16 px corners and a soft shadow; buttons, tabs, marks and chips are pills.
- **Gradients:** blue to violet (`#2F6BFF` to `#6A5CFF`) on the primary button, the active tab and
  progress bars; navy to indigo on the header. Never on the logo, on text, or to signal a result.
- **Icons:** Font Awesome (solid) through `shiny::icon()`. One icon per button, tab and section
  heading. Marks use check (Pass), warning triangle (Flag) and eye (worth a look).
- **One primary button per screen.** Stop is an outline, so it cannot be mistaken for it.
- **Type:** Segoe UI, 14.5 px; small capitals-style labels for section and table headings.
- Colour never carries meaning alone: every mark has an icon and a word.

## Light and dark mode (required for everything)

The rule: the app **and every guide, infographic and other material** must
offer light and dark mode.

- **App:** a Light / Dark / Auto switch in the header. Auto follows the PC's setting. The choice
  is remembered in the browser on that PC. All colours are variables in `app/www/autog.css`, with
  one block for light and one for dark: add a colour to both, never as a literal.
- **Help, onboarding and any page opened in the browser:** use the same stylesheet and switch.
- **Infographic and other PDFs:** ship two files, `-light.pdf` (for printing) and `-dark.pdf`
  (for screens and slides), made from one source.
- **Logo:** `autog-mark.svg` on light, `autog-mark-on-dark.svg` on dark. The header and the icon
  tile stay navy in both modes.
- **GGIR's report image is always on white.** GGIR draws it that way and it must not be recoloured
  (the colours carry meaning). In dark mode it sits on a white card.
- Dark palette: page `#0E1424`, panel `#161D31`, text `#E8EBF2`, muted `#A3ACBF`, accent `#4F83FF`.
- Check contrast in both modes for every new screen; state marks (Pass, Flag, worth a look) have
  their own dark colours.

## Files

| File | What |
|---|---|
| `app/www/autog-mark.svg` | mark for light backgrounds (navy ring, blue arrow) |
| `app/www/autog-mark-on-dark.svg` | mark for the navy header (cream ring, blue arrow) |
| `app/www/autog-icon.svg` | app icon: navy rounded square; also the browser-tab icon |
| `app/www/AutoG-infographic-light.pdf`, `-dark.pdf` | the two-page infographic; source is `tools/make_infographic.R` |
| `app/www/AutoG-technical-manual-light.pdf`, `-dark.pdf` | the technical manual; source is `tools/make_manual.R` |
| `docs/brand/*-v1-gradient.svg` | earlier gradient version, kept for reference only |

## Before any public or commercial use

- The name "AutoG" has not been checked against existing products or trademarks.
- AutoG runs GGIR, which is other people's open-source software: follow its licence, credit it,
  and do not imply its authors endorse AutoG.
- The app is documented as research use only (`docs/BIODESIGN.md`). Wider distribution is a
  different regulatory position and needs the user's decision first.
- `reference_pipeline.R` (the Mac reference script) and the study names keep their names; only the app
  was renamed.
