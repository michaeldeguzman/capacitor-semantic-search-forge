export interface SemanticSearchPlugin {
  isAvailable(options: { lang?: string }): Promise<{
    available: boolean;
    dimension: number;
    revision: number;
  }>;
  upsertMany(options: {
    collection: string;
    lang?: string;
    items: { id: string; text: string; metadata?: string }[];
  }): Promise<{ count: number; skipped: string[] }>;
  search(options: {
    collection: string;
    query: string;
    topK?: number;
    minScore?: number;
  }): Promise<{ results: { id: string; score: number; metadata: string }[] }>;
  remove(options: { collection: string; ids: string[] }): Promise<{ count: number }>;
  clear(options: { collection: string }): Promise<void>;
  getCollectionInfo(options: { collection: string }): Promise<{
    exists: boolean;
    count: number;
    lang: string;
    revision: number;
    currentRevision: number;
    needsReindex: boolean;
  }>;
}
