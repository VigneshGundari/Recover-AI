import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final neo4jServiceProvider = Provider<Neo4jService>((ref) => Neo4jService());

class Neo4jService {
  final String _nodeBackendProxy = 'https://recover-ai-zoma.onrender.com/api/graph';

  Neo4jService();

  /// Intercepts offline Native application tracking and tunnels securely to the Local Node.js proxy orchestrating the Graph protocol
  Future<void> logMedicationGraph(String patientId, String medicationName, List<String> activeIngredients) async {
    final url = Uri.parse('$_nodeBackendProxy/medication');

    final body = {
      'patientId': patientId,
      'medicationName': medicationName.toLowerCase().trim(),
      'ingredients': activeIngredients.map((e) => e.toLowerCase().trim()).toList()
    };

    try {
      final response = await http.post(
        url,
        headers: { 'Content-Type': 'application/json' },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Graph Microservice Routing Crash: HTTP ${response.statusCode} -> ${response.body}');
      }
    } catch (e) {
      print('[Graph Intelligence Error]: $e');
      rethrow;
    }
  }

  /// Evaluates pharmacological interactions querying mathematical overlapping active ingredients natively off the Neo4j API
  Future<List<Map<String, dynamic>>> checkInteractions(String patientId) async {
    final url = Uri.parse('$_nodeBackendProxy/interactions/$patientId');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['interactions']);
      } else {
        throw Exception('Graph Interaction Collision Failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('[Graph Intelligence Warning]: $e');
      return []; // Silently fall back if the Graph goes offline temporarily
    }
  }

  /// Removes a medication node and its relationships for a specific patient
  Future<void> deleteMedicationFromGraph(String patientId, String medicationName) async {
    final url = Uri.parse('$_nodeBackendProxy/medication/$patientId/${medicationName.toLowerCase().trim()}');

    try {
      final response = await http.delete(url);
      if (response.statusCode != 200) {
        throw Exception('Graph Deletion Failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('[Graph Intelligence Error]: $e');
      rethrow;
    }
  }
}
