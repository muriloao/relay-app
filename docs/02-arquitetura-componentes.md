# 02 — Arquitetura de Componentes

## Visão Estrutural
O sistema é dividido em três camadas principais que operam exclusivamente na rede local (**Wi-Fi/LAN**), sem dependência de serviços em nuvem ou descoberta automática:

1. **App Mobile/Tablet (Flutter):** Cliente visual e de controle em orientação paisagem na mão do usuário.
2. **Camada de Wake-on-LAN (Rede Local / UDP):** Canal independente para acordar a máquina quando o agente ainda está offline.
3. **Agente Desktop (Go):** Daemon em segundo plano iniciado **junto com a sessão do usuário** no **Windows** e no **macOS**, acompanhado de uma **CLI** para controle e pareamento via terminal, expondo na **mesma porta** uma **API LAN via WebSocket** e uma **API Admin via HTTP** isoladas por interface/origem.

### Diagrama de Componentes

    +-----------------------------------+
    |        App Mobile (Flutter)       |
    |  - Paisagem + Swipe (2 telas)     |
    |  - Drawer de Máquinas & QR Code   |
    |  - Controles (Mídia & Energia)    |
    |  - Emissor Wake-on-LAN (UDP)      |
    +-----------------+-----------------+
                      |
           +----------+----------+
           | (1) Máquina Offline | (2) Máquina Online (LAN / WebSocket + Token)
           v                     v
    [ Pacote Mágico WoL ]   +-------------------------------------------+
           |                |     Agente Desktop (Go — Mesma Porta)     |
           +--------------->|                                           |
                            |  +-------------------------------------+  |
                            |  |  Interface LAN (WebSocket)          |  |
                            |  |  - Stream CPU, RAM, Rede & Mídia    |  |
                            |  |  - Comandos de Mídia & Energia      |  |
                            |  +------------------+------------------+  |
                            |                     |                     |
                            |  +------------------v------------------+  |
                            |  |      Núcleo / Core do Agente        |  |
                            |  |  - Coletor de Métricas              |  |
                            |  |  - Adapters SO (Windows / macOS)    |  |
                            |  |  - Gestão de Tokens & Pareamento    |  |
                            |  +------------------+------------------+  |
                            |                     |                     |
                            |  +------------------v------------------+  |
                            |  |  Interface Admin (HTTP / Localhost) |  |
                            |  |  - Status & geração de QR Code      |  |
                            |  |  - Tokens & configurações locais    |  |
                            |  |  - [Futuro] Hotkeys & Frontend     |  |
                            |  +------------------+------------------+  |
                            +---------------------|---------------------+
                                                  |
                                +-----------------+-----------------+
                                |                                   |
                                v                                   v
                       [ CLI no Terminal ]               [ Futuro Frontend ]
                       - Parear (QR Code)                - Web ou Desktop
                       - Status / Controle               - Gestão & Hotkeys

---

## 1. App Mobile / Tablet (Flutter)
Responsável pela experiência de painel de controle em paisagem, persistência local dos perfis de máquinas e comunicação direta via WebSocket na LAN.

### Subcomponentes Internos
- **Gerenciador de Pareamento e Perfil:**
  - Lê o QR Code exibido no terminal do agente a partir do menu lateral (*Adicionar máquina*) e extrai os 5 campos definidos (**IP**, **porta**, **MAC address**, **token de pareamento** e **nome da máquina**).
  - Armazena os perfis localmente e permite edição manual do IP caso ocorra renovação via DHCP.
- **Módulo Wake-on-LAN (WoL):**
  - Monta e dispara o pacote mágico UDP diretamente para o endereço MAC salvo na mesma rede local, operando de forma totalmente independente do agente desktop.
- **Cliente WebSocket LAN:**
  - Abre e mantém a conexão WebSocket (`ws://`) com a **API LAN** na porta configurada, autenticando com o token pareado.
  - Recebe o fluxo contínuo de métricas (**CPU, RAM, rede** a cada 1 segundo com cliente conectado) e estado de mídia, envia comandos (**play/pause**, **faixa**, **volume**, **desligar**, **bloquear**, **reiniciar**) e gerencia a máquina de estados da tela (*Desligada/Offline*, *Inicializando*, *Online*, *Indisponível/Erro*).
- **Camada de Interface (Paisagem + Swipe + Drawer):**
  - Menu lateral com lista de máquinas e botão inferior para adicionar máquina via QR Code.
  - Navegação por swipe entre **Tela 1** (Energia, WoL e Métricas) e **Tela 2** (Controle de Mídia), com confirmação preventiva antes de desligar e reiniciar.

---

## 2. Agente Desktop (Daemon em Go — Windows e macOS)
É o serviço principal iniciado **automaticamente junto com a sessão do usuário** e mantido em execução em segundo plano no **Windows** e no **macOS**. Rodar na sessão do usuário garante acesso às APIs de mídia/áudio da sessão ativa, bloqueio de tela e futura gestão de *hotkeys*.

### Subcomponentes Internos (Núcleo / Core)
- **Coletor de Métricas:**
  - Lê periodicamente uso de **CPU**, consumo de **RAM** e tráfego de **rede** (a cada 1 segundo quando há cliente conectado).
- **Controlador de Mídia (Adapters por Plataforma):**
  - Isola a integração com o SO (implementações específicas para **Windows** e **macOS**) para comandos (`play_pause`, `next`, `previous`, `set_volume`, `toggle_mute`) e leitura do estado atual.
- **Controlador de Energia (Adapters por Plataforma):**
  - Implementa **desligar**, **bloquear** e **reiniciar** com APIs nativas no Windows e automação do System Events no macOS. Suspensão não está implementada nesta etapa.
  - O agente envia `command_ack` somente depois que a chamada ao sistema retorna sucesso; em caso de falha de execução/permissão, envia `command_error`. O ACK confirma que o sistema aceitou o pedido, não que a transição já terminou.
  - “Ligar” não é comando do daemon: com o agente offline, o app envia WoL diretamente à máquina usando o MAC do perfil. No macOS, WoL para ligar de um desligamento completo não é garantido.
- **Autostart de Sessão (Adapters por Plataforma):**
  - Registra e gerencia a inicialização automática na sessão do usuário no **Windows** e no **macOS**.
- **Gerenciador de Identidade e Pareamento:**
  - Valida tokens de acesso recebidos pela **API LAN** e fornece/gerencia os dados para o fluxo de pareamento via QR Code exibido no terminal.

---

## 3. API LAN (WebSocket) e API Admin (HTTP) na Mesma Porta
O agente escuta em uma única porta configurada e separa o acesso conforme a interface/origem da conexão e o protocolo/rota:

### A. API LAN (WebSocket)
- **Protocolo:** WebSocket (`ws://`) sobre a porta configurada do agente.
- **Acesso:** Disponível na interface de rede local para o app Flutter na mesma rede, exigindo autenticação via **token de pareamento**.
- **Responsabilidades:**
  - Streaming contínuo de métricas (**CPU, RAM, rede** a cada 1 segundo com cliente conectado) e estado de mídia.
  - Envio de comandos de mídia e energia com retorno de confirmação/erro. Para energia, o ACK significa aceitação pelo SO; `command_error` reporta rejeições e erros de permissão.
  - Verificação de disponibilidade do agente após um disparo de WoL.

### B. API Admin (HTTP — Interface Localhost)
- **Protocolo:** HTTP na **mesma porta**, restrito a conexões originadas em `127.0.0.1` / `localhost` (interface loopback).
- **Acesso:** Bloqueado para clientes externos/LAN na camada de rede/interface e/ou middleware de origem local.
- **Responsabilidades no MVP:**
  - Consultar o estado atual do daemon e informações da máquina (nome, IP ativo, porta, MAC address).
  - Solicitar a geração/consulta de dados de pareamento para renderizar o **QR Code no terminal**.
  - Consultar ou revogar tokens pareados.
- **Evolução Pós-MVP:**
  - Atenderá diretamente um **frontend Web** ou **frontend Desktop** para gestão de configurações, monitoramento local e cadastro de *hotkeys* sem alterar o núcleo do agente.

---

## 4. CLI de Operação e Pareamento (Terminal)
Utilitário de linha de comando (compatível com **Windows** e **macOS**) que conversa com a **API Admin (HTTP em `localhost`)** para tarefas administrativas e pareamento:
- **Pareamento via QR Code:** Solicita os dados de conexão/pareamento à API Admin e desenha o **QR Code diretamente no terminal** contendo **IP**, **porta**, **MAC address**, **token de pareamento** e **nome da máquina**.
- **Operação e diagnóstico:** Permite verificar o status do daemon iniciado com a sessão ou acionar comandos administrativos locais sem deixar um terminal preso como processo obrigatório após o pareamento.

---

## 5. Camada de Wake-on-LAN (WoL)
- Fluxo direto entre o **app Flutter** e a interface de rede da máquina na mesma rede local.
- O app dispara o pacote mágico UDP utilizando o **MAC address** salvo via QR Code e monitora a abertura/resposta do **WebSocket da API LAN** para transicionar o estado de *Inicializando* para *Online*.
- O daemon não pode receber um comando de ligar enquanto está offline. No Windows, WoL depende de suporte e configuração de BIOS/UEFI e adaptador de rede. No macOS, o despertar de repouso depende do modelo/configuração; não prometer inicialização a partir do desligamento completo.
