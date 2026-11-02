// Writes data.json (50 procedures + 10 queries) from the example app's test data.
// usage: node export_data.js
global.window = {};
require('../../example/www/js/data.js');
require('fs').writeFileSync(require('path').join(__dirname, 'data.json'), JSON.stringify({ items: window.PROCEDURES, queries: window.QUERIES }));
console.log('wrote data.json');
