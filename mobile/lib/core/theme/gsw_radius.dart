/// The only corner radii in the app. Pick by what the element is and where
/// it sits, never by eye. Radii step down as elements get smaller and as they
/// nest, so corners stay concentric (a box inside a card is rounder than
/// nothing but less round than the card around it).
///
/// - [card] 16: containers sitting directly on the screen or sheet
///   background. Cards, panels, banners, summary boxes.
/// - [control] 12: standalone controls 40 to 56 tall that are not inside a
///   card. Text fields, text areas, search fields, toggle rows, time and date
///   cells, option tiles, snackbars.
/// - [inner] 8: anything nested inside a card or panel, and small tiles under
///   40. Rows, info boxes and thumbnails inside cards, icon tiles.
/// - [sheet] 28: the top corners of bottom sheets.
/// - [full]: pills. Buttons, chips, tags, badges, progress bars, tracks.
/// - [checkbox] 4: the checkbox square only.
class GSWRadius {
  GSWRadius._();

  static const double card = 16;
  static const double control = 12;
  static const double inner = 8;
  static const double sheet = 28;
  static const double full = 999;
  static const double checkbox = 4;
}
