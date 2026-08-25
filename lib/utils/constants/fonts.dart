/// Font family names used across the app.
///
/// Keeping font families centralized prevents typos and makes future
/// font swaps a one-line change.
class TFonts {
  TFonts._();

  /// Primary display font used across Hamme UI surfaces.
  static const String nunito = 'Nunito';
  static const String schibstedGrotesk = 'Schibsted Grotesk';

  /// Fallback / theme default declared in `TAppTheme`.
  static const String poppins = 'Poppins';
}
