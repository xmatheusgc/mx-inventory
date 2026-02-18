export const mockContainers = {
    'player-inv': {
        id: 'player-inv',
        label: 'Player Inventory',
        type: 'player',
        size: { width: 6, height: 3 }, // Example size
        items: [
            { name: 'bread', count: 1, label: 'Bread', slot: { x: 1, y: 1 }, size: { x: 1, y: 1 }, type: 'food' },
            { name: 'water', count: 1, label: 'Water', slot: { x: 2, y: 1 }, size: { x: 1, y: 1 }, type: 'drink' },
            { name: 'bandage', count: 5, label: 'Bandage', slot: { x: 1, y: 2 }, size: { x: 1, y: 1 }, type: 'medical' }
        ]
    },
    'stash-mock': {
        id: 'stash-mock-1',
        label: 'Stash (Mock)',
        type: 'stash',
        size: { width: 7, height: 10 },
        items: [
            { name: 'rifle_ammo', count: 100, label: 'Rifle Ammo', slot: { x: 1, y: 1 }, size: { x: 1, y: 1 }, type: 'ammo' },
            { name: 'weapon_pistol', count: 1, label: 'Pistol', slot: { x: 3, y: 3 }, size: { x: 2, y: 1 }, type: 'weapon' }
        ]
    }
};

export const mockEquipment = {
    head: null,
    body: { name: 'armor_heavy', label: 'Heavy Armor', type: 'vest' },
    legs: null,
    feet: null,
    vest: { name: 'vest_tactical', label: 'Tactical Vest', type: 'vest' },
    backpack: { name: 'bag_large', label: 'Large Backpack', type: 'backpack' },
    primary: null,
    secondary: null
};
