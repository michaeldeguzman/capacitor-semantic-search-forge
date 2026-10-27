import { registerPlugin } from '@capacitor/core';

import type { SemanticSearchPlugin } from './definitions';

const SemanticSearch = registerPlugin<SemanticSearchPlugin>('SemanticSearch', {
  web: () => import('./web').then(m => new m.SemanticSearchWeb()),
});

export * from './definitions';
export { SemanticSearch };
