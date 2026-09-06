import 'package:flutter/material.dart';

import '../models/gst_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'doc_form_page.dart';

/// The GST state of one sales invoice, and the actions available on it.
///
/// Every government action is explicit: nothing is filed because an
/// invoice was saved. Buttons disable themselves while a request is in
/// flight, because the one thing worse than a slow response is two IRNs.
class GstPanel extends StatefulWidget {
  final int invoiceId;
  final String invoiceNo;

  /// Lets the parent screen refresh its own list after a filing.
  final VoidCallback? onChanged;

  /// Lets a test render a given state without a server. Null in the app.
  @visibleForTesting
  final GstStatus? initialStatus;

  const GstPanel({
    super.key,
    required this.invoiceId,
    required this.invoiceNo,
    this.onChanged,
    this.initialStatus,
  });

  static Future<void> open(BuildContext context, int invoiceId, String invoiceNo) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('GST Status',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    Text(invoiceNo,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).maybePop(),
                  ),
                ],
                shape: const Border(bottom: BorderSide(color: AppColors.line)),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: GstPanel(invoiceId: invoiceId, invoiceNo: invoiceNo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<GstPanel> createState() => _GstPanelState();
}

class _GstPanelState extends State<GstPanel> {
  GstStatus? _status;
  bool _loading = true;
  // Set while a government call is in flight; every button reads it, so a
  // second tap cannot start a second filing.
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatus != null) {
      _status = widget.initialStatus;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance
          .getOne('/api/sales-invoices/${widget.invoiceId}/gst-status');
      if (!mounted) return;
      setState(() {
        _status = GstStatus.fromJson(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _messageOf(e);
        _loading = false;
      });
    }
  }

  /// The backend sends {error, message, retryable}; show the message, keep
  /// the code for the cases the UI treats differently.
  String _messageOf(Object e) {
    if (e is ApiException) {
      final detail = e.detail;
      if (detail is Map && detail['message'] != null) return '${detail['message']}';
      return e.message;
    }
    return e.toString();
  }

  String? _codeOf(Object e) {
    if (e is ApiException && e.detail is Map) return '${(e.detail as Map)['error']}';
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return; // guards against a double tap
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      final code = _codeOf(e);
      // "Already generated" is not really a failure -- reload and show it.
      if (code == 'EINVOICE_ALREADY_GENERATED' || code == 'EWAYBILL_ALREADY_GENERATED') {
        await _load();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_messageOf(e)),
          backgroundColor: code == null ? AppColors.rose : AppColors.amber,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Dry run against /api/gst/validate: reports what the portal would
  /// reject *without* filing anything. Worth having as its own button --
  /// the alternative is learning about a missing HSN code by watching a
  /// generate attempt fail.
  Future<void> _checkReadiness() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await ApiService.instance
          .create('/api/gst/validate', {'invoice_id': widget.invoiceId});
      if (!mounted) return;
      final ok = r['valid'] == true;
      final tax = ok
          ? (r['is_inter_state'] == true
              ? 'IGST ${r['igst']}'
              : 'CGST ${r['cgst']} + SGST ${r['sgst']}')
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Ready to file — taxable ${r['taxable_value']}, $tax, total ${r['total']}'
              : '${r['message']}'),
          backgroundColor: ok ? AppColors.green : AppColors.amber,
          duration: const Duration(seconds: 7),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageOf(e)), backgroundColor: AppColors.rose),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateEInvoice() => _run(() async {
        await ApiService.instance
            .create('/api/sales-invoices/${widget.invoiceId}/einvoice/generate', {});
      });

  Future<void> _cancelEInvoice() async {
    final result = await _askCancelReason(context, 'Cancel e-invoice', kEInvoiceCancelReasons);
    if (result == null) return;
    await _run(() async {
      await ApiService.instance
          .create('/api/sales-invoices/${widget.invoiceId}/einvoice/cancel', result);
    });
  }

  Future<void> _generateEWayBill() async {
    final input = await _askTransport(context);
    if (input == null) return;
    await _run(() async {
      await ApiService.instance.create(
          '/api/sales-invoices/${widget.invoiceId}/eway-bill/generate', input.toJson());
    });
  }

  Future<void> _cancelEWayBill() async {
    final result = await _askCancelReason(context, 'Cancel e-way bill', kEWayBillCancelReasons);
    if (result == null) return;
    await _run(() async {
      await ApiService.instance
          .create('/api/sales-invoices/${widget.invoiceId}/eway-bill/cancel', result);
    });
  }

  Future<void> _updateVehicle(EWayBillInfo ewb) async {
    final result = await _askVehicle(context, ewb.vehicleNumber);
    if (result == null) return;
    await _run(() async {
      await ApiService.instance.create('/api/eway-bills/${ewb.id}/vehicle', result);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _box(AppColors.rose, Icons.error_outline, 'Could not load GST status', _error!,
          action: TextButton(onPressed: _load, child: const Text('Try again')));
    }
    final status = _status!;
    if (!status.gstEnabled) {
      return _box(
        AppColors.muted,
        Icons.info_outline,
        'GST integration is switched off',
        'Turn it on in Settings → GST to generate e-invoices and e-way bills.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _eInvoiceSection(status),
        const SizedBox(height: 12),
        _eWayBillSection(status),
        if (_busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 6),
          const Text('Talking to the GST portal…',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ],
    );
  }

  // ---------------- e-invoice ----------------
  Widget _eInvoiceSection(GstStatus status) {
    final ei = status.eInvoice;
    final generated = ei?.isGenerated == true;
    return _card(
      title: 'E-Invoice',
      status: status.eInvoiceStatus,
      children: [
        if (generated) ...[
          _field('IRN', ei!.irn, copyable: true),
          _field('Ack No', ei.ackNumber),
          _field('Ack Date', ei.ackDate?.replaceFirst('T', ' ').split('.').first),
          if (ei.environment == 'sandbox')
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Sandbox — not filed with the government',
                  style: TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _showQr(ei),
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: const Text('View QR'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _cancelEInvoice,
              icon: const Icon(Icons.block_outlined, size: 18),
              label: const Text('Cancel E-Invoice'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.rose),
            ),
          ]),
        ] else if (status.eInvoiceStatus == 'CANCELLED') ...[
          _field('IRN (cancelled)', ei?.irn),
          _field('Cancelled at', ei?.cancelledAt?.replaceFirst('T', ' ').split('.').first),
        ] else ...[
          if (ei?.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Last attempt: ${ei!.errorMessage}',
                  style: const TextStyle(color: AppColors.rose, fontSize: 12)),
            ),
          // Wrap, not Row: the panel is also shown in a narrow dialog,
          // where two buttons side by side do not fit.
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: _busy ? null : _generateEInvoice,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Generate E-Invoice'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _checkReadiness,
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Check readiness'),
            ),
          ]),
        ],
      ],
    );
  }

  void _showQr(EInvoiceInfo ei) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Signed QR code'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // The signed payload the portal returned. It is what has to be
            // printed as a QR -- not a picture made from the IRN.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.page,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
              ),
              child: SelectableText(
                ei.signedQrCode ?? '(none returned)',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This is the signed payload from the portal. It is rendered as the QR image '
              'on the invoice PDF.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ---------------- e-way bill ----------------
  Widget _eWayBillSection(GstStatus status) {
    final ewb = status.eWayBill;
    final active = ewb?.isActive == true;
    return _card(
      title: 'E-Way Bill',
      status: status.eWayBillStatus,
      children: [
        if (active) ...[
          _field('EWB No', ewb!.ewbNumber, copyable: true),
          _field('Valid until', ewb.validUntil?.replaceFirst('T', ' ').split('.').first),
          _field('Vehicle', ewb.vehicleNumber ?? '--'),
          _field('Distance', ewb.distanceKm == null ? '--' : '${ewb.distanceKm} km'),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _updateVehicle(ewb),
              icon: const Icon(Icons.local_shipping_outlined, size: 18),
              label: const Text('Update Vehicle'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _cancelEWayBill,
              icon: const Icon(Icons.block_outlined, size: 18),
              label: const Text('Cancel E-Way Bill'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.rose),
            ),
          ]),
        ] else if (status.eWayBillStatus == 'UNKNOWN') ...[
          _box(AppColors.amber, Icons.help_outline, 'Status unknown',
              ewb?.errorMessage ??
                  'The portal did not respond. Check the e-way bill portal before trying again.'),
        ] else ...[
          if (ewb?.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Last attempt: ${ewb!.errorMessage}',
                  style: const TextStyle(color: AppColors.rose, fontSize: 12)),
            ),
          FilledButton.icon(
            onPressed: _busy ? null : _generateEWayBill,
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Generate E-Way Bill'),
          ),
        ],
      ],
    );
  }

  // ---------------- pieces ----------------
  Widget _card({required String title, required String status, required List<Widget> children}) {
    final (colour, label) = switch (status) {
      'GENERATED' => (AppColors.green, 'Generated'),
      'GENERATING' => (AppColors.amber, 'In progress'),
      'CANCELLED' => (AppColors.rose, 'Cancelled'),
      'EXPIRED' => (AppColors.rose, 'Expired'),
      'FAILED' => (AppColors.rose, 'Failed'),
      'UNKNOWN' => (AppColors.amber, 'Unknown'),
      _ => (AppColors.muted, 'Not generated'),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 15)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: AppColors.tintedBox(colour, radius: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(status == 'GENERATED' ? Icons.check_circle : Icons.circle_outlined,
                    size: 13, color: colour),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(color: colour, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(String label, String? value, {bool copyable = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: copyable
                ? SelectableText(value ?? '--',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))
                : Text(value ?? '--',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
      );

  Widget _box(Color colour, IconData icon, String title, String body, {Widget? action}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: AppColors.tintedBox(colour, radius: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: colour, size: 18),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: colour, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          if (action != null) action,
        ]),
      );
}

// ---------------------------------------------------------------- dialogs

/// Reason and remarks for a cancellation. The reason codes are the
/// portal's own, so what the user picks is what gets filed.
Future<Map<String, dynamic>?> _askCancelReason(
  BuildContext context,
  String title,
  Map<String, String> reasons,
) {
  String reason = reasons.keys.first;
  final remarks = TextEditingController();
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: [
                for (final entry in reasons.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (v) => setState(() => reason = v ?? reason),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarks,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                hintText: 'Why is this being cancelled?',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            const Text(
              'Cancellation is filed with the portal and cannot be undone. Outside the '
              'permitted window you must raise a credit note instead.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () {
              if (remarks.text.trim().length < 3) return;
              Navigator.pop(ctx, {
                'reason_code': reason,
                'remarks': remarks.text.trim(),
              });
            },
            child: const Text('Cancel it'),
          ),
        ],
      );
    }),
  );
}

/// Transport details -- the only things the server cannot already know.
/// Invoice, customer and company details are never re-typed here.
Future<EWayBillRequestInput?> _askTransport(BuildContext context) {
  final input = EWayBillRequestInput();
  final distance = TextEditingController();
  final vehicle = TextEditingController();
  final transporterId = TextEditingController();
  final transporterName = TextEditingController();
  final docNo = TextEditingController();

  return showDialog<EWayBillRequestInput>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final byRoad = input.transportMode == '1';
      return AlertDialog(
        title: const Text('Generate E-Way Bill'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Invoice, customer and company details are taken from the invoice.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: input.transportMode,
                decoration: const InputDecoration(labelText: 'Transport mode'),
                items: [
                  for (final entry in kTransportModes.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (v) => setState(() => input.transportMode = v ?? '1'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: distance,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Approximate distance (km)',
                  hintText: 'e.g. 156',
                ),
              ),
              const SizedBox(height: 12),
              if (byRoad) ...[
                TextField(
                  controller: vehicle,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle number',
                    hintText: 'MH04NB1331',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: input.vehicleType,
                  decoration: const InputDecoration(labelText: 'Vehicle type'),
                  items: const [
                    DropdownMenuItem(value: 'R', child: Text('Regular')),
                    DropdownMenuItem(value: 'O', child: Text('Over-dimensional cargo')),
                  ],
                  onChanged: (v) => setState(() => input.vehicleType = v ?? 'R'),
                ),
              ] else
                TextField(
                  controller: docNo,
                  decoration: const InputDecoration(
                    labelText: 'Transport document number',
                    hintText: 'Required for rail, air and ship',
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: transporterId,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Transporter ID / GSTIN (optional)',
                  hintText: 'If the transporter will fill in the vehicle',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: transporterName,
                decoration: const InputDecoration(labelText: 'Transporter name (optional)'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              input.distanceKm = int.tryParse(distance.text.trim()) ?? 0;
              input.vehicleNumber =
                  vehicle.text.trim().isEmpty ? null : vehicle.text.trim().toUpperCase();
              input.transporterId = transporterId.text.trim().isEmpty
                  ? null
                  : transporterId.text.trim().toUpperCase();
              input.transporterName =
                  transporterName.text.trim().isEmpty ? null : transporterName.text.trim();
              input.transportDocNo = docNo.text.trim().isEmpty ? null : docNo.text.trim();
              Navigator.pop(ctx, input);
            },
            child: const Text('Generate'),
          ),
        ],
      );
    }),
  );
}

/// A vehicle change mid-journey: its own filing, with its own reason.
Future<Map<String, dynamic>?> _askVehicle(BuildContext context, String? current) {
  final vehicle = TextEditingController(text: current ?? '');
  final place = TextEditingController();
  final remarks = TextEditingController();
  String reason = '1';
  String type = 'R';
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: const Text('Update vehicle'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: vehicle,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'New vehicle number'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: [
                for (final entry in kVehicleUpdateReasons.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (v) => setState(() => reason = v ?? '1'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: place,
                  decoration: const InputDecoration(labelText: 'Place of change'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Vehicle type'),
                  items: const [
                    DropdownMenuItem(value: 'R', child: Text('Regular')),
                    DropdownMenuItem(value: 'O', child: Text('ODC')),
                  ],
                  onChanged: (v) => setState(() => type = v ?? 'R'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: remarks,
              decoration: const InputDecoration(labelText: 'Remarks'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'vehicle_number': vehicle.text.trim().toUpperCase(),
              'vehicle_type': type,
              'reason_code': reason,
              'remarks': remarks.text.trim(),
              'place': place.text.trim(),
            }),
            child: const Text('Update'),
          ),
        ],
      );
    }),
  );
}
