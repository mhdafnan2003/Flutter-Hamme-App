/// Which user-supplied text is being checked. Only changes the wording of the
/// rejection message.
enum ContentFilterField {
  name('name'),
  username('username'),
  instagram('Instagram username'),
  snapchat('Snapchat username');

  const ContentFilterField(this.label);

  /// How the field is referred to: "That {label} isn't allowed on Hamme."
  final String label;
}

/// Conservative client-side filter for profile text (name, username and
/// social handles), one of Hamme's objectionable-content safeguards.
///
/// Only clear-cut profanity, slurs and sexual or violent terms are caught
/// (English plus common Hindi/Hinglish abuse). Most terms must match a whole
/// word, so ordinary names that merely contain one — Harshit, Dikshit,
/// Kuntal, Cassandra, Dickson, Sussex, Scunthorpe, Hancock — are never
/// flagged. The backend runs its own filter and has the final say
/// (400 `OBJECTIONABLE_CONTENT`).
abstract final class ContentFilter {
  /// Returns the user-facing rejection message, or null when [text] is fine.
  static String? validate(String? text, ContentFilterField field) {
    final isHandle = field != ContentFilterField.name;
    return isObjectionable(text, joinWords: isHandle)
        ? rejectionMessage(field)
        : null;
  }

  static String rejectionMessage(ContentFilterField field) =>
      "That ${field.label} isn't allowed on Hamme. Please choose another.";

  /// Whether [text] contains a blocked term.
  ///
  /// With [joinWords] (usernames and handles, where `.` and `_` separate
  /// words) the words are also checked glued together, which catches
  /// `kill_yourself`. Names keep their words apart so that e.g. an initial
  /// followed by a surname can't accidentally spell a blocked term.
  static bool isObjectionable(String? text, {bool joinWords = false}) {
    if (text == null || text.trim().isEmpty) return false;
    final lower = text.toLowerCase();

    final devanagari = _normalizeDevanagari(lower);
    if (_devanagariFragments.any(devanagari.contains)) return true;

    for (final words in _wordReadings(lower)) {
      if (words.any(_isBlockedWord)) return true;
      if (joinWords &&
          words.length > 1 &&
          _containsBlockedFragment(words.join())) {
        return true;
      }
    }
    return false;
  }

  /// Splits [lower] into Latin words with look-alike characters undone
  /// ("sh1t" → "shit", "a55" → "ass"). Yields one word list per reading of
  /// the ambiguous '1' (i or l).
  static Iterable<List<String>> _wordReadings(String lower) sync* {
    final rawTokens =
        _foldDiacritics(
          lower,
        ).split(_separators).where((token) => token.isNotEmpty).toList();
    for (final one in const ['i', 'l']) {
      yield _mergeSpelledOutLetters([
        for (final raw in rawTokens) ..._decodeToken(raw, one),
      ]);
    }
  }

  static String _foldDiacritics(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_diacritics[char] ?? char);
    }
    return buffer.toString();
  }

  /// Undoes leetspeak inside one token and splits it into words. Tokens with
  /// no letter at all (e.g. "455" in "john_455") are numbers, not words.
  static List<String> _decodeToken(String raw, String one) {
    // Symbols at the edges are punctuation ("@name", "hi!"), not letters.
    final token = raw.replaceAll(_edgeSymbols, '');
    if (!_latinLetter.hasMatch(token)) return const [];
    final buffer = StringBuffer();
    for (final rune in token.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(char == '1' ? one : (_lookAlikes[char] ?? char));
    }
    return buffer
        .toString()
        .split(_nonLetters)
        .where((word) => word.isNotEmpty)
        .toList();
  }

  /// Joins runs of 4+ single letters ("f.u.c.k", "s h i t") into one word.
  /// Shorter runs are left alone: they are usually initials.
  static List<String> _mergeSpelledOutLetters(List<String> words) {
    final merged = <String>[];
    final run = <String>[];
    void flushRun() {
      if (run.length >= 4) {
        merged.add(run.join());
      } else {
        merged.addAll(run);
      }
      run.clear();
    }

    for (final word in words) {
      if (word.length == 1) {
        run.add(word);
      } else {
        flushRun();
        merged.add(word);
      }
    }
    flushRun();
    return merged;
  }

  static bool _isBlockedWord(String word) {
    for (final spelling in _spellings(word)) {
      if (_blockedWords.contains(spelling) ||
          _containsBlockedFragment(spelling)) {
        return true;
      }
    }
    return false;
  }

  /// The word plus its stretched-letter and plural readings:
  /// "fuuuck" → "fuck", "asss" → "ass", "cunts" → "cunt".
  static Iterable<String> _spellings(String word) sync* {
    final stretchedToOne = word.replaceAllMapped(
      _stretchedLetters,
      (match) => match[1]!,
    );
    final stretchedToTwo = word.replaceAllMapped(
      _stretchedLetters,
      (match) => '${match[1]}${match[1]}',
    );
    for (final spelling in {word, stretchedToOne, stretchedToTwo}) {
      yield spelling;
      if (spelling.length > 3 && spelling.endsWith('s')) {
        yield spelling.substring(0, spelling.length - 1);
      }
    }
  }

  static bool _containsBlockedFragment(String text) =>
      _blockedFragments.any(text.contains);

  static String _normalizeDevanagari(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_devanagariNuktaLetters[char] ?? char);
    }
    return buffer.toString().replaceAll(_devanagariIgnorable, '');
  }

  static final RegExp _separators = RegExp(r'[^a-z0-9@$!]+');
  static final RegExp _edgeSymbols = RegExp(r'^[@$!]+|[@$!]+$');
  static final RegExp _latinLetter = RegExp('[a-z]');
  static final RegExp _nonLetters = RegExp('[^a-z]+');
  static final RegExp _stretchedLetters = RegExp(r'([a-z])\1{2,}');

  /// Nukta and zero-width characters, used to disguise Devanagari words.
  static final RegExp _devanagariIgnorable = RegExp('[़​-‍]');

  static const Map<String, String> _lookAlikes = {
    '0': 'o',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '@': 'a',
    r'$': 's',
    '!': 'i',
  };

  static const Map<String, String> _diacritics = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
    'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', //
    'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', //
    'ô': 'o', 'õ': 'o', 'ö': 'o', 'ù': 'u', 'ú': 'u', 'û': 'u', //
    'ü': 'u', 'ý': 'y', 'ÿ': 'y',
  };

  /// Precomposed Devanagari letters with nukta, mapped to their base letter.
  static const Map<String, String> _devanagariNuktaLetters = {
    'क़': 'क', // क़ → क
    'ख़': 'ख', // ख़ → ख
    'ग़': 'ग', // ग़ → ग
    'ज़': 'ज', // ज़ → ज
    'ड़': 'ड', // ड़ → ड
    'ढ़': 'ढ', // ढ़ → ढ
    'फ़': 'फ', // फ़ → फ
    'य़': 'य', // य़ → य
  };

  /// Blocked only as a whole word. Deliberately excludes words that are
  /// also common names or name parts (e.g. "dick", "randi", "lund", "anal",
  /// "kutti", "chakka") to avoid false positives.
  static const Set<String> _blockedWords = {
    // Profanity and insults
    'shit', 'shitty', 'shite', 'shithole', 'cunt', 'twat', 'wank', 'wanker', //
    'asshole', 'arsehole', 'ass', 'dumbass', 'butthole', 'bastard', 'fck', //
    'fcking', 'biatch', 'slut', 'slutty', 'cock', 'pussy', 'pussies', //
    // Sexual content
    'penis', 'vagina', 'boobs', 'boobies', 'tits', 'titties', 'titty', //
    'cum', 'jizz', 'dildo', 'horny', 'milf', 'orgasm', 'porn', 'porno', //
    'xxx', 'nude', 'sex', 'hentai', //
    // Slurs and hate
    'chink', 'gook', 'kike', 'spic', 'wetback', 'raghead', 'towelhead', //
    'paki', 'tranny', 'trannies', 'fag', 'retard', 'retarded', 'beaner', //
    'kkk', 'nazi', 'hitler', //
    // Violence, sexual violence and abuse of minors
    'rape', 'raped', 'raping', 'rapist', 'pedo', 'paedo', 'molester', //
    // Hindi / Hinglish
    'chutiya', 'chutiye', 'chutiyapa', 'chootiya', 'chutiyo', 'gandu', //
    'gaandu', 'gaand', 'bhadwa', 'bhadwe', 'bhadva', 'bharwa', 'bharwe', //
    'harami', 'haraami', 'haramkhor', 'kutiya', 'kuttiya', 'lawda', 'lavda', //
    'lawde', 'lavde', 'lodu', 'jhantu', 'jhaant', 'chinal', 'chinaal', //
    'bsdk', 'chodu', 'choot',
  };

  /// Blocked anywhere inside a word: long or unambiguous terms that no
  /// ordinary name contains.
  static const List<String> _blockedFragments = [
    'fuck', 'nigger', 'nigga', 'faggot', 'whore', 'bitch', 'cocksuck', //
    'dicksuck', 'dickhead', 'dickface', 'bullshit', 'shithead', 'shitface', //
    'blowjob', 'handjob', 'rimjob', 'deepthroat', 'gangbang', 'cumshot', //
    'pornhub', 'childporn', 'pedophil', 'paedophil', 'killyourself', //
    'whitepower', 'heilhitler', 'bigdick', 'bigcock', 'suckmydick', //
    'suckmycock', //
    // Hindi / Hinglish
    'madarchod', 'maderchod', 'madharchod', 'maadarchod', 'behenchod', //
    'behanchod', 'bahenchod', 'bhenchod', 'bhanchod', 'betichod', 'bhosdi', //
    'bhosadi', 'bhosda', 'haramzad', 'haraamzad', 'randibaaz', 'randibaz', //
    'randikhana', 'gaandmar', 'chutmar',
  ];

  /// Hindi abuse written in Devanagari (nukta-free spellings).
  static const List<String> _devanagariFragments = [
    'मादरचोद', 'मादरचोत', 'बहनचोद', 'बहेनचोद', 'भेनचोद', 'बेटीचोद', //
    'चूतिया', 'चुतिया', 'चूतिये', 'चुतिये', 'भोसडी', 'भोसडा', 'रंडी', //
    'गांडू', 'गाँडू', 'हरामजादा', 'हरामजादी', 'हरामजादे', 'लौडा', 'लवडा', //
    'कुतिया',
  ];
}
