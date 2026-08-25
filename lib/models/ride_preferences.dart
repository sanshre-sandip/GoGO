/// What the user wants to ride in. Providers name their classes differently;
/// each adapter maps this onto its own wording.
enum RideCategory { any, bike, car }

extension RideCategoryLabel on RideCategory {
  String get label => switch (this) {
        RideCategory.any => 'Any',
        RideCategory.bike => 'Bike',
        RideCategory.car => 'Car',
      };

  String get emoji => switch (this) {
        RideCategory.any => '🚦',
        RideCategory.bike => '🏍️',
        RideCategory.car => '🚗',
      };
}

enum Priority { cheapest, nearest, fastest }

extension PriorityLabel on Priority {
  String get label => switch (this) {
        Priority.cheapest => 'Cheapest',
        Priority.nearest => 'Nearest Driver',
        Priority.fastest => 'Fastest Pickup',
      };

  String get emoji => switch (this) {
        Priority.cheapest => '💰',
        Priority.nearest => '📍',
        Priority.fastest => '⚡',
      };
}

/// Weighted priorities. Checkboxes produce 1.0/0.0 weights today; a future
/// [PreferenceInterpreter] can emit fractional ones from natural language.
class RidePreferences {
  final double pricePriority;
  final double distancePriority;
  final double etaPriority;
  final int? maxWaitMinutes;
  final RideCategory category;

  const RidePreferences({
    this.pricePriority = 0,
    this.distancePriority = 0,
    this.etaPriority = 0,
    this.maxWaitMinutes,
    this.category = RideCategory.any,
  });

  factory RidePreferences.fromSelection(
    Set<Priority> selected, {
    RideCategory category = RideCategory.any,
  }) =>
      RidePreferences(
        category: category,
        pricePriority: selected.contains(Priority.cheapest) ? 1 : 0,
        distancePriority: selected.contains(Priority.nearest) ? 1 : 0,
        etaPriority: selected.contains(Priority.fastest) ? 1 : 0,
      );

  bool get isEmpty =>
      pricePriority == 0 && distancePriority == 0 && etaPriority == 0;

  /// Nothing picked = weigh everything equally rather than ranking arbitrarily.
  RidePreferences get orBalanced => isEmpty
      ? RidePreferences(
          pricePriority: 1,
          distancePriority: 1,
          etaPriority: 1,
          maxWaitMinutes: maxWaitMinutes,
          category: category,
        )
      : this;

  Set<Priority> get selection => {
        if (pricePriority > 0) Priority.cheapest,
        if (distancePriority > 0) Priority.nearest,
        if (etaPriority > 0) Priority.fastest,
      };

  Map<String, dynamic> toJson() => {
        'pricePriority': pricePriority,
        'distancePriority': distancePriority,
        'etaPriority': etaPriority,
        'maxWaitMinutes': maxWaitMinutes,
        'category': category.name,
      };

  factory RidePreferences.fromJson(Map<String, dynamic> json) => RidePreferences(
        pricePriority: (json['pricePriority'] as num?)?.toDouble() ?? 0,
        distancePriority: (json['distancePriority'] as num?)?.toDouble() ?? 0,
        etaPriority: (json['etaPriority'] as num?)?.toDouble() ?? 0,
        maxWaitMinutes: json['maxWaitMinutes'] as int?,
        category: RideCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => RideCategory.any,
        ),
      );
}
