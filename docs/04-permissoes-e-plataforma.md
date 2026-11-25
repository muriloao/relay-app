# 04 — Permissões e Plataforma

## Premissa de Plataforma e Sessão (MVP)
- **Sistema operacional alvo:** **Windows** é o foco inicial do agente em Go no MVP.
- **Login automático habilitado:** O desktop entra diretamente na sessão do usuário sem exigir digitação de senha na tela de bloqueio/login após o boot ou despertar, permitindo que o agente inicie junto com a sessão de forma previsível após um Wake-on-LAN.
- **Execução na sessão do usuário:** O agente roda como processo em segundo plano na sessão do usuário logado (não como serviço isolado sem contexto de sessão), garantindo acesso a controles de mídia/áudio da sessão, bloqueio de tela e suporte futuro a *hotkeys* globais.
- **Execução sem terminal aberto:** Após iniciado, o daemon permanece em segundo plano sem depender de janela de terminal ativa.

---

## 1. Requisitos por Funcionalidade no Windows

### A. Inicialização Automática com a Sessão
- **Autostart na sessão:** O agente deve ser configurado para iniciar automaticamente no logon do usuário no Windows (ex.: pasta *Inicializar* / *Startup* do usuário ou *Agendador de Tarefas* disparado ao logon do usuário).
- **Login automático:** Com o login automático ativo na máquina, o Windows abre a sessão do usuário imediatamente após ligar/reiniciar, iniciando o agente e permitindo que o app Flutter reconecte sem bloqueio por tela de login.
- **Instância única:** O agente deve evitar iniciar duas instâncias simultâneas na mesma porta/sessão.

### B. Controle de Mídia e Áudio
- **Sessão de mídia do Windows:** Integração com a sessão de mídia ativa do sistema operacional para comandos `play_pause`, `next`, `previous` e leitura do estado/metadados atuais.
- **Volume e mudo:** Controle do volume e estado de mudo do dispositivo de áudio padrão da sessão do usuário (`set_volume`, `toggle_mute`).
- **Ausência de reprodução:** Quando não houver mídia ativa, o agente deve reportar estado *sem mídia* de forma estável, sem erro fatal.

### C. Ações de Energia
- **Ações suportadas no MVP:** `shutdown` (desligar), `suspend` (suspender), `lock` (bloquear) e `restart` (reiniciar).
- **Execução no Windows:** Acionamento dos comandos nativos de energia/bloqueio do Windows para a sessão/máquina atual.
- **Confirmação prévia ao app:** O agente deve enviar `command_ack` ao app Flutter **antes** de disparar `shutdown`, `suspend` ou `restart`, garantindo feedback ao usuário antes da desconexão.

### D. Coleta de Métricas (CPU, RAM e Rede)
- **CPU:** Percentual de utilização agregado no intervalo de amostragem de **1 segundo**.
- **RAM:** Memória em uso, memória total e percentual ocupado.
- **Rede:** Taxa de download e upload calculada a cada **1 segundo** a partir dos contadores das interfaces de rede ativas.
- **Baixo custo e sem privilégio elevado:** Coleta em espaço de usuário comum, executando a amostragem de 1 segundo apenas enquanto houver cliente WebSocket conectado.

---

## 2. Firewall e Wake-on-LAN no Windows
- **Windows Defender Firewall:** A porta da **API LAN (`ws://`)** deve ser liberada para a rede privada/local (LAN), enquanto a **API Admin (`http://`)** permanece restrita a `127.0.0.1` / `localhost`.
- **Wake-on-LAN (WoL):**
  - *Wake-on-LAN* habilitado na BIOS/UEFI.
  - *Magic Packet* habilitado nas propriedades avançadas do adaptador de rede no Windows (preferencialmente Ethernet).
  - *Inicialização Rápida (Fast Startup)* ajustada/desativada caso impeça o despertar a partir de desligamento completo.

---

## 3. Permissões no App Mobile (Flutter)
- **Rede local (LAN):** Permissão para enviar pacotes UDP de WoL e manter conexão WebSocket (`ws://`) com o IP e porta da máquina na mesma rede.
- **Câmera:** Utilizada apenas durante a leitura do QR Code no menu lateral (*Adicionar máquina*).
- **Armazenamento local:** Salva os perfis cadastrados (nome, IP, porta, MAC address e token de pareamento) e permite edição manual do IP caso mude.