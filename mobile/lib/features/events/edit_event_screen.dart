import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/ui/global_messenger.dart';
import '../../core/venues/venue_repository.dart';
import 'event_providers.dart';

class EditEventScreen extends ConsumerStatefulWidget {
  const EditEventScreen({super.key, required this.venueGuid});
  final String venueGuid;

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _durationHours = 3;
  bool _initialized = false;
  bool _loading = true;
  bool _saving = false;
  bool _hasPhoto = false;
  String? _photoUrl;
  Uint8List? _photoBytes;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _initFromStats(
      String name, String? description, int? durationHours, bool hasPhoto) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = name;
    _descCtrl.text = description ?? '';
    _durationHours = durationHours ?? 3;
    _hasPhoto = hasPhoto;
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      width: 140,
      height: 140,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.add_a_photo_outlined, size: 40),
    );
  }

  Future<void> _loadEvent() async {
    try {
      final event =
          await ref.read(venueRepositoryProvider).getEvent(widget.venueGuid);
      if (!mounted) return;
      setState(() {
        _initFromStats(
            event.name, event.description, event.durationHours, event.hasPhoto);
        _photoUrl = event.photoUrl != null
            ? '$kApiBaseUrl${event.photoUrl!}'
            : '$kApiBaseUrl${ApiEndpoints.venuePhotoServe(widget.venueGuid)}';
        _loading = false;
      });
      await _loadPhotoBytes();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppError(ref, e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppError(ref, e);
    }
  }

  Future<void> _loadPhotoBytes() async {
    try {
      final bytes = await ref
          .read(venueRepositoryProvider)
          .getEventPhotoBytes(widget.venueGuid);
      if (!mounted || bytes == null) return;
      setState(() {
        _photoBytes = bytes;
        _hasPhoto = true;
      });
    } on ApiException {
      // Keep URL/placeholder fallback if binary fetch fails.
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      await ref
          .read(venueRepositoryProvider)
          .uploadEventPhoto(widget.venueGuid, bytes, 'image/jpeg');
      if (!mounted) return;
      setState(() {
        _hasPhoto = true;
        _photoBytes = Uint8List.fromList(bytes);
        _photoUrl =
            '$kApiBaseUrl${ApiEndpoints.venuePhotoServe(widget.venueGuid)}?t=${DateTime.now().millisecondsSinceEpoch}';
      });
      ref.invalidate(myEventsProvider);
      if (mounted) showAppSnackBar(ref, 'Photo updated.');
    } on ApiException catch (e) {
      if (mounted) showAppError(ref, e);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(venueRepositoryProvider).patchEvent(
            widget.venueGuid,
            name: _nameCtrl.text.trim(),
            description:
                _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            durationHours: _durationHours,
          );
      // Invalidate all event-related providers so parent screens refresh
      ref.invalidate(myEventsProvider);
      ref.invalidate(eventStatsProvider(widget.venueGuid));
      ref.invalidate(eventParticipantsProvider(widget.venueGuid));
      if (!mounted) return;
      showAppSnackBar(ref, 'Event updated.');
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
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Photo section
            Center(
              child: GestureDetector(
                onTap: _pickAndUploadPhoto,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _photoBytes != null
                          ? Image.memory(
                              _photoBytes!,
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                            )
                          : (_photoUrl != null || _hasPhoto)
                              ? Image.network(
                                  _photoUrl ??
                                      '$kApiBaseUrl${ApiEndpoints.venuePhotoServe(widget.venueGuid)}',
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildPhotoPlaceholder(),
                                )
                              : _buildPhotoPlaceholder(),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.pinkAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Event name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Duration: $_durationHours hours',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Slider(
              value: _durationHours.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              label: '$_durationHours h',
              onChanged: (v) => setState(() => _durationHours = v.round()),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
