import React, { useState, useEffect, useRef, useCallback } from 'react';
import { fetchNui } from '../utils/nui';
import { type Item } from '../store/inventoryStore';
import { GIVE_ITEM_KEYS } from '../config/giveItem';

// ─── Types ────────────────────────────────────────────────────────────────────

interface NearbyPlayer {
    id: number;
    name: string;
    distance: number;
}

interface GiveTarget {
    item: Item;
    containerId: string;
}

interface ReceiveRequest {
    fromSrc: number;
    fromName: string;
    itemName: string;
    itemLabel: string;
    count: number;
    image?: string;
}

interface GiveItemModalProps {
    /** Sender mode: item to give */
    giveTarget: GiveTarget | null;
    onCloseSend: () => void;

    /** Receiver mode: incoming request */
    receiveRequest: ReceiveRequest | null;
    onCloseReceive: () => void;
}

// ─── Component ────────────────────────────────────────────────────────────────

export const GiveItemModal: React.FC<GiveItemModalProps> = ({
    giveTarget,
    onCloseSend,
    receiveRequest,
    onCloseReceive,
}) => {
    // ── Sender state ──────────────────────────────────────────────────────────
    const [nearbyPlayers, setNearbyPlayers] = useState<NearbyPlayer[]>([]);
    const [selectedPlayerId, setSelectedPlayerId] = useState<number | null>(null);
    const [quantity, setQuantity] = useState<number>(1);
    const [isSending, setIsSending] = useState(false);
    const [feedback, setFeedback] = useState<string | null>(null);
    const inputRef = useRef<HTMLInputElement>(null);

    // Request nearby players when sender modal opens
    useEffect(() => {
        if (!giveTarget) return;
        setQuantity(1);
        setSelectedPlayerId(null);
        setFeedback(null);
        setIsSending(false);
        fetchNui('requestNearbyPlayers', {});
    }, [giveTarget]);

    // Listen for nearbyPlayers + giveItemResult messages from NUI bridge
    useEffect(() => {
        const handler = (e: MessageEvent) => {
            const { action, data } = e.data;
            if (action === 'nearbyPlayers') {
                setNearbyPlayers(data || []);
            }
            if (action === 'giveItemResult') {
                setIsSending(false);
                if (data?.pending) {
                    setFeedback('⏳ Aguardando resposta do jogador…');
                    return;
                }
                if (data?.transferred) {
                    setFeedback('✅ ' + (data.message || 'Enviado!'));
                    setTimeout(onCloseSend, 1500);
                } else {
                    setFeedback('❌ ' + (data?.reason || 'Falha.'));
                }
            }
        };
        window.addEventListener('message', handler);
        return () => window.removeEventListener('message', handler);
    }, [onCloseSend]);

    // ── Receiver respond ──────────────────────────────────────────────────────
    // Defined BEFORE the keydown useEffect so it's stable in the closure
    const handleRespond = useCallback((accepted: boolean) => {
        fetchNui('respondGiveItem', { accepted });
        onCloseReceive();
    }, [onCloseReceive]);

    // Keyboard shortcut: Y = accept, N = decline (configurable via config/giveItem.ts)
    useEffect(() => {
        if (!receiveRequest) return;

        const handleKey = (e: KeyboardEvent) => {
            const key = e.key.toLowerCase();
            if (key === GIVE_ITEM_KEYS.accept) {
                e.preventDefault();
                handleRespond(true);
            } else if (key === GIVE_ITEM_KEYS.decline) {
                e.preventDefault();
                handleRespond(false);
            }
        };

        window.addEventListener('keydown', handleKey);
        return () => window.removeEventListener('keydown', handleKey);
    }, [receiveRequest, handleRespond]);

    // Auto-focus quantity input
    useEffect(() => {
        if (giveTarget && inputRef.current) {
            setTimeout(() => inputRef.current?.focus(), 50);
        }
    }, [giveTarget]);

    // ── Sender submit ─────────────────────────────────────────────────────────
    const handleSend = () => {
        if (!giveTarget || selectedPlayerId === null || quantity < 1) return;
        setIsSending(true);
        setFeedback(null);
        fetchNui('giveItem', {
            itemId: giveTarget.item.id,
            itemName: giveTarget.item.name,
            containerId: giveTarget.containerId,
            count: quantity,
            targetSrc: selectedPlayerId,
        });
    };

    // ── Render: Receiver modal ────────────────────────────────────────────────
    if (receiveRequest) {
        const imgSrc = receiveRequest.image ? `items/${receiveRequest.image}` : null;
        return (
            <div className="fixed inset-0 z-[200] flex items-center justify-center">
                <div
                    className="bg-zinc-900 border border-zinc-700 rounded-lg shadow-2xl w-80 p-5 flex flex-col gap-4"
                    style={{ boxShadow: '0 0 32px rgba(0,0,0,0.7)' }}
                >
                    {/* Header */}
                    <div className="text-center">
                        <p className="text-zinc-400 text-xs uppercase tracking-widest mb-1">Oferta de Item</p>
                        <p className="text-white font-semibold text-sm">
                            <span className="text-orange-400">{receiveRequest.fromName}</span> quer te dar:
                        </p>
                    </div>

                    {/* Item preview */}
                    <div className="flex items-center gap-3 bg-zinc-800 rounded-md p-3">
                        {imgSrc && (
                            <img
                                src={imgSrc}
                                alt={receiveRequest.itemLabel}
                                className="w-12 h-12 object-contain"
                                onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                            />
                        )}
                        <div>
                            <p className="text-white font-bold text-sm">{receiveRequest.itemLabel}</p>
                            <p className="text-zinc-400 text-xs">Quantidade: {receiveRequest.count}</p>
                        </div>
                    </div>

                    {/* Buttons */}
                    <div className="flex gap-3">
                        <button
                            onClick={() => handleRespond(false)}
                            className="flex-1 py-2 text-sm rounded-md bg-zinc-700 hover:bg-zinc-600 text-white font-semibold transition-colors flex items-center justify-center gap-2"
                        >
                            <kbd className="text-[10px] bg-zinc-600 px-1.5 py-0.5 rounded font-mono uppercase">{GIVE_ITEM_KEYS.decline}</kbd>
                            Recusar
                        </button>
                        <button
                            onClick={() => handleRespond(true)}
                            className="flex-1 py-2 text-sm rounded-md bg-orange-600 hover:bg-orange-500 text-white font-bold transition-colors flex items-center justify-center gap-2"
                        >
                            <kbd className="text-[10px] bg-orange-500 px-1.5 py-0.5 rounded font-mono uppercase">{GIVE_ITEM_KEYS.accept}</kbd>
                            Aceitar
                        </button>
                    </div>
                </div>
            </div>
        );
    }

    // ── Render: Sender modal ──────────────────────────────────────────────────
    if (!giveTarget) return null;

    const maxQty = giveTarget.item.count;

    return (
        <div className="fixed inset-0 z-[200] flex items-center justify-center">
            <div
                className="bg-zinc-900 border border-zinc-700 rounded-lg shadow-2xl w-80 p-5 flex flex-col gap-4"
                style={{ boxShadow: '0 0 32px rgba(0,0,0,0.7)' }}
            >
                {/* Header */}
                <div className="flex items-center justify-between">
                    <p className="text-zinc-400 text-xs uppercase tracking-widest">Dar Item</p>
                    <button
                        onClick={onCloseSend}
                        className="text-zinc-500 hover:text-white text-lg leading-none transition-colors"
                        aria-label="Fechar"
                    >
                        ×
                    </button>
                </div>

                {/* Item info */}
                <div className="flex items-center gap-3 bg-zinc-800 rounded-md p-3">
                    {giveTarget.item.image && (
                        <img
                            src={giveTarget.item.image}
                            alt={giveTarget.item.label ?? giveTarget.item.name}
                            className="w-10 h-10 object-contain"
                            onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                        />
                    )}
                    <div>
                        <p className="text-white font-bold text-sm">{giveTarget.item.label ?? giveTarget.item.name}</p>
                        <p className="text-zinc-400 text-xs">Disponível: {maxQty}</p>
                    </div>
                </div>

                {/* Quantity */}
                <div className="flex flex-col gap-1">
                    <label className="text-zinc-400 text-xs uppercase tracking-wider">Quantidade</label>
                    <div className="relative">
                        <input
                            ref={inputRef}
                            type="number"
                            min={1}
                            max={maxQty}
                            value={quantity}
                            onChange={(e) => setQuantity(Math.max(1, Math.min(maxQty, parseInt(e.target.value) || 1)))}
                            className="w-full bg-zinc-800 text-white border border-zinc-600 rounded px-3 py-1.5 text-sm outline-none focus:border-orange-500 transition-colors text-center"
                        />
                        <span className="absolute right-3 top-1.5 text-xs text-zinc-500">/ {maxQty}</span>
                    </div>
                </div>

                {/* Player selector */}
                <div className="flex flex-col gap-1">
                    <label className="text-zinc-400 text-xs uppercase tracking-wider">Jogador próximo</label>
                    {nearbyPlayers.length === 0 ? (
                        <p className="text-zinc-500 text-xs italic">Nenhum jogador próximo (10m).</p>
                    ) : (
                        <div className="flex flex-col gap-1 max-h-36 overflow-y-auto pr-1">
                            {nearbyPlayers.map((p) => (
                                <button
                                    key={p.id}
                                    onClick={() => setSelectedPlayerId(p.id)}
                                    className={`flex items-center justify-between px-3 py-2 rounded-md text-sm transition-colors ${selectedPlayerId === p.id
                                        ? 'bg-orange-600 text-white'
                                        : 'bg-zinc-800 text-zinc-300 hover:bg-zinc-700'
                                        }`}
                                >
                                    <span className="font-medium truncate">{p.name}</span>
                                    <span className="text-xs text-zinc-400 ml-2 shrink-0">{p.distance}m</span>
                                </button>
                            ))}
                        </div>
                    )}
                </div>

                {/* Feedback */}
                {feedback && (
                    <p className="text-xs text-center text-zinc-400">{feedback}</p>
                )}

                {/* Action buttons */}
                <div className="flex gap-3">
                    <button
                        onClick={onCloseSend}
                        className="flex-1 py-2 text-sm rounded-md bg-zinc-700 hover:bg-zinc-600 text-white font-semibold transition-colors"
                    >
                        Cancelar
                    </button>
                    <button
                        onClick={handleSend}
                        disabled={selectedPlayerId === null || isSending}
                        className="flex-1 py-2 text-sm rounded-md bg-orange-600 hover:bg-orange-500 disabled:opacity-40 text-white font-bold transition-colors"
                    >
                        {isSending ? '…' : 'Enviar'}
                    </button>
                </div>
            </div>
        </div>
    );
};
