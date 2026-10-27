#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(SemanticSearchPlugin, "SemanticSearch",
  CAP_PLUGIN_METHOD(isAvailable, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(upsertMany, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(search, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(remove, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(clear, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(getCollectionInfo, CAPPluginReturnPromise);
)
