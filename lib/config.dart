/// Determines if the UI should be rendered in color.
///
/// The default is set to `false` so the application runs in monochrome unless
/// explicitly overridden via the `NWCD_USE_COLOR` environment variable.
const bool useColor =
    bool.fromEnvironment('NWCD_USE_COLOR', defaultValue: false);

