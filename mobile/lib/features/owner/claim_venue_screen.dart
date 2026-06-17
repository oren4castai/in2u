import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/owner/owner_repository.dart';
import '../../core/ui/global_messenger.dart';
import '../venues/discovery/discovery_providers.dart';
import 'owner_providers.dart';

class ClaimVenueScreen extends ConsumerStatefulWidget {
  const ClaimVenueScreen({super.key});

  @override
  ConsumerState<ClaimVenueScreen> createState() => _ClaimVenueScreenState();
}

class _ClaimVenueScreenState extends ConsumerState<ClaimVenueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  int _radiusM = 300;
  bool _saving = false;
  Uint8List? _photoBytes;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _photoBytes = bytes);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photoBytes == null) {
      showAppSnackBar(ref, 'A venue photo is required.');
      return;
    }

    Position? pos;
    try {
      pos = await ref.read(currentPositionProvider.future);
    } catch (_) {}
    if (pos == null) {
      showAppSnackBar(
          ref, 'Could not get your location. Enable GPS and try again.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(ownerRepositoryProvider).submitClaim(
            name: _nameCtrl.text.trim(),
            contactName: _contactNameCtrl.text.trim(),
            contactPhone: _contactPhoneCtrl.text.trim(),
            lat: pos.latitude,
            lng: pos.longitude,
            radiusM: _radiusM,
            photoBytes: _photoBytes!,
          );
      ref.invalidate(myClaimsProvider);
      if (!mounted) return;
      showAppSnackBar(ref, 'Claim submitted. It is now awaiting review.');
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppError(ref, e);
    } catch (e) {
      if (!mounted) return;
      showAppError(ref, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Claim a Venue')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 150,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  image: _photoBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_photoBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _photoBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 40,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text('Add venue photo',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      )
                    : null,
              ),
            ),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Venue name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Your full name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Contact name is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactPhoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Phone number is required'
                  : null,
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.gps_fixed, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your current location will be used as the venue center.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Claim'),
            ),
          ],
        ),
      ),
    );
  }
}
