/// Model data aplikasi Arsip Dokumen Proyek PU.

class AppSettings {
  /// Alamat dasar API, contoh: http://192.168.1.10:8000/api
  final String apiUrl;

  /// true setelah admin berhasil menghubungkan aplikasi ke server.
  /// Sejak saat itu akun default administrator/administrator dimatikan
  /// dan semua login memakai akun dari server (atau cache offline-nya).
  final bool connected;

  /// Nama/jenis backend dari /health (mis. "FastAPI" atau "ASP.NET Core").
  final String serverName;

  /// Nama instansi yang tampil di aplikasi (dari server).
  final String agencyName;

  /// Kunci PC dari server (POST /devices). Dipakai menyalin daftar akun
  /// admin & staf secara berkala, juga saat belum ada yang login, supaya
  /// semua akun tetap bisa login di PC ini ketika server mati.
  final String deviceKey;
  final int deviceId;

  /// Kapan daftar akun terakhir disalin dari server ('' = belum pernah).
  final String usersSyncedAt;

  const AppSettings({
    this.apiUrl = '',
    this.connected = false,
    this.serverName = '',
    this.agencyName = '',
    this.deviceKey = '',
    this.deviceId = 0,
    this.usersSyncedAt = '',
  });

  AppSettings copyWith({String? deviceKey, int? deviceId, String? usersSyncedAt}) => AppSettings(
        apiUrl: apiUrl,
        connected: connected,
        serverName: serverName,
        agencyName: agencyName,
        deviceKey: deviceKey ?? this.deviceKey,
        deviceId: deviceId ?? this.deviceId,
        usersSyncedAt: usersSyncedAt ?? this.usersSyncedAt,
      );

  bool get hasApi => apiUrl.trim().isNotEmpty;

  Map<String, Object?> toJson() => {
        'api_url': apiUrl,
        'connected': connected,
        'server_name': serverName,
        'agency_name': agencyName,
        'device_key': deviceKey,
        'device_id': deviceId,
        'users_synced_at': usersSyncedAt,
      };

  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
        apiUrl: (j['api_url'] ?? '').toString(),
        connected: j['connected'] == true,
        serverName: (j['server_name'] ?? '').toString(),
        agencyName: (j['agency_name'] ?? '').toString(),
        deviceKey: (j['device_key'] ?? '').toString(),
        deviceId: (j['device_id'] as num?)?.toInt() ?? 0,
        usersSyncedAt: (j['users_synced_at'] ?? '').toString(),
      );
}

/// Akun yang tersimpan di PC ini supaya bisa login saat internet mati.
/// Password TIDAK disimpan — hanya hash PBKDF2-SHA256.
class CachedUser {
  final String username;
  final String fullName;
  final String role; // 'admin' | 'staff'
  final bool active;
  final String salt;
  final String hash;
  final int iterations;

  const CachedUser({
    required this.username,
    required this.fullName,
    required this.role,
    required this.active,
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  Map<String, Object?> toJson() => {
        'username': username,
        'full_name': fullName,
        'role': role,
        'active': active,
        'offline_salt': salt,
        'offline_hash': hash,
        'offline_iter': iterations,
      };

  factory CachedUser.fromJson(Map<String, Object?> j) => CachedUser(
        username: (j['username'] ?? '').toString(),
        fullName: (j['full_name'] ?? j['username'] ?? '').toString(),
        role: (j['role'] ?? 'staff').toString(),
        active: j['active'] != false,
        salt: (j['offline_salt'] ?? '').toString(),
        hash: (j['offline_hash'] ?? '').toString(),
        iterations: (j['offline_iter'] as num?)?.toInt() ?? 20000,
      );
}

/// Akun dari server (halaman Staf & Admin).
class ServerUser {
  final String username;
  final String fullName;
  final String role;
  final bool active;
  final String nip;
  final String jabatan;
  final String? lastLogin;
  final String? createdAt;

  const ServerUser({
    required this.username,
    required this.fullName,
    required this.role,
    required this.active,
    this.nip = '',
    this.jabatan = '',
    this.lastLogin,
    this.createdAt,
  });

  factory ServerUser.fromJson(Map<String, dynamic> j) => ServerUser(
        username: (j['username'] ?? '').toString(),
        fullName: (j['full_name'] ?? '').toString(),
        role: (j['role'] ?? 'staff').toString(),
        active: j['active'] != false,
        nip: (j['nip'] ?? '').toString(),
        jabatan: (j['jabatan'] ?? '').toString(),
        lastLogin: j['last_login']?.toString(),
        createdAt: j['created_at']?.toString(),
      );
}

/// Proyek / paket pekerjaan PU.
class Project {
  final String id; // id dari server
  final String code; // kode paket, mis. "PU-JLN-2026-001"
  final String name;
  final String type; // Jalan / Jembatan / Gedung ...
  final String location;
  final int year; // tahun anggaran
  final String fundingSource;
  final double contractValue;
  final String contractor;
  final String supervisor; // konsultan pengawas
  final String ppk; // pejabat pembuat komitmen
  final String contractNumber;
  final String startDate; // yyyy-MM-dd
  final String endDate;
  final String status;
  final int progress; // 0..100 (%)
  final String description;

  const Project({
    required this.id,
    required this.code,
    required this.name,
    this.type = 'Jalan',
    this.location = '',
    required this.year,
    this.fundingSource = 'APBD Kabupaten/Kota',
    this.contractValue = 0,
    this.contractor = '',
    this.supervisor = '',
    this.ppk = '',
    this.contractNumber = '',
    this.startDate = '',
    this.endDate = '',
    this.status = 'Perencanaan',
    this.progress = 0,
    this.description = '',
  });

  String get label => code.isEmpty ? name : '$code — $name';

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'type': type,
        'location': location,
        'year': year,
        'funding_source': fundingSource,
        'contract_value': contractValue,
        'contractor': contractor,
        'supervisor': supervisor,
        'ppk': ppk,
        'contract_number': contractNumber,
        'start_date': startDate,
        'end_date': endDate,
        'status': status,
        'progress': progress,
        'description': description,
      };

  factory Project.fromJson(Map<String, Object?> j) => Project(
        id: (j['id'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        type: (j['type'] ?? 'Jalan').toString(),
        location: (j['location'] ?? '').toString(),
        year: (j['year'] as num?)?.toInt() ?? DateTime.now().year,
        fundingSource: (j['funding_source'] ?? '').toString(),
        contractValue: (j['contract_value'] as num?)?.toDouble() ?? 0,
        contractor: (j['contractor'] ?? '').toString(),
        supervisor: (j['supervisor'] ?? '').toString(),
        ppk: (j['ppk'] ?? '').toString(),
        contractNumber: (j['contract_number'] ?? '').toString(),
        startDate: (j['start_date'] ?? '').toString(),
        endDate: (j['end_date'] ?? '').toString(),
        status: (j['status'] ?? 'Perencanaan').toString(),
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        description: (j['description'] ?? '').toString(),
      );
}

/// draft = disimpan di PC untuk diperiksa dulu, BELUM masuk antrian kirim.
enum DocStatus { draft, pending, uploading, uploaded, failed }

DocStatus _statusFrom(Object? s) => switch (s) {
      'uploaded' => DocStatus.uploaded,
      'failed' => DocStatus.failed,
      'draft' => DocStatus.draft,
      // 'uploading' saat aplikasi ditutup = belum pasti selesai -> ulangi.
      _ => DocStatus.pending,
    };

/// Satu dokumen arsip. Dipakai untuk dokumen buatan PC ini (antrian upload)
/// maupun dokumen dari server (cache offline) — keduanya disatukan lewat
/// [clientId] yang juga disimpan server.
class DocRecord {
  final String clientId;
  String title;
  String docNumber; // nomor surat/dokumen
  String docDate; // tanggal dokumen yyyy-MM-dd
  String category; // kode kategori (lihat categories.dart)
  String projectId; // id proyek di server ('' = tanpa proyek)
  String projectCode;
  String projectName;
  String description;
  String tags; // dipisah koma

  /// Seri / kelompok dokumen — menyatukan dokumen yang sama dari tahun ke tahun
  /// (mis. "Dokumen 1": Formula A 2000, Formula B 2002, Formula C 2026).
  String series;
  String fileName; // bisa diganti selama belum terkirim
  int fileSize;

  /// Lokasi file di PC ini ('' = belum diunduh dari server).
  String localPath;
  String createdBy; // username pengunggah
  String createdByName;
  final DateTime createdAt;
  DocStatus status;
  String? serverId;
  String? lastError;
  int attempts;
  DateTime? uploadedAt;

  /// Sidik jari file di server — kalau berubah (file diganti lewat permintaan
  /// edit yang disetujui), salinan lokal lama dibuang.
  String sha256;

  /// Status pembacaan isi file di server: pending | ok | empty | unsupported | error:..
  String contentStatus;

  DocRecord({
    required this.clientId,
    required this.title,
    this.docNumber = '',
    this.docDate = '',
    this.category = 'LAINNYA',
    this.projectId = '',
    this.projectCode = '',
    this.projectName = '',
    this.description = '',
    this.tags = '',
    this.series = '',
    required this.fileName,
    required this.fileSize,
    this.localPath = '',
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.status = DocStatus.pending,
    this.serverId,
    this.lastError,
    this.attempts = 0,
    this.uploadedAt,
    this.sha256 = '',
    this.contentStatus = '',
  });

  String get extension {
    final i = fileName.lastIndexOf('.');
    return i < 0 ? '' : fileName.substring(i + 1).toLowerCase();
  }

  bool get isUnsynced => status != DocStatus.uploaded;

  int get year {
    final d = DateTime.tryParse(docDate);
    return (d ?? createdAt).year;
  }

  /// Teks gabungan untuk pencarian cepat.
  String get searchText =>
      '$title $docNumber $description $tags $series $fileName $projectCode $projectName $createdBy $createdByName'.toLowerCase();

  Map<String, Object?> toJson() => {
        'client_id': clientId,
        'title': title,
        'doc_number': docNumber,
        'doc_date': docDate,
        'category': category,
        'project_id': projectId,
        'project_code': projectCode,
        'project_name': projectName,
        'description': description,
        'tags': tags,
        'series': series,
        'file_name': fileName,
        'file_size': fileSize,
        'local_path': localPath,
        'created_by': createdBy,
        'created_by_name': createdByName,
        'created_at': createdAt.toIso8601String(),
        'status': status.name,
        'server_id': serverId,
        'last_error': lastError,
        'attempts': attempts,
        'uploaded_at': uploadedAt?.toIso8601String(),
        'sha256': sha256,
        'content_status': contentStatus,
      };

  factory DocRecord.fromJson(Map<String, Object?> j) => DocRecord(
        clientId: (j['client_id'] ?? '').toString(),
        title: (j['title'] ?? j['name'] ?? '').toString(),
        docNumber: (j['doc_number'] ?? '').toString(),
        docDate: (j['doc_date'] ?? '').toString(),
        category: (j['category'] ?? 'LAINNYA').toString(),
        projectId: (j['project_id'] ?? '').toString(),
        projectCode: (j['project_code'] ?? '').toString(),
        projectName: (j['project_name'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        tags: (j['tags'] ?? '').toString(),
        series: (j['series'] ?? '').toString(),
        fileName: (j['file_name'] ?? '').toString(),
        fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
        localPath: (j['local_path'] ?? '').toString(),
        createdBy: (j['created_by'] ?? j['uploaded_by'] ?? '').toString(),
        createdByName: (j['created_by_name'] ?? j['uploaded_by_name'] ?? j['created_by'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        status: _statusFrom(j['status']),
        serverId: j['server_id']?.toString(),
        lastError: j['last_error']?.toString(),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        uploadedAt: DateTime.tryParse((j['uploaded_at'] ?? '').toString())?.toLocal(),
        sha256: (j['sha256'] ?? '').toString(),
        contentStatus: (j['content_status'] ?? '').toString(),
      );

  /// Dokumen dari jawaban server GET /documents.
  factory DocRecord.fromServer(Map<String, dynamic> j) => DocRecord(
        clientId: (j['client_id'] ?? 'srv-${j['id']}').toString(),
        title: (j['title'] ?? '').toString(),
        docNumber: (j['doc_number'] ?? '').toString(),
        docDate: (j['doc_date'] ?? '').toString(),
        category: (j['category'] ?? 'LAINNYA').toString(),
        projectId: (j['project_id'] ?? '').toString(),
        projectCode: (j['project_code'] ?? '').toString(),
        projectName: (j['project_name'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        tags: (j['tags'] ?? '').toString(),
        series: (j['series'] ?? '').toString(),
        fileName: (j['file_name'] ?? '').toString(),
        fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
        createdBy: (j['uploaded_by'] ?? '').toString(),
        createdByName: (j['uploaded_by_name'] ?? j['uploaded_by'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        status: DocStatus.uploaded,
        serverId: j['id'].toString(),
        uploadedAt: DateTime.tryParse((j['uploaded_at'] ?? '').toString())?.toLocal(),
        sha256: (j['sha256'] ?? '').toString(),
        contentStatus: (j['content_status'] ?? '').toString(),
      );
}

/// Baris log aktivitas dari server.
class AuditEntry {
  final String at;
  final String username;
  final String action;
  final String detail;
  final String ip;
  const AuditEntry(this.at, this.username, this.action, this.detail, this.ip);

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        (j['at'] ?? '').toString(),
        (j['username'] ?? '').toString(),
        (j['action'] ?? '').toString(),
        (j['detail'] ?? '').toString(),
        (j['ip'] ?? '').toString(),
      );
}

/// Sesi login yang sedang aktif.
class Session {
  final String username;
  final String fullName;
  final String role;

  /// true = login pakai akun default administrator (belum ada server).
  final bool isSetupAdmin;

  /// true = login tanpa server (internet mati). Jadi false begitu
  /// aplikasi berhasil mendapat token dari server.
  bool offline;

  /// Token dari server. null = sedang offline / belum dapat token.
  String? token;

  /// Disimpan HANYA di memori selama sesi, supaya saat internet kembali
  /// aplikasi bisa minta token baru otomatis tanpa user login ulang.
  String _password;

  Session({
    required this.username,
    required this.fullName,
    required this.role,
    required String password,
    this.isSetupAdmin = false,
    this.offline = false,
    this.token,
  }) : _password = password;

  bool get isAdmin => role == 'admin';
  String get password => _password;

  /// Dipanggil setelah user mengganti password-nya sendiri.
  void updatePassword(String p) => _password = p;
}

/// Kamus pencarian: istilah <-> kata/kode terkait.
class SearchTerm {
  final String id;
  final String term;
  final String related; // dipisah koma
  final String note;
  const SearchTerm({required this.id, required this.term, required this.related, this.note = ''});

  /// Semua kata dalam satu kelompok (istilah + terkait), huruf kecil.
  Set<String> get group => {
        term.trim().toLowerCase(),
        ...related.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      };

  Map<String, Object?> toJson() => {'id': id, 'term': term, 'related': related, 'note': note};

  factory SearchTerm.fromJson(Map<String, Object?> j) => SearchTerm(
        id: (j['id'] ?? '').toString(),
        term: (j['term'] ?? '').toString(),
        related: (j['related'] ?? '').toString(),
        note: (j['note'] ?? '').toString(),
      );
}

/// Permintaan perubahan dokumen (staf -> admin).
class EditRequest {
  final String id;
  final String documentId;
  final String documentClientId;
  final String documentTitle;
  final String documentFileName;
  final String requestedBy;
  final String requestedByName;
  final DateTime? requestedAt;
  final String reason;
  final Map<String, dynamic> changes;
  final Map<String, dynamic> old;
  final String newFileName;
  final int newFileSize;
  final String status; // pending | approved | rejected | cancelled
  final String reviewedByName;
  final DateTime? reviewedAt;
  final String reviewNote;

  const EditRequest({
    required this.id,
    required this.documentId,
    required this.documentClientId,
    required this.documentTitle,
    required this.documentFileName,
    required this.requestedBy,
    required this.requestedByName,
    required this.requestedAt,
    required this.reason,
    required this.changes,
    required this.old,
    required this.newFileName,
    required this.newFileSize,
    required this.status,
    required this.reviewedByName,
    required this.reviewedAt,
    required this.reviewNote,
  });

  bool get hasFile => newFileName.isNotEmpty;

  factory EditRequest.fromJson(Map<String, dynamic> j) => EditRequest(
        id: j['id'].toString(),
        documentId: j['document_id'].toString(),
        documentClientId: (j['document_client_id'] ?? '').toString(),
        documentTitle: (j['document_title'] ?? '').toString(),
        documentFileName: (j['document_file_name'] ?? '').toString(),
        requestedBy: (j['requested_by'] ?? '').toString(),
        requestedByName: (j['requested_by_name'] ?? '').toString(),
        requestedAt: DateTime.tryParse((j['requested_at'] ?? '').toString())?.toLocal(),
        reason: (j['reason'] ?? '').toString(),
        changes: Map<String, dynamic>.from((j['changes'] ?? const {}) as Map),
        old: Map<String, dynamic>.from((j['old'] ?? const {}) as Map),
        newFileName: (j['new_file_name'] ?? '').toString(),
        newFileSize: (j['new_file_size'] as num?)?.toInt() ?? 0,
        status: (j['status'] ?? 'pending').toString(),
        reviewedByName: (j['reviewed_by_name'] ?? '').toString(),
        reviewedAt: DateTime.tryParse((j['reviewed_at'] ?? '').toString())?.toLocal(),
        reviewNote: (j['review_note'] ?? '').toString(),
      );
}

/// Versi file lama sebuah dokumen.
class DocVersion {
  final String id;
  final int versionNo;
  final String fileName;
  final int fileSize;
  final DateTime? replacedAt;
  final String replacedBy;
  final String note;
  const DocVersion(this.id, this.versionNo, this.fileName, this.fileSize, this.replacedAt, this.replacedBy, this.note);

  factory DocVersion.fromJson(Map<String, dynamic> j) => DocVersion(
        j['id'].toString(),
        (j['version_no'] as num?)?.toInt() ?? 0,
        (j['file_name'] ?? '').toString(),
        (j['file_size'] as num?)?.toInt() ?? 0,
        DateTime.tryParse((j['replaced_at'] ?? '').toString())?.toLocal(),
        (j['replaced_by'] ?? '').toString(),
        (j['note'] ?? '').toString(),
      );
}
