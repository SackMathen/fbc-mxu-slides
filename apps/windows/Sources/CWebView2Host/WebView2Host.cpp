// The native window for MxU Slides on Windows: a plain Win32 window with a
// WebView2 control filling it. No WRL, no ATL: the two completion handlers
// WebView2 needs are small hand-written COM objects.

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0A00
#endif

#include <windows.h>
#include <dwmapi.h>
#include <objbase.h>
#include <atomic>
#include <functional>
#include <string>

#include "WebView2.h"
#include "CWebView2Host.h"

namespace {

template <typename Interface, typename Arg>
class CompletedHandler : public Interface {
public:
    explicit CompletedHandler(std::function<HRESULT(HRESULT, Arg *)> fn) : fn_(std::move(fn)) {}

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **ppv) override {
        if (ppv == nullptr) return E_POINTER;
        if (riid == __uuidof(Interface) || riid == IID_IUnknown) {
            *ppv = static_cast<Interface *>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }

    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs_; }

    ULONG STDMETHODCALLTYPE Release() override {
        ULONG remaining = --refs_;
        if (remaining == 0) delete this;
        return remaining;
    }

    HRESULT STDMETHODCALLTYPE Invoke(HRESULT result, Arg *arg) override { return fn_(result, arg); }

private:
    std::atomic<ULONG> refs_{1};
    std::function<HRESULT(HRESULT, Arg *)> fn_;
};

using EnvironmentHandler = CompletedHandler<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler, ICoreWebView2Environment>;
using ControllerHandler = CompletedHandler<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler, ICoreWebView2Controller>;

struct HostState {
    HWND window = nullptr;
    ICoreWebView2Controller *controller = nullptr;
    ICoreWebView2 *webview = nullptr;
    std::wstring url;
    int result = 0;
};

HostState *g_state = nullptr;
std::atomic<HWND> g_window{nullptr};

const wchar_t *const kWindowClass = L"MxUSlidesHostWindow";

void resizeWebView(HostState *state) {
    if (state == nullptr || state->controller == nullptr || state->window == nullptr) return;
    RECT bounds;
    GetClientRect(state->window, &bounds);
    state->controller->put_Bounds(bounds);
}

LRESULT CALLBACK windowProcedure(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_SIZE:
        resizeWebView(g_state);
        return 0;
    case WM_DPICHANGED: {
        const RECT *suggested = reinterpret_cast<const RECT *>(lParam);
        SetWindowPos(hwnd, nullptr, suggested->left, suggested->top, suggested->right - suggested->left,
                     suggested->bottom - suggested->top, SWP_NOZORDER | SWP_NOACTIVATE);
        return 0;
    }
    case WM_GETMINMAXINFO: {
        MINMAXINFO *info = reinterpret_cast<MINMAXINFO *>(lParam);
        info->ptMinTrackSize.x = 960;
        info->ptMinTrackSize.y = 600;
        return 0;
    }
    case WM_DESTROY:
        g_window = nullptr;
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcW(hwnd, message, wParam, lParam);
    }
}

void applyDarkTitleBar(HWND hwnd) {
    BOOL dark = TRUE;
    // DWMWA_USE_IMMERSIVE_DARK_MODE is 20 on Windows 10 2004 and later.
    DwmSetWindowAttribute(hwnd, 20, &dark, sizeof(dark));
}

HWND createWindow(const wchar_t *title, int width, int height) {
    HINSTANCE instance = GetModuleHandleW(nullptr);
    WNDCLASSEXW windowClass = {};
    windowClass.cbSize = sizeof(windowClass);
    windowClass.style = CS_HREDRAW | CS_VREDRAW;
    windowClass.lpfnWndProc = windowProcedure;
    windowClass.hInstance = instance;
    windowClass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    windowClass.hbrBackground = CreateSolidBrush(RGB(31, 31, 30));
    windowClass.lpszClassName = kWindowClass;
    windowClass.hIcon = LoadIconW(instance, L"AppIcon");
    RegisterClassExW(&windowClass);

    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    UINT dpi = GetDpiForSystem();
    int scaledWidth = MulDiv(width, dpi, 96);
    int scaledHeight = MulDiv(height, dpi, 96);
    if (scaledWidth > screenWidth - 40) scaledWidth = screenWidth - 40;
    if (scaledHeight > screenHeight - 80) scaledHeight = screenHeight - 80;
    int x = (screenWidth - scaledWidth) / 2;
    int y = (screenHeight - scaledHeight) / 2;

    HWND hwnd = CreateWindowExW(0, kWindowClass, title, WS_OVERLAPPEDWINDOW, x, y, scaledWidth, scaledHeight,
                                nullptr, nullptr, instance, nullptr);
    if (hwnd == nullptr) return nullptr;
    applyDarkTitleBar(hwnd);
    ShowWindow(hwnd, SW_SHOWNORMAL);
    UpdateWindow(hwnd);
    return hwnd;
}

HRESULT startWebView(HostState *state, const wchar_t *userDataFolder) {
    auto *environmentHandler = new EnvironmentHandler([state](HRESULT result, ICoreWebView2Environment *environment) -> HRESULT {
        if (FAILED(result) || environment == nullptr) {
            state->result = 3;
            PostMessageW(state->window, WM_CLOSE, 0, 0);
            return result;
        }
        auto *controllerHandler = new ControllerHandler([state](HRESULT controllerResult, ICoreWebView2Controller *controller) -> HRESULT {
            if (FAILED(controllerResult) || controller == nullptr) {
                state->result = 3;
                PostMessageW(state->window, WM_CLOSE, 0, 0);
                return controllerResult;
            }
            controller->AddRef();
            state->controller = controller;
            controller->get_CoreWebView2(&state->webview);
            if (state->webview != nullptr) {
                ICoreWebView2Settings *settings = nullptr;
                if (SUCCEEDED(state->webview->get_Settings(&settings)) && settings != nullptr) {
                    settings->put_IsStatusBarEnabled(FALSE);
                    settings->put_AreDefaultContextMenusEnabled(FALSE);
                    settings->put_IsZoomControlEnabled(FALSE);
                    settings->put_AreDevToolsEnabled(TRUE);
                    settings->Release();
                }
                COREWEBVIEW2_COLOR background = {255, 31, 31, 30};
                ICoreWebView2Controller2 *controller2 = nullptr;
                if (SUCCEEDED(controller->QueryInterface(__uuidof(ICoreWebView2Controller2), reinterpret_cast<void **>(&controller2))) && controller2 != nullptr) {
                    controller2->put_DefaultBackgroundColor(background);
                    controller2->Release();
                }
                resizeWebView(state);
                state->webview->Navigate(state->url.c_str());
            }
            return S_OK;
        });
        HRESULT created = environment->CreateCoreWebView2Controller(state->window, controllerHandler);
        controllerHandler->Release();
        return created;
    });
    HRESULT started = CreateCoreWebView2EnvironmentWithOptions(nullptr, userDataFolder, nullptr, environmentHandler);
    environmentHandler->Release();
    return started;
}

}  // namespace

extern "C" int mxu_webview_runtime_available(void) {
    LPWSTR version = nullptr;
    HRESULT result = GetAvailableCoreWebView2BrowserVersionString(nullptr, &version);
    if (SUCCEEDED(result) && version != nullptr) {
        CoTaskMemFree(version);
        return 1;
    }
    return 0;
}

extern "C" int mxu_webview_run(const wchar_t *url, const wchar_t *title, const wchar_t *userDataFolder, int width, int height) {
    if (!mxu_webview_runtime_available()) return 1;
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    HRESULT comResult = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    bool initializedCOM = SUCCEEDED(comResult);

    HostState state;
    state.url = url != nullptr ? url : L"about:blank";
    state.window = createWindow(title != nullptr ? title : L"MxU Slides", width > 0 ? width : 1480, height > 0 ? height : 920);
    if (state.window == nullptr) {
        if (initializedCOM) CoUninitialize();
        return 2;
    }
    g_state = &state;
    g_window = state.window;

    if (FAILED(startWebView(&state, userDataFolder))) {
        state.result = 3;
        DestroyWindow(state.window);
    }

    MSG message;
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }

    if (state.webview != nullptr) state.webview->Release();
    if (state.controller != nullptr) {
        state.controller->Close();
        state.controller->Release();
    }
    g_state = nullptr;
    g_window = nullptr;
    if (initializedCOM) CoUninitialize();
    return state.result;
}

extern "C" void mxu_webview_close(void) {
    HWND hwnd = g_window.load();
    if (hwnd != nullptr) PostMessageW(hwnd, WM_CLOSE, 0, 0);
}
