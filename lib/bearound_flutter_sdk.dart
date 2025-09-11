export 'src/core/beacon_scanner.dart';
export 'src/data/models/beacon.dart';

import 'src/core/permission_service.dart';
import 'src/core/beacon_scanner.dart';

/// SDK principal do Bearound para integração com beacons.
///
/// Esta facade estática centraliza permissões, scanner, sync automático e acesso à stream de eventos.
class BearoundFlutterSdk {
  BearoundFlutterSdk._();

  /// Solicita todas as permissões necessárias para operar o scanner de beacons.
  ///
  /// Exemplo de uso:
  /// ```dart
  /// final ok = await BearoundFlutterSdk.requestPermissions();
  /// if (!ok) {
  ///   // Avise o usuário que permissões são obrigatórias.
  /// }
  /// ```
  /// Retorna `true` se todas as permissões foram concedidas, ou `false` caso contrário.
  static Future<bool> requestPermissions() => PermissionService.instance.requestPermissions();

  /// Inicia o scanner de beacons e sincronização automática com a API.
  ///
  /// Esse método inicializa toda a stack (scanner + sync local/API).
  /// O parâmetro [debug] ativa logs extras no nativo.
  ///
  /// Exemplo:
  /// ```dart
  /// await BearoundFlutterSdk.startScan(debug: true);
  /// ```
  ///
  /// Importante: Não precisa se preocupar em passar IDFA, estado do app ou deviceType, pois tudo é obtido automaticamente pelo SDK.
  static Future<void> startScan(String clientToken, {bool debug = false}) async => await BeaconScanner.startScan(clientToken, debug: debug);

  /// Para completamente o scanner e a sincronização dos beacons.
  ///
  /// Exemplo:
  /// ```dart
  /// await BearoundFlutterSdk.stopScan();
  /// ```
  ///
  /// Recomenda-se sempre chamar esse método ao fechar a tela ou app, para evitar uso desnecessário de recursos.
  static Future<void> stopScan() async => await BeaconScanner.stopScan();

  /// Stream dos beacons encontrados em tempo real.
  ///
  /// Pode ser usada, por exemplo, para exibir na UI ou para log/debug:
  /// ```dart
  /// BearoundFlutterSdk.beaconStream.listen((beacons) {
  ///   // Atualize sua interface, salve logs, etc.
  /// });
  /// ```
  //static Stream<List<Beacon>> get beaconStream => BeaconScanner.beaconStream;
}
