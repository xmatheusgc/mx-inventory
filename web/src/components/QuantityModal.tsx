import React, { useState, useEffect, useRef } from 'react';

interface QuantityModalProps {
    isOpen: boolean;
    onClose: () => void;
    onConfirm: (quantity: number) => void;
    maxQuantity: number;
    title?: string;
}

export const QuantityModal: React.FC<QuantityModalProps> = ({ isOpen, onClose, onConfirm, maxQuantity, title = 'Quantidade' }) => {
    const [value, setValue] = useState<string>('1');
    const inputRef = useRef<HTMLInputElement>(null);

    useEffect(() => {
        if (isOpen) {
            setValue('1');
            // Focus input on open
            setTimeout(() => {
                inputRef.current?.focus();
                inputRef.current?.select();
            }, 50);
        }
    }, [isOpen]);

    if (!isOpen) return null;

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        const num = parseInt(value);
        if (num > 0 && num <= maxQuantity) {
            onConfirm(num);
            onClose();
        }
    };

    return (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 backdrop-blur-sm">
            <div className="bg-surface-dark border border-border-dark p-4 rounded-md shadow-2xl w-64">
                <h3 className="text-zinc-200 text-sm font-bold mb-4 uppercase tracking-wider">{title}</h3>
                <form onSubmit={handleSubmit} className="flex flex-col gap-4">
                    <div className="relative">
                        <input
                            ref={inputRef}
                            type="number"
                            min="1"
                            max={maxQuantity}
                            value={value}
                            onChange={(e) => setValue(e.target.value)}
                            className="w-full bg-surface-light text-white border border-border-light rounded px-2 py-1 text-center outline-none focus:border-primary"
                        />
                        <span className="absolute right-2 top-1.5 text-xs text-text-muted">/ {maxQuantity}</span>
                    </div>

                    <div className="flex gap-2 justify-end">
                        <button
                            type="button"
                            onClick={onClose}
                            className="px-3 py-1 text-xs text-text-subtle hover:text-white transition-colors"
                        >
                            Cancelar
                        </button>
                        <button
                            type="submit"
                            className="px-3 py-1 text-xs bg-orange-600 hover:bg-primary text-white rounded font-bold transition-colors"
                        >
                            Confirmar
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
};
