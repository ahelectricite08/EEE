'use strict';

const assert = require('assert');
const {
  isReserveOrR2,
  isSedanMatch,
  hoursLeftLabel,
  frenchWeekday,
  parisDayKey,
  buildScoreDayGroups,
  pickScoreDayReminders,
  pickXiReminders,
  collectDueReminders,
  predictionHasScore,
  lineupIsComplete,
  userNeedsScoreReminder,
  userNeedsXiReminder,
  missingScoreCount,
  scoreReminderBodyForUser,
} = require('./lib/prono_lock_reminders');

assert.strictEqual(isReserveOrR2('fff_r2_1', 'Régional 1'), true);
assert.strictEqual(isReserveOrR2('fff_5579', 'Régional 1'), false);
assert.strictEqual(isSedanMatch('SEDAN ARDENNES CS', 'UCKANGE'), true);
assert.strictEqual(isSedanMatch('EPERNAY', 'HETTANGE'), false);
assert.strictEqual(hoursLeftLabel(50 * 60 * 1000), '1 h');
assert.strictEqual(hoursLeftLabel(3 * 60 * 60 * 1000), '3 h');

const sat15 = Date.parse('2026-10-10T13:00:00.000Z'); // 15h Paris (CEST)
assert.strictEqual(frenchWeekday(sat15), 'samedi');
assert.strictEqual(parisDayKey(sat15), '2026-10-10');

const sun13 = Date.parse('2026-10-11T11:00:00.000Z'); // 13h Paris
const groups = buildScoreDayGroups(
  [
    { id: 'a', date: new Date(sat15), competition: 'Régional 1', team1: 'A', team2: 'B' },
    { id: 'b', date: new Date(sat15 + 3 * 3600000), competition: 'Régional 1', team1: 'C', team2: 'D' },
    { id: 'c', date: new Date(sun13), competition: 'Régional 1', team1: 'E', team2: 'F' },
    { id: 'r2', date: new Date(sat15), competition: 'Régional 2', team1: 'X', team2: 'Y' },
  ],
  sat15 - 5 * 3600000,
);
assert.strictEqual(groups.length, 2);
assert.strictEqual(groups[0].weekday, 'samedi');
assert.strictEqual(groups[0].count, 2);
assert.deepStrictEqual(groups[0].matchIds, ['a', 'b']);
assert.strictEqual(groups[1].weekday, 'dimanche');

const now1h = sat15 - 60 * 60 * 1000;
const score1h = pickScoreDayReminders(groups, now1h);
assert.ok(score1h.some((r) => r.id === 'score-1h-2026-10-10'));
assert.ok(score1h[0].title.includes('samedi'));
assert.ok(score1h[0].body.includes('samedi'));
assert.ok(score1h[0].body.includes('1 h'));

const now3h = sat15 - 3 * 60 * 60 * 1000;
const score3h = pickScoreDayReminders(groups, now3h);
assert.ok(score3h.some((r) => r.id === 'score-3h-2026-10-10'));

const sedanKo = sat15;
const sedanRow = {
  id: 'fff_sedan',
  date: new Date(sedanKo),
  team1: 'SEDAN ARDENNES CS',
  team2: 'UCKANGE',
  competition: 'Régional 1',
};
const wed20 = Date.parse('2026-10-07T18:00:00.000Z'); // mercredi 20 h Paris
const xiWed = pickXiReminders([sedanRow], wed20);
assert.ok(xiWed.some((r) => r.id === 'xi-wed20-2026-10-07'));
assert.ok(xiWed[0].body.includes('composition'));
assert.ok(xiWed[0].body.includes('samedi'));
assert.ok(xiWed[0].body.includes('UCKANGE'));

assert.strictEqual(
  pickXiReminders([sedanRow], Date.parse('2026-10-07T16:00:00.000Z')).length,
  0,
  'pas de push XI mercredi 18 h',
);

const dupXi = pickXiReminders(
  [sedanRow, { ...sedanRow, id: 'manual_sedan' }],
  wed20,
);
assert.strictEqual(dupXi.filter((r) => r.kind === 'xi').length, 1);
assert.strictEqual(dupXi[0].matchId, 'fff_sedan');

const sunOnly = pickXiReminders(
  [{
    id: 'fff_sun',
    date: new Date(sun13),
    team1: 'SEDAN ARDENNES CS',
    team2: 'X',
    competition: 'Régional 1',
  }],
  wed20,
);
assert.ok(sunOnly[0].body.includes('dimanche'));

assert.strictEqual(
  pickXiReminders([sedanRow], Date.parse('2026-10-08T18:00:00.000Z')).length,
  0,
  'pas de push XI le jeudi',
);

const sunGroups = buildScoreDayGroups(
  [{ id: 'c', date: new Date(sun13), competition: 'Régional 1', team1: 'E', team2: 'F' }],
  sun13 - 3 * 3600000,
);
const scoreSun = pickScoreDayReminders(sunGroups, sun13 - 3 * 3600000);
assert.ok(scoreSun.some((r) => r.id === 'score-3h-2026-10-11'));
assert.ok(scoreSun[0].body.includes('dimanche'));

const tooEarly = pickScoreDayReminders(groups, sat15 - 8 * 3600000);
assert.strictEqual(tooEarly.length, 0, 'hors fenêtre 3 h / 1 h → rien');

const due = collectDueReminders([sedanRow], wed20);
assert.ok(due.some((r) => r.id === 'xi-wed20-2026-10-07'));

assert.strictEqual(predictionHasScore({ score1Pred: 2, score2Pred: 1 }), true);
assert.strictEqual(predictionHasScore({ score1Pred: 0, score2Pred: 0 }), true);
assert.strictEqual(predictionHasScore({ score1Pred: 1 }), false);
assert.strictEqual(lineupIsComplete({ playerNames: Array(11).fill('A') }), true);
assert.strictEqual(lineupIsComplete({ playerNames: ['A', 'B'] }), false);

const filled = new Map([
  ['a', new Set(['u1', 'u2'])],
  ['b', new Set(['u1'])],
]);
assert.strictEqual(userNeedsScoreReminder(['a', 'b'], 'u1', filled), false);
assert.strictEqual(userNeedsScoreReminder(['a', 'b'], 'u2', filled), true);
assert.strictEqual(missingScoreCount(['a', 'b'], 'u2', filled), 1);
assert.strictEqual(userNeedsScoreReminder(['a', 'b'], 'u3', filled), true);
assert.strictEqual(userNeedsXiReminder('u1', new Set(['u1'])), false);
assert.strictEqual(userNeedsXiReminder('u2', new Set(['u1'])), true);

const partialBody = scoreReminderBodyForUser(
  {
    body: 'Les pronos pour samedi ferment dans 1 h (1er KO 15h00).',
    weekday: 'samedi',
    when: '1 h',
    matchIds: ['a', 'b'],
  },
  1,
);
assert.ok(partialBody.includes('Encore 1 prono'));
assert.ok(partialBody.includes('1 h'));

console.log('test_prono_lock_reminders: OK');
