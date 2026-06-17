import 'feed_item.dart';

class FeedResponse {
  final List<FeedItem> items;
  final String? nextCursor;

  const FeedResponse({required this.items, this.nextCursor});

  factory FeedResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
            .toList(growable: false)
        : <FeedItem>[];
    return FeedResponse(
      items: items,
      nextCursor: json['nextCursor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'nextCursor': nextCursor,
      };
}
