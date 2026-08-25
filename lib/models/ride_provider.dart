import 'package:flutter/material.dart';

/// A ride-hailing provider GoGo can compare and hand the user off to.
/// [androidPackage] / [deepLink] stay nullable: not every provider supports one.
class RideProvider {
  final String id;
  final String name;
  final Color color;
  final String? androidPackage;
  final String? deepLink;

  const RideProvider({
    required this.id,
    required this.name,
    required this.color,
    this.androidPackage,
    this.deepLink,
  });
}
