import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/volunteer_service.dart';
import '../models/models.dart';

/// Shows the Verification Details dialog exactly like the website.
/// On submit: marks task complete + sends [PROOF_OF_WORK] to admin.
Future<bool> showProofDialog(BuildContext context, VolunteerTask task) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProofDialog(task: task),
  );
  return result ?? false;
}

class _ProofDialog extends StatefulWidget {
  final VolunteerTask task;
  const _ProofDialog({required this.task});
  @override
  State<_ProofDialog> createState() => _ProofDialogState();
}

class _ProofDialogState extends State<_ProofDialog> {
  final _notesCtrl = TextEditingController();
  Uint8List? _photoBytes;
  String?    _photoName;
  bool       _submitting = false;

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      // On mobile: show camera OR gallery choice
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.camera_alt, color: AppColors.teal),
            title: const Text('Take Photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library, color: AppColors.orange),
            title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          const SizedBox(height: 8),
        ])));
      if (source == null) return;
      final file = await picker.pickImage(source: source, imageQuality: 75);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() { _photoBytes = Uint8List.fromList(bytes); _photoName = file.name; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick photo: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _submit() async {
    final notes = _notesCtrl.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please add completion notes before submitting.'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _submitting = true);
    try {
      await VolunteerService.submitProof(
        taskId:     widget.task.id,
        taskTitle:  widget.task.title,
        notes:      notes,
        photoBytes: _photoBytes,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Submission failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          // Header
          const Text('Verification Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Before marking this task complete, please provide Proof of Work. '
            'Admins will review this to verify task completion.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 20),

          // Notes field
          const Text('Completion Notes / Evidence',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. Delivered 50 boxes of food rations to shelter coordinator Mr. Rajesh. Attached photo evidence.',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textHint),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.teal, width: 2)),
              fillColor: AppColors.surface2, filled: true,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),

          // Photo upload
          const Text('Attach Photo Proof (Optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.teal.withOpacity(0.4),
                    style: BorderStyle.solid)),
              child: _photoBytes == null
                  ? Column(children: const [
                      Icon(Icons.camera_alt_outlined, color: AppColors.teal, size: 28),
                      SizedBox(height: 6),
                      Text('Tap to capture or upload photo',
                          style: TextStyle(color: AppColors.teal, fontSize: 13, fontWeight: FontWeight.w500)),
                    ])
                  : Column(children: [
                      const Icon(Icons.check_circle, color: AppColors.green, size: 28),
                      const SizedBox(height: 6),
                      Text(_photoName ?? 'Photo selected',
                          style: const TextStyle(color: AppColors.green, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => setState(() { _photoBytes = null; _photoName = null; }),
                        child: const Text('Remove', style: TextStyle(color: AppColors.error, fontSize: 12))),
                    ])),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _submitting ? null : () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Verification',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)))),
          ]),
        ]),
      ),
    );
  }
}
