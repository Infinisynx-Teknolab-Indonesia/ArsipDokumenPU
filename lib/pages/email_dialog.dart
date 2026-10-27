import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

/// Kirim dokumen ke email. File asli dilampirkan OLEH SERVER (lewat SMTP yang
/// diatur admin di aplikasi Admin Server) dan tercatat di log aktivitas.
Future<void> showEmailDialog(BuildContext context, DocRecord doc) {
  final app = AppState.instance;
  if (doc.serverId == null) {
    showSnack(context, 'Dokumen ini belum terkirim ke server. Kirim email setelah dokumen tersimpan di server.', error: true);
    return Future.value();
  }
  if (!app.canUseServer) {
    showSnack(context, 'Kirim email butuh koneksi ke server.', error: true);
    return Future.value();
  }
  return showDialog(context: context, builder: (_) => _EmailDialog(doc: doc));
}

class _EmailDialog extends StatefulWidget {
  final DocRecord doc;
  const _EmailDialog({required this.doc});

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _to = TextEditingController();
  final _cc = TextEditingController();
  late final _subject = TextEditingController(text: '[Arsip PU] ${widget.doc.title}');
  final _message = TextEditingController();
  bool _sending = false;
  String? _error;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _to.dispose();
    _cc.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  List<String> _split(String s) => s.split(RegExp(r'[,;\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _send() async {
    final to = _split(_to.text), cc = _split(_cc.text);
    final bad = [...to, ...cc].where((e) => !_emailRe.hasMatch(e)).toList();
    if (to.isEmpty) {
      setState(() => _error = 'Isi minimal satu alamat email tujuan.');
      return;
    }
    if (bad.isNotEmpty) {
      setState(() => _error = 'Alamat email tidak valid: ${bad.join(', ')}');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final sent = await AppState.instance.emailDocument(widget.doc, to: to, cc: cc, subject: _subject.text.trim(), message: _message.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Email terkirim ke ${sent.join(', ')}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.forward_to_inbox_rounded, color: YmColors.accentPurple),
        const SizedBox(width: 10),
        Text('Kirim dokumen ke email', style: YmTextStyles.username.copyWith(fontSize: 16)),
      ]),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: YmColors.panelBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: YmColors.borderLavender)),
              child: Row(children: [
                FileTypeIcon(ext: d.extension, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username),
                    Text('Lampiran: ${d.fileName} • ${formatBytes(d.fileSize)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: YmTextStyles.label.copyWith(fontSize: 11.5)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _to,
              enabled: !_sending,
              autofocus: true,
              decoration: fieldDecoration('Kepada *', icon: Icons.alternate_email_rounded, hint: 'ppk@pu.go.id, konsultan@contoh.co.id'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cc,
              enabled: !_sending,
              decoration: fieldDecoration('CC (opsional)', icon: Icons.group_rounded, hint: 'pisahkan dengan koma'),
            ),
            const SizedBox(height: 10),
            TextField(controller: _subject, enabled: !_sending, decoration: fieldDecoration('Subjek', icon: Icons.subject_rounded)),
            const SizedBox(height: 10),
            TextField(
              controller: _message,
              enabled: !_sending,
              minLines: 3,
              maxLines: 6,
              decoration: fieldDecoration('Pesan (opsional)', hint: 'mis. Mohon diperiksa dan ditandatangani.'),
            ),
            const SizedBox(height: 8),
            Text('Data dokumen (judul, nomor, tanggal, proyek) otomatis ditambahkan di isi email. Pengiriman tercatat di Log Aktivitas.',
                style: YmTextStyles.label.copyWith(fontSize: 11.5)),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: YmColors.buzzRed.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: YmColors.buzzRed, fontSize: 12.5)),
              ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton.icon(
          style: primaryButtonStyle(),
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(_sending ? 'Mengirim...' : 'Kirim'),
        ),
      ],
    );
  }
}
