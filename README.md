# mx-inv: Advanced Modular Inventory System

`mx-inv` is a highly advanced, grid-based, modular inventory system for FiveM. It features nested containers (bags within bags), equipment slots, weapon attachments, dynamic folding items, world drops, and secure server-authoritative movement validation.

## Architecture

The system is designed with a strict separation of concerns, heavily prioritizing server authority to prevent spoofing and duping.

### Server Modularization (`server/modules/`)
-   **`inventory.lua`**: Contains core logic for calculating weight, fetching containers, and formatting payload syncs for the NUI.
-   **`movement.lua`**: The **Movement Engine**. Handles collision logic, boundary checks, and free-slot algorithms used by drops, stashes, and players.
-   **`equipment.lua`**: Handles assigning/removing weapons and specific clothing items from dynamic equipment slots (+ attaching/removing attachments & helmet accessories).
-   **`stash.lua`**: Handles state management and distance verification for open stashes.
-   **`drop.lua`**: Handles persistent map drops (spawning local props on client via sync).

### Client Modularization (`client/modules/`)
-   **`nui.lua`**: Listens to all `RegisterNUICallback` events from the React frontend, acting as a passthrough to the server events.
-   **`camera.lua`**: Handles the Pause menu character preview camera.
-   **`equipment.lua`**: Visual sync. When the server applies an equipment update, the client physically attaches the weapon model, components, or clothing drawables.

### Frontend Modularization (`web/src/hooks/` & `web/src/utils/`)
The React frontend (Typescript) is decentralized from `App.tsx` into:
-   **`useDndHandlers.ts`**: Complex `@dnd-kit/core` rules.
-   **`useNuiMessages.ts`**: Event listener manager.
-   **`useKeyboardShortcuts.ts`**: `useEffect` keyboard listener logic.
-   **`validation.ts`**: Frontend collision forecasting to prevent server rejection latency.

## Security & Validations

1.  **Drop & Stash Spoofing**: `mx-inv:server:moveItem` verifies `PlayerOpenStash[src]` and `PlayerOpenDrop[src]` to ensure a player cannot move items into a stash they are not physically standing next to.
2.  **Item Ownership (`UUIDs`)**: Stackable and identical items are uniquely tracked. The server strictly matches UUIDs during movement instead of just trusting item slot queries from the UI.
3.  **SQL Injection**: All database operations (`oxmysql`) use prepared parameterized commands (`MySQL.prepare.await('query', { params })`).
4.  **CPU Optimization**: Distance calculation loops (`#(coords - dropCoords)`) in `client/main.lua` yield `Wait(1000)` unless a player is actively within 2 meters (`Wait(0)`) where the 3D Text needs to be smoothly drawn.

## Adding Custom Items (`data/items.lua`)

To add a new item, you define it in the shared Items table. It has extensive customization:

```lua
['tactical_backpack'] = {
    label = "Tactical Backpack",
    description = "Provides massive storage but takes up the bag slot.",
    weight = 1.0, 
    type = "backpack", -- Tells the equip system where it goes
    image = "tactical_backpack.png",
    stackable = false,
    size = { x = 3, y = 3 },
    foldedSize = { x = 1, y = 2 }, -- Allows folding in UI
    container = { -- This turns the item into a nested container when equipped!
        size = { width = 6, height = 6 },
        maxWeight = 50.0
    }
}
```
