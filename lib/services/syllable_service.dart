class SyllableService {
  static final SyllableService _instance = SyllableService._internal();
  factory SyllableService() => _instance;
  SyllableService._internal();



  List<String> breakIntoSyllables(String word) {
    final clean = word.toLowerCase().replaceAll(RegExp(r"[^a-z']"), '');
    if (clean.isEmpty) return [word];

    
    if (clean.length <= 2) return [clean];

    
    final irregular = _irregularWords[clean];
    if (irregular != null) return irregular;

    return _syllabify(clean);
  }

  String formatSyllables(List<String> syllables) => syllables.join('·');



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



  static const Set<String> _legalOnsets = {
    'b','c','d','f','g','h','j','k','l','m','n','p','q','r','s','t','v','w','x','y','z',
    'bl','br','cl','cr','dr','fl','fr','gl','gr','pl','pr','sc','sk','sl','sm',
    'sn','sp','sq','st','sw','tr','tw','wh','wr','ch','gh','kn','ph','sh','th',
    'shr','spl','spr','squ','str','thr','sch',
  };

  static const String _vowels = 'aeiouy';


  List<String> _syllabify(String word) {
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


    final coreSyllables = _splitCore(core);

    final result = <String>[];
    if (prefix != null) result.add(prefix);
    result.addAll(coreSyllables);
    if (suffix != null) result.addAll(_syllabifyShort(suffix));

    return result.isEmpty ? [word] : result;
  }


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
      
      int clusterStart = i;
      int clusterEnd = i;
      while (clusterEnd < s.length && !_isVowel(s[clusterEnd])) {
        clusterEnd++;
      }
      if (clusterEnd >= s.length) break; 

      final cluster = s.substring(clusterStart, clusterEnd);

  
      int splitAt = clusterStart; 
      for (int take = cluster.length; take > 0; take--) {
        final onset = cluster.substring(cluster.length - take);
        if (_legalOnsets.contains(onset)) {
          splitAt = clusterEnd - take;
          break;
        }
      }

      if (splitAt > start) {
        syllables.add(s.substring(start, splitAt));
        start = splitAt;
      }
    }

    
    if (start < s.length) syllables.add(s.substring(start));

    return syllables.isEmpty ? [s] : syllables;
  }


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