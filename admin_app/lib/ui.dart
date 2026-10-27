import 'package:flutter/material.dart';

/// Warna & komponen tampilan — sama dengan aplikasi Arsip Dokumen PU.
class C {
  static const barStart = Color(0xFF1E2A6E);
  static const barEnd = Color(0xFF4C4FCE);
  static const accent = Color(0xFF5B4FE0);
  static const bg = Color(0xFFF3F4FC);
  static const border = Color(0xFFD8DAF0);
  static const text = Color(0xFF232849);
  static const muted = Color(0xFF8A8DAE);
  static const green = Color(0xFF2ECC71);
  static const orange = Color(0xFFF5A623);
  static const red = Color(0xFFE24C4B);
  static const sidebar = Color(0xFF141B4D);
}

class Panel extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final bool expand;
  const Panel({super.key, this.title, this.icon, this.trailing, required this.child, this.padding = const EdgeInsets.all(18), this.expand = false});

  @override
  Widget build(BuildContext context) {
    final body = Material(type: MaterialType.transparency, child: Padding(padding: padding, child: child));
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Column(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: C.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: C.border)),
            ),
            child: Row(children: [
              if (icon != null) ...[Icon(icon, size: 17, color: C.accent), const SizedBox(width: 8)],
              Expanded(child: Text(title!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: C.text))),
              if (trailing != null) trailing!,
            ]),
          ),
        if (expand) Expanded(child: body) else body,
      ]),
    );
  }
}

InputDecoration field(String label, {IconData? icon, String? hint, Widget? suffix}) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      prefixIcon: icon == null ? null : Icon(icon, size: 18, color: C.muted),
      suffixIcon: suffix,
      filled: true,
      fillColor: C.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.accent, width: 1.5)),
    );

ButtonStyle primary({Color color = C.accent}) => ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

ButtonStyle outline() => OutlinedButton.styleFrom(
      foregroundColor: C.accent,
      side: const BorderSide(color: C.border),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

void snack(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    backgroundColor: error ? C.red : C.barStart,
    behavior: SnackBarBehavior.floating,
    width: 560,
    duration: Duration(seconds: error ? 6 : 3),
  ));
}

Future<bool> confirm(BuildContext context, String title, String message, {String ok = 'Ya', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(width: 420, child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        ElevatedButton(style: primary(color: danger ? C.red : C.accent), onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

/// Label status kecil berwarna.
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String fmtTime(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '-';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${_bulan[d.month - 1]} ${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String fmtBytes(num b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

/// Status PC -> (label, warna, ikon)
(String, Color, IconData) deviceStatusInfo(String s) => switch (s) {
      'approved' => ('DISETUJUI', C.green, Icons.verified_rounded),
      'pending' => ('MENUNGGU', C.orange, Icons.hourglass_top_rounded),
      'rejected' => ('DITOLAK', C.red, Icons.block_rounded),
      'revoked' => ('DICABUT', C.muted, Icons.link_off_rounded),
      _ => (s.toUpperCase(), C.muted, Icons.help_outline_rounded),
    };
