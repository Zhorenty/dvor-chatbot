import 'dart:async';
import 'dart:convert';

import 'package:dvor_chatbot/src/data/promo_code_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/promo_code.dart';
import 'package:http/http.dart' as http;
import 'package:l/l.dart';

final class GoogleSheetsPromoCodeRepository implements PromoCodeRepository {
  GoogleSheetsPromoCodeRepository({
    required Uri csvUrl,
    int promoCodesSheetId = 432112868,
    Duration requestTimeout = const Duration(seconds: 10),
    Duration minRefreshInterval = const Duration(minutes: 5),
    http.Client? httpClient,
    DateTime Function()? nowProvider,
  })  : _csvUrl = _replaceGid(csvUrl, promoCodesSheetId),
        _requestTimeout = requestTimeout,
        _minRefreshInterval = minRefreshInterval,
        _httpClient = httpClient ?? http.Client(),
        _nowProvider = nowProvider ?? DateTime.now;

  final Uri _csvUrl;
  final Duration _requestTimeout;
  final Duration _minRefreshInterval;
  final http.Client _httpClient;
  final DateTime Function() _nowProvider;

  DateTime? _lastRefreshAt;
  List<PromoCode> _cached = const <PromoCode>[];

  @override
  List<PromoCode> all() => _cached;

  @override
  PromoCode? findByCode(String code) {
    final normalized = code.trim().toUpperCase();
    for (final item in _cached) {
      if (item.code.trim().toUpperCase() == normalized) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<bool> refresh({bool force = false}) async {
    final current = _nowProvider();
    if (!force &&
        _lastRefreshAt != null &&
        current.difference(_lastRefreshAt!) < _minRefreshInterval) {
      return true;
    }

    try {
      final response = await _httpClient.get(_csvUrl).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        l.w('Google Sheets promo codes sync failed: HTTP ${response.statusCode}');
        return false;
      }
      _cached = _parseCsv(utf8.decode(response.bodyBytes));
      _lastRefreshAt = current;
      l.i('Google Sheets promo codes sync completed. Loaded ${_cached.length} promo codes.');
      return true;
    } on TimeoutException catch (error) {
      l.w('Google Sheets promo codes sync timeout: $error');
      return false;
    } on Object catch (error, stackTrace) {
      l.w('Google Sheets promo codes sync error: $error', stackTrace);
      return false;
    }
  }

  List<PromoCode> _parseCsv(String body) {
    final rows = _parseCsvRows(body);
    if (rows.isEmpty) {
      return const <PromoCode>[];
    }
    final headers =
        rows.first.map((cell) => _normalizeHeader(cell.toString())).toList(growable: false);

    final codeIndex = _firstExistingHeaderIndex(
      headers,
      const <String>['code', 'promocode', 'промокод', 'код'],
    );
    final discountIndex = _firstExistingHeaderIndex(
      headers,
      const <String>['discount_percent', 'discount', 'percent', 'скидка', 'процент'],
    );
    final categoriesIndex = _firstExistingHeaderIndex(
      headers,
      const <String>[
        'categories',
        'category',
        'категория',
        'категории',
        'тип',
        'тип_мероприятия',
        'мероприятия',
      ],
    );

    if (codeIndex < 0 || discountIndex < 0) {
      l.w('Promo codes CSV must contain code and discount_percent columns. Skipping sync.');
      return const <PromoCode>[];
    }

    final byCode = <String, PromoCode>{};
    for (final row in rows.skip(1)) {
      final code = _cell(row, codeIndex);
      final discountRaw = _cell(row, discountIndex);
      if (code.isEmpty || discountRaw.isEmpty) {
        continue;
      }
      final discountPercent = _parseDiscountPercent(discountRaw);
      if (discountPercent == null) {
        l.w('Skipping promo code "$code": invalid discount value "$discountRaw".');
        continue;
      }
      final categoriesRaw = categoriesIndex < 0 ? '' : _cell(row, categoriesIndex);
      byCode[code.trim().toUpperCase()] = PromoCode(
        code: code.trim(),
        discountPercent: discountPercent,
        categories: _parseCategories(categoriesRaw),
      );
    }
    return byCode.values.toList(growable: false);
  }

  int? _parseDiscountPercent(String raw) {
    final cleaned = raw.trim().replaceAll('%', '').trim();
    final value = int.tryParse(cleaned) ?? double.tryParse(cleaned)?.round();
    if (value == null || value <= 0) {
      return null;
    }
    return value > 100 ? 100 : value;
  }

  Set<ActivityCategory> _parseCategories(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty || normalized.contains('все') || normalized.contains('all')) {
      return const <ActivityCategory>{};
    }
    final categories = <ActivityCategory>{};
    for (final part in normalized.split(RegExp(r'[,;]'))) {
      final token = part.trim();
      if (token.isEmpty) {
        continue;
      }
      if (token.contains('трениров')) {
        categories.add(ActivityCategory.trainings);
      } else if (token.contains('йог')) {
        categories.add(ActivityCategory.yoga);
      } else if (token.contains('поход')) {
        categories.add(ActivityCategory.hikes);
      } else if (token.contains('трейл')) {
        categories.add(ActivityCategory.trails);
      }
    }
    return categories;
  }

  int _firstExistingHeaderIndex(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final index = headers.indexOf(_normalizeHeader(candidate));
      if (index >= 0) {
        return index;
      }
    }
    return -1;
  }

  String _cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index].toString().trim();
  }

  String _normalizeHeader(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_').replaceAll('ё', 'е');
  }

  List<List<String>> _parseCsvRows(String source) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentCell = StringBuffer();
    var inQuotes = false;
    var index = 0;

    void finishCell() {
      currentRow.add(currentCell.toString());
      currentCell.clear();
    }

    void finishRow() {
      finishCell();
      if (currentRow.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(List<String>.from(currentRow));
      }
      currentRow.clear();
    }

    while (index < source.length) {
      final char = source[index];
      if (char == '"') {
        final nextIndex = index + 1;
        if (inQuotes && nextIndex < source.length && source[nextIndex] == '"') {
          currentCell.write('"');
          index = nextIndex;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        finishCell();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && index + 1 < source.length && source[index + 1] == '\n') {
          index += 1;
        }
        finishRow();
      } else {
        currentCell.write(char);
      }
      index += 1;
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      finishRow();
    }
    return rows;
  }

  static Uri _replaceGid(Uri source, int gid) {
    final params = <String, String>{...source.queryParameters};
    params['gid'] = '$gid';
    params.putIfAbsent('format', () => 'csv');
    return source.replace(queryParameters: params);
  }
}
