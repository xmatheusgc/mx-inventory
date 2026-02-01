export async function fetchNui<T = unknown>(
    eventName: string,
    data?: unknown,
    mockData?: T
): Promise<T> {
    const options = {
        method: 'post',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data),
    };

    if (typeof window !== 'undefined' && (window as any).invokeNative) {
        const resourceName = (window as any).GetParentResourceName
            ? (window as any).GetParentResourceName()
            : 'mx-inv';

        const resp = await fetch(`https://${resourceName}/${eventName}`, options);

        const respFormatted = await resp.json();

        return respFormatted;
    } else {
        // Development fallback
        if (mockData) return mockData;
        return {} as T;
    }
}

export const isEnvBrowser = (): boolean => !(window as any).invokeNative;

// Debug function to trigger events in browser
export const debugData = (events: { action: string; data: any }[], timer = 1000) => {
    if (import.meta.env.MODE === 'development' && isEnvBrowser()) {
        for (const event of events) {
            setTimeout(() => {
                window.dispatchEvent(
                    new MessageEvent('message', {
                        data: {
                            action: event.action,
                            data: event.data,
                        },
                    })
                );
            }, timer);
        }
    }
};
