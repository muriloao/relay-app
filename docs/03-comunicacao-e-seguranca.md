# 03 — Comunicação e Segurança

## Premissas Gerais de Rede e Transporte
- **Escopo de rede:** Celular/tablet e desktop operam na **mesma rede local (Wi-Fi/LAN)**, sem descoberta automática (mDNS/scan) e sem acesso externo (internet/VPN) no MVP.
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
4. **Validação inicial e persistência:** O app abre a conexão `ws://` usando os dados lidos e autentica com o token; após confirmação do agente, salva o perfil localmente (permitindo editar apenas o IP manualmente no futuro caso o DHCP altere o endereço).

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

---

## 3. Fluxo de Wake-on-LAN (WoL) e Reconexão
Quando a máquina selecionada no menu lateral está **Offline**:

1. **Disparo UDP:** O app monta o *Magic Packet* contendo o **MAC address** salvo no perfil da máquina e o envia em broadcast na mesma rede local (portas padrão UDP 7 ou 9).
2. **Transição de estado:** A interface do app muda o status da máquina de *Offline* para *Inicializando*.
3. **Tentativas de conexão:** O app inicia tentativas periódicas de conexão WebSocket (`ws://`) com o IP e porta cadastrados por uma janela limitada de tempo (timeout).
4. **Confirmação:** Assim que o agente sobe junto com a sessão do usuário e aceita a conexão autenticada, o app transita para *Online* e passa a receber métricas e estado de mídia. Caso o tempo expire sem resposta, exibe estado de *Indisponível / Timeout* (orientando verificar WoL na BIOS/placa ou atualização de IP).

---

## 4. Protocolo de Mensagens WebSocket (Contrato Lógico)
A comunicação sobre `ws://` é bidirecional e orientada a eventos estruturados, dividida em quatro categorias:

### 1. Autenticação e Sessão
- **`auth` (App → Agente):** Envio do token de pareamento logo após abrir a conexão (ou via cabeçalho/parâmetro no handshake).
- **`auth_ok` / `auth_error` (Agente → App):** Confirmação de sessão autorizada (retornando nome atual da máquina e capacidades) ou falha de autenticação.

### 2. Telemetria Contínua (Agente → App)
- **`metrics_update`:** Enviado a cada **1 segundo** apenas enquanto houver pelo menos um app conectado, contendo:
  - Uso percentual de **CPU**
  - Uso e total/disponível de **RAM**
  - Taxa atual de **rede** (download e upload)
- **`media_state`:** Enviado na conexão inicial e sempre que houver mudança no player ativo do sistema:
  - Estado de reprodução (*tocando*, *pausado*, *sem mídia*)
  - Metadados básicos disponíveis (título, artista/aplicativo de origem)
  - Nível atual de volume e status de mudo

### 3. Comandos de Controle (App → Agente)
- **`media_command`:**
  - Ações: `play_pause`, `next`, `previous`, `set_volume`, `toggle_mute`
- **`power_command`:**
  - Ações: `shutdown` (desligar), `suspend` (suspender), `lock` (bloquear), `restart` (reiniciar)

### 4. Confirmação e Erro (Agente → App)
- **`command_ack`:** Confirma que o comando foi recebido e aceito para execução (especialmente crítico antes de `shutdown`, `suspend` ou `restart`, pois a conexão cairá logo em seguida).
- **`command_error`:** Informa falha na execução (ex.: falta de permissão no SO, ausência de sessão de mídia ativa ou comando inválido).