/// Intervalo de sincronização de beacons (frequência de scan).
///
/// Define com que frequência o SDK faz scan de beacons.
/// Valores menores = maior consumo de bateria, mas detecção mais rápida.
/// Valores maiores = menor consumo de bateria, mas detecção mais lenta.
enum SyncInterval {
  /// 5 segundos - Alta frequência (maior consumo de bateria)
  time5(5),

  /// 10 segundos - Frequência alta
  time10(10),

  /// 15 segundos - Frequência moderada-alta
  time15(15),

  /// 20 segundos - Frequência padrão (balanceada)
  time20(20),

  /// 25 segundos - Frequência moderada
  time25(25),

  /// 30 segundos - Frequência moderada-baixa
  time30(30),

  /// 35 segundos - Frequência baixa
  time35(35),

  /// 40 segundos - Frequência baixa
  time40(40),

  /// 45 segundos - Frequência muito baixa
  time45(45),

  /// 50 segundos - Frequência muito baixa
  time50(50),

  /// 55 segundos - Frequência mínima
  time55(55),

  /// 60 segundos - Frequência mínima (máxima economia de bateria)
  time60(60);

  const SyncInterval(this.seconds);

  /// Duração em segundos
  final int seconds;

  /// Converte de string para enum
  static SyncInterval fromString(String value) {
    return SyncInterval.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SyncInterval.time20,
    );
  }

  /// Converte de valor inteiro para enum
  static SyncInterval fromSeconds(int seconds) {
    return SyncInterval.values.firstWhere(
      (e) => e.seconds == seconds,
      orElse: () => SyncInterval.time20,
    );
  }
}

/// Tamanho do backup de beacons perdidos.
///
/// Define quantos beacons que falharam na sincronização devem ser
/// armazenados para retry. Valores maiores = mais memória usada.
enum BackupSize {
  /// 5 beacons - Backup mínimo
  size5(5),

  /// 10 beacons - Backup pequeno
  size10(10),

  /// 15 beacons - Backup moderado-pequeno
  size15(15),

  /// 20 beacons - Backup moderado
  size20(20),

  /// 25 beacons - Backup moderado
  size25(25),

  /// 30 beacons - Backup moderado-grande
  size30(30),

  /// 35 beacons - Backup grande
  size35(35),

  /// 40 beacons - Backup padrão (balanceado)
  size40(40),

  /// 45 beacons - Backup muito grande
  size45(45),

  /// 50 beacons - Backup máximo
  size50(50);

  const BackupSize(this.value);

  /// Número de beacons no backup
  final int value;

  /// Converte de string para enum
  static BackupSize fromString(String value) {
    return BackupSize.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BackupSize.size40,
    );
  }

  /// Converte de valor inteiro para enum
  static BackupSize fromValue(int value) {
    return BackupSize.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BackupSize.size40,
    );
  }
}
