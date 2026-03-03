import { useEffect } from 'react';
import { useInventoryStore } from '../store/inventoryStore';
import { ITEM_CONFIGS } from '../config/items';

export function useNuiMessages() {
    const {
        setOpen,
        setContainers,
        setEquipment,
        updateContainerWeight,
        addNotification,
        setGiveTarget,
        setItemDefs,
        itemDefs: storeDefs,
    } = useInventoryStore();

    useEffect(() => {
        const handleMessage = (event: MessageEvent) => {
            const { action, data } = event.data;

            if (action === 'notify') {
                if (data) Object.assign(window, { __notify: data }); // generic attach
                if (data) {
                    addNotification(data.message, data.type, data.duration);
                }
            }

            if (action === 'open' || action === 'update') {
                if (data) {
                    const { itemDefs: incomingDefs, equipment: equipData } = data;

                    if (incomingDefs) {
                        setItemDefs(incomingDefs);
                        (window as any).__itemDefs = incomingDefs;
                    }

                    const defs = incomingDefs || storeDefs;

                    const enrichItems = (items: any[]) => items.map((item: any) => {
                        const def = defs[item.name] || {};
                        const itemConfig = ITEM_CONFIGS[item.name];
                        let resolvedSize: { x: number; y: number };
                        if (item.folded && itemConfig) {
                            resolvedSize = itemConfig.foldedSize;
                        } else if (itemConfig && !item.folded) {
                            resolvedSize = itemConfig.expandedSize;
                        } else {
                            resolvedSize = def?.size || item.size || { x: 1, y: 1 };
                        }

                        return {
                            ...def,
                            ...item,
                            size: resolvedSize,
                            weight: def?.weight || item.weight || 0,
                            type: def?.type || item.type || 'generic',
                            image: (def?.image || item.image) ? `items/${def?.image || item.image}` : undefined
                        };
                    });

                    const newContainers: Record<string, any> = {};
                    Object.entries(data).forEach(([key, value]: [string, any]) => {
                        if (key === 'itemDefs' || key === 'equipment') return;
                        if (typeof value === 'object' && value !== null && value.items) {
                            const enriched = { ...value, items: enrichItems(value.items) };
                            newContainers[enriched.id] = enriched;
                        }
                    });

                    setContainers(newContainers);

                    if (equipData) {
                        const enrichedEquip: any = {};
                        Object.entries(equipData).forEach(([slot, item]: [string, any]) => {
                            if (item) {
                                const def = defs[item.name] || {};
                                const itemConfig = ITEM_CONFIGS[item.name];
                                enrichedEquip[slot] = {
                                    ...def,
                                    ...item,
                                    folded: false,
                                    size: itemConfig ? itemConfig.expandedSize : (def?.size || item.size || { x: 1, y: 1 }),
                                    image: (def?.image || item.image) ? `items/${def?.image || item.image}` : undefined
                                };
                            } else {
                                enrichedEquip[slot] = null;
                            }
                        });
                        setEquipment(enrichedEquip);
                    }
                }
            }

            if (action === 'open') {
                setOpen(true);
            }

            if (action === 'close') {
                setOpen(false);
                setGiveTarget(null);
                useInventoryStore.setState({ detailsWindows: [], openWindows: [], activeContextMenuItemId: null });
            } else if (action === 'updateWeaponAmmo') {
                const { weaponSlot, totalAmmo, clipAmmo } = data;
                useInventoryStore.getState().updateWeaponAmmo(weaponSlot, totalAmmo, clipAmmo);
            } else if (action === 'updateWeights') {
                const weights = data;
                Object.entries(weights).forEach(([id, weight]) => {
                    updateContainerWeight(id, weight as number);
                });
            } else if (action === 'receiveItemRequest') {
                useInventoryStore.getState().setReceiveRequest(data);
            } else if (action === 'giveRequestExpired') {
                useInventoryStore.getState().setReceiveRequest(null);
            }
        };

        window.addEventListener('message', handleMessage);
        return () => window.removeEventListener('message', handleMessage);
    }, [setOpen, setContainers, updateContainerWeight, setEquipment, addNotification, setGiveTarget]);
}
