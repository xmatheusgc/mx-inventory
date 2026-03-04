-- data/layouts.lua
-- Mirrored from web/src/config/layouts.ts for server-side validation

Config = Config or {}

Config.ContainerLayouts = {
    ['vest'] = {
        label = 'Tactical Vest',
        pockets = {
            { x = 1, y = 1, width = 2, height = 2 },
            { x = 3, y = 1, width = 2, height = 2 },
            { x = 1, y = 3, width = 4, height = 4 }
        }
    },
    ['vest_complex'] = {
        label = 'Tactical Vest',
        pockets = {
            { x = 1, y = 1, width = 2, height = 2 },
            { x = 3, y = 1, width = 2, height = 2 },
            { x = 5, y = 1, width = 1, height = 4 },
            { x = 1, y = 3, width = 4, height = 4 },
            { x = 6, y = 1, width = 1, height = 4 },
            { x = 1, y = 7, width = 1, height = 4 },
            { x = 2, y = 7, width = 2, height = 4 },
            { x = 4, y = 7, width = 1, height = 4 }
        }
    },
    ['backpack'] = {
        label = 'Field Backpack',
        pockets = {
            { x = 1, y = 1, width = 5, height = 5 },
            { x = 6, y = 1, width = 2, height = 5 }
        }
    },
    ['rig_st_tipo_4'] = {
        label = 'ST Tipo 4',
        pockets = {
            { x = 1, y = 1, width = 1, height = 1 },
            { x = 2, y = 1, width = 1, height = 1 },
            { x = 1, y = 2, width = 1, height = 2 },
            { x = 2, y = 2, width = 2, height = 2 },
            { x = 4, y = 2, width = 1, height = 2 },
            { x = 1, y = 4, width = 1, height = 3 },
            { x = 2, y = 4, width = 1, height = 3 },
            { x = 3, y = 4, width = 1, height = 3 },
            { x = 4, y = 4, width = 1, height = 3 }
        }
    },
    ['mochila_tatica_expansivel_luc'] = {
        label = 'Mochila Tática Expansível Luc',
        pockets = {
            { x = 1, y = 1, width = 5, height = 7 },
            { x = 1, y = 8, width = 1, height = 2 },
            { x = 2, y = 8, width = 3, height = 2 },
            { x = 5, y = 8, width = 1, height = 2 }
        }
    }
}
