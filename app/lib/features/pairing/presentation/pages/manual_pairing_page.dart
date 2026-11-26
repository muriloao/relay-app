import 'package:material_ui/material_ui.dart';

class ManualPairingPage extends StatefulWidget {
  const ManualPairingPage({super.key});

  @override
  State<ManualPairingPage> createState() => _ManualPairingPageState();
}

class _ManualPairingPageState extends State<ManualPairingPage> {
  final _payloadController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _payloadController.dispose();
    super.dispose();
  }

  void _continue() {
    final rawPayload = _payloadController.text.trim();
    if (rawPayload.isEmpty) {
      setState(() => _error = 'Cole o código de pareamento do agente.');
      return;
    }
    Navigator.of(context).pop(rawPayload);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Inserir pareamento')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'No Terminal do macOS, copie o JSON exibido após “Pareamento:” e cole abaixo.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _payloadController,
                  minLines: 5,
                  maxLines: 8,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'Código de pareamento (JSON)',
                    hintText: '{"name":"Mac", "ip":"192.168.1.10", ...}',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _continue,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continuar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
