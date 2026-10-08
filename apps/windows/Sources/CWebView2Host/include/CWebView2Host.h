// A native window that hosts the app's user interface in WebView2 (the Edge
// engine that ships with Windows), plus borderless output windows on chosen
// displays. C so Swift can call it; see NativeWindow.swift.
#ifndef C_WEBVIEW2_HOST_H
#define C_WEBVIEW2_HOST_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Creates the main window and shows `url` in it, then runs the window's
/// message loop until the window closes. Call it on a thread you can block;
/// it initializes COM on that thread. Output windows live on the same thread.
///
/// Returns 0 when the window closed normally, otherwise a nonzero code:
/// 1 = the WebView2 runtime is not installed, 2 = the window could not be
/// created, 3 = the browser could not be created.
int mxu_webview_run(const wchar_t *url, const wchar_t *title, const wchar_t *userDataFolder, int width, int height);

/// Asks the window opened by mxu_webview_run to close (safe from any thread).
void mxu_webview_close(void);

/// 1 when a WebView2 runtime is available on this machine.
int mxu_webview_runtime_available(void);

/// 1 while the main window opened by mxu_webview_run exists (safe from any thread).
int mxu_webview_is_running(void);

/// The number of attached displays (safe from any thread).
int mxu_display_count(void);

/// Describes display `index` (0-based, in enumeration order). `name` receives
/// the monitor's friendly name, NUL-terminated, truncated to `nameCapacity`
/// characters. Position and size are physical pixels. Returns 1 on success.
int mxu_display_info(int index, wchar_t *name, int nameCapacity, int *x, int *y, int *width, int *height, int *primary);

/// Opens a borderless window filling display `displayIndex` that shows `url`
/// (safe from any thread; the window appears on the UI thread shortly after).
/// Returns the output's id, or -1 when the main window is not running.
int mxu_output_open(const wchar_t *url, int displayIndex);

/// Closes the output window with that id (safe from any thread).
void mxu_output_close(int outputId);

/// Lists the open outputs: fills up to `capacity` ids and their display
/// indexes, returns the number open (safe from any thread).
int mxu_output_list(int *ids, int *displayIndexes, int capacity);

#ifdef __cplusplus
}
#endif

#endif
