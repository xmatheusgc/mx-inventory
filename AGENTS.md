# 📦 Sistema de Inventário – FiveM (Zombie Server)
### Inspirado em Arena Breakout Infinite & Escape From Tarkov

## 📌 Visão Geral

Este projeto tem como objetivo criar um **sistema de inventário avançado e imersivo** para FiveM, focado em **realismo, tática e gerenciamento de recursos**, ideal para um servidor com temática **zumbi/survival**.

O sistema será baseado em:
- Inventário por **Grid**
- **Containers físicos**
- **Drag and Drop**
- **Rotação de itens**
- **Limitações realistas**
- Comunicação total com **Lua (FiveM)**

---

## 🎯 Objetivos do Sistema

- Criar sensação de **peso, risco e planejamento**
- Incentivar loot tático e tomada de decisão
- Evitar inventários infinitos ou irreais
- Integrar perfeitamente com mecânicas de combate, loot e sobrevivência
- Ser extensível para IA, crafting, traders e eventos

---

## 🧱 Arquitetura Geral

### Frontend (UI)
- React 18
- TypeScript
- Vite (build rápido e bundle controlado)
- TailwindCSS (UI consistente e produtiva)
- Zustand (estado global leve, melhor que Redux aqui)
- @dnd-kit/core (drag and drop performático e controlável)
- Framer Motion (animações leves e condicionais)
- clsx / tailwind-merge (controle de classes)
- Floating UI (tooltips inteligentes e posicionamento)

### Backend
- Lua (FiveM)
- Estado do inventário sincronizado
- Validações de peso, espaço e regras
- Comunicação NUI ↔ Lua via `SendNUIMessage` e `RegisterNUICallback`

---

## 🧩 Conceito de Inventário

### Tipos de Inventário
| Tipo | Descrição |
|----|----|
| Player | Inventário principal |
| Mochila | Container vestível |
| Colete | Slots rápidos |
| Bolso | Itens pequenos |
| Container | Caixas, baús, stash |
| Loot no chão | Drop físico |

---

## 🟦 Sistema de Grid

### Estrutura
- Inventário é uma **matriz (X,Y)**
- Cada item ocupa um espaço específico
- Exemplo:  
  - Pistola: `2x2`
  - Rifle: `2x5`
  - Mochila: `4x6`

### Regras
- Itens **não podem sobrepor**
- Deve haver espaço livre contínuo
- Grid pode variar por container

---

## 🔄 Rotação de Itens

### Funcionalidade
- Tecla dedicada (ex: `R`)
- Alterna entre:
  - Horizontal → Vertical
- Recalcula ocupação do grid

### Restrições
- Nem todos os itens são rotacionáveis
- Ex: mochilas e coletes não giram

---

## 🧲 Drag and Drop

### Ações Permitidas
- Mover dentro do mesmo container
- Transferir entre containers abertos
- Equipar item arrastando para slot
- Dropar no mundo

### Validações
- Espaço disponível
- Peso máximo
- Tipo de slot compatível
- Regras de nesting (ver abaixo)

---

## 🧠 Tooltips Inteligentes

### Conteúdo do Tooltip
- Nome do item
- Tipo
- Peso
- Tamanho (grid)
- Durabilidade
- Proteção (se aplicável)
- Efeitos especiais
- Ações possíveis

### Extras
- Mudança visual se item estiver quebrado
- Cores por raridade

---

## 🎒 Mochilas e Containers (Nesting)

### Regra Principal
> ❌ **Não é permitido colocar mochilas dentro de mochilas**

### Regras de Proteção
- Mochila **não pode conter outro item do tipo container**
- Limite configurável por item
- Evita exploits de espaço infinito

### Exemplo
| Item | Pode conter |
|----|----|
| Mochila | Itens comuns |
| Caixa | Itens comuns |
| Caixa | ❌ Outra caixa |
| Mochila | ❌ Outra mochila |

---

## ⚖️ Sistema de Peso

### Peso Total
- Cada item possui peso
- Containers somam peso interno
- Peso afeta:
  - Velocidade
  - Stamina
  - Animações

### Estados
- Leve
- Normal
- Pesado
- Sobrecarregado

---

## 🛡️ Itens e Categorias

### Categorias Principais
- Armas
- Munição
- Comida
- Medicamentos
- Proteções
- Ferramentas
- Quest Items
- Lixo (loot comum)

### Proteções
| Tipo | Área |
|----|----|
| Capacete | Cabeça |
| Colete | Tronco |
| Máscara | Rosto |

- Cada proteção tem:
  - Classe
  - Durabilidade
  - Redução de dano

---

## 🔗 Comunicação com Lua (FiveM)

### Ações Suportadas

#### Abrir / Fechar
```lua
TriggerEvent("inventory:open")
TriggerEvent("inventory:close")
````

#### Equipar Item

```lua
TriggerServerEvent("inventory:equip", itemId)
```

#### Dropar Item

```lua
TriggerServerEvent("inventory:drop", itemId, amount)
```

#### Pegar Item

```lua
TriggerServerEvent("inventory:pickup", entityId)
```

#### Enviar Item (trade)

```lua
TriggerServerEvent("inventory:send", targetId, itemId)
```

#### Abrir Container / Stash

```lua
TriggerServerEvent("inventory:openContainer", containerId)
```

---

## 🌐 Sincronização

* Inventário validado **sempre no servidor**
* Frontend é apenas visual
* Anti-dup e anti-exploit
* Lock de container quando aberto

---

## 🧠 Integração com IA (Zumbis / NPCs)

### Loot em NPCs

* NPCs possuem inventário próprio
* Loot dinâmico por tipo de zumbi
* Chance de containers quebrados

### IA usando inventário

* NPCs podem:

  * Usar itens
  * Dropar loot ao morrer
  * Proteger containers

---

## 🤖 Referência para Agentes de IA

### Agente: Inventory Architect

Responsável por:

* Modelagem de grid
* Regras de nesting
* Performance

### Agente: UI/UX Specialist

Responsável por:

* Drag and drop
* Tooltips
* Feedback visual

### Agente: Lua Gameplay Engineer

Responsável por:

* Eventos
* Validações
* Sincronização

### Agente: Anti-Exploit Analyst

Responsável por:

* Edge cases
* Dupes
* Abusos

### Agente: AI Gameplay Designer

Responsável por:

* Loot tables
* Comportamento de NPCs
* Balanceamento

---

## 🚀 Roadmap

### Fase 1

* Grid básico
* Drag and drop
* Inventário player

### Fase 2

* Containers
* Mochilas
* Peso

### Fase 3

* Proteções
* Tooltips avançados
* Rotação

### Fase 4

* IA
* Loot dinâmico
* Eventos

---

## 📎 Referências

* Escape From Tarkov
* Arena Breakout Infinite
* DayZ Inventory
* STALKER Anomaly

---

## ✅ Conclusão

Este sistema busca **realismo, imersão e profundidade**, sendo um diferencial competitivo para servidores FiveM de sobrevivência.
