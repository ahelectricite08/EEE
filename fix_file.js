const fs = require('fs');
const path = require('path');

const sourceFile = path.join(__dirname, 'lib/screens/home_screen_new.dart');
const destFile = path.join(__dirname, 'lib/screens/home_screen.dart');

try {
  // Read source file
  const content = fs.readFileSync(sourceFile, 'utf-8');
  
  // Write to destination file
  fs.writeFileSync(destFile, content, 'utf-8');
  
  // Count lines in destination file
  const lines = content.split('\n');
  const lineCount = lines.length - 1; // Don't count the final empty element
  
  console.log('Successfully replaced home_screen.dart');
  console.log(`Final line count: ${lineCount}`);
  
  if (lineCount === 1537) {
    console.log('✓ Line count is exactly 1537 as expected!');
  } else {
    console.log(`✗ Line count is ${lineCount}, expected 1537`);
  }
} catch (error) {
  console.error('Error:', error.message);
  process.exit(1);
}
