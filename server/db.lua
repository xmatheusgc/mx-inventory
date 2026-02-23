-- Using global MySQL from @oxmysql/lib/MySQL.lua
DB = {}
DB.Ready = false

-- Initialize Database Tables (Async)
function DB.Init()
    local queries = {
        [[
            CREATE TABLE IF NOT EXISTS `mx_inventory_players` (
                `identifier` varchar(60) NOT NULL,
                `inventory` longtext DEFAULT NULL,
                `settings` longtext DEFAULT NULL,
                `last_updated` timestamp DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                PRIMARY KEY (`identifier`)
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `mx_inventory_stashes` (
                `name` varchar(100) NOT NULL,
                `inventory` longtext DEFAULT NULL,
                PRIMARY KEY (`name`)
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `mx_inventory_drops` (
                `id` varchar(60) NOT NULL,
                `data` longtext DEFAULT NULL,
                PRIMARY KEY (`id`)
            )
        ]]
    }

    local success = true
    for _, query in ipairs(queries) do
        -- Use MySQL.query.await for async query execution that pauses the thread
        local result = MySQL.query.await(query)
        if not result then success = false end
    end

    if success then
        print('^2[mx-inv] Database tables initialized successfully.^0')
        DB.Ready = true
    else
        print('^1[mx-inv] Failed to initialize database tables.^0')
    end
end

-- Load Player Inventory (Async)
function DB.LoadPlayer(identifier)
    -- Use MySQL.scalar.await to fetch a single value without blocking the main thread
    local result = MySQL.scalar.await('SELECT inventory FROM mx_inventory_players WHERE identifier = ?', { identifier })
    if result then
        return json.decode(result)
    end
    return nil
end

-- Save Player Inventory (Async)
function DB.SavePlayer(identifier, inventoryData)
    local jsonInventory = json.encode(inventoryData)
    -- Use MySQL.prepare.await for secure execution
    MySQL.prepare.await(
        'INSERT INTO mx_inventory_players (identifier, inventory) VALUES (?, ?) ON DUPLICATE KEY UPDATE inventory = ?', {
            identifier,
            jsonInventory,
            jsonInventory
        })
end

-- Load Stash (Async)
function DB.LoadStash(name)
    local result = MySQL.scalar.await('SELECT inventory FROM mx_inventory_stashes WHERE name = ?', { name })
    if result then
        return json.decode(result)
    end
    return nil
end

-- Save Stash (Async)
function DB.SaveStash(name, inventoryData)
    local jsonInventory = json.encode(inventoryData)
    MySQL.prepare.await(
        'INSERT INTO mx_inventory_stashes (name, inventory) VALUES (?, ?) ON DUPLICATE KEY UPDATE inventory = ?', {
            name,
            jsonInventory,
            jsonInventory
        })
end

-- Drops Management (Async)
function DB.LoadDrops()
    local result = MySQL.query.await('SELECT data FROM mx_inventory_drops')
    local drops = {}
    if result then
        for _, row in ipairs(result) do
            local data = json.decode(row.data)
            drops[data.id] = data
        end
    end
    return drops
end

function DB.SaveDrop(id, dropData)
    local jsonData = json.encode(dropData)
    MySQL.prepare.await('INSERT INTO mx_inventory_drops (id, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = ?', {
        id,
        jsonData,
        jsonData
    })
end

function DB.DeleteDrop(id)
    MySQL.prepare.await('DELETE FROM mx_inventory_drops WHERE id = ?', { id })
end
