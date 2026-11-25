# 01 — Visão Geral

## Objetivo
Criar um painel de controle e monitoramento remoto para o desktop via **Wi-Fi/LAN** (sem dependência de ADB ou acesso remoto pela internet no início), combinando em um único aplicativo:
- **Ligar o PC** via Wake-on-LAN (WoL).
- **Controlar mídia** (play/pause, faixa, volume e visualização do estado atual).
- **Executar ações de energia** (desligar, suspender, bloquear e reiniciar).
- **Acompanhar informações do sistema** (métricas de CPU, RAM e rede, além do status da conexão).

A proposta é unificar funções hoje espalhadas em múltiplos utilitários em uma interface limpa e pensada para uso rápido no celular ou tablet sobre a mesa.

## Escopo do MVP
O MVP deve cobrir o ciclo essencial de uso na rede local:
- **Pareamento via QR Code exibido no terminal** do agente desktop e escaneado pelo app Flutter (sem descoberta automática na rede, permitindo também edição manual do IP se necessário).
- Disparo de Wake-on-LAN para ligar o PC a partir do endereço MAC cadastrado.
- Envio de comandos de energia (**desligar, suspender, bloquear e reiniciar**) e mídia (**play/pause, faixa, volume**).
- Exibição contínua de métricas de **CPU, RAM e rede** (além do estado do agente/mídia) enquanto o app estiver conectado.

## Fora do Escopo Inicial (Pós-MVP)
Para manter o foco e validar a arquitetura rapidamente, ficam de fora da primeira versão:
- Frontend administrativo (Web ou Desktop) para gestão visual de configurações, dispositivos pareados e hotkeys customizadas (previsto para evolução futura sobre a API local do agente).
- Descoberta automática na rede (mDNS / scan de rede).
- Uso fora da mesma rede local (acesso entre sub-redes distintas, via VPN ou internet).
- Customização profunda de temas, layouts complexos ou múltiplos perfis avançados.
- Coleta avançada de sensores de hardware que exijam integrações específicas por fabricante/driver.

## Premissa de Rede e Pareamento
- **Celular e PC devem estar na mesma rede local** para que o envio do pacote Wake-on-LAN e a comunicação com o agente desktop funcionem.
- O pareamento ocorre exclusivamente via **QR Code exibido no terminal**, contendo os seguintes campos:
  - **IP local da máquina**
  - **Porta de comunicação do agente**
  - **MAC address** (para Wake-on-LAN)
  - **Token de pareamento**
  - **Nome da máquina**
- Caso o IP da máquina mude via DHCP na rede local, o usuário pode atualizar o IP manualmente no app e restabelecer a conexão.

## Modelo de Execução do Agente Desktop
- O agente opera como um **serviço/daemon em segundo plano na sessão do usuário**, mantendo APIs locais desacopladas (uma para comunicação LAN com o app mobile e outra administrativa restrita a `localhost` para evoluções futuras de interface Web/Desktop).
- O **terminal** é utilizado para iniciar/gerenciar o agente no MVP e exibir o **QR Code sob demanda** durante o pareamento, sem exigir que a janela do terminal permaneça aberta após o pareamento concluído.

## Diretrizes de Interface (Modo Paisagem)
- Orientação principal em **paisagem (landscape)**, com estética **dark mode clean, moderna e sóbria** (preparada para futura personalização).
- Navegação horizontal por **swipe** entre duas telas principais:
  - **Tela 1:** Ações de energia, Wake-on-LAN e métricas/dados do PC.
  - **Tela 2:** Controle de mídia.
- **Menu lateral (drawer)** exibindo a lista de máquinas cadastradas e um botão na base para **adicionar máquina** via leitura de QR Code.

## Estados do PC na Visão do App
O aplicativo precisa representar de forma clara em qual estado o desktop se encontra, pois isso define quais ações estão disponíveis:
1. **Desligado / Suspenso (Agente offline):** O agente não responde na rede. A ação principal disponível é **Ligar (Wake-on-LAN)**.
2. **Inicializando:** O pacote WoL foi enviado ou a rede acabou de subir, mas o agente ainda não está pronto. O app deve indicar espera e tentar reconectar.
3. **Online (Agente conectado):** O agente responde na LAN; métricas (CPU, RAM, rede), estado de mídia e comandos de energia (desligar, suspender, bloquear, reiniciar) e mídia ficam disponíveis.
4. **Indisponível / Erro de conexão:** O PC pode estar ligado, mas o agente não respondeu (ex.: bloqueio de firewall, serviço parado ou IP alterado). O app deve informar o motivo provável sem travar a tela.

## Cenários e Fluxos Principais
- **Cenário 1 — Pareamento via QR Code no terminal:** O usuário aciona o pareamento no terminal do agente, que exibe o QR Code com IP, porta, MAC address, token e nome da máquina; o app Flutter escaneia e salva o perfil do PC.
- **Cenário 2 — Ligar o PC à distância na mesma rede:** O usuário abre o app com o PC desligado, vê o estado *Offline* e toca em **Ligar**. O app envia o pacote WoL para o MAC configurado e monitora até o agente ficar online.
- **Cenário 3 — Controle rápido de mídia:** Com o PC online, o usuário usa o app para pausar/retomar reprodução, trocar faixa ou ajustar volume sem precisar alternar janelas no computador.
- **Cenário 4 — Consulta rápida de status:** O usuário olha para o painel para conferir uso de CPU, RAM e atividade de rede, ou verificar se o PC está ativo antes de sair.
- **Cenário 5 — Ações de energia:** O usuário aciona desligar, suspender, bloquear ou reiniciar no app; o agente confirma o recebimento e executa a ação no sistema operacional (com confirmação preventiva antes de desligar/reiniciar).

## Critérios de Sucesso do MVP
O MVP será considerado bem-sucedido quando:
- Concluir o pareamento escaneando o QR Code no terminal com os 5 campos definidos e manter o agente ativo em segundo plano após fechar o terminal.
- Conseguir ligar o PC via WoL e ver o app reconhecer o retorno do agente.
- Executar play/pause, faixa, volume e as ações de energia (desligar, suspender, bloquear, reiniciar) com resposta rápida e feedback claro de sucesso ou falha.
- Exibir métricas de CPU, RAM e rede em tempo real com consumo baixo de recursos no desktop e sem travamentos no app.
- Manter a arquitetura do agente preparada para acoplar um frontend Web ou Desktop via API local no futuro sem reescrever o núcleo.