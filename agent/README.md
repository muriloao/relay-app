# Relay — agente desktop

Este diretório contém a base inicial do daemon Go descrito em [`../docs/`](../docs/01-visao-geral.md). O processo roda na sessão do usuário. A CLI permite iniciar o daemon, consultar seu estado e gerar o QR de pareamento.

## Requisitos

- Go 1.23 ou superior
- Windows ou macOS para ações de energia; o código de transporte também pode ser desenvolvido em outros sistemas

## Executar

```sh
go run ./cmd/relay serve
```

Na primeira execução, a configuração e o token são criados no diretório de configuração do usuário (`%AppData%/relay/config.json` no Windows). Para escolher outro arquivo:

```sh
go run ./cmd/relay serve -config ./relay.json
```

Em outro terminal, consulte o daemon ou exiba o QR:

```sh
go run ./cmd/relay status
go run ./cmd/relay pair
```

A porta padrão é `8765`. O QR contém JSON com `ip`, `port`, `mac`, `token` e `name`, como definido nos documentos. O `pair` e `status` consultam a API Admin em `127.0.0.1`.

## Estrutura

```text
cmd/relay/             CLI (serve, status, pair)
internal/agent/        HTTP, WebSocket, autenticação e streaming
internal/config/       configuração e token persistente
internal/pairing/      cliente Admin e QR no terminal
internal/platform/     contrato dos adaptadores do sistema operacional
internal/protocol/     mensagens e dados de pareamento
docs/                  visão geral e requisitos do produto
```

## Estado da implementação

- A API Admin e a API WebSocket compartilham a mesma porta; rotas `/admin/*` só respondem a clientes loopback.
- `/ws` exige a mensagem inicial `{"type":"auth","token":"…"}` e transmite `auth_ok` ou `auth_error`.
- Métricas de CPU, RAM e rede são coletadas com `gopsutil` a cada segundo somente enquanto existir cliente autenticado.
- CPU e taxas de rede são calculadas por diferença entre contadores; a primeira amostra após conectar/reconectar inicializa a base e pode trazer CPU/rede em zero.
- Rede agrega todas as interfaces ativas que não sejam loopback, inclusive interfaces virtuais. Queda/reset de contador retorna taxa zero na amostra e redefine a base.
- Falhas de fonte são enviadas como `metrics_error` com as fontes e mensagens; o cliente pode marcar esses dados como desatualizados até o próximo `metrics_update` (`status: "ok").
- O suporte de contadores de rede do `gopsutil` no macOS é parcial e precisa de validação em execução; se os valores forem inconsistentes, será usado um coletor nativo para rede no macOS.
- Bloquear, desligar e reiniciar usam integração nativa no Windows e automação do System Events no macOS.
- No Windows, o processo deve estar na sessão interativa do usuário e a conta precisa ter o direito de desligar o sistema.
- No macOS, o usuário pode precisar autorizar o controle do System Events e o acesso de Acessibilidade para o processo que executa o agente. Faça essa autorização durante um teste local antes de iniciar o agente sem terminal.
- Wake-on-LAN é enviado pelo app, não pelo daemon. Ligar um Mac totalmente desligado não é garantido; o suporte depende do modelo e do estado de energia.
- macOS: controle e estado de Apple Music e Spotify via AppleScript, com volume master do sistema. O macOS pode solicitar permissão de Automação/Acessibilidade; outros players ainda não são consultados.
- Windows: consulta e controle da sessão ativa via Windows GSMTC, metadados de título/artista/origem e volume master/mudo via Core Audio. `set_volume` ajusta ao passo de volume suportado mais próximo pelo dispositivo. O processo precisa rodar na sessão interativa do usuário; aplicativos que não publicam sessão GSMTC não aparecem como mídia ativa.
- WebSocket envia `media_state` ao autenticar e quando o snapshot mudar. O snapshot contém `status`, `playback`, `player`, `title`, `artist`, `volume` (0–100) e `muted`; `no_media` é um estado normal.
- `suspend` ainda não faz parte das ações implementadas; as ações remotas disponíveis são `shutdown`, `lock` e `restart`.
- Inicialização automática no logon, instância única, firewall e serviço em segundo plano ainda precisam ser implementados.
- O esquema de métricas usa `cpu_percent`, `memory_used_bytes`, `memory_total_bytes`, `download_bytes_per_second` e `upload_bytes_per_second`.

## Próximos passos sugeridos

1. Validar valores de CPU, RAM e rede no Windows e no macOS com clientes conectados.
2. Validar sessão GSMTC, áudio master e comandos em execução em uma máquina Windows; testar Apple Music/Spotify no macOS.
3. Validar no app o contrato e as mudanças de `media_state` nas duas plataformas.
4. Acrescentar instalação/autostart e prevenção de instância duplicada.
5. Integrar firewall e empacotamento para distribuição.
