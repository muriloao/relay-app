# Relay — daemon para Windows

Este diretório contém a base inicial do daemon Go descrito em [`../docs/`](../docs/01-visao-geral.md). O processo roda na sessão do usuário. A CLI permite iniciar o daemon, consultar seu estado e gerar o QR de pareamento.

## Requisitos

- Go 1.23 ou superior
- Windows como plataforma alvo do MVP (o código de transporte também pode ser desenvolvido em outros sistemas)

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
- Métricas são amostradas a cada segundo somente enquanto existir cliente autenticado.
- O adaptador `platform.Stub` ainda não integra as APIs de mídia, áudio, energia ou métricas do Windows. Os comandos retornam erro de integração pendente.
- Inicialização automática no logon, instância única, firewall e serviço em segundo plano ainda precisam ser implementados.
- O esquema de métricas usa `cpu_percent`, `memory_used_bytes`, `memory_total_bytes`, `download_bytes_per_second` e `upload_bytes_per_second`.

## Próximos passos sugeridos

1. Implementar coleta Windows de CPU, RAM e rede no adaptador `platform`.
2. Implementar mídia e áudio da sessão do usuário e comandos nativos de energia.
3. Definir o contrato final de eventos `media_state` e validação inicial do app.
4. Acrescentar instalação/autostart e prevenção de instância duplicada no Windows.
5. Integrar firewall e empacotamento para distribuição.
