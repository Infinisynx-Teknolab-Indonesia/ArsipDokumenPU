import 'package:flutter/material.dart';
import '../core/categories.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
import 'doc_detail.dart';
import 'edit_request_dialog.dart';
import '../viewer/document_viewer.dart';

/// Permintaan perubahan dokumen.
/// Admin: tinjau, bandingkan data lama vs usulan, setujui / tolak.
/// Staf: pantau status permintaan miliknya, batalkan yang masih menunggu.
class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  String _status = 'pending';
  List<EditRequest>? _items;
  bool _loading = false;
  String? _error;
  bool _wasOnline = false;

  @override
  void initState() {
    super.initState();
    _status = AppState.instance.session?.isAdmin == true ? 'pending' : 'all';
    AppState.instance.addListener(_onApp);
    _load();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onApp);
    super.dispose();
  }

  void _onApp() {
    final online = AppState.instance.canUseServer;
    if (online && !_wasOnline) _load();
    _wasOnline = online;
  }

  Future<void> _load() async {
    final app = AppState.instance;
    if (!app.canUseServer) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await app.listRequests(_status);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(EditRequest r, bool approve) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(approve ? 'Setujui perubahan?' : 'Tolak permintaan?'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                approve
                    ? 'Perubahan langsung diterapkan ke "${r.documentTitle}"${r.hasFile ? ' dan file lama disimpan sebagai versi sebelumnya' : ''}. '
                        'Semua PC akan menerima data baru saat sinkron.'
                    : 'Permintaan dari ${r.requestedByName} untuk "${r.documentTitle}" ditolak. Data dokumen tidak berubah.',
                style: YmTextStyles.chatText.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 4,
                autofocus: true,
                decoration: fieldDecoration(approve ? 'Catatan untuk staf (opsional)' : 'Alasan penolakan *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          ElevatedButton(
            style: primaryButtonStyle(color: approve ? YmColors.statusOnline : YmColors.buzzRed),
            onPressed: () {
              if (!approve && note.text.trim().isEmpty) return;
              Navigator.pop(c, true);
            },
            child: Text(approve ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppState.instance.reviewRequest(r, approve: approve, note: note.text.trim());
      if (mounted) showSnack(context, approve ? 'Perubahan disetujui dan diterapkan.' : 'Permintaan ditolak.');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _cancel(EditRequest r) async {
    if (!await confirmDialog(context, title: 'Batalkan permintaan?', message: 'Permintaan untuk "${r.documentTitle}" dibatalkan.', ok: 'Batalkan')) {
      return;
    }
    try {
      await AppState.instance.cancelRequest(r);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _openProposedFile(EditRequest r) async {
    try {
      final path = await AppState.instance.downloadTemp('/edit-requests/${r.id}/file', 'permintaan_${r.id}', r.newFileName);
      if (!mounted) return;
      await openDocumentViewer(context, path: path, title: 'File usulan: ${r.documentTitle}', fileName: r.newFileName, subtitle: 'Permintaan perubahan dari ${r.requestedByName}');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  void _openDoc(EditRequest r) {
    final d = AppState.instance.allDocs.where((e) => e.clientId == r.documentClientId).firstOrNull;
    if (d != null) {
      showDocDetail(context, d);
    } else {
      showSnack(context, 'Dokumen belum tersinkron ke PC ini. Klik Sinkronkan lalu coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final isAdmin = app.session!.isAdmin;
        if (!app.canUseServer) {
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: app.setupMode ? 'Belum terhubung ke server' : 'Server offline',
            message: 'Permintaan perubahan dokumen disimpan di server. Halaman ini aktif lagi saat terhubung.',
          );
        }
        final items = _items ?? const <EditRequest>[];
        return PageBody(
          scroll: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isAdmin
                          ? 'Staf tidak bisa mengubah dokumen yang sudah diarsipkan secara langsung. Tinjau usulan mereka di sini.'
                          : 'Permintaan perubahan yang Anda ajukan. Buka dokumen di Arsip lalu klik "Ajukan Perubahan" untuk membuat permintaan baru.',
                      style: YmTextStyles.label.copyWith(fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: outlineButtonStyle(),
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Muat ulang'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final (code, label) in const [
                    ('pending', 'Menunggu'),
                    ('approved', 'Disetujui'),
                    ('rejected', 'Ditolak'),
                    ('cancelled', 'Dibatalkan'),
                    ('all', 'Semua'),
                  ])
                    ChoiceChip(
                      label: Text(code == 'pending' && app.pendingRequests > 0 ? '$label (${app.pendingRequests})' : label),
                      selected: _status == code,
                      selectedColor: YmColors.accentPurple.withOpacity(0.15),
                      onSelected: (_) {
                        setState(() => _status = code);
                        _load();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_error != null) Text(_error!, style: const TextStyle(color: YmColors.buzzRed)),
              Expanded(
                child: _loading && _items == null
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? EmptyState(
                            icon: Icons.inbox_rounded,
                            title: _status == 'pending' ? 'Tidak ada permintaan yang menunggu' : 'Tidak ada data',
                            message: isAdmin ? 'Permintaan perubahan dari staf akan muncul di sini.' : 'Anda belum punya permintaan di kategori ini.',
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _RequestCard(
                              r: items[i],
                              isAdmin: isAdmin,
                              onApprove: () => _review(items[i], true),
                              onReject: () => _review(items[i], false),
                              onCancel: () => _cancel(items[i]),
                              onOpenFile: () => _openProposedFile(items[i]),
                              onOpenDoc: () => _openDoc(items[i]),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final EditRequest r;
  final bool isAdmin;
  final VoidCallback onApprove, onReject, onCancel, onOpenFile, onOpenDoc;

  const _RequestCard({
    required this.r,
    required this.isAdmin,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    required this.onOpenFile,
    required this.onOpenDoc,
  });

  String _fmt(String key, dynamic v, {bool old = false}) {
    final s = (v ?? '').toString();
    if (s.isEmpty) return '—';
    switch (key) {
      case 'category':
        return categoryOf(s).label;
      case 'doc_date':
        return formatIsoDate(s);
      case 'project_id':
        final label = (old ? r.old['project_label'] : r.changes['project_label'])?.toString() ?? '';
        return label.isEmpty ? s : label;
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (r.status) {
      'approved' => (YmColors.statusOnline, 'DISETUJUI'),
      'rejected' => (YmColors.buzzRed, 'DITOLAK'),
      'cancelled' => (YmColors.textMuted, 'DIBATALKAN'),
      _ => (YmColors.statusAway, 'MENUNGGU'),
    };
    final keys = r.changes.keys.where((k) => k != 'project_label').toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: r.status == 'pending' ? YmColors.statusAway.withOpacity(0.6) : YmColors.borderLavender),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onOpenDoc,
                  child: Text(r.documentTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: YmColors.accentBlue, decoration: TextDecoration.underline)),
                ),
              ),
              Text('#${r.id} • ${r.requestedByName} • ${formatDateTime(r.requestedAt)}', style: YmTextStyles.label.copyWith(fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: YmColors.panelBackground, borderRadius: BorderRadius.circular(8)),
            child: Text('Alasan: ${r.reason}', style: YmTextStyles.chatText.copyWith(fontSize: 12.5)),
          ),
          const SizedBox(height: 10),
          if (keys.isNotEmpty)
            Table(
              columnWidths: const {0: FixedColumnWidth(110), 1: FlexColumnWidth(), 2: FixedColumnWidth(26), 3: FlexColumnWidth()},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(children: [
                  Text('DATA', style: YmTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                  Text('LAMA', style: YmTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(),
                  Text('USULAN BARU', style: YmTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                ]),
                for (final k in keys)
                  TableRow(children: [
                    Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(fieldLabel(k), style: YmTextStyles.username)),
                    Text(_fmt(k, r.old[k], old: true),
                        style: YmTextStyles.chatText.copyWith(fontSize: 12.5, color: YmColors.buzzRed, decoration: TextDecoration.lineThrough)),
                    const Icon(Icons.arrow_forward_rounded, size: 15, color: YmColors.textMuted),
                    Text(_fmt(k, r.changes[k]), style: YmTextStyles.chatText.copyWith(fontSize: 12.5, color: YmColors.statusOnline, fontWeight: FontWeight.w700)),
                  ]),
              ],
            ),
          if (r.hasFile)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  FileTypeIcon(ext: r.newFileName.split('.').last, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Ganti file: ${r.documentFileName}  →  ${r.newFileName} (${formatBytes(r.newFileSize)})',
                        style: YmTextStyles.chatText.copyWith(fontSize: 12.5)),
                  ),
                  if (r.status == 'pending')
                    TextButton.icon(onPressed: onOpenFile, icon: const Icon(Icons.visibility_rounded, size: 17), label: const Text('Lihat file usulan')),
                ],
              ),
            ),
          if (r.status != 'pending' && r.status != 'cancelled') ...[
            const Divider(height: 20),
            Text(
              '${r.status == 'approved' ? 'Disetujui' : 'Ditolak'} oleh ${r.reviewedByName} • ${formatDateTime(r.reviewedAt)}'
              '${r.reviewNote.isEmpty ? '' : '\nCatatan admin: ${r.reviewNote}'}',
              style: YmTextStyles.chatText.copyWith(fontSize: 12.5, color: color),
            ),
          ],
          if (r.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isAdmin) ...[
                  OutlinedButton.icon(
                    style: outlineButtonStyle(),
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 17, color: YmColors.buzzRed),
                    label: const Text('Tolak'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: primaryButtonStyle(color: YmColors.statusOnline),
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('Setujui & Terapkan'),
                  ),
                ] else
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: YmColors.buzzRed),
                    onPressed: onCancel,
                    icon: const Icon(Icons.undo_rounded, size: 17),
                    label: const Text('Batalkan permintaan'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
