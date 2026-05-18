import 'package:dio/dio.dart';

class RxNormInteraction {
  final String drug1;
  final String drug2;
  final String severity;
  final String description;
  final String source;

  const RxNormInteraction({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.description,
    required this.source,
  });
}

class RxNormService {
  static const _base = 'https://rxnav.nlm.nih.gov/REST';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // In-memory cache of drug name → RxCUI; persists for app session
  final _rxcuiCache = <String, String?>{};

  Future<String?> lookupRxCui(String drugName) async {
    final key = drugName.toLowerCase().trim();
    if (_rxcuiCache.containsKey(key)) return _rxcuiCache[key];
    try {
      final res = await _dio.get(
        '$_base/rxcui.json',
        queryParameters: {'name': key, 'search': '1'},
      );
      final ids = (res.data['idGroup']?['rxnormId'] as List?)?.cast<String>();
      _rxcuiCache[key] = ids?.firstOrNull;
      return _rxcuiCache[key];
    } catch (_) {
      _rxcuiCache[key] = null;
      return null;
    }
  }

  Future<List<RxNormInteraction>> checkInteractions(List<String> drugNames) async {
    final uniqueNames = drugNames.toSet().toList();
    if (uniqueNames.length < 2) return [];

    final cuis = await Future.wait(uniqueNames.map(lookupRxCui));
    final validCuis = cuis.whereType<String>().toList();
    if (validCuis.length < 2) return [];

    try {
      final res = await _dio.get(
        '$_base/interaction/list.json',
        queryParameters: {'rxcuis': validCuis.join(' ')},
      );

      final interactions = <RxNormInteraction>[];
      final groups = res.data['fullInteractionTypeGroup'] as List? ?? [];

      for (final group in groups) {
        final sourceName = group['sourceName'] as String? ?? '';
        final types = group['fullInteractionType'] as List? ?? [];
        for (final type in types) {
          final pairs = type['interactionPair'] as List? ?? [];
          for (final pair in pairs) {
            final concepts = pair['interactionConcept'] as List? ?? [];
            if (concepts.length < 2) continue;
            final drug1 = concepts[0]['minConceptItem']?['name'] as String? ?? '';
            final drug2 = concepts[1]['minConceptItem']?['name'] as String? ?? '';
            if (drug1.isEmpty || drug2.isEmpty) continue;
            interactions.add(RxNormInteraction(
              drug1: drug1,
              drug2: drug2,
              severity: pair['severity'] as String? ?? 'unknown',
              description: pair['description'] as String? ?? '',
              source: sourceName,
            ));
          }
        }
      }

      return interactions;
    } catch (_) {
      return [];
    }
  }
}
