# Plano de Implementação: Banco de Dados Standalone (oxmysql)

Baseado na análise do `ox_inventory`, este plano detalha a implementação de um sistema de persistência de dados independente de framework (Standalone), utilizando `oxmysql`.

## Objetivo
Criar uma camada de abstração de banco de dados robusta que permita ao script de inventário funcionar sem depender de ESX ou QBox, gerenciando seus próprios dados de jogadores e inventários.

## Estrutura do Banco de Dados

### 1. Tabela `mx_inventory_players`
Como não há garantia de uma tabela `users` ou `players` pré-existente em um ambiente standalone, criaremos uma dedicada.

```sql
CREATE TABLE IF NOT EXISTS `mx_inventory_players` (
  `identifier` varchar(60) NOT NULL, -- Chave primária (ex: license:...)
  `inventory` longtext DEFAULT NULL, -- Dados do inventário em JSON
  `settings` longtext DEFAULT NULL,  -- Configurações extras (opcional)
  `last_updated` timestamp DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`identifier`)
);
```

### 2. Tabela `mx_inventory_stashes` (Opcional/Futuro)
Para baús e inventários que não pertencem a jogadores.

```sql
CREATE TABLE IF NOT EXISTS `mx_inventory_stashes` (
  `name` varchar(100) NOT NULL,
  `inventory` longtext DEFAULT NULL,
  PRIMARY KEY (`name`)
);
```

## Módulos do Script

### 1. Configuração (`fxmanifest.lua`)
Adicionar a dependência obrigatória.
```lua
dependencies {
    'oxmysql',
}
```

### 2. Camada de Dados (`server/db.lua`)
Um módulo encapsulado para lidar com todas as queries SQL.

-   **`DB.Init()`**: Executa as queries `CREATE TABLE` ao iniciar o recurso.
-   **`DB.LoadPlayer(identifier)`**: Busca os dados do jogador. Retorna `nil` se não existir.
-   **`DB.SavePlayer(identifier, data)`**: Salva ou atualiza os dados do jogador (Upsert).

### 3. Gerenciamento de Jogadores (`server/main.lua`)
Integração com o ciclo de vida do jogador no FiveM.

-   **Evento `playerConnecting` / `playerSpawned`**:
    -   Obter o identificador do jogador (License é o mais seguro para standalone).
    -   Carregar dados do banco via `DB.LoadPlayer`.
    -   Inicializar inventário em memória (cache).
-   **Evento `playerDropped`**:
    -   Salvar os dados do inventário em memória para o banco via `DB.SavePlayer`.
    -   Limpar da memória.
-   **Save Periódico**:
    -   Um loop a cada X minutos para salvar todos os jogadores online, prevenindo perda de dados em caso de crash.

## Exemplo de Fluxo de Dados

1.  **Jogador Entra**: Script captura a licença `license:12345`.
2.  **Load**: `SELECT inventory FROM mx_inventory_players WHERE identifier = 'license:12345'`.
3.  **Resultado**:
    -   *Encontrado*: Decodifica o JSON e carrega na tabela Lua `Inventories[source]`.
    -   *Não Encontrado*: Cria tabela Lua padrão `{ items = {}, weight = 0 }`.
4.  **Gameplay**: Jogador ganha item. A alteração é feita apenas na tabela Lua `Inventories[source]`.
5.  **Save (Auto/Saiu)**: Codifica `Inventories[source]` para JSON e executa `INSERT ... ON DUPLICATE KEY UPDATE`.

## Próximos Passos
1.  Criar `server/db.lua` com a conexão `oxmysql`.
2.  Implementar a lógica de Load/Save no `server/main.lua`.
3.  Testar persistência reiniciando o servidor.
