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
  - **Windows:** Sessão ativa consultada/controlada via GSMTC, com metadados de título, artista e aplicativo de origem. Volume master e estado de mudo usam Core Audio no dispositivo de saída padrão; `set_volume` aproxima o percentual solicitado ao passo de volume suportado mais próximo. O agente deve rodar na sessão interativa do usuário; players que não publicam uma sessão GSMTC podem não aparecer.
  - **macOS (implementação inicial):** Apple Music e Spotify via AppleScript para reprodução/metadados; áudio master via `osascript`. Outros players ainda não são consultados.
- **Ausência de reprodução:** Quando não houver mídia ativa, o agente deve reportar estado *sem mídia* de forma estável, sem erro fatal.

### C. Ações de Energia
- **Ações implementadas:** `shutdown` (desligar), `lock` (bloquear) e `restart` (reiniciar), em Windows e macOS. `suspend` fica para uma etapa futura.
- **Ligar / acordar:** Não é uma ação executada pelo daemon. O app envia WoL diretamente ao MAC quando o agente está offline. O alcance depende do hardware e do estado de energia; para Macs, não há garantia de ligar após desligamento completo.
- **Execução por plataforma:**
  - **Windows:** Bloqueio via `LockWorkStation`; desligamento/reinício via API `ExitWindowsEx`, habilitando o privilégio `SeShutdownPrivilege` do processo quando disponível. O agente deve permanecer na sessão interativa; a conta precisa ter o direito do Windows de desligar o sistema.
  - **macOS:** Bloqueio via atalho do sistema acionado pelo System Events; desligamento/reinício solicitados ao System Events via `osascript`. O processo precisa rodar na sessão gráfica do usuário. A ação de bloqueio exige autorização de Acessibilidade; o controle do System Events pode exigir autorização de Automação. Se o usuário negar ou a chamada falhar, o agente retorna erro.
- **ACK e erro:** O agente envia `command_ack` depois que a chamada do SO retorna sucesso, antes da conclusão da transição quando possível. Esse ACK significa que a solicitação foi aceita, não confirma que a máquina já desligou/reiniciou. Em falha, retorna `command_error` sem ACK.

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
  - **macOS:** O recurso *Wake for network access* pode acordar alguns Macs em repouso, conforme modelo, rede e configuração. Não tratar WoL como método garantido para iniciar um Mac desligado. MacBooks podem depender de adaptador de rede compatível para WoL por Ethernet.

---

## 3. Permissões no App Mobile (Flutter)
- **Rede local (LAN):** Permissão para enviar pacotes UDP de WoL e manter conexão WebSocket (`ws://`) com o IP e porta da máquina na mesma rede.
- **Câmera:** Utilizada apenas durante a leitura do QR Code no menu lateral (*Adicionar máquina*).
- **Armazenamento local:** Perfis (nome, IP, porta e MAC address) ficam em Hive. O token é salvo separadamente no armazenamento seguro do sistema operacional (Keychain/Keystore), não no banco Hive. O app migra perfis legados de `shared_preferences` na primeira inicialização. Edição manual do IP após o cadastro continua prevista.
