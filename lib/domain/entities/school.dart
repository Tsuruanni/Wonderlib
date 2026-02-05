import 'package:equatable/equatable.dart';

enum SchoolStatus { active, trial, suspended }

class School extends Equatable {

  const School({
    required this.id,
    required this.name,
    required this.code,
    this.logoUrl,
    this.status = SchoolStatus.active,
    this.subscriptionTier = 'free',
    this.subscriptionExpiresAt,
    this.settings = const {},
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String name;
  final String code;
  final String? logoUrl;
  final SchoolStatus status;
  final String subscriptionTier;
  final DateTime? subscriptionExpiresAt;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == SchoolStatus.active;
  bool get isTrial => status == SchoolStatus.trial;
  bool get isSuspended => status == SchoolStatus.suspended;

  bool get isSubscriptionActive {
    if (subscriptionExpiresAt == null) return true;
    return subscriptionExpiresAt!.isAfter(DateTime.now());
  }

  @override
  List<Object?> get props => [
        id,
        name,
        code,
        logoUrl,
        status,
        subscriptionTier,
        subscriptionExpiresAt,
        settings,
        createdAt,
        updatedAt,
      ];
}
