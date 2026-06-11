typedef ShellHomeHandler = void Function();

class ShellNavigationController {
  ShellHomeHandler? _goHomeHandler;

  void bindGoHome(ShellHomeHandler handler) {
    _goHomeHandler = handler;
  }

  void goHome() {
    _goHomeHandler?.call();
  }
}
