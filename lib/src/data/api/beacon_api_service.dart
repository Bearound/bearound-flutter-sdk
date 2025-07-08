import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../models/beacon.dart';

class BeaconApiService {
  final String apiUrl;
  final http.Client client;

  BeaconApiService({
    this.apiUrl = Constants.apiBaseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  Future<bool> sendBeacons({
    required String deviceType,
    required String idfa,
    required String eventType,
    required String appState,
    required List<Beacon> beacons,
  }) async {
    final body = {
      "deviceType": deviceType,
      "idfa": idfa,
      "eventType": eventType,
      "appState": appState,
      "beacons": beacons.map((b) => b.toJson()).toList(),
    };
    try {
      final response = await client.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('[BeaconApiService] Beacons enviados com sucesso: ${beacons.length}');
        return true;
      } else {
        print('[BeaconApiService] Error ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[BeaconApiService] Exception: $e');
      return false;
    }
  }
}
