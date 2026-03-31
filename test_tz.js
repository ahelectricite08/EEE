function _parseMatchDate(dateStr, timeStr) {
  const base = new Date(dateStr);
  if (timeStr) {
    const match = timeStr.match(/(\d+)H(\d+)/i);
    if (match) {
      const h = parseInt(match[1]);
      const m = parseInt(match[2]);
      const paris = new Date(base.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
      const utc   = new Date(base.toLocaleString('en-US', { timeZone: 'UTC' }));
      const offsetMs = paris - utc;
      base.setUTCHours(h, m, 0, 0);
      base.setTime(base.getTime() - offsetMs);
    }
  }
  return base;
}

const d = _parseMatchDate('2025-06-14', '20H00');
console.log('UTC:', d.toISOString());
console.log('Paris:', d.toLocaleString('fr-FR', { timeZone: 'Europe/Paris' }));
