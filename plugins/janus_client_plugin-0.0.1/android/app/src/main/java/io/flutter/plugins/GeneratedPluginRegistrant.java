package io.flutter.plugins;

import io.flutter.plugin.common.PluginRegistry;
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin;
import org.janus.janus_client_plugin.JanusClientPlugin;

/**
 * Generated file. Do not edit.
 */
public final class GeneratedPluginRegistrant {
  public static void registerWith(PluginRegistry registry) {
    if (alreadyRegisteredWith(registry)) {
      return;
    }
    FlutterWebRTCPlugin.registerWith(registry.registrarFor("com.cloudwebrtc.webrtc.FlutterWebRTCPlugin"));
    JanusClientPlugin.registerWith(registry.registrarFor("org.janus.janus_client_plugin.JanusClientPlugin"));
  }

  private static boolean alreadyRegisteredWith(PluginRegistry registry) {
    final String key = GeneratedPluginRegistrant.class.getCanonicalName();
    if (registry.hasPlugin(key)) {
      return true;
    }
    registry.registrarFor(key);
    return false;
  }
}
