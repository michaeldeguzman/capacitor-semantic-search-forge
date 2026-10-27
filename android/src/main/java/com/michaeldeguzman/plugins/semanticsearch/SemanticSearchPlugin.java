package com.michaeldeguzman.plugins.semanticsearch;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "SemanticSearch")
public class SemanticSearchPlugin extends Plugin {

    private static final String UNAVAILABLE = "SemanticSearch is not yet available on Android";

    @PluginMethod
    public void isAvailable(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("available", false);
        ret.put("dimension", 0);
        ret.put("revision", 0);
        call.resolve(ret);
    }

    @PluginMethod
    public void upsertMany(PluginCall call) {
        call.reject(UNAVAILABLE);
    }

    @PluginMethod
    public void search(PluginCall call) {
        call.reject(UNAVAILABLE);
    }

    @PluginMethod
    public void remove(PluginCall call) {
        call.reject(UNAVAILABLE);
    }

    @PluginMethod
    public void clear(PluginCall call) {
        call.reject(UNAVAILABLE);
    }

    @PluginMethod
    public void getCollectionInfo(PluginCall call) {
        call.reject(UNAVAILABLE);
    }
}
