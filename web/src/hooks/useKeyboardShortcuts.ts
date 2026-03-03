import { useEffect } from 'react';
import { useInventoryStore } from '../store/inventoryStore';
import { fetchNui } from '../utils/nui';

export function useKeyboardShortcuts({
    isOpen,
    activeId,
    activeContainerId,
    activeDragData,
    containers,
    equipment,
    setActiveDragRotation,
    setActiveDragFolded
}: {
    isOpen: boolean;
    activeId: string | null;
    activeContainerId: string | null;
    activeDragData: any | null;
    containers: Record<string, any>;
    equipment: Record<string, any>;
    setActiveDragRotation: React.Dispatch<React.SetStateAction<boolean>>;
    setActiveDragFolded: React.Dispatch<React.SetStateAction<boolean>>;
}) {
    const { setOpen, setShortcut, addNotification, setHoveredItem } = useInventoryStore();

    useEffect(() => {
        const handleKeyDown = (e: KeyboardEvent) => {
            // Allow inputs
            if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
                return;
            }

            if (['5', '6', '7', '8'].includes(e.key)) {
                setShortcut(e.key);
            }

            if (e.key === 'Escape') {
                fetchNui('close');
                setOpen(false);
            }

            if (e.key.toLowerCase() === 'x') {
                const hovered = useInventoryStore.getState().hoveredItem;
                if (hovered && hovered.item && !activeId) {
                    fetchNui('dropItem', {
                        itemId: hovered.item.id,
                        item: hovered.item.name,
                        name: hovered.item.name,
                        amount: hovered.item.count,
                        containerId: hovered.containerId,
                        slot: hovered.item.slot
                    });
                    setHoveredItem(null);
                }
            }

            if (e.key.toLowerCase() === 'f') {
                if (activeId) {
                    const itemToFold = activeDragData;
                    if (itemToFold && (itemToFold.type === 'backpack' || itemToFold.type === 'vest' || itemToFold.type === 'bag')) {
                        const targetContainer = useInventoryStore.getState().containers[activeId];
                        if (targetContainer && targetContainer.items && targetContainer.items.length > 0) {
                            addNotification('Não é possível dobrar um container com itens dentro.', 'error');
                            return;
                        }
                    }
                    setActiveDragFolded(prev => !prev);
                } else {
                    const hovered = useInventoryStore.getState().hoveredItem;
                    if (hovered && hovered.item) {
                        const isEquipped = hovered.item.isEquipment || hovered.containerId.startsWith('equip-');

                        if (isEquipped) {
                            fetchNui('unequipItem', {
                                item: hovered.item.name,
                                id: hovered.item.id,
                                fromSlot: hovered.containerId.replace('equip-', ''),
                                to: 'player-inv',
                                slot: {}
                            });
                        } else {
                            let targetSlot = '';
                            const type = hovered.item.type;
                            if (type === 'helmet') targetSlot = 'head';
                            else if (type === 'mask') targetSlot = 'face';
                            else if (type === 'armor') targetSlot = 'armor';
                            else if (type === 'earpiece') targetSlot = 'earpiece';
                            else if (type === 'vest') targetSlot = 'vest';
                            else if (type === 'backpack') targetSlot = 'backpack';
                            else if (type === 'weapon_pistol') targetSlot = 'pistol';
                            else if (type === 'weapon_melee') targetSlot = 'melee';
                            else if (type?.startsWith('weapon_')) {
                                const eq = useInventoryStore.getState().equipment;
                                if (!eq.primary) targetSlot = 'primary';
                                else if (!eq.secondary) targetSlot = 'secondary';
                                else targetSlot = 'primary';
                            }

                            if (targetSlot) {
                                fetchNui('equipItem', {
                                    item: hovered.item.name,
                                    id: hovered.item.id,
                                    from: hovered.containerId,
                                    slot: targetSlot
                                });
                            }
                        }
                        setHoveredItem(null);
                    }
                }
            }

            if (!activeId) return;

            if (e.key.toLowerCase() === 'r') {
                setActiveDragRotation(prev => !prev);
            }
        };

        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [isOpen, activeId, activeContainerId, activeDragData, containers, equipment, setActiveDragRotation, setActiveDragFolded, setOpen, setShortcut, addNotification, setHoveredItem]);
}
