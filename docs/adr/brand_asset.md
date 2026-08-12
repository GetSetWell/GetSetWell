# GetSetWell Brand Asset Guide

> Version: 1.0
>
> Last Updated: August 2026

---

# Purpose

This document defines the production standard for exporting, naming, and organizing all visual assets used throughout the GetSetWell mobile application.

Following this guide ensures:

- Consistent branding
- Smaller app size
- Correct Android adaptive icons
- Correct iOS icons
- Consistent splash screens
- Easy onboarding for future designers and developers

---

# Asset Directory Structure

```
assets/
├── icons/
│   ├── app_icon.png
│   ├── app_icon_foreground.png
│   └── app_icon_background.png
│
├── logos/
│   ├── logo_mark.png
│   ├── logo_wordmark.png
│   └── splash_logo.png
│
├── illustrations/
├── images/
└── animations/
```

---

# App Icon

## File

```
assets/icons/app_icon.png
```

## Usage

- Android Launcher
- iOS Home Screen
- Play Store
- App Store

## Export Settings

| Property | Value |
|----------|-------|
| Format | PNG |
| Size | 1024 × 1024 px |
| Background | Solid Brand Lime |
| Transparency | No |

---

# Android Adaptive Icon

Android launcher icons are composed of **two separate layers**.

---

## Background

### File

```
assets/icons/app_icon_background.png
```

### Export Settings

| Property | Value |
|----------|-------|
| Format | PNG |
| Size | 1024 × 1024 px |
| Background | #DAE64B |
| Transparency | No |

### Contents

- Solid color only
- No logo
- No text
- No gradients

---

## Foreground

### File

```
assets/icons/app_icon_foreground.png
```

### Export Settings

| Property | Value |
|----------|-------|
| Format | PNG |
| Size | 1024 × 1024 px |
| Background | Transparent |
| Transparency | Yes |

### Contents

- Only the GetSetWell "G"
- Center aligned
- Approximately 20% transparent padding on all sides

---

# Splash Screen Logo

## File

```
assets/logos/splash_logo.png
```

## Usage

Used by:

- Flutter Native Splash
- Flutter Splash Screen

## Export Settings

| Property | Value |
|----------|-------|
| Format | PNG |
| Size | 1024 × 1024 px |
| Background | Transparent |
| Transparency | Yes |

### Notes

The logo should contain **only the "G" mark**.

Do **not** include:

- Lime square
- Dark background
- Circle
- Wordmark

The background color is supplied by Flutter Native Splash.

---

# Logo Mark

## File

```
assets/logos/logo_mark.png
```

## Usage

- Navigation
- Profile
- Empty States
- Branding

## Export Settings

| Property              | Value       |
|-----------------------|-------------|
| Format                | PNG         |
| Background            | Transparent |

---

# Logo Wordmark

## File

```
assets/logos/logo_wordmark.png
```

## Usage

- Authentication Screens
- Marketing Pages
- Headers
- About Screen

## Export Settings

| Property          | Value       |
|-------------------|-------------|
| Format            | PNG.        |
| Background        | Transparent |

Contains only the text:

```
GetSetWell
```

---

# Illustrations

Directory

```
assets/illustrations/
```

Guidelines

- Prefer SVG
- PNG only when necessary
- Transparent background

---

# Images

Directory

```
assets/images/
```

Guidelines

- JPG for photographs
- PNG when transparency is required
- WebP whenever possible

---

# Animations

Directory

```
assets/animations/
```

Preferred formats

- Lottie (.json)
- Rive (.riv)

Avoid GIFs in production.

---

# Brand Colors

| Name                 | Hex       |
|----------------------|-----------|
| Primary Lime         | #DAE64B |
| Background           | #000D1B |
| Surface              | #0D1926 |
| White                | #FFFFFF |
| Secondary Text       | #82888F |
| Success              | #37D67A |
| Warning              | #FBBF24 |
| Error                | #F26D6D |
| Info                 | #3B82F6 |

---

# Typography

## Display

Bebas Neue

## Body

Outfit

---

# Naming Convention

Use lowercase filenames with underscores.

✅ Correct

```
logo_mark.png
logo_wordmark.png
splash_logo.png
app_icon.png
app_icon_foreground.png
app_icon_background.png
```

❌ Incorrect

```
LogoFinal.png
logo-new.png
GetSetWellLogo.png
icon_latest_v2.png
```

---

# Production Checklist

Before committing any new asset, verify:

- [ ] Canvas size is correct
- [ ] Background is correct (transparent or solid)
- [ ] Logo is centered
- [ ] Safe padding is maintained
- [ ] Filename follows the naming convention
- [ ] Asset is optimized for production
- [ ] Export matches this document

---

# Revision History

| Version | Date | Description |
|----------|------|-------------|
| 1.0 | August 2026 | Initial production asset guide |