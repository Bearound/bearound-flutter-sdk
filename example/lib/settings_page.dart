import 'package:flutter/material.dart';
import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SyncInterval _currentInterval = SyncInterval.time20;
  BackupSize _currentBackupSize = BackupSize.size40;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);
    try {
      final interval = await BearoundFlutterSdk.getSyncInterval();
      final backupSize = await BearoundFlutterSdk.getBackupSize();
      setState(() {
        _currentInterval = interval;
        _currentBackupSize = backupSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar configurações: $e')),
        );
      }
    }
  }

  Future<void> _updateSyncInterval(SyncInterval interval) async {
    try {
      await BearoundFlutterSdk.setSyncInterval(interval);
      setState(() => _currentInterval = interval);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Intervalo de sincronização atualizado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar intervalo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateBackupSize(BackupSize size) async {
    try {
      await BearoundFlutterSdk.setBackupSize(size);
      setState(() => _currentBackupSize = size);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tamanho do backup atualizado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getIntervalDescription(SyncInterval interval) {
    if (interval.seconds <= 10) {
      return 'Alta frequência (maior consumo de bateria)';
    } else if (interval.seconds <= 30) {
      return 'Frequência moderada (balanceado)';
    } else {
      return 'Baixa frequência (economia de bateria)';
    }
  }

  String _getBackupSizeDescription(BackupSize size) {
    if (size.value <= 15) {
      return 'Backup pequeno (menor uso de memória)';
    } else if (size.value <= 35) {
      return 'Backup moderado (balanceado)';
    } else {
      return 'Backup grande (mais resiliência)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Intervalo de Sincronização'),
                _buildInfoCard(
                  'O intervalo de sincronização define com que frequência '
                  'o SDK faz scan de beacons. Valores menores detectam beacons '
                  'mais rapidamente, mas consomem mais bateria.',
                ),
                const SizedBox(height: 8),
                _buildCurrentSettingCard(
                  icon: Icons.timer,
                  title: 'Intervalo Atual',
                  value: '${_currentInterval.seconds} segundos',
                  description: _getIntervalDescription(_currentInterval),
                ),
                const SizedBox(height: 16),
                _buildIntervalSelector(),
                const SizedBox(height: 32),
                _buildSectionHeader('Tamanho do Backup'),
                _buildInfoCard(
                  'O tamanho do backup define quantos beacons que falharam na '
                  'sincronização devem ser armazenados para retry. Valores maiores '
                  'usam mais memória.',
                ),
                const SizedBox(height: 8),
                _buildCurrentSettingCard(
                  icon: Icons.storage,
                  title: 'Backup Atual',
                  value: '${_currentBackupSize.value} beacons',
                  description: _getBackupSizeDescription(_currentBackupSize),
                ),
                const SizedBox(height: 16),
                _buildBackupSizeSelector(),
                const SizedBox(height: 32),
                _buildRecommendationsCard(),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSettingCard({
    required IconData icon,
    required String title,
    required String value,
    required String description,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.blue.shade700, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecionar Intervalo:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SyncInterval.values.map((interval) {
                final isSelected = interval == _currentInterval;
                return FilterChip(
                  label: Text('${interval.seconds}s'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) _updateSyncInterval(interval);
                  },
                  backgroundColor: isSelected
                      ? Colors.blue
                      : Colors.grey.shade200,
                  selectedColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupSizeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecionar Tamanho:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BackupSize.values.map((size) {
                final isSelected = size == _currentBackupSize;
                return FilterChip(
                  label: Text('${size.value}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) _updateBackupSize(size);
                  },
                  backgroundColor: isSelected
                      ? Colors.blue
                      : Colors.grey.shade200,
                  selectedColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Recomendações',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRecommendation(
              '⚡ Monitoramento em tempo real',
              'Intervalo: 5-10s | Backup: 15-20',
            ),
            _buildRecommendation(
              '⚖️ Monitoramento padrão (recomendado)',
              'Intervalo: 20-30s | Backup: 30-40',
            ),
            _buildRecommendation(
              '🔋 Economia de bateria',
              'Intervalo: 40-60s | Backup: 40-50',
            ),
            _buildRecommendation(
              '📶 Apps offline-first',
              'Intervalo: 30-60s | Backup: 50',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendation(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
