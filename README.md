# capacitor-semantic-search

On-device semantic search for Capacitor apps. Text is embedded and
searched on the phone with a bundled
[all-MiniLM-L6-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2)
Core ML model and a native vector index: no network, no API key, and no
data leaves the device.

Index short texts (FAQ entries, procedure steps, chunks of a document),
then search them by meaning: "backup power plant needs its monthly run"
finds "Generator load test" even though no key words match.

## Install

```bash
npm install capacitor-semantic-search
npx cap sync
```

Requires Capacitor 5 and iOS 14 or later.

| Platform | Support |
|---|---|
| iOS | Full |
| Android | Stub: `isAvailable` resolves `available: false`; other methods reject with "SemanticSearch is not yet available on Android" |
| Web | Every method rejects with "SemanticSearch is not available on web" |

## Example

```typescript
import { SemanticSearch } from 'capacitor-semantic-search';

// 1. Check the device can embed English text.
const { available } = await SemanticSearch.isAvailable({ lang: 'en' });
if (!available) {
  // Fall back to keyword search.
}

// 2. Index content once (for example after syncing it from your server).
const { count, skipped } = await SemanticSearch.upsertMany({
  collection: 'manual',
  lang: 'en',
  items: [
    {
      id: 'p18',
      text: 'Generator load test. Run the standby generator under load once a month for thirty minutes.',
      metadata: 'Generator load test',
    },
    {
      id: 'p19',
      text: 'Battery terminal cleaning. Disconnect the leads, scrub corrosion from the battery posts and apply terminal grease.',
      metadata: 'Battery terminal cleaning',
    },
  ],
});

// 3. Search, offline.
const { results } = await SemanticSearch.search({
  collection: 'manual',
  query: 'backup power plant needs its monthly run',
  topK: 5,
  minScore: 0.35,
});
// results: [{ id: 'p18', score: 0.50, metadata: 'Generator load test' }]

// 4. On app start, re-index if the bundled model has changed.
const info = await SemanticSearch.getCollectionInfo({ collection: 'manual' });
if (info.needsReindex) {
  // Call upsertMany again with the same items.
}
```

Notes:
- `id` is yours; upserting an existing id replaces its text and metadata.
- `metadata` is a free-text string returned with each result (for
  example a title or a JSON string).
- `skipped` lists ids whose text produced no vector (empty or
  whitespace-only text).
- Scores are cosine similarity. `minScore: 0.35` is a starting point;
  tune it with your own content.
- Collections are saved as JSON in the app's Application Support folder
  and survive restarts. 2,000 items take about 9.5 MB.

## Limits

- **iOS only.** Android and web are stubs (see the table above).
- **English only.** `isAvailable` and `upsertMany` accept `lang` values
  starting with `en`.
- **128 tokens per item.** Longer text is truncated (roughly 90 to 100
  words). Split long documents into chunks before indexing.
- **Adds about 22 MB to the app** (the bundled 8-bit model).
- **Small model.** Good for short text; weaker than large hosted
  embedding models on long or nuanced text. Right and wrong answers'
  scores can overlap, so no `minScore` filters perfectly.
- **Same model for content and queries.** Vectors from other embedding
  models can't be imported.

## API

<docgen-index>

* [`isAvailable(...)`](#isavailable)
* [`upsertMany(...)`](#upsertmany)
* [`search(...)`](#search)
* [`remove(...)`](#remove)
* [`clear(...)`](#clear)
* [`getCollectionInfo(...)`](#getcollectioninfo)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### isAvailable(...)

```typescript
isAvailable(options: { lang?: string; }) => Promise<{ available: boolean; dimension: number; revision: number; }>
```

| Param         | Type                            |
| ------------- | ------------------------------- |
| **`options`** | <code>{ lang?: string; }</code> |

**Returns:** <code>Promise&lt;{ available: boolean; dimension: number; revision: number; }&gt;</code>

--------------------


### upsertMany(...)

```typescript
upsertMany(options: { collection: string; lang?: string; items: { id: string; text: string; metadata?: string; }[]; }) => Promise<{ count: number; skipped: string[]; }>
```

| Param         | Type                                                                                                           |
| ------------- | -------------------------------------------------------------------------------------------------------------- |
| **`options`** | <code>{ collection: string; lang?: string; items: { id: string; text: string; metadata?: string; }[]; }</code> |

**Returns:** <code>Promise&lt;{ count: number; skipped: string[]; }&gt;</code>

--------------------


### search(...)

```typescript
search(options: { collection: string; query: string; topK?: number; minScore?: number; }) => Promise<{ results: { id: string; score: number; metadata: string; }[]; }>
```

| Param         | Type                                                                                  |
| ------------- | ------------------------------------------------------------------------------------- |
| **`options`** | <code>{ collection: string; query: string; topK?: number; minScore?: number; }</code> |

**Returns:** <code>Promise&lt;{ results: { id: string; score: number; metadata: string; }[]; }&gt;</code>

--------------------


### remove(...)

```typescript
remove(options: { collection: string; ids: string[]; }) => Promise<{ count: number; }>
```

| Param         | Type                                                |
| ------------- | --------------------------------------------------- |
| **`options`** | <code>{ collection: string; ids: string[]; }</code> |

**Returns:** <code>Promise&lt;{ count: number; }&gt;</code>

--------------------


### clear(...)

```typescript
clear(options: { collection: string; }) => Promise<void>
```

| Param         | Type                                 |
| ------------- | ------------------------------------ |
| **`options`** | <code>{ collection: string; }</code> |

--------------------


### getCollectionInfo(...)

```typescript
getCollectionInfo(options: { collection: string; }) => Promise<{ exists: boolean; count: number; lang: string; revision: number; currentRevision: number; needsReindex: boolean; }>
```

| Param         | Type                                 |
| ------------- | ------------------------------------ |
| **`options`** | <code>{ collection: string; }</code> |

**Returns:** <code>Promise&lt;{ exists: boolean; count: number; lang: string; revision: number; currentRevision: number; needsReindex: boolean; }&gt;</code>

--------------------

</docgen-api>

## Third-party notice

The bundled model (`ios/Plugin/Resources/MiniLM.mlmodelc`) and its
vocabulary (`ios/Plugin/Resources/vocab.txt`) are derived from
[all-MiniLM-L6-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2)
by sentence-transformers, licensed under the
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0). They
were converted to Core ML with mean pooling and normalisation added and
weights quantised to 8 bits. See
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) and
`ios/Plugin/Resources/MiniLM-LICENSE.txt` (also shipped inside apps).

The plugin's own code is MIT licensed.
