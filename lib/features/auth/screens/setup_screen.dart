// lib/features/auth/screens/setup_screen.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _step = 0;
  final _formKey    = GlobalKey<FormState>();

  // Step 1 – business type
  BusinessType _bizType = BusinessType.general;

  // Step 2 – business info
  final _nameCtrl    = TextEditingController();
  final _ntnCtrl     = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl    = TextEditingController();

  // Step 3 – branch
  final _branchCtrl  = TextEditingController(text: 'Main Branch');

  @override
  void dispose() {
    _nameCtrl.dispose(); _ntnCtrl.dispose(); _phoneCtrl.dispose();
    _addressCtrl.dispose(); _cityCtrl.dispose(); _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;

    await AppErrorHandler.guard(
      ref:            ref,
      context:        context,
      message:        'Setting up your business…',
      successMessage: 'Setup complete! Welcome to IS Accounting.',
      action: () async {
        final db       = ref.read(databaseProvider);
        final prefs    = ref.read(prefsProvider);
        const uuid     = Uuid();
        final tenantId = prefs.getString(AppConstants.keyTenantId) ?? uuid.v4();
        final branchId = uuid.v4();
        final now      = DateTime.now().millisecondsSinceEpoch;

        // ── Save Tenant ─────────────────────────────
        await db.into(db.tenants).insertOnConflictUpdate(
          TenantsCompanion.insert(
            id:           tenantId,
            name:         _nameCtrl.text.trim(),
            businessType: Value(_bizType.name),
            ntn:          Value(_ntnCtrl.text.trim()),
            phone:        Value(_phoneCtrl.text.trim()),
            address:      Value(_addressCtrl.text.trim()),
            city:         Value(_cityCtrl.text.trim()),
            updatedAt:    Value(now),
          ),
        );

        // ── Save Branch ─────────────────────────────
        await db.into(db.branches).insertOnConflictUpdate(
          BranchesCompanion.insert(
            id:        branchId,
            tenantId:  tenantId,
            name:      _branchCtrl.text.trim(),
            city:      Value(_cityCtrl.text.trim()),
            updatedAt: Value(now),
          ),
        );

        // ── Seed COA ────────────────────────────────
        await db.seedDefaultAccounts(tenantId);

        // ── Save prefs ──────────────────────────────
        await prefs.setString(AppConstants.keyTenantId,     tenantId);
        await prefs.setString(AppConstants.keyBranchId,     branchId);
        await prefs.setString(AppConstants.keyBusinessType, _bizType.name);

        ref.read(businessTypeProvider.notifier).set(_bizType);
      },
    );

    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    const steps = ['Business Type', 'Business Info', 'First Branch'];

    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 640,
          child: Form(
            key: _formKey,
            child: Column(children: [
              // ── Stepper header ──────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
                child: _StepperHeader(step: _step, steps: steps),
              ),

              // ── Step content ────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildStep(),
                  ),
                ),
              ),

              // ── Nav buttons ─────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: Row(children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _step < 2
                        ? () => setState(() => _step++)
                        : _finish,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14)),
                    child: Text(_step < 2 ? 'Continue' : 'Finish Setup',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
        0 => _TypeStep(key: const ValueKey(0), selected: _bizType,
              onSelect: (t) => setState(() => _bizType = t)),
        1 => _InfoStep(key: const ValueKey(1), nameCtrl: _nameCtrl,
              ntnCtrl: _ntnCtrl, phoneCtrl: _phoneCtrl,
              addressCtrl: _addressCtrl, cityCtrl: _cityCtrl),
        _ => _BranchStep(key: const ValueKey(2), branchCtrl: _branchCtrl),
      };
}

// ── Stepper indicator ─────────────────────────────
class _StepperHeader extends StatelessWidget {
  final int _step;
  final List<String> steps;
  const _StepperHeader({required int step, required this.steps}) : _step = step;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(child: Container(height: 2,
              color: i ~/ 2 < _step
                  ? t.colorScheme.primary : t.colorScheme.outline));
        }
        final idx    = i ~/ 2;
        final done   = idx < _step;
        final active = idx == _step;
        final color  = (done || active) ? t.colorScheme.primary : t.colorScheme.outline;
        return Column(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  (done || active) ? color : t.colorScheme.surface,
              border: Border.all(color: color, width: 2),
            ),
            child: Center(child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('${idx + 1}', style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : t.colorScheme.outline))),
          ),
          const SizedBox(height: 4),
          Text(steps[idx], style: TextStyle(fontSize: 10,
              color: active ? t.colorScheme.primary : t.colorScheme.onSurface.withOpacity(0.45),
              fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ]);
      }),
    );
  }
}

// ── Step 1: Business Type ─────────────────────────
class _TypeStep extends StatelessWidget {
  final BusinessType selected;
  final void Function(BusinessType) onSelect;
  const _TypeStep({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('What type of business?', style: t.textTheme.headlineLarge),
      const SizedBox(height: 6),
      Text('We\'ll tailor the interface for your business.', style: t.textTheme.bodyMedium),
      const SizedBox(height: 20),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10,
        childAspectRatio: 1.4,
        children: BusinessType.values.map((bt) {
          final sel = bt == selected;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(bt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? t.colorScheme.primary : t.colorScheme.outline,
                  width: sel ? 2 : 1),
                color: sel
                    ? t.colorScheme.primary.withOpacity(0.08)
                    : t.colorScheme.surface,
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(bt.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text(bt.label, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: sel ? t.colorScheme.primary : t.colorScheme.onSurface)),
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
  }
}

// ── Step 2: Business Info ─────────────────────────
class _InfoStep extends StatelessWidget {
  final TextEditingController nameCtrl, ntnCtrl, phoneCtrl, addressCtrl, cityCtrl;
  const _InfoStep({super.key, required this.nameCtrl, required this.ntnCtrl,
      required this.phoneCtrl, required this.addressCtrl, required this.cityCtrl});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Business Information', style: t.textTheme.headlineLarge),
      const SizedBox(height: 6),
      Text('This appears on invoices and FBR receipts.', style: t.textTheme.bodyMedium),
      const SizedBox(height: 20),
      ErpField(label: 'Business Name', hint: 'e.g. Ahmed Traders',
          controller: nameCtrl, required: true,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: ErpField(label: 'NTN (FBR)', hint: '1234567-8', controller: ntnCtrl)),
        const SizedBox(width: 12),
        Expanded(child: ErpField(label: 'Phone', hint: '0300-0000000',
            controller: phoneCtrl, keyboardType: TextInputType.phone)),
      ]),
      const SizedBox(height: 12),
      ErpField(label: 'Address', hint: 'Shop #5, Main Market', controller: addressCtrl),
      const SizedBox(height: 12),
      ErpField(label: 'City', hint: 'Lahore', controller: cityCtrl),
      const SizedBox(height: 20),
    ]);
  }
}

// ── Step 3: Branch ────────────────────────────────
class _BranchStep extends StatelessWidget {
  final TextEditingController branchCtrl;
  const _BranchStep({super.key, required this.branchCtrl});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Your First Branch', style: t.textTheme.headlineLarge),
      const SizedBox(height: 6),
      Text('You can add more branches later from Settings.', style: t.textTheme.bodyMedium),
      const SizedBox(height: 20),
      ErpField(label: 'Branch Name', hint: 'Main Branch',
          controller: branchCtrl, required: true,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
      const SizedBox(height: 16),
      const InfoBanner(
        message: 'Each branch has its own inventory, cashiers, and FBR POS ID. '
                 'Data is isolated per branch using Row Level Security.',
        icon: Icons.info_outline_rounded,
      ),
      const SizedBox(height: 20),
    ]);
  }
}
