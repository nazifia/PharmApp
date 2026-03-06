import 'package:dio/dio.dart';
import '../../../shared/models/item.dart';

class InventoryApiClient {
  final Dio _dio;

  InventoryApiClient(this._dio);

  Future<List<Item>> fetchInventory() async {
    try {
      final response = await _dio.get('/inventory/items/'); // Adjust to your actual Django endpoint
      
      if (response.statusCode == 200) {
        // Assuming the Django API returns a JSON array of items or a paginated response
        final data = response.data;
        List<dynamic> results = data;
        
        // Handle DRF pagination object if necessary:
        if (data is Map<String, dynamic> && data.containsKey('results')) {
           results = data['results'];
        }

        return results.map((e) => Item.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load inventory: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('API Error: ${e.response?.statusCode}');
      } else {
        throw Exception('Network Error: Could not reach the server.');
      }
    }
  }
  
  // Example for future: Searching products by barcode directly from server
  Future<Item?> fetchItemByBarcode(String barcode) async {
     try {
       final response = await _dio.get('/inventory/items/', queryParameters: {'barcode': barcode});
       if (response.statusCode == 200) {
          final results = response.data is Map ? response.data['results'] : response.data;
          if (results.isNotEmpty) return Item.fromJson(results[0]);
       }
       return null;
     } catch (e) {
       return null;
     }
  }
}
