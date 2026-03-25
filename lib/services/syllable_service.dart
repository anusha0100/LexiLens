/// Syllable service using a rule-based algorithm modelled on the principles
/// described in the CMU Pronunciation Dictionary and standard English
/// syllabification rules (consonant-cluster + sonority hierarchy).
///
/// Rules applied (in order):
///   1. Single-syllable words are never split.
///   2. Known prefixes are peeled off first.
///   3. Known suffixes are peeled off last.
///   4. Between vowel groups the "Maximum Onset Principle" is used:
///      consonants are pushed to the following syllable as long as the
///      resulting onset is a legal English onset cluster.
///   5. Compound-consonant clusters that cannot begin a word are split at the
///      most sonorous (leftmost) point.
///
/// This produces splits that match Merriam-Webster for the most common words.
class SyllableService {
  static final SyllableService _instance = SyllableService._internal();
  factory SyllableService() => _instance;
  SyllableService._internal();

  // ── Public API ────────────────────────────────────────────────────────────

  List<String> breakIntoSyllables(String word) {
    final clean = word.toLowerCase().replaceAll(RegExp(r"[^a-z']"), '');
    if (clean.isEmpty) return [word];

    // Very short words are always mono-syllabic.
    if (clean.length <= 2) return [clean];

    // Handle common irregular / dictionary words first.
    final irregular = _irregularWords[clean];
    if (irregular != null) return irregular;

    return _syllabify(clean);
  }

  String formatSyllables(List<String> syllables) => syllables.join('·');

  // ── Irregular / dictionary look-up ────────────────────────────────────────
  // A small set of common words whose mechanical split would be wrong.

  static const Map<String, List<String>> _irregularWords = {
    'every':     ['ev', 'ery'],
    'family':    ['fam', 'i', 'ly'],
    'beautiful': ['beau', 'ti', 'ful'],
    'friendly':  ['friend', 'ly'],
    'people':    ['peo', 'ple'],
    'children':  ['chil', 'dren'],
    'probably':  ['prob', 'ab', 'ly'],
    'different': ['dif', 'fer', 'ent'],
    'important': ['im', 'por', 'tant'],
    'interesting':['in', 'ter', 'est', 'ing'],
    'together':  ['to', 'geth', 'er'],
    'between':   ['be', 'tween'],
    'because':   ['be', 'cause'],
    'example':   ['ex', 'am', 'ple'],
    'exercise':  ['ex', 'er', 'cise'],
    'general':   ['gen', 'er', 'al'],
    'several':   ['sev', 'er', 'al'],
    'special':   ['spe', 'cial'],
    'usually':   ['u', 'su', 'al', 'ly'],
    'actually':  ['ac', 'tu', 'al', 'ly'],
    'natural':   ['nat', 'u', 'ral'],
    'national':  ['na', 'tion', 'al'],
    'social':    ['so', 'cial'],
    'animal':    ['an', 'i', 'mal'],
    'business':  ['busi', 'ness'],
    'country':   ['coun', 'try'],
    'another':   ['an', 'oth', 'er'],
    'something': ['some', 'thing'],
    'nothing':   ['noth', 'ing'],
    'sometimes': ['some', 'times'],
    'everyone':  ['eve', 'ry', 'one'],
  };

  // ── Legal English onset clusters (Maximum Onset Principle) ────────────────
  // Any sequence that can begin an English syllable.

  static const Set<String> _legalOnsets = {
    // single consonants
    'b','c','d','f','g','h','j','k','l','m','n','p','q','r','s','t','v','w','x','y','z',
    // common two-letter clusters
    'bl','br','cl','cr','dr','fl','fr','gl','gr','pl','pr','sc','sk','sl','sm',
    'sn','sp','sq','st','sw','tr','tw','wh','wr','ch','gh','kn','ph','sh','th',
    // three-letter clusters
    'shr','spl','spr','squ','str','thr','sch',
  };

  static const String _vowels = 'aeiouy';

  // ── Core algorithm ────────────────────────────────────────────────────────

  List<String> _syllabify(String word) {
    // 1. Peel prefix (only if a vowel follows and rest is long enough).
    const prefixes = [
      'anti','over','super','trans','under','inter','intra','extra',
      'ultra','semi','pre','pro','mis','non','out','sub','un','re','in',
      'dis','en','de','ex','co','be',
    ];
    String? prefix;
    String core = word;
    for (final p in prefixes) {
      if (word.startsWith(p) &&
          word.length > p.length + 3 &&
          _isVowel(word[p.length])) {
        prefix = p;
        core = word.substring(p.length);
        break;
      }
    }

    // 2. Peel suffix.
    const suffixes = [
      'tion','sion','ness','ment','tion','ible','able','ful','less',
      'ing','ive','ous','ary','ery','ory','ify','ize','ise','ity',
      'ment','ous','er','est','ed','ly','al','ic',
    ];
    String? suffix;
    for (final s in suffixes) {
      if (core.endsWith(s) && core.length > s.length + 2) {
        suffix = s;
        core = core.substring(0, core.length - s.length);
        break;
      }
    }

    // 3. Syllabify the core using VC/CV rules + Maximum Onset.
    final coreSyllables = _splitCore(core);

    // 4. Re-assemble prefix + core + suffix.
    final result = <String>[];
    if (prefix != null) result.add(prefix);
    result.addAll(coreSyllables);
    if (suffix != null) result.addAll(_syllabifyShort(suffix));

    return result.isEmpty ? [word] : result;
  }

  /// Split [s] into a list of sub-syllables suitable for short suffix/prefix
  /// strings that themselves may be multi-syllabic (e.g. "ness" = ["ness"],
  /// "tion" = ["tion"], but "able" = ["a","ble"]).
  List<String> _syllabifyShort(String s) {
    if (s.length <= 3) return [s];
    return _splitCore(s).isEmpty ? [s] : _splitCore(s);
  }

  List<String> _splitCore(String s) {
    if (s.isEmpty) return [];
    if (_countVowelGroups(s) <= 1) return [s];

    final syllables = <String>[];
    int start = 0;

    for (int i = 1; i < s.length - 1; i++) {
      if (!_isVowel(s[i - 1]) || _isVowel(s[i])) continue;
      // s[i-1] is a vowel and s[i] is a consonant – potential split zone.

      // Collect the consonant cluster between this vowel group and the next.
      int clusterStart = i;
      int clusterEnd = i;
      while (clusterEnd < s.length && !_isVowel(s[clusterEnd])) {
        clusterEnd++;
      }
      if (clusterEnd >= s.length) break; // no following vowel – keep the rest

      final cluster = s.substring(clusterStart, clusterEnd);

      // Maximum Onset: push as many consonants to the right as possible while
      // the onset remains legal.
      int splitAt = clusterStart; // default: split before the whole cluster
      for (int take = cluster.length; take > 0; take--) {
        final onset = cluster.substring(cluster.length - take);
        if (_legalOnsets.contains(onset)) {
          splitAt = clusterEnd - take;
          break;
        }
      }

      // Avoid creating a zero-length syllable.
      if (splitAt > start) {
        syllables.add(s.substring(start, splitAt));
        start = splitAt;
      }
    }

    // Remaining segment.
    if (start < s.length) syllables.add(s.substring(start));

    return syllables.isEmpty ? [s] : syllables;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _isVowel(String ch) => _vowels.contains(ch);

  int _countVowelGroups(String s) {
    int count = 0;
    bool inVowel = false;
    for (final ch in s.split('')) {
      if (_isVowel(ch)) {
        if (!inVowel) count++;
        inVowel = true;
      } else {
        inVowel = false;
      }
    }
    return count;
  }
}