import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/my_claim.dart';
import '../../core/models/owner_venue_detail.dart';
import '../../core/models/owner_venue_summary.dart';
import '../../core/owner/owner_repository.dart';

final ownerVenuesProvider =
    FutureProvider.autoDispose<List<OwnerVenueSummary>>((ref) {
  return ref.watch(ownerRepositoryProvider).listVenues();
});

final myClaimsProvider = FutureProvider.autoDispose<List<MyClaim>>((ref) {
  return ref.watch(ownerRepositoryProvider).listMyClaims();
});

final ownerVenueDetailProvider = FutureProvider.autoDispose
    .family<OwnerVenueDetail, String>((ref, ownerGuid) {
  return ref.watch(ownerRepositoryProvider).getVenueDetail(ownerGuid);
});
