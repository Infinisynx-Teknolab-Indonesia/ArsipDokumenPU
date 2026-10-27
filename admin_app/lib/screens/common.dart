import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';

/// Jalankan aksi ke server; error ditampilkan, sesi habis -> kembali ke login.
Future<T?> runApi<T>(BuildContext context, Future<T> Function() action, VoidCallback onUnauthorized, {String? ok}) async {
  try {
    final r = await action();
    if (ok != null && context.mounted) snack(context, ok);
    return r;
  } on AdminApiException catch (e) {
    if (e.unauthorized) {
      onUnauthorized();
    } else if (context.mounted) {
      snack(context, e.message, error: true);
    }
  } catch (e) {
    if (context.mounted) snack(context, e.toString(), error: true);
  }
  return null;
}

class PagePad extends StatelessWidget {
  final Widget child;
  final bool scroll;
  const PagePad({super.key, required this.child, this.scroll = true});
  @override
  Widget build(BuildContext context) =>
      scroll ? SingleChildScrollView(padding: const EdgeInsets.all(22), child: child) : Padding(padding: const EdgeInsets.all(22), child: child);
}
