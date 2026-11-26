# 03 — Comunicação e Segurança

## Premissas Gerais de Rede e Transporte
- **Escopo de rede:** Celular/tablet e máquina desktop (**Windows** ou **macOS**) operam na **mesma rede local (Wi-Fi/LAN)**, sem descoberta automática (mDNS/scan) e sem acesso externo (internet/VPN) no MVP.
- **Transporte LAN sem TLS no MVP:** A comunicação WebSocket na LAN utiliza **`ws://`** com autenticação via token, evitando a complexidade de certificados autoassinados no celular durante o MVP.
- **Porta única com separação de interface/protocolo:**
  - **API LAN (`ws://`):** Exposta na interface de rede local para comunicação contínua com o app Flutter, exigindo token de pareamento válido.
  - **API Admin (`http://`):** Exposta na **mesma porta**, porém restrita estritamente à interface `127.0.0.1` / `localhost` (consumida pela CLI no MVP e pelo futuro frontend Web/Desktop).

---

## 1. Fluxo de Pareamento via QR Code
O pareamento transfere todas as credenciais e parâmetros de rede de uma única vez, evitando digitação manual inicial:

1. **Geração/consulta sob demanda:** O usuário executa o comando de pareamento na CLI no terminal; a CLI consulta a **API Admin (`localhost`)** do agente em execução.
2. **Exibição no terminal:** O agente disponibiliza os dados de conexão e a CLI desenha o **QR Code diretamente no terminal**.
3. **Leitura no App Flutter:** No menu lateral (*Adicionar máquina*), o app escaneia o QR Code e extrai os **5 campos obrigatórios**:
   - **IP local da máquina** (ex.: `192.168.x.x`)
   - **Porta** do agente
   - **MAC address** da interface de rede (para Wake-on-LAN)
   - **Token de pareamento** (credencial de acesso à API LAN)
   - **Nome da máquina** (identificador amigável exibido na lista de máquinas)
4. **Revisão e persistência:** O app valida o payload, permite revisar o nome/IP, salva o perfil em Hive e grava o token no armazenamento seguro do dispositivo.
5. **Autenticação:** Depois da gravação local, o app abre a conexão `ws://` e envia o token. O estado muda para autenticado somente ao receber `auth_ok`; falhas de conexão mantêm o perfil salvo para nova tentativa.

O app não persiste o token junto ao perfil. Dados legados de perfil anteriormente armazenados em `shared_preferences` são migrados para Hive; a chave do token permanece no armazenamento seguro, pois o identificador do perfil é preservado.

---

## 2. Segurança e Controle de Acesso

### A. Autenticação e Ciclo de Vida do Token
- **Token reutilizável:** O token embutido no QR Code pode ser **reutilizado** em múltiplos pareamentos ou releituras no MVP, facilitando registrar mais de um dispositivo ou refazer o pareamento sem travar o fluxo.
- **Autenticação obrigatória na LAN:** Nenhuma leitura de métrica ou comando de mídia/energia é aceito sem o token válido na sessão WebSocket.
- **Rejeição imediata:** Conexões sem token ou com token inválido/revogado são encerradas imediatamente pelo agente.
- **Gestão administrativa:** A revogação ou rotação do token fica exposta apenas pela **API Admin (`localhost`)** (e futuramente pelo frontend de gestão).

### B. Isolamento da API Admin (`http://localhost`)
- **Bloqueio de rede externa:** Requisições HTTP administrativas só são atendidas quando originadas na própria máquina (`127.0.0.1` / `::1`), impedindo que dispositivos na Wi-Fi/LAN consultem dados do agente, exibam/gerem QR Codes ou alterem configurações.

### C. Segurança Operacional de Comandos Sensíveis
- Ações destrutivas ou disruptivas (**Desligar** e **Reiniciar**) exigem confirmação explícita na interface do app antes do disparo do evento ao agente.
- O agente é executado na sessão interativa do usuário, não como serviço isolado. No Windows, a conta precisa ter o direito de desligar o sistema. No macOS, a automação pode exigir permissões de **Acessibilidade** e **Automação** em *Ajustes do Sistema → Privacidade e Segurança*.
- O daemon nunca armazena senha administrativa. Se o sistema operacional negar ou não autorizar uma ação, o agente retorna `command_error`.

---

## 3. Fluxo de Wake-on-LAN (WoL) e Reconexão
Quando a máquina selecionada no menu lateral está **Offline**:

1. **Disparo UDP:** O app monta o *Magic Packet* contendo o **MAC address** salvo no perfil da máquina e o envia em broadcast na mesma rede local (portas padrão UDP 7 ou 9).
2. **Transição de estado:** A interface do app muda o status da máquina de *Offline* para *Inicializando*.
3. **Tentativas de conexão:** O app inicia tentativas periódicas de conexão WebSocket (`ws://`) com o IP e porta cadastrados por uma janela limitada de tempo (timeout).
4. **Confirmação:** Assim que o agente sobe junto com a sessão do usuário e aceita a conexão autenticada, o app transita para *Online* e passa a receber métricas e estado de mídia. Caso o tempo expire sem resposta, exibe estado de *Indisponível / Timeout* (orientando verificar WoL/hardware ou atualização de IP; no macOS, considerando que o despertar confiável costuma exigir repouso/tomada e adaptador compatível).

---

## 4. Protocolo de Mensagens WebSocket (Contrato Lógico)
A comunicação sobre `ws://` é bidirecional e orientada a eventos estruturados, dividida em quatro categorias:

### 1. Autenticação e Sessão
- **`auth` (App → Agente):** Envio do token de pareamento logo após abrir a conexão (ou via cabeçalho/parâmetro no handshake).
- **`auth_ok` / `auth_error` (Agente → App):** Confirmação de sessão autorizada (retornando nome atual da máquina e capacidades) ou falha de autenticação. Além das capacidades gerais (`metrics`, `media`, `power`), o agente anuncia ações de energia individualmente (`power.lock`, `power.shutdown`, `power.restart`) quando implementadas na plataforma. O app mantém compatibilidade com agentes antigos que anunciam apenas `power`, limitado às ações já conhecidas; `suspend` não é inferido dessa capacidade legada.

### 2. Telemetria Contínua (Agente → App)
- **`metrics_update`:** Enviado a cada **1 segundo** apenas enquanto houver pelo menos um app conectado, contendo:
  - Uso percentual de **CPU**
  - Uso e total/disponível de **RAM**
  - Taxa atual de **rede** (download e upload)
- O envelope de `metrics_update` inclui `status: "ok"`. CPU e taxas de rede são derivadas de diferenças entre contadores; a primeira amostra após conectar/reconectar serve como base e pode trazer esses valores em zero.
- **`metrics_error`:** Enviado quando uma ou mais fontes falharem. Inclui `status: "error"`, timestamp e lista `failures` com a fonte (`cpu`, `memory` ou `network`) e a mensagem. O app marca as métricas como falhas/desatualizadas; quando a coleta normalizar, o próximo `metrics_update` com `status: "ok"` limpa o estado de falha.
- A taxa de rede agrega todas as interfaces marcadas como ativas, exceto loopback; interfaces virtuais ativas também entram na soma. Queda/reset de contador produz taxa zero naquela amostra e atualiza a referência para a próxima.
- **`media_state`:** Enviado na conexão inicial e sempre que houver mudança no player ativo do sistema:
  - `status`: `ok`, `no_media`, `unavailable` ou `error`.
  - `payload`: `playback` (`playing`, `paused`, `no_media` ou `unavailable`), `player`, `title`, `artist`, `volume` (0–100), `muted` e, em falha, `error`.
  - O agente envia uma amostra ao autenticar e volta a enviar quando qualquer campo mudar. A coleta é feita a cada segundo enquanto houver cliente autenticado.
  - `no_media` é um estado normal; `unavailable` indica que a plataforma ainda não dispõe de adaptador de mídia.

### 3. Comandos de Controle (App → Agente)
- **`media_command`:**
  - Ações: `play_pause`, `next`, `previous`, `set_volume`, `toggle_mute`
  - `set_volume` recebe `value` numérico de 0 a 100 e altera o volume master do sistema. Os controles de faixa exigem uma sessão de mídia disponível.
- **`power_command`:**
  - Ações implementadas: `shutdown` (desligar), `lock` (bloquear), `restart` (reiniciar).
  - `suspend` ainda não está implementada. `wake` também não é um comando WebSocket: o app envia WoL diretamente quando o agente está offline.

### 4. Confirmação e Erro (Agente → App)
- **`command_ack`:** Confirma que o comando foi recebido e que o sistema operacional aceitou a solicitação. Não garante que a transição de energia já terminou; a conexão pode cair logo depois de desligar/reiniciar.
- **`command_error`:** Informa que a ação não foi aceita ou não pôde ser iniciada (ex.: falta de permissão do SO, ausência de sessão de mídia ativa ou comando inválido). Em caso de erro, o agente não envia `command_ack` para aquela ação.
- Se a conexão cair ou o ACK expirar durante `shutdown`/`restart`, o app apresenta o resultado como **transição não confirmada**, não como rejeição certa. O usuário deve verificar o estado da máquina; a desconexão, isoladamente, não prova que o sistema concluiu a ação.
