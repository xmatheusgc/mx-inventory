import React, { useEffect, useState } from 'react';
import { useInventoryStore } from '../store/inventoryStore';
import { AlertCircle, CheckCircle2, Info, X } from 'lucide-react';

export const InventoryNotification: React.FC = () => {
    const notifications = useInventoryStore(state => state.notifications);
    const removeNotification = useInventoryStore(state => state.removeNotification);

    return (
        <div className="fixed bottom-10 left-1/2 -translate-x-1/2 z-[9999] flex flex-col gap-2 pointer-events-none">
            {notifications.map((n) => (
                <NotificationItem
                    key={n.id}
                    notification={n}
                    onRemove={() => removeNotification(n.id)}
                />
            ))}
        </div>
    );
};

const NotificationItem: React.FC<{
    notification: { id: string; message: string; type: 'error' | 'success' | 'info' };
    onRemove: () => void
}> = ({ notification, onRemove }) => {
    const [visible, setVisible] = useState(false);

    useEffect(() => {
        // Animation entrance
        const timer = setTimeout(() => setVisible(true), 10);
        return () => clearTimeout(timer);
    }, []);

    const typeConfig = {
        error: {
            icon: <AlertCircle className="w-5 h-5 text-red-400" />,
            bg: 'bg-red-500/10',
            border: 'border-red-500/50',
            text: 'text-red-200'
        },
        success: {
            icon: <CheckCircle2 className="w-5 h-5 text-green-400" />,
            bg: 'bg-green-500/10',
            border: 'border-green-500/50',
            text: 'text-green-200'
        },
        info: {
            icon: <Info className="w-5 h-5 text-blue-400" />,
            bg: 'bg-blue-500/10',
            border: 'border-blue-500/50',
            text: 'text-blue-200'
        }
    };

    const config = typeConfig[notification.type];

    return (
        <div
            className={`
                flex items-center gap-3 px-4 py-3 rounded-lg border shadow-lg backdrop-blur-md pointer-events-auto
                transition-all duration-300 ease-out min-w-[300px]
                ${visible ? 'opacity-100 translate-y-0 scale-100' : 'opacity-0 translate-y-4 scale-95'}
                ${config.bg} ${config.border} ${config.text}
            `}
        >
            <div className="shrink-0">{config.icon}</div>
            <div className="flex-1 font-medium text-sm pr-2">
                {notification.message}
            </div>
            <button
                onClick={onRemove}
                className="shrink-0 hover:bg-white/10 rounded-full p-1 transition-colors"
            >
                <X className="w-4 h-4 opacity-60" />
            </button>
        </div>
    );
};
