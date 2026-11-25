# Relay

Painel mobile em modo paisagem e agente desktop na rede local (Wi-Fi/LAN) para Wake-on-LAN, ações de energia, controle de mídia e monitoramento de métricas do PC/Mac (CPU, RAM e rede).

## Visão Geral
O **Relay** permite controlar e acompanhar um computador na mesma rede local sem depender de ADB, nuvem ou acesso remoto externo no MVP:

- **App Mobile/Tablet (Flutter):** Interface em **paisagem (landscape)** com estética *dark mode* limpa e sóbria, navegação por **swipe** entre duas telas principais e **menu lateral (drawer)** com lista de máquinas e adição via **QR Code**.
- **Agente Desktop (Go):** Daemon em segundo plano iniciado **junto com a sessão do usuário** no **Windows** e no **macOS** (com login automático habilitado no desktop), acompanhado de uma **CLI** para pareamento via QR Code no terminal.
- **Wake-on-LAN (WoL):** Envio de pacote mágico UDP direto do app para o MAC address da máquina quando ela está offline/em repouso (sujeito às limitações de hardware/rede do sistema).

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
└── README.md