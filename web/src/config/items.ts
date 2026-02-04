export interface ItemConfig {
    name: string;
    label: string;
    expandedSize: { x: number; y: number };
    foldedSize: { x: number; y: number };
}

export const ITEM_CONFIGS: Record<string, ItemConfig> = {
    'mochila_tatica_expansivel_luc': {
        name: 'mochila_tatica_expansivel_luc',
        label: 'Mochila Tática',
        expandedSize: { x: 4, y: 5 },
        foldedSize: { x: 2, y: 2 }
    },
    'rig_st_tipo_4': {
        name: 'rig_st_tipo_4',
        label: 'Colete Tático',
        expandedSize: { x: 3, y: 3 },
        foldedSize: { x: 2, y: 2 }
    }
};
