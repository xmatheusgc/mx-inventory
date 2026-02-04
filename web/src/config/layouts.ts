
export const CONTAINER_LAYOUTS: Record<string, {
    label: string;
    rows: {
        className?: string; // Wrapper class for the row (e.g. "flex justify-center gap-1")
        pockets: {
            label: string;
            x: number;
            y: number;
            width: number;
            height: number;
            className?: string;
        }[]
    }[]
}> = {
    'vest': {
        label: 'Tactical Vest',
        rows: [
            // Row 1: Top Pouches
            {
                className: "flex justify-center gap-1",
                pockets: [
                    { label: 'Mag Pouch L', x: 1, y: 1, width: 2, height: 2 },
                    { label: 'Mag Pouch R', x: 3, y: 1, width: 2, height: 2 }
                ]
            },
            // Row 2: Main Body
            {
                className: "flex justify-center",
                pockets: [
                    { label: 'Main Rig', x: 1, y: 3, width: 4, height: 4 }
                ]
            }
        ]
    },
    'vest_complex': {
        label: 'Tactical Vest',
        rows: [
            {
                className: "flex justify-center gap-1",
                pockets: [
                    { label: 'Top Left', x: 1, y: 1, width: 2, height: 2 },
                    { label: 'Top Right', x: 3, y: 1, width: 2, height: 2 }
                ]
            },
            {
                className: "flex justify-center gap-1",
                pockets: [
                    { label: 'Side Left', x: 5, y: 1, width: 1, height: 4 },
                    { label: 'Center', x: 1, y: 3, width: 4, height: 4 },
                    { label: 'Side Right', x: 6, y: 1, width: 1, height: 4 }
                ]
            },
            {
                className: "flex justify-center gap-1",
                pockets: [
                    { label: 'Bot Left', x: 1, y: 7, width: 1, height: 4 },
                    { label: 'Bot Mid', x: 2, y: 7, width: 2, height: 4 },
                    { label: 'Bot Right', x: 4, y: 7, width: 1, height: 4 }
                ]
            }
        ]
    },
    'backpack': {
        label: 'Field Backpack',
        rows: [
            {
                className: "flex justify-center gap-1",
                pockets: [
                    { label: 'Main Compartment', x: 1, y: 1, width: 5, height: 5 },
                    { label: 'Side Pocket', x: 6, y: 1, width: 2, height: 5 }
                ]
            }
        ]
    },
    'rig_st_tipo_4': {
        label: 'ST Tipo 4',
        rows: [
            // Row 1: Top Pockets
            {
                className: "flex justify-center gap-1",
                pockets: [
                    { label: 'Bolso Superior 1', x: 1, y: 1, width: 1, height: 1 },
                    { label: 'Bolso Superior 2', x: 2, y: 1, width: 1, height: 1 }
                ]
            },
            // Row 2: Middle Cluster
            {
                className: "flex justify-center gap-1",
                pockets: [
                    { label: 'Bolso Lateral 1', x: 1, y: 2, width: 1, height: 2 },
                    { label: 'Bolso Central 1', x: 2, y: 2, width: 2, height: 2 },
                    { label: 'Bolso Lateral 2', x: 4, y: 2, width: 1, height: 2 }
                ]
            },
            // Row 3: Mag Pouches
            {
                className: "flex justify-center gap-1",
                pockets: [
                    { label: 'Porta Carregador 1', x: 1, y: 4, width: 1, height: 3 },
                    { label: 'Porta Carregador 2', x: 2, y: 4, width: 1, height: 3 },
                    { label: 'Porta Carregador 3', x: 3, y: 4, width: 1, height: 3 },
                    { label: 'Porta Carregador 4', x: 4, y: 4, width: 1, height: 3 }
                ]
            }
        ]
    },
    'mochila_tatica_expansivel_luc': {
        label: 'Mochila Tática Expansível Luc',
        rows: [
            {
                className: "flex justify-center",
                pockets: [
                    { label: 'Compartimento Principal', x: 1, y: 1, width: 5, height: 7 }
                ]
            },
            {
                className: "flex justify-center gap-1",
                pockets: [
                    { label: 'Porta Carregador 1', x: 1, y: 8, width: 1, height: 2 },
                    { label: 'Porta Suprimentos 1', x: 2, y: 8, width: 3, height: 2 },
                    { label: 'Porta Carregador 2', x: 5, y: 8, width: 1, height: 2 }
                ]
            }
        ]
    }
};
