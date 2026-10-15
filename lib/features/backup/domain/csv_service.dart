enum ImportMode { append, overwrite, replaceAll }

class CsvSchema {
  const CsvSchema({
    this.requiredColumns = const {},
    this.dateColumns = const {},
    this.integerColumns = const {},
    this.references = const {},
  });
  final Set<String> requiredColumns;
  final Set<String> dateColumns;
  final Set<String> integerColumns;
  final Map<String, Set<String>> references;
}

class CsvValidationResult {
  const CsvValidationResult(this.errors);
  final List<String> errors;
  bool get isValid => errors.isEmpty;
}

class ImportPreview {
  const ImportPreview({
    required this.added,
    required this.updated,
    required this.deleted,
    required this.skipped,
  });
  final int added;
  final int updated;
  final int deleted;
  final int skipped;
}

class CsvService {
  const CsvService();

  List<Map<String, String>> parse(String source) {
    final input = source.startsWith('\uFEFF') ? source.substring(1) : source;
    final matrix = _parseRows(input);
    if (matrix.isEmpty) return [];
    final headers = matrix.first.map((e) => e.trim()).toList();
    if (headers.any((e) => e.isEmpty)) throw const FormatException('空の列名があります');
    return [
      for (var rowIndex = 1; rowIndex < matrix.length; rowIndex++)
        if (matrix[rowIndex].any((cell) => cell.isNotEmpty))
          {
            for (var column = 0; column < headers.length; column++)
              headers[column]: column < matrix[rowIndex].length
                  ? matrix[rowIndex][column]
                  : '',
          },
    ];
  }

  String encode(
    List<Map<String, Object?>> rows, {
    required List<String> columns,
    bool bom = false,
  }) {
    final buffer = StringBuffer(bom ? '\uFEFF' : '');
    buffer.writeln(columns.map(_quote).join(','));
    for (final row in rows) {
      buffer.writeln(
        columns
            .map((column) => _quote(row[column]?.toString() ?? ''))
            .join(','),
      );
    }
    return buffer.toString();
  }

  CsvValidationResult validate(
    List<Map<String, String>> rows, {
    required CsvSchema schema,
  }) {
    final errors = <String>[];
    final ids = <String>{};
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final number = index + 2;
      for (final column in schema.requiredColumns) {
        if ((row[column] ?? '').trim().isEmpty) {
          errors.add('$number行: $column は必須です');
        }
      }
      final id = row['id']?.trim();
      if (id != null && id.isNotEmpty && !ids.add(id)) {
        errors.add('$number行: 重複ID $id');
      }
      for (final column in schema.dateColumns) {
        final value = row[column]?.trim() ?? '';
        if (value.isNotEmpty && !_isIsoDate(value)) {
          errors.add('$number行: $column の日付が不正です');
        }
      }
      for (final column in schema.integerColumns) {
        final value = row[column]?.trim() ?? '';
        if (value.isNotEmpty && int.tryParse(value) == null) {
          errors.add('$number行: $column の数値が不正です');
        }
      }
      for (final reference in schema.references.entries) {
        final value = row[reference.key]?.trim() ?? '';
        if (value.isNotEmpty && !reference.value.contains(value)) {
          errors.add('$number行: ${reference.key} の参照先 $value が存在しません');
        }
      }
    }
    return CsvValidationResult(errors);
  }

  ImportPreview preview(
    List<Map<String, String>> rows, {
    required Set<String> existingIds,
    required ImportMode mode,
  }) {
    final incoming = rows
        .map((row) => row['id'] ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final shared = incoming.intersection(existingIds).length;
    final added = incoming.difference(existingIds).length;
    return ImportPreview(
      added: added,
      updated: mode == ImportMode.append ? 0 : shared,
      deleted: mode == ImportMode.replaceAll
          ? existingIds.difference(incoming).length
          : 0,
      skipped: mode == ImportMode.append ? shared : 0,
    );
  }

  List<List<String>> _parseRows(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    for (var index = 0; index < input.length; index++) {
      final char = input[index];
      if (char == '"') {
        if (quoted && index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(field.toString());
        field = StringBuffer();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' &&
            index + 1 < input.length &&
            input[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        field = StringBuffer();
        rows.add(row);
        row = [];
      } else {
        field.write(char);
      }
    }
    if (quoted) throw const FormatException('引用符が閉じられていません');
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  bool _isIsoDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12) return false;
    final parsed = DateTime(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day;
  }

  String _quote(Object? value) {
    final text = value?.toString() ?? '';
    if (!text.contains(RegExp('[,"\\r\\n]'))) return text;
    return '"${text.replaceAll('"', '""')}"';
  }
}

const csvFileColumns = <String, List<String>>{
  'genres.csv': ['id', 'name', 'memo', 'archived'],
  'events.csv': ['id', 'name', 'memo', 'archived'],
  'characters.csv': [
    'id',
    'genre_id',
    'name',
    'memo',
    'default_lens_product_id',
    'archived',
  ],
  'costumes.csv': [
    'id',
    'name',
    'is_general',
    'character_id',
    'memo',
    'archived',
  ],
  'character_lenses.csv': ['character_id', 'lens_product_id', 'is_default'],
  'contact_lenses.csv': [
    'id',
    'name',
    'manufacturer',
    'color',
    'wear_type',
    'open_period_days',
    'memo',
    'archived',
  ],
  'lens_purchases.csv': [
    'id',
    'lens_product_id',
    'purchased_on',
    'unopened_expires_on',
    'quantity',
  ],
  'lens_inventory.csv': ['id', 'purchase_id', 'opened_on', 'disposed'],
  'lens_usage.csv': ['id', 'diary_id', 'inventory_id', 'used_on'],
  'diary.csv': [
    'id',
    'activity_date',
    'activity_type',
    'genre_id',
    'character_id',
    'costume_id',
    'event_id',
    'memo',
    'photo_id',
    'lens_inventory_id',
  ],
  'photos.csv': [
    'id',
    'relative_path',
    'original_name',
    'width',
    'height',
    'created_at',
  ],
};
