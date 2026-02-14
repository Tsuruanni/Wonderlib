import 'package:equatable/equatable.dart';

/// Represents a book assigned to a vocabulary unit for a specific scope.
/// The scope resolution (school/grade/class) happens at the RPC level;
/// by the time this entity reaches the app, it's already filtered.
class UnitBook extends Equatable {
  const UnitBook({
    required this.unitId,
    required this.bookId,
    required this.orderInUnit,
  });

  final String unitId;
  final String bookId;
  final int orderInUnit;

  @override
  List<Object?> get props => [unitId, bookId, orderInUnit];
}
