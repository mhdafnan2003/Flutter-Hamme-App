const {
  DataSet,
  RegExpMatcher,
  englishDataset,
  englishRecommendedTransformers,
  englishRecommendedWhitelistMatcherTransformers,
  pattern,
  resolveConfusablesTransformer,
  resolveLeetSpeakTransformer,
} = require('obscenity');

const { objectionableContentError } = require('./safety');

// Profanity / slur / sexual-content filter for the names, usernames and social
// handles people choose. Built on obscenity's English list, which already
// handles leetspeak ("sh1t"), look-alike characters and stretched letters
// ("fuuuck"), plus a supplementary Hindi/Hinglish list for our mostly Indian
// user base.
//
// False positives stop real people from using their own name, so the stock
// list is adjusted: a few phrases are redefined and real names that contain a
// blocked word (Harshit, Akshit, Anusha, Wankhede...) are whitelisted. Run a
// wide list of real names through isObjectionable() after changing anything.

function phraseOf(originalWord, patterns, whitelist = []) {
  return (phrase) => {
    phrase.setMetadata({ originalWord });
    patterns.forEach((value) => phrase.addPattern(value));
    whitelist.forEach((value) => phrase.addWhitelistedTerm(value));
    return phrase;
  };
}

// Stock phrases whose patterns are replaced below.
const REDEFINED_PHRASES = new Set(['fuck', 'sex', 'anal', 'jizz']);

// Real names and words that contain a blocked pattern. Whitelisted terms apply
// to every pattern: a match lying inside one of these words is ignored.
const NAME_WHITELIST = [
  // "shit": Harshit, Akshit, Dikshit, Parikshit, Kshitij, Nishit, Shital, Shitole...
  'kshit', 'harshit', 'darshit', 'nishit', 'rishit', 'tushit', 'ashit', 'shittu',
  'shital', 'shitij', 'shitiz', 'shitanshu', 'shitol', 'shiitake', 'shithil',
  // "anus": Anusha, Anushka, Dhanush, Tanushree, Manushi, Anusuya, Anusree.
  'anush', 'anusk', 'anusuya', 'anusooya', 'anusri', 'anusree',
  // "anal": Annalise / Analise.
  'annalise', 'annalisa', 'analise', 'analisa', 'analia',
  // "dick": surnames.
  'dickson', 'dickinson', 'dickerson', 'dickey', 'dickie', 'dicky', 'riddick',
  // "sex": places and ordinary words.
  'sussex', 'essex', 'wessex', 'middlesex', 'unisex', 'intersex', 'sexton', 'sextant',
  'sextet', 'sextupl', 'sexagen', 'sexena',
  // "porn": Thai given names (Pornchai, Porntip, Pornpimol, Pornsak...).
  'pornchai', 'porntip', 'pornthip', 'pornpimol', 'pornpim', 'pornsak', 'pornsiri',
  'pornthep', 'pornrat', 'pornsawan', 'pornprom',
  // "boob": Tamil names (Boobathi, Boobalan).
  'boobathi', 'boobathy',
  // "fag": Fagun / Phagun (a Hindu month, used as a name).
  'fagun', 'fagoon',
  // Assorted names and words (Wankhede, Pornima, Phukan, Pat Cummins...).
  'wankhede', 'pornima', 'boobalan', 'georgy', 'georgie', 'cumin', 'cumming', 'cummins',
  'semenya', 'semenov', 'penistone', 'rapeseed', 'fagan', 'fagin', 'cockpit',
  'phukan', 'phuket',
];

function buildMatcher() {
  const dataset = new DataSet()
    .addAll(englishDataset)
    .removePhrasesIf((phrase) => REDEFINED_PHRASES.has(phrase.metadata?.originalWord))
    // The stock version also rejects the whole word "fu", a common surname.
    .addPhrase(
      phraseOf(
        'fuck',
        [pattern`f[?]ck`, pattern`|fk`, pattern`|fuk`, pattern`phuck`, pattern`phuk`, pattern`|fcuk`],
        ['fick', 'kung-fu', 'kung fu', 'fuku']
      )
    )
    // The stock version only rejects the exact words "sex" and "sexy".
    .addPhrase(phraseOf('sex', [pattern`|s[s]e[e]x`, pattern`s[s]e[e]x|`]))
    // The stock version also rejects "?anal" (Pranali, Sanal); keep the anchored form.
    .addPhrase(
      phraseOf('anal', [pattern`|anal`], ['analabos', 'analagous', 'analav', 'analy', 'analog', 'an al'])
    )
    // The stock "jizz" never matches: repeated letters are collapsed first.
    .addPhrase(phraseOf('jizz', [pattern`|jiz`]))
    .addPhrase(phraseOf('nazi', [pattern`|nazi|`, pattern`|nazis|`, pattern`hitler`]))
    .addPhrase(phraseOf('paki', [pattern`|paki|`, pattern`|pakis|`]))
    .addPhrase(phraseOf('kill yourself', [pattern`kil[l][ ]your[ ]self`, pattern`|kys|`]))
    // Hinglish (romanised Hindi), written in the collapsed form the matcher sees:
    // repeated letters are merged first ("gaandu" -> "gandu"), except b/e/o/l/s/g.
    // Deliberately absent because they are also common names or words: randi,
    // lund, gand(hi), chutia (an Assamese community), kutti, chakka.
    .addPhrase(
      phraseOf('chutiya', [
        pattern`chutiy`,
        pattern`chootiy`,
        pattern`|chut|`,
        pattern`|choot|`,
        pattern`chutmar`,
        pattern`chootmar`,
      ])
    )
    .addPhrase(
      phraseOf('madarchod', [
        pattern`mad[a]rchod`,
        pattern`maderchod`,
        pattern`madarjat`,
        pattern`motherchod`,
      ])
    )
    .addPhrase(
      phraseOf('behenchod', [
        pattern`beh[e]nchod`,
        pattern`bahenchod`,
        pattern`bahanchod`,
        pattern`bhenchod`,
        pattern`bhanchod`,
        pattern`benchod`,
        pattern`banchod`,
        pattern`|bhencho|`,
        pattern`|behencho|`,
        pattern`|bencho|`,
      ])
    )
    .addPhrase(phraseOf('bhosdike', [pattern`bhosd`, pattern`bhosad`, pattern`|bsdk`]))
    .addPhrase(phraseOf('gandu', [pattern`|gandu`]))
    .addPhrase(
      phraseOf('lauda', [
        pattern`|lauda|`,
        pattern`|lawda`,
        pattern`|lavda`,
        pattern`|loda|`,
        pattern`|lodu|`,
        pattern`|laude|`,
        pattern`|lawde|`,
        pattern`|lavde|`,
      ])
    )
    .addPhrase(
      phraseOf('randi', [pattern`randikhana`, pattern`randibaz`, pattern`|randwa`, pattern`|randwe`])
    )
    .addPhrase(
      phraseOf('harami', [pattern`harami`, pattern`haramzad`, pattern`haramjad`, pattern`haramkhor`])
    )
    .addPhrase(phraseOf('kutiya', [pattern`kutiya`]))
    .addPhrase(phraseOf('bhadwa', [pattern`bhadw`, pattern`bhadv`]))
    .addPhrase(phraseOf('jhaatu', [pattern`|jhat|`, pattern`|jhatu`, pattern`|jhant`]))
    .addPhrase(phraseOf('chhinal', [pattern`|chinal`]))
    .addPhrase(
      phraseOf(
        'chudai',
        [pattern`chudai`, pattern`|chodu`, pattern`chudakad`, pattern`|chudw`],
        ['chudail']
      )
    )
    .addPhrase(phraseOf('hijda', [pattern`|hijd`]))
    .addPhrase(phraseOf('tmkc', [pattern`|tmkc|`]));

  const { blacklistedTerms, whitelistedTerms } = dataset.build();
  return new RegExpMatcher({
    blacklistedTerms,
    whitelistedTerms: [...whitelistedTerms, ...NAME_WHITELIST],
    ...englishRecommendedTransformers,
    // The stock whitelist transformers skip leetspeak, so "sh1tal" matched the
    // "shit" pattern but not the "shital" whitelist entry.
    whitelistMatcherTransformers: [
      resolveConfusablesTransformer(),
      resolveLeetSpeakTransformer(),
      ...englishRecommendedWhitelistMatcherTransformers,
    ],
  });
}

// Devanagari spellings, matched as substrings after normalising nukta and
// chandrabindu (so ड़/ड and ँ/ं compare equal).
const DEVANAGARI_TERMS = [
  'चूतिय', 'चुतिय', 'मादरचोद', 'बहनचोद', 'बहनचो', 'भेनचोद', 'भेनचो', 'भोसड', 'गांडू',
  'गान्डू', 'लौडा', 'लौडे', 'लवडा', 'रंडी', 'रण्डी', 'हरामी', 'हरामजादा', 'हरामजादी',
  'हरामखोर', 'कुतिया', 'चुदाई', 'चोदू', 'छिनाल', 'भडवा', 'भडवे', 'झाटू', 'झांटू',
];

// "f.u.c.k", "s-h-i-t", "f u c k": single characters split by separators.
const SPACED_LETTERS = /(?<![\p{L}\p{N}])(?:[\p{L}\p{N}][\s.-]){2,}[\p{L}\p{N}](?![\p{L}\p{N}])/gu;
// Stand-alone numbers ("rahul_455") are not leetspeak for letters.
const NUMBER_TOKEN = /(?<![\p{L}\p{N}])\p{N}+(?![\p{L}\p{N}])/gu;
const ZERO_WIDTH = /[\u200B-\u200D\u2060\uFEFF]/g;
const LATIN_ACCENTS = /[\u0300-\u036f]/g;
const NUKTA = /\u093C/g;
const CHANDRABINDU = /\u0901/g;
const ANUSVARA = '\u0902';

let matcher = null;

function normalize(value) {
  return (
    value
      .normalize('NFKC')
      // Zero-width characters can be used to split a word.
      .replace(ZERO_WIDTH, '')
      // Drop accents from Latin letters only (Devanagari vowel signs are marks too).
      .normalize('NFD')
      .replace(LATIN_ACCENTS, '')
      .normalize('NFC')
      // The matcher's word boundaries treat "_" as a letter; usernames use it as a space.
      .replace(/_/g, ' ')
      .replace(NUMBER_TOKEN, (digits) => ' '.repeat(digits.length))
  );
}

function variantsOf(text) {
  const variants = new Set([text]);
  variants.add(text.replace(SPACED_LETTERS, (run) => run.replace(/[\s.-]/g, '')));
  // A masked letter ("sh*t", "a**hole") is usually a vowel or an s.
  if (text.includes('*')) {
    ['a', 'e', 'i', 'o', 'u', 's'].forEach((letter) => variants.add(text.replace(/\*/g, letter)));
  }
  return variants;
}

/** True if the text contains profanity, a slur or sexual content. */
function isObjectionable(value) {
  if (typeof value !== 'string' || !value.trim()) return false;
  const text = normalize(value);

  const devanagari = text.replace(NUKTA, '').replace(CHANDRABINDU, ANUSVARA);
  if (DEVANAGARI_TERMS.some((term) => devanagari.includes(term))) return true;

  // Built on first use so cold starts that never check a name don't pay for it.
  matcher = matcher || buildMatcher();
  for (const variant of variantsOf(text)) {
    if (matcher.hasMatch(variant)) return true;
  }
  return false;
}

// Label used in the user-facing message, keyed by request field name.
const FIELD_LABELS = {
  name: 'name',
  displayName: 'name',
  username: 'username',
  instagramId: 'Instagram username',
  snapchatId: 'Snapchat username',
};

/**
 * Throws 400 OBJECTIONABLE_CONTENT (details.field = request field name) for the
 * first objectionable value. `fields` maps field names to submitted values;
 * absent values are skipped.
 */
function assertCleanFields(fields) {
  for (const [field, value] of Object.entries(fields)) {
    if (isObjectionable(value)) {
      throw objectionableContentError(field, FIELD_LABELS[field] || field);
    }
  }
}

module.exports = { isObjectionable, assertCleanFields };
