

/**
 * Formats a UNIX timestamp (seconds) to Server Time string (UTC).
 * Format: YYYY/MM/DD HH:mm:ss
 * @param timestamp UNIX timestamp in seconds
 */
export const formatServerTime = (timestamp: number): string => {
    if (!timestamp) return '---';
    // Ensure we are working with milliseconds for Date object
    const date = new Date(timestamp * 1000);
    // Convert to UTC Date object (technically same instant, but we want to format it as if it were UTC)
    // Actually, to display UTC time, we can use toLocaleString with timeZone: 'UTC'
    // or manually construct string.

    // Using simple manual construction for format YYYY/MM/DD HH:mm:ss to avoid dep issues if date-fns-tz is not installed
    // (though project likely has date-fns, let's check package.json if needed, but manual is safer and lighter)

    const year = date.getUTCFullYear();
    const month = String(date.getUTCMonth() + 1).padStart(2, '0');
    const day = String(date.getUTCDate()).padStart(2, '0');
    const hours = String(date.getUTCHours()).padStart(2, '0');
    const minutes = String(date.getUTCMinutes()).padStart(2, '0');
    const seconds = String(date.getUTCSeconds()).padStart(2, '0');

    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
};

/**
 * Formats a UNIX timestamp (seconds) to Server Time Time-only string (UTC).
 * Format: HH:mm:ss
 */
export const formatServerTimeOnly = (timestamp: number): string => {
    if (!timestamp) return '--:--:--';
    const date = new Date(timestamp * 1000);
    const hours = String(date.getUTCHours()).padStart(2, '0');
    const minutes = String(date.getUTCMinutes()).padStart(2, '0');
    const seconds = String(date.getUTCSeconds()).padStart(2, '0');

    return `${hours}:${minutes}:${seconds}`;
};
