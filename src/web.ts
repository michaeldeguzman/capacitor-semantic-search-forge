import { WebPlugin } from '@capacitor/core';

import type { SemanticSearchPlugin } from './definitions';

const UNAVAILABLE = 'SemanticSearch is not available on web';

export class SemanticSearchWeb extends WebPlugin implements SemanticSearchPlugin {
  async isAvailable(): Promise<{ available: boolean; dimension: number; revision: number }> {
    throw this.unavailable(UNAVAILABLE);
  }

  async upsertMany(): Promise<{ count: number; skipped: string[] }> {
    throw this.unavailable(UNAVAILABLE);
  }

  async search(): Promise<{ results: { id: string; score: number; metadata: string }[] }> {
    throw this.unavailable(UNAVAILABLE);
  }

  async remove(): Promise<{ count: number }> {
    throw this.unavailable(UNAVAILABLE);
  }

  async clear(): Promise<void> {
    throw this.unavailable(UNAVAILABLE);
  }

  async getCollectionInfo(): Promise<{
    exists: boolean;
    count: number;
    lang: string;
    revision: number;
    currentRevision: number;
    needsReindex: boolean;
  }> {
    throw this.unavailable(UNAVAILABLE);
  }
}
