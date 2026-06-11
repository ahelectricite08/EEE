const fs = require('fs');
const path = require('path');

const p = path.join(__dirname, '..', 'index.js');
let s = fs.readFileSync(p, 'utf8');

const channels = [
  'dvcr_alerts',
  'dvcr_live',
  'dvcr_live_events',
  'dvcr_notifications',
  'dvcr_articles',
];

function replacePair(androidLine, channelId, opts = '') {
  const esc = channelId.replace(/'/g, "\\'");
  const pattern = new RegExp(
    `${androidLine.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*apns:\\s*\\{\\s*payload:\\s*\\{\\s*aps:\\s*\\{\\s*sound:\\s*'default'\\s*\\}\\s*\\}\\s*\\},`,
    'g',
  );
  s = s.replace(pattern, `...fcmChannelBlocks('${esc}'${opts}),`);
}

for (const ch of channels) {
  replacePair(
    `android: { priority: 'high', notification: { sound: 'default', channelId: '${ch}' } },`,
    ch,
  );
  replacePair(
    `android: { priority: 'normal', notification: { sound: 'default', channelId: '${ch}' } },`,
    ch,
    ", { priority: 'normal' }",
  );
  replacePair(
    `          android: { priority: 'high', notification: { sound: 'default', channelId: '${ch}' } },`,
    ch,
  );
  replacePair(
    `        android: { priority: 'high', notification: { sound: 'default', channelId: '${ch}' } },`,
    ch,
  );
  replacePair(
    `      android: { priority: 'high', notification: { sound: 'default', channelId: '${ch}' } },`,
    ch,
  );
}

// Multiline blocks
for (const ch of channels) {
  const old = `    android: {
      priority: 'high',
      notification: { sound: 'default', channelId: '${ch}' },
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },`;
  s = s.split(old).join(`    ...fcmChannelBlocks('${ch}'),`);
}

s = s.replace(
  /let channelId = 'dvcr_alerts';\s*\n\s*if \(topic === 'dvcr_live'\) channelId = 'dvcr_live';\s*\n\s*else if \(topic === 'dvcr_articles'\) channelId = 'dvcr_articles';/,
  "const channelId = channelFromTopic(topic);",
);

s = s.replace(
  /    android: \{\s*\n\s*priority: 'high',\s*\n\s*notification: \{ sound: 'default', channelId \},\s*\n\s*\},\s*\n\s*apns: \{\s*\n\s*payload: \{ aps: \{ sound: 'default' \} \},\s*\n\s*\},/,
  '    ...fcmChannelBlocks(channelId),',
);

fs.writeFileSync(p, s);
const left = (s.match(/payload: \{ aps: \{ sound: 'default' \} \}/g) || []).length;
console.log('remaining:', left);
