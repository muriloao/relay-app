# 04 — Permissões e Plataforma

## Premissas de Plataforma e Sessão (MVP)
- **Sistemas operacionais alvo:** **Windows** e **macOS** integram o escopo do MVP do agente em Go, isolados por interfaces/adapters específicos por plataforma.
- **Login automático habilitado:** As máquinas desktop utilizam **login automático** na sessão do usuário, permitindo que a sessão gráfica abra de forma previsível após boot/despertar e inicie o agente automaticamente.
- **Execução na sessão do usuário:** O agente roda como processo em segundo plano na sessão do usuário logado (não como serviço isolado sem contexto de sessão), garantindo acesso a controles de mídia/áudio da sessão, bloqueio de tela e suporte futuro a *hotkeys* globais.
- **Execução sem terminal aberto:** Após iniciado, o daemon permanece em segundo plano sem depender de janela de terminal ativa.

---

## 1. Requisitos por Funcionalidade (Windows e macOS)

### A. Inicialização Automática com a Sessão
- **Windows:** Registro de autostart na sessão do usuário (ex.: pasta *Inicializar / Startup* do usuário ou *Agendador de Tarefas* no logon do usuário).
- **macOS:** Registro via *LaunchAgent* do usuário (`~/Library/LaunchAgents/`) para iniciar na sessão gráfica ativa.
- **Login automático:** Com o login automático ativo, o sistema abre a sessão do usuário imediatamente após ligar/reiniciar, iniciando o agente e permitindo a reconexão do app Flutter sem bloqueio em tela de senha.
- **Instância única:** O agente deve evitar iniciar duas instâncias simultâneas na mesma porta/sessão.

### B. Controle de Mídia e Áudio
- **Sessão de mídia e volume:**
  - **Windows:** Integração com a sessão de mídia ativa e o dispositivo de áudio padrão da sessão do usuário para `play_pause`, `next`, `previous`, `set_volume`, `toggle_mute` e leitura do estado/metadados.
  - **macOS:** Integração com controles de mídia/sistema e áudio da sessão do usuário (`set_volume`, `toggle_mute`, `play_pause`, `next`, `previous` e metadados quando disponíveis).
- **Ausência de reprodução:** Quando não houver mídia ativa, o agente deve reportar estado *sem mídia* de forma estável, sem erro fatal.

### C. Ações de Energia
- **Ações suportadas no MVP:** `shutdown` (desligar), `suspend` (suspender), `lock` (bloquear) e `restart` (reiniciar).
- **Execução por plataforma:**
  - **Windows:** Acionamento dos comandos/APIs nativas do Windows para bloqueio, suspensão, reinicialização e desligamento.
  - **macOS:** Acionamento dos mecanismos nativos do macOS para bloqueio de sessão, repouso (*sleep*), reinicialização e desligamento (observando eventuais permissões necessárias para `shutdown`/`restart` sem prompt bloqueante).
- **Confirmação prévia ao app:** O agente deve enviar `command_ack` ao app Flutter **antes** de disparar `shutdown`, `suspend` ou `restart`, garantindo feedback ao usuário antes da desconexão.

### D. Coleta de Métricas (CPU, RAM e Rede)
- **CPU:** Percentual de utilização agregado no intervalo de amostragem de **1 segundo**.
- **RAM:** Memória em uso, memória total e percentual ocupado.
- **Rede:** Taxa de download e upload calculada a cada **1 segundo** a partir dos contadores das interfaces de rede ativas.
- **Baixo custo e sem privilégio elevado:** Coleta em espaço de usuário comum no Windows e no macOS, executando a amostragem de 1 segundo apenas enquanto houver cliente WebSocket conectado.

---

## 2. Rede, Firewall/TCC e Wake-on-LAN (WoL)
- **Firewall e permissões do sistema:**
  - **Windows:** Liberar a porta da **API LAN (`ws://`)** no *Windows Defender Firewall* para a rede privada/local, mantendo a **API Admin (`http://`)** restrita a `127.0.0.1` / `localhost`.
  - **macOS:** Garantir permissão de *Rede Local* e eventuais permissões de *Acessibilidade / Automação* em *Ajustes do Sistema → Privacidade e Segurança* necessárias para controle de mídia/sistema.
- **Wake-on-LAN (WoL):**
  - **Windows:** *Wake-on-LAN* habilitado na BIOS/UEFI, *Magic Packet* habilitado nas propriedades avançadas da placa de rede (preferencialmente Ethernet) e *Inicialização Rápida (Fast Startup)* ajustada/desativada caso impeça o despertar após desligamento completo.
  - **macOS:** Considerar que MacBooks não possuem porta Ethernet nativa (dependendo de adaptador compatível quando via cabo) e que o despertar via Wi-Fi costuma funcionar de forma confiável quando a máquina está **em repouso e na tomada**, podendo não acordar a partir de desligamento total.

---

## 3. Permissões no App Mobile (Flutter)
- **Rede local (LAN):** Permissão para enviar pacotes UDP de WoL e manter conexão WebSocket (`ws://`) com o IP e porta da máquina na mesma rede.
- **Câmera:** Utilizada apenas durante a leitura do QR Code no menu lateral (*Adicionar máquina*).
- **Armazenamento local:** Salva os perfis cadastrados (nome, IP, porta, MAC address e token de pareamento) e permite edição manual do IP caso mude.