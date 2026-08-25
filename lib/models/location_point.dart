class LocationPoint {
  final double latitude;
  final double longitude;
  final String label;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    this.label = '',
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
      };

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        label: json['label'] as String? ?? '',
      );

  @override
  String toString() => label.isEmpty
      ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
      : label;
}
