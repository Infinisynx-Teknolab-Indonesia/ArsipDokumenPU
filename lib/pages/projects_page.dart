import 'package:flutter/material.dart';
import '../services/find_shortcut.dart';
import 'package:flutter/services.dart';
import '../core/categories.dart';
import '../core/file_tools.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/nav.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> with PageSearchField<ProjectsPage> {
  final _search = TextEditingController();

  @override
  String get searchPageId => 'projects';
  @override
  TextEditingController get searchController => _search;
  int _year = 0;
  String _status = '';
  String _type = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit([Project? p]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _ProjectDialog(project: p));
    if (saved == true && mounted) showSnack(context, p == null ? 'Proyek ditambahkan.' : 'Proyek diperbarui.');
  }

  Future<void> _delete(Project p, int docCount) async {
    if (docCount > 0) {
      showSnack(context, 'Proyek masih punya $docCount dokumen. Pindahkan/hapus dokumennya dulu.', error: true);
      return;
    }
    final ok = await confirmDialog(context, title: 'Hapus proyek?', message: 'Proyek "${p.label}" akan dihapus dari server.', ok: 'Hapus', danger: true);
    if (!ok) return;
    try {
      await AppState.instance.deleteProject(p);
      if (mounted) showSnack(context, 'Proyek dihapus.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final isAdmin = app.session!.isAdmin;
        final docCount = <String, int>{};
        final docSize = <String, int>{};
        for (final d in app.visibleDocs) {
          if (d.projectId.isEmpty) continue;
          docCount[d.projectId] = (docCount[d.projectId] ?? 0) + 1;
          docSize[d.projectId] = (docSize[d.projectId] ?? 0) + d.fileSize;
        }
        final q = _search.text.toLowerCase();
        final list = app.projects.where((p) {
          if (_year != 0 && p.year != _year) return false;
          if (_status.isNotEmpty && p.status != _status) return false;
          if (_type.isNotEmpty && p.type != _type) return false;
          if (q.isNotEmpty) {
            final t = '${p.code} ${p.name} ${p.location} ${p.contractor} ${p.supervisor} ${p.ppk} ${p.contractNumber}'.toLowerCase();
            if (!t.contains(q)) return false;
          }
          return true;
        }).toList();
        final years = app.projects.map((p) => p.year).toSet().toList()..sort((a, b) => b.compareTo(a));
        final total = list.fold<double>(0, (a, p) => a + p.contractValue);

        return PageBody(
          scroll: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      focusNode: searchFocus,
                      onChanged: (_) => setState(() {}),
                      decoration: fieldDecoration('Cari kode paket, nama, lokasi, kontraktor, PPK, nomor kontrak...', icon: Icons.search_rounded)
                          .copyWith(fillColor: YmColors.surface),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterDropdown<int>(
                    width: 150,
                    icon: Icons.event_rounded,
                    value: years.contains(_year) ? _year : 0,
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('Semua TA')),
                      for (final y in years) DropdownMenuItem(value: y, child: Text('TA $y')),
                    ],
                    onChanged: (v) => setState(() => _year = v ?? 0),
                  ),
                  const SizedBox(width: 8),
                  FilterDropdown<String>(
                    width: 180,
                    icon: Icons.category_rounded,
                    value: _type,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Semua jenis')),
                      for (final t in projectTypes) DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? ''),
                  ),
                  const SizedBox(width: 8),
                  FilterDropdown<String>(
                    width: 190,
                    icon: Icons.flag_rounded,
                    value: _status,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Semua status')),
                      for (final s in projectStatuses) DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? ''),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: outlineButtonStyle(),
                    onPressed: list.isEmpty
                        ? null
                        : () async {
                            final path = await FileTools.exportProjectsCsv(list, docCount);
                            if (path != null && context.mounted) showSnack(context, 'Export ke $path');
                          },
                    icon: const Icon(Icons.file_download_rounded, size: 18),
                    label: const Text('Export'),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: primaryButtonStyle(),
                      onPressed: app.canUseServer ? () => _edit() : null,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tambah Proyek'),
                    ),
                  ],
                ],
              ),
              if (isAdmin && !app.canUseServer)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    app.setupMode ? 'Hubungkan ke server dulu untuk mengelola proyek.' : 'Offline: daftar proyek dari cache. Tambah/ubah proyek butuh koneksi server.',
                    style: YmTextStyles.label.copyWith(fontSize: 11.5),
                  ),
                ),
              const SizedBox(height: 12),
              Text('${list.length} proyek • total nilai kontrak ${formatRupiah(total)}', style: YmTextStyles.label.copyWith(fontSize: 12)),
              const SizedBox(height: 8),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(
                        icon: Icons.engineering_rounded,
                        title: app.projects.isEmpty ? 'Belum ada proyek' : 'Tidak ada proyek yang cocok',
                        message: app.projects.isEmpty
                            ? 'Proyek / paket pekerjaan (jalan, jembatan, gedung, irigasi) dikelola admin dan tersimpan di server. Dokumen bisa dikelompokkan per proyek.'
                            : 'Ubah kata kunci atau filter.',
                      )
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final p = list[i];
                          return _ProjectCard(
                            project: p,
                            docCount: docCount[p.id] ?? 0,
                            docSize: docSize[p.id] ?? 0,
                            isAdmin: isAdmin,
                            canEdit: app.canUseServer,
                            onEdit: () => _edit(p),
                            onDelete: () => _delete(p, docCount[p.id] ?? 0),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Color _statusColor(String s) => switch (s) {
      'Pelaksanaan' => const Color(0xFF1F7AE0),
      'PHO' || 'Masa Pemeliharaan' => const Color(0xFF0E8F7E),
      'FHO / Selesai' => YmColors.statusOnline,
      'Dihentikan' => YmColors.buzzRed,
      _ => YmColors.statusAway,
    };

class _ProjectCard extends StatelessWidget {
  final Project project;
  final int docCount;
  final int docSize;
  final bool isAdmin;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.docCount,
    required this.docSize,
    required this.isAdmin,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = project;
    final sc = _statusColor(p.status);
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: Text(k, style: YmTextStyles.label.copyWith(fontSize: 11.5))),
              Expanded(child: Text(v.isEmpty ? '-' : v, style: YmTextStyles.chatText.copyWith(fontSize: 12))),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: YmColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: YmColors.borderLavender),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(
              switch (p.type) {
                'Jalan' => Icons.add_road_rounded,
                'Jembatan' => Icons.water_rounded,
                'Gedung / Bangunan' => Icons.apartment_rounded,
                'Irigasi' => Icons.water_drop_rounded,
                'Drainase' => Icons.waves_rounded,
                _ => Icons.construction_rounded,
              },
              color: sc,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(p.code, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: YmColors.accentPurple)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(p.status, style: TextStyle(fontSize: 11, color: sc, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    Text('TA ${p.year} • ${p.type}', style: YmTextStyles.label.copyWith(fontSize: 11.5)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(p.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: YmColors.textDark)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.place_rounded, size: 14, color: YmColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(p.location.isEmpty ? '-' : p.location, style: YmTextStyles.label.copyWith(fontSize: 12))),
                ]),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: p.progress / 100,
                          minHeight: 8,
                          backgroundColor: YmColors.panelBackground,
                          valueColor: AlwaysStoppedAnimation(sc),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Progres ${p.progress}%', style: YmTextStyles.username.copyWith(fontSize: 11.5)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 5,
            child: Column(
              children: [
                kv('Nilai kontrak', p.contractValue > 0 ? formatRupiah(p.contractValue) : '-'),
                kv('Sumber dana', p.fundingSource),
                kv('No. kontrak', p.contractNumber),
                kv('Kontraktor', p.contractor),
                kv('Konsultan', p.supervisor),
                kv('PPK', p.ppk),
                kv('Jadwal', '${formatIsoDate(p.startDate)} s/d ${formatIsoDate(p.endDate)}'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 170,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$docCount dokumen', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: YmColors.accentPurple)),
                Text(formatBytes(docSize), textAlign: TextAlign.center, style: YmTextStyles.label),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: primaryButtonStyle().copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 11))),
                  onPressed: () => Nav.openDocsForProject(p.id),
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text('Lihat dokumen'),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  style: outlineButtonStyle().copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 11))),
                  onPressed: () => Nav.uploadForProject(p.id),
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: const Text('Unggah'),
                ),
                if (isAdmin)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(tooltip: 'Edit proyek', onPressed: canEdit ? onEdit : null, icon: const Icon(Icons.edit_rounded, size: 18)),
                      IconButton(
                        tooltip: 'Hapus proyek',
                        onPressed: canEdit ? onDelete : null,
                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: YmColors.buzzRed),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectDialog extends StatefulWidget {
  final Project? project;
  const _ProjectDialog({this.project});

  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  late final TextEditingController _code, _name, _location, _value, _contractNo, _contractor, _supervisor, _ppk, _desc;
  late String _type, _status, _funding, _start, _end;
  late int _year;
  late double _progress;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _code = TextEditingController(text: p?.code ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _location = TextEditingController(text: p?.location ?? '');
    _value = TextEditingController(text: p == null || p.contractValue == 0 ? '' : p.contractValue.round().toString());
    _contractNo = TextEditingController(text: p?.contractNumber ?? '');
    _contractor = TextEditingController(text: p?.contractor ?? '');
    _supervisor = TextEditingController(text: p?.supervisor ?? '');
    _ppk = TextEditingController(text: p?.ppk ?? '');
    _desc = TextEditingController(text: p?.description ?? '');
    _type = projectTypes.contains(p?.type) ? p!.type : projectTypes.first;
    _status = projectStatuses.contains(p?.status) ? p!.status : projectStatuses.first;
    _funding = fundingSources.contains(p?.fundingSource) ? p!.fundingSource : fundingSources[2];
    _start = p?.startDate ?? '';
    _end = p?.endDate ?? '';
    _year = p?.year ?? DateTime.now().year;
    _progress = (p?.progress ?? 0).toDouble();
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _location, _value, _contractNo, _contractor, _supervisor, _ppk, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<String?> _pickDate(String current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    return picked == null ? null : isoDate(picked);
  }

  Future<void> _save() async {
    if (_code.text.trim().isEmpty || _name.text.trim().isEmpty) {
      showSnack(context, 'Kode paket dan nama paket wajib diisi.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await AppState.instance.saveProject(Project(
        id: widget.project?.id ?? '',
        code: _code.text.trim(),
        name: _name.text.trim(),
        type: _type,
        location: _location.text.trim(),
        year: _year,
        fundingSource: _funding,
        contractValue: double.tryParse(_value.text.replaceAll('.', '').replaceAll(',', '').trim()) ?? 0,
        contractor: _contractor.text.trim(),
        supervisor: _supervisor.text.trim(),
        ppk: _ppk.text.trim(),
        contractNumber: _contractNo.text.trim(),
        startDate: _start,
        endDate: _end,
        status: _status,
        progress: _progress.round(),
        description: _desc.text.trim(),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, e.toString(), error: true);
      }
    }
  }

  Widget _dateField(String label, String value, ValueChanged<String> onPicked) => InkWell(
        onTap: () async {
          final v = await _pickDate(value);
          if (v != null) setState(() => onPicked(v));
        },
        child: InputDecorator(
          decoration: fieldDecoration(label, icon: Icons.event_rounded),
          child: Text(value.isEmpty ? 'Pilih tanggal' : formatIsoDate(value), style: const TextStyle(fontSize: 13.5)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    const hgap = SizedBox(width: 12);
    final yearNow = DateTime.now().year;
    final years = [for (var y = yearNow + 2; y >= 2015; y--) y];
    if (!years.contains(_year)) years.add(_year);
    return AlertDialog(
      title: Text(widget.project == null ? 'Tambah Proyek / Paket Pekerjaan' : 'Edit Proyek'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(children: [
                Expanded(flex: 2, child: TextField(controller: _code, decoration: fieldDecoration('Kode Paket *', hint: 'PU-JLN-2026-001'))),
                hgap,
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: fieldDecoration('Tahun Anggaran'),
                    items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))],
                    onChanged: (v) => setState(() => _year = v ?? yearNow),
                  ),
                ),
                hgap,
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: fieldDecoration('Jenis Pekerjaan'),
                    items: [for (final t in projectTypes) DropdownMenuItem(value: t, child: Text(t))],
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                ),
              ]),
              gap,
              TextField(controller: _name, decoration: fieldDecoration('Nama Paket Pekerjaan *', hint: 'Peningkatan Jalan Simpang Kara – Batu Aji')),
              gap,
              TextField(controller: _location, decoration: fieldDecoration('Lokasi', icon: Icons.place_rounded, hint: 'Kec. Batu Aji, Kota Batam (STA 0+000 – 3+200)')),
              gap,
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _value,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: fieldDecoration('Nilai Kontrak (Rp)', icon: Icons.payments_rounded),
                  ),
                ),
                hgap,
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _funding,
                    decoration: fieldDecoration('Sumber Dana'),
                    items: [for (final f in fundingSources) DropdownMenuItem(value: f, child: Text(f))],
                    onChanged: (v) => setState(() => _funding = v ?? _funding),
                  ),
                ),
                hgap,
                Expanded(child: TextField(controller: _contractNo, decoration: fieldDecoration('Nomor Kontrak'))),
              ]),
              gap,
              Row(children: [
                Expanded(child: TextField(controller: _contractor, decoration: fieldDecoration('Kontraktor Pelaksana', icon: Icons.business_rounded))),
                hgap,
                Expanded(child: TextField(controller: _supervisor, decoration: fieldDecoration('Konsultan Pengawas', icon: Icons.fact_check_rounded))),
              ]),
              gap,
              Row(children: [
                Expanded(child: TextField(controller: _ppk, decoration: fieldDecoration('PPK (Pejabat Pembuat Komitmen)', icon: Icons.badge_rounded))),
                hgap,
                Expanded(child: _dateField('Tanggal Mulai', _start, (v) => _start = v)),
                hgap,
                Expanded(child: _dateField('Tanggal Selesai', _end, (v) => _end = v)),
              ]),
              gap,
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: fieldDecoration('Status Proyek', icon: Icons.flag_rounded),
                    items: [for (final s in projectStatuses) DropdownMenuItem(value: s, child: Text(s))],
                    onChanged: (v) => setState(() => _status = v ?? _status),
                  ),
                ),
                hgap,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Progres fisik: ${_progress.round()}%', style: YmTextStyles.username),
                      Slider(value: _progress, min: 0, max: 100, divisions: 100, label: '${_progress.round()}%', onChanged: (v) => setState(() => _progress = v)),
                    ],
                  ),
                ),
              ]),
              gap,
              TextField(controller: _desc, minLines: 2, maxLines: 4, decoration: fieldDecoration('Keterangan', icon: Icons.notes_rounded)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(style: primaryButtonStyle(), onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan...' : 'Simpan')),
      ],
    );
  }
}
