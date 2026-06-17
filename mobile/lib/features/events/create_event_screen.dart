import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/ui/global_messenger.dart';
import '../../core/venues/event_category.dart';
import '../../core/venues/governance_preview.dart';
import '../../core/venues/venue_repository.dart';
import '../owner/owner_providers.dart';
import '../venues/discovery/discovery_providers.dart';
import 'event_providers.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  /// When provided, the event is created on behalf of the venue owner
  /// using the venue's fixed coordinates instead of the user's GPS.
  const CreateEventScreen({
    super.key,
    this.ownerGuid,
    this.venueLat,
    this.venueLng,
    this.venueRadiusM,
  });

  final String? ownerGuid;
  final double? venueLat;
  final double? venueLng;
  final int? venueRadiusM;

  bool get isOwnerMode => ownerGuid != null;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _eventType = 'Public';
  DateTime _startsAt = DateTime.now();
  int _durationHours = 3;
  int _radiusM = 100;
  bool _saving = false;
  Uint8List? _photoBytes;
  EventCategory? _category;
  GovernancePreview? _governance;

  @override
  void initState() {
    super.initState();
    // Pre-fill radius from venue when in owner mode
    if (widget.isOwnerMode && widget.venueRadiusM != null) {
      _radiusM = widget.venueRadiusM!.clamp(50, 1000);
    }
    if (!widget.isOwnerMode) _loadGovernance();
  }

  Future<void> _loadGovernance() async {
    Position? pos;
    try {
      pos = await ref.read(currentPositionProvider.future);
    } catch (_) {}
    if (pos == null || !mounted) return;
    try {
      final gov = await ref
          .read(venueRepositoryProvider)
          .previewGovernance(lat: pos.latitude, lng: pos.longitude);
      if (!mounted) return;
      setState(() {
        _governance = gov;
        if (gov.governed && !gov.privateAllowed) _eventType = 'Public';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    double? lat;
    double? lng;

    if (widget.isOwnerMode) {
      // Owner mode: use fixed venue coordinates
      lat = widget.venueLat;
      lng = widget.venueLng;
    } else {
      Position? pos;
      try {
        pos = await ref.read(currentPositionProvider.future);
      } catch (_) {}
      if (pos == null) {
        showAppSnackBar(
            ref, 'Could not get your location. Enable GPS and try again.');
        return;
      }
      lat = pos.latitude;
      lng = pos.longitude;
    }

    setState(() => _saving = true);
    try {
      final result = await ref.read(venueRepositoryProvider).createEvent(
            name: _nameCtrl.text.trim(),
            description:
                _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            eventType: _eventType,
            lat: lat!,
            lng: lng!,
            radiusM: _radiusM,
            startsAt: _startsAt.toUtc(),
            durationHours: _durationHours,
            category: _category,
          );
      ref.invalidate(nearbyVenuesProvider);
      if (!mounted) return;
      final venueGuid = result['venueGuid'] as String;

      // Upload photo if picked
      if (_photoBytes != null) {
        try {
          await ref.read(venueRepositoryProvider).uploadEventPhoto(
                venueGuid,
                _photoBytes!,
                'image/jpeg',
              );
        } catch (e) {
          if (mounted) {
            showAppSnackBar(ref,
                'Event created, but photo upload failed. You can add it later.');
          }
        }
      }

      if (!mounted) return;
      // Only invalidate myEventsProvider for personal events
      // Venue owner events are separate and don't appear in My Events
      if (!widget.isOwnerMode) {
        ref.invalidate(myEventsProvider);
      }
      if (widget.isOwnerMode) {
        ref.invalidate(ownerVenueDetailProvider(widget.ownerGuid!));
        ref.invalidate(ownerVenuesProvider);
      }
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

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) return;
    setState(() {
      _startsAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _photoBytes = bytes);
  }

  Widget _governanceBanner(ThemeData theme) {
    final gov = _governance;
    if (gov == null || !gov.governed) return const SizedBox.shrink();

    final blocked = !gov.privateAllowed && (gov.publicSlotsRemaining ?? 1) <= 0;
    final color = blocked ? theme.colorScheme.error : theme.colorScheme.primary;
    final String message;
    if (gov.privateAllowed) {
      message = "You're inside your venue ${gov.ownerName}.";
    } else if (blocked) {
      message =
          "You're inside ${gov.ownerName}. This venue has reached its public event limit — creation may be blocked.";
    } else {
      message =
          "You're inside ${gov.ownerName}. Only public events are allowed here"
          "${gov.publicSlotsRemaining != null ? ' (${gov.publicSlotsRemaining} slots left)' : ''}.";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
          title:
              Text(widget.isOwnerMode ? 'Create Venue Event' : 'Create Event')),
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text('Add photo',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ],
                      )
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.7),
                            child: Icon(Icons.edit,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurface),
                          ),
                        ),
                      ),
              ),
            ),
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
            const SizedBox(height: 16),
            DropdownButtonFormField<EventCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: EventCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.displayName),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 20),
            _governanceBanner(theme),
            if (!widget.isOwnerMode &&
                (_governance == null ||
                    !_governance!.governed ||
                    _governance!.privateAllowed)) ...[
              Text('Type', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'Public',
                      label: Text('Public'),
                      icon: Icon(Icons.public)),
                  ButtonSegment(
                      value: 'Private',
                      label: Text('Private'),
                      icon: Icon(Icons.lock_outline)),
                ],
                selected: {_eventType},
                onSelectionChanged: (v) => setState(() => _eventType = v.first),
              ),
              const SizedBox(height: 20),
            ],
            Text('Start date & time', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.calendar_today),
              label: Text(DateFormat('MMM d, yyyy  HH:mm').format(_startsAt)),
            ),
            const SizedBox(height: 20),
            Text('Duration: $_durationHours hours',
                style: theme.textTheme.titleSmall),
            Slider(
              value: _durationHours.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              label: '$_durationHours h',
              onChanged: (v) => setState(() => _durationHours = v.round()),
            ),
            const SizedBox(height: 8),
            Text('Check-in radius: ${_radiusM}m',
                style: theme.textTheme.titleSmall),
            Slider(
              value: _radiusM.toDouble(),
              min: 50,
              max: 1000,
              divisions: 19,
              label: '${_radiusM}m',
              onChanged: (v) => setState(() => _radiusM = v.round()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.gps_fixed, size: 16),
                const SizedBox(width: 6),
                Text(widget.isOwnerMode
                    ? 'Location is fixed to your venue'
                    : 'Location is set automatically from your GPS'),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Event'),
            ),
          ],
        ),
      ),
    );
  }
}
