import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/ui/global_messenger.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _initialized = false;
  int _age = 25;
  String _gender = 'Male';
  String _preferGender = 'Everyone';
  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _loadingPhoto = false;
  Uint8List? _photoBytes;

  static const _genders = ['Male', 'Female', 'Other'];
  static const _preferences = ['Everyone', 'OnlyMale', 'OnlyFemale'];
  static const _preferenceLabels = ['Everyone', 'Men only', 'Women only'];

  @override
  void initState() {
    super.initState();
    _loadPhotoBytes();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPhotoBytes() async {
    final user = ref.read(authControllerProvider).userOrNull;
    if (user == null || user.photoUrl == null) return;
    setState(() => _loadingPhoto = true);
    try {
      final bytes = await ref
          .read(authRepositoryProvider)
          .fetchMyPhotoBytes(user.userGuid);
      if (mounted && bytes != null) {
        setState(() => _photoBytes = bytes);
      }
    } catch (_) {
      // Fall back to network image if bytes fetch fails
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  void _initFromUser() {
    final user = ref.read(authControllerProvider).userOrNull;
    if (user == null || _initialized) return;
    _initialized = true;
    _nameCtrl.text = user.displayName;
    _bioCtrl.text = user.bio ?? '';
    final currentYear = DateTime.now().year;
    _age = user.birthYear != null
        ? (currentYear - user.birthYear!).clamp(18, 70)
        : 25;
    _gender = user.gender ?? 'Male';
    _preferGender = user.preferGender;
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      // Show preview immediately
      if (mounted) {
        setState(() {
          _photoBytes = Uint8List.fromList(bytes);
          _uploadingPhoto = true;
        });
      }
      // Upload in background
      final repo = ref.read(authRepositoryProvider);
      final updatedUser = await repo.uploadPhoto(bytes, picked.name);
      if (mounted) {
        ref.read(authControllerProvider.notifier).updateUser(updatedUser);
        showAppSnackBar(ref, 'Photo updated');
      }
    } catch (e) {
      if (mounted) {
        showAppError(ref, e);
        // Reload from server on error to revert preview
        await _loadPhotoBytes();
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(ref, 'Display name cannot be empty');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final birthYear = DateTime.now().year - _age;
      final updatedUser = await repo.updateMe(
        displayName: name,
        bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        birthYear: birthYear,
        gender: _gender,
        preferGender: _preferGender,
      );
      ref.read(authControllerProvider.notifier).updateUser(updatedUser);
      if (mounted) {
        showAppSnackBar(ref, 'Profile saved');
      }
    } catch (e) {
      if (mounted) {
        showAppError(ref, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).userOrNull;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _initFromUser();

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Photo
          Center(
            child: GestureDetector(
              onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    backgroundImage:
                        _photoBytes != null ? MemoryImage(_photoBytes!) : null,
                    child: _photoBytes == null && user.photoUrl == null
                        ? Icon(Icons.person,
                            size: 60, color: theme.colorScheme.onSurfaceVariant)
                        : null,
                  ),
                  if (_uploadingPhoto || _loadingPhoto)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.camera_alt,
                        size: 18, color: theme.colorScheme.onPrimary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Display name
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Display name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          // Bio
          TextField(
            controller: _bioCtrl,
            decoration: const InputDecoration(
              labelText: 'Bio',
              border: OutlineInputBorder(),
              hintText: 'Tell people a bit about yourself...',
            ),
            maxLines: 4,
            maxLength: 500,
          ),
          const SizedBox(height: 16),

          // Age
          Row(
            children: [
              const Text('Age: '),
              const SizedBox(width: 8),
              Text('$_age', style: theme.textTheme.titleMedium),
              Expanded(
                child: Slider(
                  value: _age.toDouble(),
                  min: 18,
                  max: 70,
                  divisions: 52,
                  label: '$_age',
                  onChanged: (v) => setState(() => _age = v.round()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Gender
          Text('I am', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _genders
                .map((g) => ChoiceChip(
                      label: Text(g),
                      selected: _gender == g,
                      onSelected: (_) => setState(() => _gender = g),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          // Preference
          Text('Interested in', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(
              _preferences.length,
              (i) => ChoiceChip(
                label: Text(_preferenceLabels[i]),
                selected: _preferGender == _preferences[i],
                onSelected: (_) =>
                    setState(() => _preferGender = _preferences[i]),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Save
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(height: 12),

          // Sign out
          OutlinedButton.icon(
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {
                await ref.read(authControllerProvider.notifier).logout();
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),

          const SizedBox(height: 24),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
