/// Configuration required by a reusable server module.
abstract interface class ServerConfig {
  /// Port on which the server listens.
  int get port;
}

/// Defaults a reusable package can offer without owning an app config model.
mixin DefaultServerConfig implements ServerConfig {
  @override
  int get port => 8080;
}
