// lib/features/pos/widgets/product_search_field.dart
import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/providers/app_providers.dart';

class ProductSearchField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String tenantId;
  final void Function(Product, double) onSelected;

  const ProductSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.tenantId,
    required this.onSelected,
  });

  @override
  ConsumerState<ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends ConsumerState<ProductSearchField> {
  final _link = LayerLink();
  OverlayEntry? _overlay;
  List<Product> _results = [];
  Timer? _debounce;
  DateTime? _firstKey;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      _removeOverlay();
      _results = [];
      return;
    }

    _firstKey ??= DateTime.now();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      final elapsed = DateTime.now().difference(_firstKey!).inMilliseconds;
      _firstKey = null;
      // Barcode scanner types full code in <120ms
      if (text.length >= 4 && elapsed < 150) {
        await _scanBarcode(text);
      } else {
        await _search(text);
      }
    });
  }

  Future<void> _scanBarcode(String code) async {
    final db = ref.read(databaseProvider);
    final p =
        await (db.select(db.products)..where(
              (t) =>
                  t.tenantId.equals(widget.tenantId) &
                  t.barcode.equals(code) &
                  t.isActive.equals(true),
            ))
            .getSingleOrNull();
    if (p != null) {
      widget.controller.clear();
      _removeOverlay();
      widget.onSelected(p, 1.0);
    }
  }

  Future<void> _search(String q) async {
    if (mounted) setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final results =
        await (db.select(db.products)
              ..where(
                (t) =>
                    t.tenantId.equals(widget.tenantId) &
                    t.isActive.equals(true) &
                    t.isDeleted.equals(false) &
                    (t.name.contains(q) | t.sku.contains(q)),
              )
              ..limit(8))
            .get();
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
    results.isNotEmpty ? _showOverlay() : _removeOverlay();
  }

  void _showOverlay() {
    _removeOverlay();
    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        width: 440,
        child: CompositedTransformFollower(
          link: _link,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: _Dropdown(
              results: _results,
              onSelect: (p) {
                widget.onSelected(p, 1.0);
                widget.controller.clear();
                _removeOverlay();
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        decoration: InputDecoration(
          hintText: 'Search products or scan barcode… (F1)',
          prefixIcon: _loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.search_rounded, size: 20),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    widget.controller.clear();
                    _removeOverlay();
                  },
                )
              : null,
        ),
        onFieldSubmitted: (_) {
          if (_results.isNotEmpty) {
            widget.onSelected(_results.first, 1.0);
            widget.controller.clear();
            _removeOverlay();
          }
        },
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final List<Product> results;
  final void Function(Product) onSelect;
  const _Dropdown({required this.results, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.colorScheme.outline),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        shrinkWrap: true,
        itemCount: results.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: t.colorScheme.outline),
        itemBuilder: (_, i) {
          final p = results[i];
          return ListTile(
            dense: true,
            onTap: () => onSelect(p),
            title: Text(
              p.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: p.sku != null
                ? Text(
                    'SKU: ${p.sku}',
                    style: TextStyle(
                      fontSize: 11,
                      color: t.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  )
                : null,
            trailing: Text(
              'PKR ${p.salePrice.toStringAsFixed(0)}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.colorScheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}
