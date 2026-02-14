import '../../../domain/entities/unit_book.dart';

/// Data model for UnitBook — maps RPC result to entity.
class UnitBookModel {
  const UnitBookModel({
    required this.unitId,
    required this.bookId,
    required this.orderInUnit,
  });

  factory UnitBookModel.fromJson(Map<String, dynamic> json) {
    return UnitBookModel(
      unitId: json['unit_id'] as String,
      bookId: json['book_id'] as String,
      orderInUnit: json['order_in_unit'] as int? ?? 0,
    );
  }

  final String unitId;
  final String bookId;
  final int orderInUnit;

  UnitBook toEntity() => UnitBook(
        unitId: unitId,
        bookId: bookId,
        orderInUnit: orderInUnit,
      );
}
