import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';
import 'common.dart';

/// EMAIL (SMTP): server yang dipakai untuk fitur "Kirim Email" di aplikasi.
class EmailSettingsPage extends StatefulWidget {
  final AdminApi api;
  final VoidCallback onUnauthorized;
  const EmailSettingsPage({super.key, required this.api, required this.onUnauthorized});

  @override
  State<EmailSettingsPage> createState() => _EmailSettingsPageState();
}

class _EmailSettingsPageState extends State<EmailSettingsPage> {
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _fromEmail = TextEditingController();
  final _fromName = TextEditingController();
  final _footer = TextEditingController();
  final _maxMb = TextEditingController();
  final _testTo = TextEditingController();
  String _security = 'starttls';
  bool _passSet = false, _loaded = false, _busy = false, _obscure = true;

  static const _presets = [
    ('Gmail / Google Workspace', 'smtp.gmail.com', 587, 'starttls', 'Wajib App Password (Akun Google → Keamanan → Sandi aplikasi).'),
    ('Outlook / Microsoft 365', 'smtp.office365.com', 587, 'starttls', 'SMTP AUTH harus diaktifkan admin Microsoft 365.'),
    ('Yahoo Mail', 'smtp.mail.yahoo.com', 465, 'ssl', 'Pakai App Password dari pengaturan keamanan Yahoo.'),
    ('Mail server instansi (mis. mail.batam.go.id)', '', 587, 'starttls', 'Tanyakan host/port ke pengelola email instansi.'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_host, _port, _user, _pass, _fromEmail, _fromName, _footer, _maxMb, _testTo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = await runApi(context, widget.api.settings, widget.onUnauthorized);
    if (s == null || !mounted) return;
    setState(() {
      _host.text = '${s['smtp_host']}';
      _port.text = '${s['smtp_port']}';
      _user.text = '${s['smtp_user']}';
      _fromEmail.text = '${s['smtp_from_email']}';
      _fromName.text = '${s['smtp_from_name']}';
      _footer.text = '${s['email_footer']}';
      _maxMb.text = '${s['email_max_mb']}';
      _security = '${s['smtp_security']}';
      _passSet = s['smtp_password_set'] == true;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final r = await runApi(
      context,
      () => widget.api.saveSettings({
        'smtp_host': _host.text.trim(),
        'smtp_port': int.tryParse(_port.text.trim()) ?? 587,
        'smtp_security': _security,
        'smtp_user': _user.text.trim(),
        if (_pass.text.isNotEmpty) 'smtp_password': _pass.text,
        'smtp_from_email': _fromEmail.text.trim(),
        'smtp_from_name': _fromName.text.trim(),
        'email_footer': _footer.text.trim(),
        'email_max_mb': int.tryParse(_maxMb.text.trim()) ?? 20,
      }),
      widget.onUnauthorized,
      ok: 'Pengaturan email disimpan.',
    );
    if (r != null && mounted) {
      _pass.clear();
      setState(() => _passSet = r['smtp_password_set'] == true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _test() async {
    final to = _testTo.text.trim();
    if (to.isEmpty) {
      snack(context, 'Isi alamat email tujuan tes.', error: true);
      return;
    }
    setState(() => _busy = true);
    await runApi(context, () => widget.api.testEmail(to), widget.onUnauthorized, ok: 'Email tes terkirim ke $to. Cek kotak masuk (dan folder spam).');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return PagePad(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Panel(
            title: 'Server email (SMTP)',
            icon: Icons.mail_rounded,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Dipakai tombol "Kirim Email" di aplikasi Arsip Dokumen: file dokumen dikirim oleh SERVER sebagai lampiran.',
                  style: TextStyle(color: C.muted, fontSize: 12.5)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in _presets)
                  ActionChip(
                    label: Text(p.$1),
                    tooltip: p.$5,
                    onPressed: () => setState(() {
                      if (p.$2.isNotEmpty) _host.text = p.$2;
                      _port.text = '${p.$3}';
                      _security = p.$4;
                      snack(context, p.$5);
                    }),
                  ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(flex: 3, child: TextField(controller: _host, decoration: field('Host SMTP', icon: Icons.dns_rounded, hint: 'smtp.gmail.com'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _port, keyboardType: TextInputType.number, decoration: field('Port'))),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_security),
                    initialValue: _security,
                    decoration: field('Keamanan'),
                    items: const [
                      DropdownMenuItem(value: 'starttls', child: Text('STARTTLS (587)')),
                      DropdownMenuItem(value: 'ssl', child: Text('SSL/TLS (465)')),
                      DropdownMenuItem(value: 'none', child: Text('Tanpa enkripsi (25)')),
                    ],
                    onChanged: (v) => setState(() => _security = v ?? 'starttls'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: _user, decoration: field('Username SMTP', icon: Icons.person_rounded, hint: 'arsip@pu.go.id'))),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _pass,
                    obscureText: _obscure,
                    decoration: field(_passSet ? 'Password SMTP (tersimpan — isi untuk mengganti)' : 'Password SMTP', icon: Icons.key_rounded,
                        suffix: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        )),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: _fromEmail, decoration: field('Email pengirim', icon: Icons.outgoing_mail, hint: 'arsip@pu.go.id'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _fromName, decoration: field('Nama pengirim', hint: 'Arsip Dokumen PUPR'))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(flex: 3, child: TextField(controller: _footer, decoration: field('Catatan di bawah email (opsional)', hint: 'Dinas PUPR Kota Batam — jangan balas email ini'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _maxMb, keyboardType: TextInputType.number, decoration: field('Maks lampiran (MB)'))),
              ]),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(style: primary(), onPressed: _busy ? null : _save, icon: const Icon(Icons.save_rounded, size: 18), label: const Text('Simpan')),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Panel(
            title: 'Tes kirim email',
            icon: Icons.send_rounded,
            child: Row(children: [
              Expanded(child: TextField(controller: _testTo, decoration: field('Kirim email tes ke', icon: Icons.alternate_email_rounded, hint: 'email Anda'))),
              const SizedBox(width: 10),
              OutlinedButton.icon(style: outline(), onPressed: _busy ? null : _test, icon: const Icon(Icons.send_rounded, size: 18), label: const Text('Kirim tes')),
            ]),
          ),
        ]),
      ),
    );
  }
}
