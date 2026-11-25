## Objetivo
Criar um painel de controle e monitoramento remoto para desktop (**Windows** e **macOS**) via **Wi-Fi/LAN** (sem dependência de ADB ou acesso remoto pela internet no MVP), combinando em um único aplicativo:
- **Acordar a máquina** via Wake-on-LAN (WoL), enviado diretamente pelo app e respeitando as capacidades de hardware e estado de energia da plataforma. No Mac, despertar de repouso pode estar disponível; ligar a partir do desligamento completo não é garantido.
- **Controlar mídia** (play/pause, faixa, volume e visualização do estado atual).
- **Executar ações de energia** (desligar, bloquear e reiniciar). Suspensão fica fora do escopo implementado nesta etapa.
- **Acompanhar informações do sistema** (métricas de CPU, RAM e rede, além do status da conexão).

A proposta é unificar funções hoje espalhadas em múltiplos utilitários em uma interface limpa e pensada para uso rápido no celular ou tablet sobre a mesa.

## Escopo do MVP
O MVP deve cobrir o ciclo essencial de uso na rede local para **Windows** e **macOS**:
- **Pareamento via QR Code exibido no terminal** do agente desktop e escaneado pelo app Flutter (sem descoberta automática na rede, permitindo também edição manual do IP se necessário).
- Disparo de Wake-on-LAN para acordar/ligar a máquina a partir do endereço MAC cadastrado.
- Envio de comandos de energia (**desligar, bloquear e reiniciar**) e mídia (**play/pause, faixa, volume**).
- Exibição contínua de métricas de **CPU, RAM e rede** (além do estado do agente/mídia) a cada 1 segundo enquanto houver cliente conectado.

## Fora do Escopo Inicial (Pós-MVP)
Para manter o foco e validar a arquitetura rapidamente, ficam de fora da primeira versão:
- Frontend administrativo (Web ou Desktop) para gestão visual de configurações, dispositivos pareados e hotkeys customizadas (previsto para evolução futura sobre a API local do agente).
- Descoberta automática na rede (mDNS / scan de rede).
- Uso fora da mesma rede local (acesso entre sub-redes distintas, via VPN ou internet).
- Customização profunda de temas, layouts complexos ou múltiplos perfis avançados.
- Coleta avançada de sensores de hardware que exijam integrações específicas por fabricante/driver.

## Premissa de Rede e Pareamento
- **Celular/tablet e máquina desktop devem estar na mesma rede local** para que o envio do pacote Wake-on-LAN e a comunicação com o agente funcionem.
- O pareamento ocorre exclusivamente via **QR Code exibido no terminal** (reutilizável), contendo os seguintes campos:
  - **IP local da máquina**
  - **Porta de comunicação do agente**
  - **MAC address** (para Wake-on-LAN)
  - **Token de pareamento**
  - **Nome da máquina**
- Caso o IP da máquina mude via DHCP na rede local, o usuário pode atualizar o IP manualmente no app e restabelecer a conexão.

## Modelo de Execução do Agente Desktop
- O agente opera como um **daemon em segundo plano na sessão do usuário** (com **login automático** habilitado no desktop para subir de forma previsível junto com a sessão), mantendo APIs locais desacopladas (uma para comunicação LAN com o app mobile via `ws://` e outra administrativa via `http://` restrita a `localhost` para evoluções futuras de interface Web/Desktop).
- O **terminal** é utilizado para iniciar/gerenciar o agente via CLI e exibir o **QR Code sob demanda** durante o pareamento, sem exigir que a janela do terminal permaneça aberta após o pareamento concluído.

## Diretrizes de Interface (Modo Paisagem)
- Orientação principal em **paisagem (landscape)**, com estética **dark mode clean, moderna e sóbria** (preparada para futura personalização).
- Navegação horizontal por **swipe** entre duas telas principais:
  - **Tela 1:** Ações de energia, Wake-on-LAN e métricas/dados da máquina.
  - **Tela 2:** Controle de mídia.
- **Menu lateral (drawer)** exibindo a lista de máquinas cadastradas e um botão na base para **adicionar máquina** via leitura de QR Code.

## Estados da Máquina na Visão do App
O aplicativo precisa representar de forma clara em qual estado a máquina se encontra, pois isso define quais ações estão disponíveis:
1. **Desligada / Em repouso (Agente offline):** O agente não responde na rede. A ação principal disponível é **Ligar / Acordar (Wake-on-LAN)**.
2. **Inicializando:** O pacote WoL foi enviado ou a rede acabou de subir, mas o agente ainda não está pronto. O app deve indicar espera e tentar reconectar.
3. **Online (Agente conectado):** O agente responde na LAN; métricas (CPU, RAM, rede), estado de mídia e comandos de energia (desligar, bloquear, reiniciar) e mídia ficam disponíveis.
4. **Indisponível / Erro de conexão:** A máquina pode estar ligada, mas o agente não respondeu (ex.: bloqueio de firewall/permissão, serviço parado ou IP alterado). O app deve informar o motivo provável sem travar a tela.

## Cenários e Fluxos Principais
- **Cenário 1 — Pareamento via QR Code no terminal:** O usuário aciona o pareamento na CLI no terminal do agente, que exibe o QR Code com IP, porta, MAC address, token e nome da máquina; o app Flutter escaneia e salva o perfil da máquina.
- **Cenário 2 — Acordar/ligar a máquina na mesma rede:** O usuário abre o app com a máquina offline/em repouso, vê o estado *Offline* e toca em **Ligar**. O app envia o pacote WoL para o MAC configurado e monitora até o agente ficar online.
- **Cenário 3 — Controle rápido de mídia:** Com a máquina online, o usuário usa o app para pausar/retomar reprodução, trocar faixa ou ajustar volume sem precisar alternar janelas no computador.
- **Cenário 4 — Consulta rápida de status:** O usuário olha para o painel para conferir uso de CPU, RAM e atividade de rede, ou verificar se a máquina está ativa antes de sair.
- **Cenário 5 — Ações de energia:** O usuário aciona desligar, bloquear ou reiniciar no app; o agente pede a ação ao sistema operacional e confirma somente quando o sistema aceita o pedido. A interface pede confirmação antes de desligar/reiniciar.

## Critérios de Sucesso do MVP
O MVP será considerado bem-sucedido quando:
- Concluir o pareamento escaneando o QR Code no terminal com os 5 campos definidos e manter o agente ativo em segundo plano após fechar o terminal no Windows e no macOS.
- Conseguir acordar/ligar a máquina via WoL (dentro das capacidades do hardware/rede) e ver o app reconhecer o retorno do agente.
- Executar play/pause, faixa e volume, além de desligar, bloquear e reiniciar no Windows e no macOS, com resposta rápida e feedback claro de sucesso ou falha.
- Exibir métricas de CPU, RAM e rede a cada 1 segundo (com cliente conectado) com consumo baixo de recursos na máquina e sem travamentos no app.
- Manter a arquitetura do agente preparada para acoplar um frontend Web ou Desktop via API local no futuro sem reescrever o núcleo.
