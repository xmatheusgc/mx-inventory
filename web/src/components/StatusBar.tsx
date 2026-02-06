import React from 'react';

interface StatusBarProps {
    weight: number;
    maxWeight: number;
    health?: number;
    fatigue?: number;
    sick?: boolean;
}

export const StatusBar: React.FC<StatusBarProps> = ({ weight, health = 100, fatigue = 0, sick = false }) => {
    return (
        <div className="flex justify-between bg-black/60 rounded-sm p-1 mt-auto">
            <div className="flex flex-col items-center justify-center w-full border-r border-white/10 last:border-r-0 px-2 py-1">
                <span className="text-[10px] font-bold text-text-subtle uppercase tracking-widest">KG</span>
                <span className="text-sm font-bold text-white">{weight.toFixed(1)}</span>
            </div>

            <div className="flex flex-col items-center justify-center w-full border-r border-white/10 last:border-r-0 px-2 py-1">
                <span className="text-[10px] font-bold text-text-subtle uppercase tracking-widest">HEALTH</span>
                <span className="text-sm font-bold text-white">{health}%</span>
            </div>

            <div className="flex flex-col items-center justify-center w-full border-r border-white/10 last:border-r-0 px-2 py-1">
                <span className="text-[10px] font-bold text-text-subtle uppercase tracking-widest">FATIGUE</span>
                <span className="text-sm font-bold text-text-muted">{fatigue}%</span>
                {/* Mocked as gray/low for now */}
            </div>

            <div className="flex flex-col items-center justify-center w-full px-2 py-1">
                <span className="text-[10px] font-bold text-text-subtle uppercase tracking-widest">SICK</span>
                <span className={`text-sm font-bold ${sick ? 'text-error' : 'text-text-muted'}`}>
                    {sick ? 'YES' : 'NO'}
                </span>
            </div>
        </div>
    );
};
