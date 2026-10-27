import 'dart:math';
import 'categories.dart';
import 'models.dart';

/// Hasil pencarian satu dokumen.
class SearchHit {
  final DocRecord doc;
  final int score;

  /// Bagian yang cocok: judul, nomor, tag, proyek, keterangan, nama file, isi file...
  final List<String> matched;

  /// Kata/kode yang ditemukan di ISI file (untuk ditampilkan "cocok di isi file: 544").
  final List<String> contentHits;

  /// Kata dari kamus yang ikut dipakai (bukan kata yang diketik).
  final List<String> viaKamus;

  const SearchHit(this.doc, this.score, this.matched, this.contentHits, this.viaKamus);
}

/// Dokumen terkait + alasannya.
class RelatedDoc {
  final DocRecord doc;
  final int score;
  final List<String> reasons;

  /// true = satu seri (versi lain dari dokumen yang sama, mis. Formula A/B/C).
  final bool sameSeries;
  const RelatedDoc(this.doc, this.score, this.reasons, {this.sameSeries = false});
}

const _stopwords = {
  'dan', 'yang', 'di', 'ke', 'dari', 'untuk', 'dengan', 'pada', 'ini', 'itu', 'atau', 'dalam', 'akan', 'oleh',
  'adalah', 'sebagai', 'tidak', 'ada', 'juga', 'telah', 'tersebut', 'bahwa', 'serta', 'kepada', 'agar', 'bagi',
  'laporan', 'dokumen', 'surat', 'paket', 'pekerjaan', 'kegiatan', 'tahun', 'the', 'of', 'and',
};

final _codeRe = RegExp(r'\d+(?:[./\-]\d+)+');
final _numRe = RegExp(r'\d{3,}');
final _wordRe = RegExp(r'[0-9a-zA-ZÀ-ɏ]+');

String _compact(String s) => s.replaceAll(RegExp(r'[./\-\s]'), '');

/// Pencarian pintar di sisi aplikasi (jalan online maupun offline):
/// - mencari di metadata DAN token isi file (PDF/Word/Excel/TXT yang dibaca server),
/// - memperluas kata kunci lewat Kamus Pencarian (mis. "pengeluaran" -> 544, belanja),
/// - kode bertitik cocok dengan/atau tanpa titik (5.2.2.01 = 52201),
/// - semua kata kunci harus cocok (AND), hasil diurutkan menurut skor.
class SmartSearch {
  final List<Set<String>> _groups;
  final Map<String, String> tokens; // clientId -> token isi file

  SmartSearch(List<SearchTerm> terms, this.tokens) : _groups = terms.map((t) => t.group).toList();

  /// Tiap kata yang diketik -> himpunan variannya (kata itu + kamus + versi rapat kode).
  List<Set<String>> expand(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return [
      for (final w in words)
        {
          w,
          if (_compact(w) != w && _compact(w).isNotEmpty) _compact(w),
          for (final g in _groups)
            if (g.contains(w)) ...g,
        },
    ];
  }

  /// Kata-kata tambahan dari kamus (untuk ditampilkan "juga mencari: ...").
  List<String> extraTerms(String query) {
    final typed = query.toLowerCase().split(RegExp(r'\s+')).toSet();
    return expand(query).expand((g) => g).where((v) => !typed.contains(v)).toSet().toList();
  }

  List<SearchHit> search(String query, Iterable<DocRecord> docs) {
    final groups = expand(query);
    if (groups.isEmpty) return docs.map((d) => SearchHit(d, 0, const [], const [], const [])).toList();
    final typed = query.toLowerCase().split(RegExp(r'\s+')).toSet();
    final out = <SearchHit>[];
    for (final d in docs) {
      final fields = <(String, int, String)>[
        ('judul', 10, d.title.toLowerCase()),
        ('nomor', 8, '${d.docNumber.toLowerCase()} ${_compact(d.docNumber.toLowerCase())}'),
        ('tag', 6, d.tags.toLowerCase()),
        ('seri', 7, d.series.toLowerCase()),
        ('proyek', 5, '${d.projectCode} ${d.projectName}'.toLowerCase()),
        ('keterangan', 4, d.description.toLowerCase()),
        ('kategori', 3, categoryOf(d.category).label.toLowerCase()),
        ('nama file', 3, d.fileName.toLowerCase()),
        ('pengunggah', 1, '${d.createdBy} ${d.createdByName}'.toLowerCase()),
        ('isi file', 2, tokens[d.clientId] ?? ''),
      ];
      var total = 0;
      var allMatched = true;
      final matched = <String>[];
      final contentHits = <String>[];
      final viaKamus = <String>[];
      for (final g in groups) {
        var best = 0;
        for (final v in g) {
          final isTyped = typed.contains(v) || typed.any((t) => _compact(t) == v);
          for (final (name, weight, text) in fields) {
            if (text.isEmpty) continue;
            // isi file bisa panjang: lewati kalau kata ini sudah cocok di data yang lebih penting
            if (name == 'isi file' && best >= weight) continue;
            if (!text.contains(v)) continue;
            final val = isTyped ? weight : max(1, weight ~/ 2);
            if (val > best) best = val;
            if (!matched.contains(name)) matched.add(name);
            if (name == 'isi file' && !contentHits.contains(v) && contentHits.length < 5) contentHits.add(v);
            if (!isTyped && !viaKamus.contains(v) && viaKamus.length < 5) viaKamus.add(v);
          }
        }
        if (best == 0) {
          allMatched = false;
          break;
        }
        total += best;
      }
      if (allMatched) out.add(SearchHit(d, total, matched, contentHits, viaKamus));
    }
    out.sort((a, b) => b.score != a.score ? b.score.compareTo(a.score) : b.doc.createdAt.compareTo(a.doc.createdAt));
    return out;
  }

  // ------------------------------------------------------------ terkait

  static bool _isYear(String n) {
    if (n.length != 4) return false;
    final v = int.tryParse(n) ?? 0;
    return v >= 1980 && v <= 2040;
  }

  /// Angka yang terlalu umum untuk dijadikan penghubung: nomor urut pendek
  /// (001, 014, 050), angka bulat 100/1000, dan gabungan yang memuat tahun
  /// (2026001, 30122019 dari tanggal/kode paket).
  static bool _weakNumber(String n) {
    final v = int.tryParse(n);
    if (v == null) return true;
    if (v < 100 || v == 1000) return true;
    // 3 digit kelipatan 10 (600, 900, 300, 500) = kode klasifikasi surat / angka bulat umum
    if (n.length == 3 && v % 10 == 0) return true;
    if (n.length > 4 && (_isYear(n.substring(0, 4)) || _isYear(n.substring(n.length - 4)))) return true;
    return false;
  }

  /// Kode/nomor penting dari metadata (judul, nomor, tag, keterangan, nama file).
  static Set<String> metaCodes(DocRecord d) {
    final text = '${d.title} ${d.docNumber} ${d.tags} ${d.description} ${d.fileName}'.toLowerCase();
    final out = <String>{};
    for (final m in _codeRe.allMatches(text)) {
      final c = m.group(0)!;
      final parts = c.split(RegExp(r'[./\-]'));
      // 5.4.4 -> 544 (kode rekening), tapi 2026-001 / 30-12-2019 tidak (mengandung tahun)
      if (!parts.any(_isYear)) {
        final k = _compact(c);
        if (!_weakNumber(k)) out.add(k);
      }
    }
    for (final m in _numRe.allMatches(text)) {
      final n = m.group(0)!;
      if (!_isYear(n) && !_weakNumber(n)) out.add(n);
    }
    return out;
  }

  /// Cache kode isi file per dokumen (dihitung sekali, diperbarui bila token berubah).
  static final Map<String, (int, Set<String>)> _codeCache = {};

  Set<String> _contentCodesOf(String clientId) {
    final t = tokens[clientId] ?? '';
    final cached = _codeCache[clientId];
    if (cached != null && cached.$1 == t.length) return cached.$2;
    final codes = contentCodes(t);
    _codeCache[clientId] = (t.length, codes);
    return codes;
  }

  /// Kode/nomor dari isi file (token).
  static Set<String> contentCodes(String tokens) {
    if (tokens.isEmpty) return const {};
    final out = <String>{};
    for (final t in tokens.split(' ')) {
      if (t.length >= 3 && t.length <= 12 && RegExp(r'^\d+$').hasMatch(t) && !_isYear(t) && !_weakNumber(t)) out.add(t);
    }
    return out;
  }

  static Set<String> titleWords(DocRecord d) => _wordRe
      .allMatches(d.title.toLowerCase())
      .map((m) => m.group(0)!)
      .where((w) => w.length >= 4 && !_stopwords.contains(w) && !RegExp(r'^\d+$').hasMatch(w))
      .toSet();

  /// Kata penanda versi yang diabaikan saat membandingkan judul.
  static const _versionWords = {
    'rev', 'revisi', 'versi', 'ver', 'final', 'draft', 'draf', 'addendum', 'adendum', 'perubahan', 'update', 'edisi',
    'baru', 'lama', 'terbaru', 'awal', 'akhir', 'i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix', 'x',
  };

  static final Map<String, Set<String>> _baseCache = {};

  /// "Inti" judul untuk mengenali seri: huruf kecil, tanpa kata umum, tanpa huruf tunggal
  /// (A/B/C), tanpa angka tahun, tanpa kata versi (rev, revisi, v2, addendum...).
  /// Angka lain dipertahankan supaya "Dokumen 1" berbeda dengan "Dokumen 2".
  ///   "Dokumen 1 Formula A (2000)"  -> {1, formula}
  ///   "Dokumen 1 Formula C Rev.2"   -> {1, formula}
  static Set<String> baseTitle(String title) {
    final cached = _baseCache[title];
    if (cached != null) return cached;
    final out = <String>{};
    var afterVersionWord = false; // angka setelah "rev", "versi", "addendum" = nomor versi -> abaikan
    for (final m in _wordRe.allMatches(title.toLowerCase())) {
      final w = m.group(0)!;
      final isNum = RegExp(r'^\d+$').hasMatch(w);
      if (isNum) {
        if (!_isYear(w) && !afterVersionWord) out.add(w);
        afterVersionWord = false;
        continue;
      }
      afterVersionWord = false;
      if (_versionWords.contains(w) || RegExp(r'^v\d+$').hasMatch(w) || RegExp(r'^rev\d+$').hasMatch(w)) {
        afterVersionWord = true;
        continue;
      }
      if (w.length == 1) continue; // A, B, C
      if (_stopwords.contains(w) && w != 'dokumen') continue;
      out.add(w);
    }
    _baseCache[title] = out;
    return out;
  }

  /// Dua dokumen satu seri? (seri diisi sama, atau inti judulnya sama persis)
  static bool sameSeries(DocRecord a, DocRecord b) {
    final sa = a.series.trim().toLowerCase();
    final sb = b.series.trim().toLowerCase();
    if (sa.isNotEmpty && sb.isNotEmpty) return sa == sb;
    final ba = baseTitle(a.title);
    final bb = baseTitle(b.title);
    if (ba.isEmpty || bb.isEmpty) return false;
    // butuh inti judul yang cukup "berisi": minimal 2 kata, atau 1 kata >= 5 huruf
    final strong = ba.length >= 2 || ba.first.length >= 5;
    return strong && ba.length == bb.length && ba.containsAll(bb);
  }

  /// Semua anggota seri dari [d] (termasuk d), urut dari yang paling lama.
  List<DocRecord> seriesOf(DocRecord d, List<DocRecord> all) {
    final list = [for (final o in all) if (o.clientId == d.clientId || sameSeries(d, o)) o];
    if (!list.any((o) => o.clientId == d.clientId)) list.add(d);
    list.sort((a, b) {
      final da = a.docDate.isNotEmpty ? a.docDate : a.createdAt.toIso8601String();
      final db = b.docDate.isNotEmpty ? b.docDate : b.createdAt.toIso8601String();
      return da.compareTo(db);
    });
    return list;
  }

  /// Dokumen yang berhubungan dengan [d], lintas tahun:
  /// - SATU SERI (seri sama / judul inti sama: Formula A 2000, B 2002, C 2026) — paling kuat,
  /// - kode/nomor yang sama (di data atau isi file),
  /// - proyek sama, tag sama, judul mirip.
  List<RelatedDoc> related(DocRecord d, List<DocRecord> all, {int limit = 60}) {
    final myMeta = metaCodes(d);
    final myContent = _contentCodesOf(d.clientId);
    final myTags = d.tags.toLowerCase().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final myWords = titleWords(d);
    final myBase = baseTitle(d.title);

    // Kode yang muncul di terlalu banyak dokumen (mis. "100", nomor halaman) tidak dipakai.
    final df = <String, int>{};
    final metaCache = <String, Set<String>>{};
    final contentCache = <String, Set<String>>{};
    final wanted = {...myMeta, ...myContent};
    for (final o in all) {
      final m = metaCodes(o);
      final c = _contentCodesOf(o.clientId);
      metaCache[o.clientId] = m;
      contentCache[o.clientId] = c;
      if (wanted.isEmpty) continue;
      for (final code in wanted) {
        if (m.contains(code) || c.contains(code)) df[code] = (df[code] ?? 0) + 1;
      }
    }
    final maxDf = max(6, (all.length * 0.15).round());
    final maxDfMeta = max(10, (all.length * 0.25).round());

    // Tag & kata judul yang dipakai terlalu banyak dokumen (mis. "kontrak") tidak dianggap penghubung.
    final tagDf = <String, int>{};
    final wordDf = <String, int>{};
    for (final o in all) {
      for (final t in o.tags.toLowerCase().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet()) {
        tagDf[t] = (tagDf[t] ?? 0) + 1;
      }
      for (final w in titleWords(o)) {
        wordDf[w] = (wordDf[w] ?? 0) + 1;
      }
    }

    final out = <RelatedDoc>[];
    for (final o in all) {
      if (o.clientId == d.clientId) continue;
      var score = 0;
      final reasons = <String>[];

      var strong = false; // ada bukti kuat: seri / judul hampir sama / kode sama / satu proyek
      var weakOnlyOk = false; // tanpa bukti kuat, tag/judul harus sangat mirip

      // 1) satu seri
      final series = sameSeries(d, o);
      if (series) {
        score += 20;
        reasons.add(d.series.isNotEmpty && o.series.isNotEmpty ? 'satu seri: ${o.series}' : 'satu seri (judul sama, versi berbeda)');
      } else {
        final ob = baseTitle(o.title);
        if (myBase.length >= 2 && ob.length >= 2) {
          final inter = myBase.intersection(ob).length;
          final union = myBase.union(ob).length;
          if (union > 0 && inter / union >= 0.75) {
            score += 8;
            strong = true;
            reasons.add('judul hampir sama');
          }
        }
      }

      // 2) kode / nomor sama
      final oMeta = metaCache[o.clientId]!;
      final oContent = contentCache[o.clientId]!;
      final sharedCodes = <String>[];
      for (final code in wanted) {
        // Kode di nomor/judul dokumen ini = identitas kuat -> boleh dipakai banyak dokumen.
        // Kode yang hanya ada di isi file -> harus jarang supaya tidak menyambungkan semua dokumen.
        final limit = myMeta.contains(code) ? maxDfMeta : maxDf;
        if ((df[code] ?? 0) > limit) continue;
        final inMetaBoth = myMeta.contains(code) && oMeta.contains(code);
        final inMetaOne = (myMeta.contains(code) && oContent.contains(code)) || (myContent.contains(code) && oMeta.contains(code));
        final inContentBoth = myContent.contains(code) && oContent.contains(code);
        if (inMetaBoth) {
          score += 8;
        } else if (inMetaOne) {
          score += 5;
        } else if (inContentBoth) {
          score += 5; // kode yang sama & jarang di isi dua dokumen (mis. 544, BM-0458)
        } else {
          continue;
        }
        sharedCodes.add(code);
      }
      if (sharedCodes.isNotEmpty) {
        strong = true;
        reasons.add('kode ${sharedCodes.take(3).join(', ')}');
      }

      // 3) proyek, tag, judul
      if (d.projectId.isNotEmpty && o.projectId == d.projectId) {
        score += 5; // satu proyek / paket = selalu terkait
        strong = true;
        reasons.add('proyek sama');
      }
      final oTags = o.tags.toLowerCase().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
      final sharedTags = myTags.intersection(oTags).where((t) => (tagDf[t] ?? 0) <= maxDf).toSet();
      if (sharedTags.any((t) => (tagDf[t] ?? 0) <= 3)) weakOnlyOk = true; // tag yang jarang dipakai
      if (sharedTags.isNotEmpty) {
        score += 3 * sharedTags.length;
        reasons.add('tag ${sharedTags.take(2).join(', ')}');
      }
      if (!series) {
        final sharedWords = myWords.intersection(titleWords(o)).where((w) => (wordDf[w] ?? 0) <= maxDf).toSet();
        if (sharedWords.length >= 3) weakOnlyOk = true;
        if (sharedWords.length >= 2) {
          score += min(sharedWords.length, 3);
          reasons.add('judul mirip');
        }
      }
      if (score >= 5 && o.category == d.category) {
        score += 1;
        reasons.add('kategori sama');
      }
      if (series) strong = true;
      if (score >= 5 && (strong || weakOnlyOk)) out.add(RelatedDoc(o, score, reasons, sameSeries: series));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    final top = out.take(limit).toList()
      ..sort((a, b) => a.doc.year != b.doc.year ? b.doc.year.compareTo(a.doc.year) : b.score.compareTo(a.score));
    return top;
  }
}
