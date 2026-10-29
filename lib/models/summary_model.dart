class SummaryModel {
  final int total;
  final int pending;
  final int missing;
  final int validated;
  final int notEntered;
  final int normal;
  final int added;
  final int sqlserver;

  SummaryModel({
    required this.total,
    required this.pending,
    required this.missing,
    required this.validated,
    required this.notEntered,
    required this.normal,
    required this.added,
    required this.sqlserver,
  });

  factory SummaryModel.fromJson(Map<String, dynamic> json) {
    return SummaryModel(
      total: _parseInt(json['total']) ?? 0,
      pending: _parseInt(json['pending']) ?? 0,
      missing: _parseInt(json['missing']) ?? 0,
      validated: _parseInt(json['validated']) ?? 0,
      notEntered: _parseInt(json['notEntered']) ?? 0,
      normal: _parseInt(json['normal']) ?? 0,
      added: _parseInt(json['added']) ?? 0,
      sqlserver: _parseInt(json['sqlserver']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'pending': pending,
      'missing': missing,
      'valide': validated,
      'notEntered': notEntered,
      'normal': normal,
      'added': added,
      'sqlserver': sqlserver,
    };
  }

  SummaryModel copyWith({
    int? total,
    int? pending,
    int? missing,
    int? validated,
    int? notEntered,
    int? normal,
    int? added,
    int? sqlserver,
  }) {
    return SummaryModel(
      total: total ?? this.total,
      pending: pending ?? this.pending,
      missing: missing ?? this.missing,
      validated: validated ?? this.validated,
      notEntered: notEntered ?? this.notEntered,
      normal: normal ?? this.normal,
      added: added ?? this.added,
      sqlserver: sqlserver ?? this.sqlserver,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }
}