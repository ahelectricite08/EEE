const fs = require('fs');
const path = require('path');

const src = 'C:\\Users\\axeld\\Music\\dvcr_appli\\lib\\screens\\home_screen_new.dart';
const dst = 'C:\\Users\\axeld\\Music\\dvcr_appli\\lib\\screens\\home_screen.dart';

try {
  const content = fs.readFileSync(src, 'utf8');
  fs.writeFileSync(dst, content, 'utf8');
  console.log('SUCCESS: File replaced successfully');
  process.exit(0);
} catch (err) {
  console.error('ERROR:', err.message);
  process.exit(1);
}
