export 'src/core.dart';
import 'src/core.dart';
import 'bearound_flutter_sdk_platform_interface.dart';

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
  static Future<bool> requestPermissions() =>
      PermissionService.instance.requestPermissions();

  /// Inicia o scanner de beacons e sincronização automática com a API.
  ///
  /// Esse método inicializa toda a stack (scanner + sync local/API).
  /// O parâmetro [debug] ativa logs extras no nativo.
  ///
  /// Exemplo:
  /// ```dart
  /// await BearoundFlutterSdk.startScan('your-client-token', debug: true);
  /// ```
  ///
  /// Importante: Não precisa se preocupar em passar IDFA, estado do app ou deviceType, pois tudo é obtido automaticamente pelo SDK.
  static Future<void> startScan(
    String clientToken, {
    bool debug = false,
  }) async => await BeaconScanner.startScan(clientToken, debug: debug);

  /// Para completamente o scanner e a sincronização dos beacons.
  ///
  /// Exemplo:
  /// ```dart
  /// await BearoundFlutterSdk.stopScan();
  /// ```
  ///
  /// Recomenda-se sempre chamar esse método ao fechar a tela ou app, para evitar uso desnecessário de recursos.
  static Future<void> stopScan() async => await BeaconScanner.stopScan();

  /// Verifica se o SDK já foi inicializado e está rodando.
  ///
  /// Este método é útil ao reabrir o app para verificar se o scanner
  /// em background ainda está ativo.
  ///
  /// Exemplo:
  /// ```dart
  /// final isRunning = await BearoundFlutterSdk.isInitialized();
  /// if (isRunning) {
  ///   // SDK já está rodando, atualizar UI
  /// }
  /// ```
  ///
  /// Retorna `true` se o SDK está inicializado, ou `false` caso contrário.
  static Future<bool> isInitialized() async =>
      await BearoundFlutterSdkPlatform.instance.isInitialized();

  /// Stream dos beacons detectados em tempo real.
  ///
  /// Recebe eventos quando beacons são detectados (enter, exit, ou failed).
  ///
  /// Exemplo de uso:
  /// ```dart
  /// BearoundFlutterSdk.beaconsStream.listen((event) {
  ///   print('Event type: ${event.eventType}');
  ///   print('Beacons detected: ${event.beacons.length}');
  ///   for (var beacon in event.beacons) {
  ///     print('Beacon: ${beacon.uuid}, major: ${beacon.major}, minor: ${beacon.minor}');
  ///   }
  /// });
  /// ```
  static Stream<BeaconsDetectedEvent> get beaconsStream =>
      BearoundFlutterSdkPlatform.instance.beaconsStream;

  /// Stream de eventos de sincronização com a API.
  ///
  /// Recebe eventos de sucesso (SyncSuccessEvent) ou erro (SyncErrorEvent)
  /// quando o SDK tenta sincronizar dados de beacons com a API.
  ///
  /// Exemplo de uso:
  /// ```dart
  /// BearoundFlutterSdk.syncStream.listen((event) {
  ///   if (event is SyncSuccessEvent) {
  ///     print('Sync success: ${event.message}');
  ///     print('Beacons synced: ${event.beaconsCount}');
  ///   } else if (event is SyncErrorEvent) {
  ///     print('Sync error: ${event.errorMessage}');
  ///     print('Error code: ${event.errorCode}');
  ///   }
  /// });
  /// ```
  static Stream<BeaconEvent> get syncStream =>
      BearoundFlutterSdkPlatform.instance.syncStream;

  /// Stream de eventos de entrada/saída de regiões de beacons.
  ///
  /// Recebe eventos quando o dispositivo entra (BeaconRegionEnterEvent) ou
  /// sai (BeaconRegionExitEvent) de uma região de beacons.
  ///
  /// Exemplo de uso:
  /// ```dart
  /// BearoundFlutterSdk.regionStream.listen((event) {
  ///   if (event is BeaconRegionEnterEvent) {
  ///     print('Entered region: ${event.regionName}');
  ///   } else if (event is BeaconRegionExitEvent) {
  ///     print('Exited region: ${event.regionName}');
  ///   }
  /// });
  /// ```
  static Stream<BeaconEvent> get regionStream =>
      BearoundFlutterSdkPlatform.instance.regionStream;

  /// Define o intervalo de sincronização de beacons (frequência de scan).
  ///
  /// Configura com que frequência o SDK faz scan de beacons.
  /// Valores menores = maior consumo de bateria, mas detecção mais rápida.
  /// Valores maiores = menor consumo de bateria, mas detecção mais lenta.
  ///
  /// Exemplo:
  /// ```dart
  /// await BearoundFlutterSdk.setSyncInterval(SyncInterval.time20); // 20 segundos (padrão)
  /// await BearoundFlutterSdk.setSyncInterval(SyncInterval.time60); // 60 segundos (economia de bateria)
  /// ```
  ///
  /// Pode ser chamado antes ou depois de `startScan()` para ajuste dinâmico.
  static Future<void> setSyncInterval(SyncInterval interval) async =>
      await BearoundFlutterSdkPlatform.instance.setSyncInterval(interval);

  /// Define o tamanho do backup de beacons perdidos.
  ///
  /// Configura quantos beacons que falharam na sincronização devem ser
  /// armazenados para retry. Valores maiores = mais memória usada.
  ///
  /// Exemplo:
  /// ```dart
  /// await BearoundFlutterSdk.setBackupSize(BackupSize.size40); // 40 beacons (padrão)
  /// await BearoundFlutterSdk.setBackupSize(BackupSize.size10); // 10 beacons (economia de memória)
  /// ```
  ///
  /// ⚠️ Android: Deve ser chamado ANTES de `startScan()`.
  /// ⚠️ iOS: Pode ser chamado a qualquer momento.
  static Future<void> setBackupSize(BackupSize size) async =>
      await BearoundFlutterSdkPlatform.instance.setBackupSize(size);

  /// Retorna o intervalo de sincronização atual.
  ///
  /// Exemplo:
  /// ```dart
  /// final interval = await BearoundFlutterSdk.getSyncInterval();
  /// print('Intervalo atual: ${interval.seconds} segundos');
  /// ```
  static Future<SyncInterval> getSyncInterval() async =>
      await BearoundFlutterSdkPlatform.instance.getSyncInterval();

  /// Retorna o tamanho do backup atual.
  ///
  /// Exemplo:
  /// ```dart
  /// final size = await BearoundFlutterSdk.getBackupSize();
  /// print('Tamanho do backup: ${size.value} beacons');
  /// ```
  static Future<BackupSize> getBackupSize() async =>
      await BearoundFlutterSdkPlatform.instance.getBackupSize();
}
