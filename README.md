# Relay

Painel mobile em modo paisagem e agente desktop na rede local (Wi-Fi/LAN) para Wake-on-LAN, ações de energia, controle de mídia e monitoramento de métricas do PC/Mac (CPU, RAM e rede).

## Visão Geral
O **Relay** permite controlar e acompanhar um computador na mesma rede local sem depender de ADB, nuvem ou acesso remoto externo no MVP:

- **App Mobile/Tablet (Flutter):** Interface em **paisagem (landscape)** com estética *dark mode* limpa e sóbria, navegação por **swipe** entre duas telas principais e **menu lateral (drawer)** com lista de máquinas e adição via **QR Code**.
- **Agente Desktop (Go):** Daemon em segundo plano iniciado **junto com a sessão do usuário** no **Windows** e no **macOS** (com login automático habilitado no desktop), acompanhado de uma **CLI** para pareamento via QR Code no terminal.
- **Wake-on-LAN (WoL):** Envio de pacote mágico UDP direto do app para o MAC address da máquina quando ela está offline/em repouso (sujeito às limitações de hardware/rede do sistema).
- **Ações de energia implementadas no agente:** desligar, bloquear e reiniciar no Windows e no macOS. O agente confirma apenas depois que o sistema operacional aceita a solicitação; falhas retornam `command_error`.
- **Ligar:** WoL é disparado pelo app, não pelo daemon. Em Macs, o despertar de repouso pode depender do modelo e da configuração; ligar após desligamento completo não é garantido.
- **Permissões:** o agente roda na sessão interativa. Windows requer o direito de desligar o sistema para desligar/reiniciar; no macOS, bloquear pode exigir Acessibilidade e automação pode exigir permissão para controlar System Events. Suspensão ainda não está implementada.

## Estrutura do Repositório
```text
.
├── docs/
│   ├── 01-visao-geral.md
│   ├── 02-arquitetura-componentes.md
│   ├── 03-comunicacao-e-seguranca.md
│   └── 04-permissoes-e-plataforma.md
├── agent/          # Agente desktop em Go + CLI (Windows & macOS)
├── app/            # Aplicativo mobile/tablet em Flutter
├── ui/             # Protótipo Lovable (React, estado simulado)
└── README.md
```

O app Flutter inicial está em `app/`, com pareamento por QR e autenticação no WebSocket do agente. Ele segue Clean Architecture por funcionalidade (`domain`, `data`, `presentation`); consulte [app/README.md](app/README.md) e [docs/02-arquitetura-componentes.md](docs/02-arquitetura-componentes.md). A pasta `ui/` é apenas a referência visual e não se conecta ao agente.
