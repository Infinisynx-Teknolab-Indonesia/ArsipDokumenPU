import 'package:flutter/material.dart';
import '../core/categories.dart';
import '../core/file_tools.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';

/// Kartu angka di Dashboard: angka besar, keterangan di bawahnya, ikon kecil
/// berwarna di pojok. Disorot halus saat mouse di atasnya (kalau bisa diklik).
class StatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;
  final VoidCallback? onTap;

  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.color, this.sub, this.onTap});

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final active = _hover && w.onTap != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: w.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: w.onTap,
        child: AnimatedContainer(
          duration: motion(context, kMotionFast),
          curve: kMotionCurve,
          padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? w.color.withOpacity(0.55) : YmColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(w.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600))),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: w.color.withOpacity(0.10), borderRadius: BorderRadius.circular(9)),
                    child: Icon(w.icon, color: w.color, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(w.value,
                  style: const TextStyle(fontFamily: kFont, fontSize: 28, fontWeight: FontWeight.w800, color: YmColors.textDark, letterSpacing: -0.6, height: 1.1)),
              if (w.sub != null) ...[
                const SizedBox(height: 4),
                Text(w.sub!, style: YmTextStyles.label.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryBadge extends StatelessWidget {
  final String code;
  final bool compact;
  const CategoryBadge({super.key, required this.code, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(code);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.color.withOpacity(0.09), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(c.icon, size: 12, color: c.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(compact ? c.label.split(' ').first : c.label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.color)),
          ),
        ],
      ),
    );
  }
}

class DocStatusChip extends StatelessWidget {
  final DocStatus status;
  const DocStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (status) {
      DocStatus.draft => (YmColors.accentPurple, Icons.edit_note_rounded),
      DocStatus.uploaded => (YmColors.statusOnline, Icons.cloud_done_rounded),
      DocStatus.uploading => (YmColors.accentBlue, Icons.cloud_upload_rounded),
      DocStatus.pending => (YmColors.statusAway, Icons.schedule_rounded),
      DocStatus.failed => (YmColors.buzzRed, Icons.error_outline_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(statusLabel(status), style: TextStyle(fontFamily: kFont, fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Ikon jenis file.
class FileTypeIcon extends StatelessWidget {
  final String ext;
  final double size;
  const FileTypeIcon({super.key, required this.ext, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (ext.toLowerCase()) {
      'pdf' => (const Color(0xFFD93025), Icons.picture_as_pdf_rounded),
      'doc' || 'docx' => (const Color(0xFF2B579A), Icons.description_rounded),
      'xls' || 'xlsx' || 'csv' => (const Color(0xFF217346), Icons.table_chart_rounded),
      'txt' => (const Color(0xFF6B6F8E), Icons.article_rounded),
      'jpg' || 'jpeg' || 'png' || 'bmp' || 'gif' || 'webp' => (const Color(0xFF16A085), Icons.image_rounded),
      'dwg' => (const Color(0xFFB7472A), Icons.architecture_rounded),
      'zip' || 'rar' => (const Color(0xFF8E44AD), Icons.folder_zip_rounded),
      _ => (YmColors.textMuted, Icons.insert_drive_file_rounded),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(size * 0.25)),
      child: Icon(icon, color: color, size: size * 0.6),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: YmColors.line),
              ),
              child: Icon(icon, size: 28, color: YmColors.puBlue),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: YmTextStyles.sectionTitle.copyWith(fontSize: 15)),
            const SizedBox(height: 6),
            SizedBox(width: 420, child: Text(message, textAlign: TextAlign.center, style: YmTextStyles.label.copyWith(fontSize: 13, height: 1.5))),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Pembungkus halaman: padding standar + area scroll opsional.
class PageBody extends StatelessWidget {
  final Widget child;
  final bool scroll;
  const PageBody({super.key, required this.child, this.scroll = true});

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.fromLTRB(28, 24, 28, 28);
    return scroll ? SingleChildScrollView(padding: pad, child: child) : Padding(padding: pad, child: child);
  }
}

/// Dropdown kecil dengan gaya seragam (untuk filter).
class FilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;
  final IconData icon;

  const FilterDropdown({super.key, required this.value, required this.items, required this.onChanged, this.width = 200, this.icon = Icons.filter_list_rounded});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: YmColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: YmColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                items: items,
                onChanged: onChanged,
                isExpanded: true,
                style: const TextStyle(fontFamily: kFont, fontSize: 12.5, color: YmColors.textDark, fontWeight: FontWeight.w500),
                icon: const Icon(Icons.expand_more_rounded, size: 18, color: YmColors.textMuted),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
