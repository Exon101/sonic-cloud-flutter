---
name: Sonic Cloud
colors:
  surface: '#131318'
  surface-dim: '#131318'
  surface-bright: '#39383e'
  surface-container-lowest: '#0e0e13'
  surface-container-low: '#1b1b20'
  surface-container: '#1f1f25'
  surface-container-high: '#2a292f'
  surface-container-highest: '#35343a'
  on-surface: '#e4e1e9'
  on-surface-variant: '#c8c5ce'
  inverse-surface: '#e4e1e9'
  inverse-on-surface: '#303036'
  outline: '#928f98'
  outline-variant: '#47464d'
  surface-tint: '#c5c3e5'
  primary: '#c5c3e5'
  on-primary: '#2e2e48'
  primary-container: '#12122b'
  on-primary-container: '#7d7c9b'
  inverse-primary: '#5c5c79'
  secondary: '#e6feff'
  on-secondary: '#003739'
  secondary-container: '#00f4fe'
  on-secondary-container: '#006c71'
  tertiary: '#c9bfff'
  on-tertiary: '#2e009c'
  tertiary-container: '#130051'
  on-tertiary-container: '#7f66ff'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e2dfff'
  primary-fixed-dim: '#c5c3e5'
  on-primary-fixed: '#191932'
  on-primary-fixed-variant: '#444460'
  secondary-fixed: '#63f7ff'
  secondary-fixed-dim: '#00dce5'
  on-secondary-fixed: '#002021'
  on-secondary-fixed-variant: '#004f53'
  tertiary-fixed: '#e5deff'
  tertiary-fixed-dim: '#c9bfff'
  on-tertiary-fixed: '#1a0063'
  on-tertiary-fixed-variant: '#441cc8'
  background: '#131318'
  on-background: '#e4e1e9'
  surface-variant: '#35343a'
typography:
  headline-xl:
    fontFamily: Montserrat
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Montserrat
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Montserrat
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 8px
  sm: 16px
  md: 24px
  lg: 32px
  xl: 48px
  edge-margin: 20px
  gutter: 16px
---

## Brand & Style

The design system is built upon a "Cloud & Sonic" narrative, blending the ethereal qualities of cloud computing with the precision of high-fidelity audio. The personality is premium, focused, and futuristic, aimed at tech-savvy music enthusiasts who value both aesthetics and performance.

The visual style leverages **Glassmorphism** as its core aesthetic. Interfaces utilize translucent layers, vibrant background blurs, and thin-line strokes to create a sense of depth and lightness. This "airy" approach ensures that even with a dark default theme, the UI feels spacious and intuitive rather than heavy or claustrophobic.

## Colors

The palette is anchored in deep, atmospheric tones to provide a high-end "night mode" experience.

- **Primary (Deep Indigo):** Used for the base background and deep structural elements. It evokes the vastness of the digital cloud.
- **Secondary (Vibrant Cyan):** The "Sonic" energy. Used for active states, playback progress, and primary actions. It should glow against the dark backgrounds.
- **Tertiary (Electric Violet):** Provides accent variety, specifically for cloud-sync status and metadata highlights.
- **Neutral:** A range of deep obsidian grays used for surface containers, ensuring legibility and contrast without breaking the dark-room immersion.

## Typography

This design system uses a dual-font strategy. **Montserrat** is employed for headlines and titles to provide a bold, geometric, and modern character. **Inter** is used for all functional text, lists, and metadata, ensuring maximum readability and a clean, systematic feel.

For mobile-specific views:
- Use `headline-xl` only for featured album titles or "Now Playing" screens.
- `label-sm` is strictly for secondary metadata like file type (FLAC/MP3) or timestamps.
- Maintain generous line heights to preserve the "airy" feel of the brand.

## Layout & Spacing

The layout follows a **Fluid Grid** model optimized for mobile-first interaction. 

- **Safe Zones:** A 20px horizontal margin is maintained on all screens to ensure content doesn't hit the bezel.
- **Vertical Rhythm:** Content sections (e.g., "Recently Played" vs "Cloud Library") are separated by `lg` (32px) spacing.
- **Touch Targets:** Interactive elements must maintain a minimum 44x44px hit area, even if the visual representation is smaller.
- **Cloud Shelves:** Horizontal scrolling carousels are used for album art to maximize vertical real estate while showcasing large, high-quality imagery.

## Elevation & Depth

Depth is conveyed through **Glassmorphism** rather than traditional shadows. 

1.  **Background Layer:** Deep Indigo gradient (#12122B to #0A0A0F).
2.  **Mid Layer (Content Cards):** Semi-transparent white (5-10% opacity) with a `backdrop-filter: blur(20px)`.
3.  **Top Layer (Floating Controls):** Higher opacity (15-20%) with a vibrant 1px border stroke at 30% opacity to define the shape against moving background artwork.
4.  **Sonic Glow:** Active playback elements (like the seek bar thumb) use a Cyan outer glow (drop-shadow) to simulate a light-emitting diode.

## Shapes

The design system utilizes **Rounded (Level 2)** shapes to strike a balance between tech-precision and organic cloud-like forms.

- **Album Art:** Standard `rounded-lg` (1rem).
- **Glass Cards:** `rounded-lg` (1rem) for main containers.
- **Play/Pause Buttons:** Use pill-shaped buttons for primary actions to distinguish them from navigation items.
- **Input Fields:** Softly rounded corners to maintain the approachable, sleek aesthetic.

## Components

### Buttons
- **Primary Play:** Large circular button with a vibrant Cyan gradient. It features a subtle outer glow when music is active.
- **Secondary Actions:** Ghost buttons with thin-line 1px borders and transparent fills.

### Cards (Glassmorphic)
- Cards should have a 1px solid border (top and left) at 20% opacity to simulate light hitting the edge of a glass pane.
- Content inside cards uses white text at varying opacities (87% for primary, 60% for secondary).

### Progress Bars (Sonic Seekers)
- The track should be a dark indigo bar.
- The progress fill is a vibrant Cyan gradient.
- The thumb is a small, glowing Cyan circle that expands slightly on touch.

### Icons
- Use **Thin-line (1px or 1.5px)** stroke icons exclusively.
- Icons should be consistent in weight across the entire app.
- Active icons in the navigation bar should transition from white to Cyan.

### Cloud Integration Indicators
- A subtle "cloud" badge or icon next to song titles indicates cloud-only tracks.
- Download progress is shown via a thin Cyan ring around the play button or icon.