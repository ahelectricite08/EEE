async function main() {
  const BASE = 'https://api-dofa.fff.fr/api';
  const CP = 436257, PH = 1, GP = 1;
  const headers = { Accept: 'application/ld+json' };

  // Test pagination Hydra sur /matchs?journee=1
  console.log('=== PAGINATION matchs?journee=1 ===');
  const r = await fetch(`${BASE}/compets/${CP}/phases/${PH}/poules/${GP}/matchs?journee=1`, { headers });
  const d = await r.json();
  console.log('Total items:', d['hydra:totalItems']);
  console.log('Items this page:', d['hydra:member']?.length);
  console.log('hydra:view:', JSON.stringify(d['hydra:view'], null, 2));

  // Test avec itemsPerPage élevé
  console.log('\n=== matchs?journee=1&itemsPerPage=200 ===');
  const r2 = await fetch(`${BASE}/compets/${CP}/phases/${PH}/poules/${GP}/matchs?journee=1&itemsPerPage=200`, { headers });
  const d2 = await r2.json();
  console.log('Total items:', d2['hydra:totalItems']);
  console.log('Items this page:', d2['hydra:member']?.length);

  // CSSA dans la page 1
  const sedan = (d2['hydra:member'] ?? []).filter(m =>
    m.home?.club?.cl_no === 380 || m.away?.club?.cl_no === 380
  );
  console.log('Matchs SEDAN:', sedan.length);
  sedan.forEach(m => console.log(` - J${m.poule_journee?.number} | ${m.home?.short_name} vs ${m.away?.short_name} | ${m.home_score}-${m.away_score} | ${m.date}`));
}
main().catch(console.error);
