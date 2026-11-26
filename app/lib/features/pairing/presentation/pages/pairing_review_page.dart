import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../domain/entities/pairing_payload.dart';

class PairingReviewPage extends StatefulWidget {
  const PairingReviewPage({required this.payload, super.key});

  final PairingPayload payload;

  @override
  State<PairingReviewPage> createState() => _PairingReviewPageState();
}

class _PairingReviewPageState extends State<PairingReviewPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.payload.name);
    _hostController = TextEditingController(text: widget.payload.host);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final host = _hostController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe um nome para a máquina.');
      return;
    }
    if (InternetAddress.tryParse(host) == null) {
      setState(() => _error = 'Informe um endereço IP válido.');
      return;
    }
    Navigator.of(context).pop(widget.payload.copyWith(name: name, host: host));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar máquina')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Confira os dados recebidos do agente.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome da máquina',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (Platform.isAndroid) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        _hostController.text = '10.0.2.2';
                        setState(() => _error = null);
                      },
                      icon: const Icon(Icons.phone_android),
                      label: const Text('Usar endereço do emulador Android'),
                    ),
                  ),
                  Text(
                    'No emulador Android padrão, 10.0.2.2 aponta para o Mac host.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _hostController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Endereço IP',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _ReadOnlyDetail(
                  label: 'Porta',
                  value: '${widget.payload.port}',
                ),
                _ReadOnlyDetail(label: 'MAC', value: widget.payload.mac),
                const SizedBox(height: 12),
                Text(
                  'O token de acesso será salvo no armazenamento seguro do dispositivo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.link),
                  label: const Text('Salvar e conectar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyDetail extends StatelessWidget {
  const _ReadOnlyDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label)),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
