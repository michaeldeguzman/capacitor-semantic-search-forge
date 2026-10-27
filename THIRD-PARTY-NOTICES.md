# Third-party notices

## all-MiniLM-L6-v2

The bundled embedding model (`ios/Plugin/Resources/MiniLM.mlmodelc`) and
its vocabulary (`ios/Plugin/Resources/vocab.txt`) are derived from
[all-MiniLM-L6-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2)
by sentence-transformers (revision `1110a243fdf4706b3f48f1d95db1a4f5529b4d41`),
fine-tuned from `nreimers/MiniLM-L6-H384-uncased`.

- Licence: Apache License, Version 2.0. Full text and the list of
  modifications: [`ios/Plugin/Resources/MiniLM-LICENSE.txt`](ios/Plugin/Resources/MiniLM-LICENSE.txt).
  The same file ships inside apps in the `SemanticSearchModel` resource
  bundle.
- Modifications: converted to Core ML (neuralnetwork format, iOS 14),
  mean pooling and L2 normalisation added to the graph, fixed 128-token
  input, 8-bit weights (converted with coremltools 9.0).

The plugin's own code is MIT licensed (see `package.json`).
