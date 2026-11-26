# Relay — app Flutter

Este é o app mobile/tablet do Relay. A pasta `ui/` contém o protótipo do Lovable em React e permanece como referência visual; seus dados e ações são simulados e não devem ser reutilizados como integração real.

## Requisitos

- Flutter 3.50.0 ou superior (Dart 3.14.0 ou superior).
- Para Android: Android SDK compatível com a versão configurada pelo Flutter, Gradle 9.5.0 e Android Gradle Plugin 9.3.1 (já definidos no projeto).
- O projeto usa `flutter_bloc`, `hive`, `dio`, `go_router` e `get_it` nos contextos descritos abaixo.

## Executar

```sh
flutter pub get
flutter run
```

Use um dispositivo Android/iOS com câmera e conectado à mesma rede do agente. Para iniciar em um dispositivo selecionado:

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

O primeiro fluxo lê e valida o QR do agente, permite revisar nome/IP, salva o perfil e tenta autenticar no WebSocket. Na tela inicial é possível selecionar uma máquina salva, ver o estado de conexão e tentar conectar novamente. Métricas, mídia, energia e Wake-on-LAN ainda serão adicionados nas próximas etapas.

## Arquitetura do app

- **Domínio:** entidades, contratos de repositório e casos de uso. Não importa Flutter nem plugins.
- **Dados:** modelos de persistência, data sources e implementações dos contratos. Aqui ficam Hive, armazenamento seguro e a conexão WebSocket.
- **Apresentação:** páginas, Cubits e estados. A interface chama casos de uso; não acessa Hive nem o socket diretamente.
- **Composição:** `app/` e `core/di/` montam o app e ligam as implementações às abstrações.

Estrutura por contexto: `lib/features/<feature>/{domain,data,presentation}/`. A direção permitida é apresentação → domínio e dados → domínio; a composição injeta as dependências concretas. Assim, regras de negócio não dependem de Flutter, Hive, Dio ou APIs de plataforma.

- **Estado:** `flutter_bloc`; `MachineCubit` orquestra os casos de uso e observa o contrato de conexão do agente.
- **Armazenamento:** `hive`/`hive_flutter` persistem perfis; `flutter_secure_storage` mantém tokens no Keychain/Keystore. Perfis legados em `shared_preferences` migram para Hive na primeira inicialização.
- **HTTP:** `dio` é registrado como cliente HTTP compartilhado para endpoints HTTP futuros. A comunicação atual em tempo real continua por WebSocket.
- **Rotas:** `go_router` define as rotas de máquinas, leitura de QR e revisão do pareamento.
- **Injeção:** `get_it` configura data sources, repositórios, casos de uso, gateway de conexão, Cubits e roteador.

O `Dio` está configurado na composição, mas ainda não faz requisições: o protocolo atualmente usado pelo app para falar com o agente é WebSocket.

O perfil persistido guarda somente nome, IP, porta e MAC. O token é separado e nunca vai para Hive.

## Fluxo implementado

- `features/pairing/`: leitura do QR e revisão dos dados recebidos.
- `features/machines/domain/`: entidade de máquina, contrato de repositório e casos de uso.
- `features/machines/data/`: modelos Hive, migração dos dados legados e acesso ao token seguro.
- `features/machines/presentation/`: lista de máquinas, pareamento e estado da tela via Cubit.
- `features/agent/domain/`: contrato do gateway e snapshot de conexão.
- `features/agent/data/`: WebSocket, autenticação e recepção de mensagens do agente.
- `features/pairing/domain/` e `presentation/`: validação do payload e telas de QR/revisão.

O token é escrito no armazenamento seguro antes do perfil. Se a gravação do perfil falhar, a gravação do token é desfeita. O app não mostra o token na interface.

## Próximas entregas

1. Consumir `metrics_update`, `metrics_error` e `media_state` na visão geral e mídia.
2. Implementar envio de comandos de mídia, energia e Wake-on-LAN.
3. Acrescentar reconexão automática e estados de agente indisponível.

As telas principais do protótipo são duas vistas da mesma máquina — visão geral e mídia — com seleção de máquinas, pareamento e ajustes em painéis modais. Energia e Wake-on-LAN devem ser ligados ao agente/protocolo somente na implementação Flutter, respeitando as confirmações de desligamento e reinício.
