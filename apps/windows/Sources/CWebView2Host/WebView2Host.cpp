// The native windows for MxU Slides on Windows: a plain Win32 main window with
// a WebView2 control filling it, and borderless output windows (one per
// display) that show the output page. No WRL, no ATL: the completion
// handlers WebView2 needs are small hand-written COM objects.
//
// Every window lives on the thread that called mxu_webview_run; the other
// entry points post requests to it.

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
#include <algorithm>
#include <atomic>
#include <functional>
#include <map>
#include <mutex>
#include <string>
#include <vector>

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

// ---------- Displays ----------

struct DisplayInfo {
    std::wstring device;   // "\\.\DISPLAY1"
    std::wstring name;     // the monitor's friendly name, or the device name
    RECT rect = {};
    bool primary = false;
};

BOOL CALLBACK collectMonitor(HMONITOR monitor, HDC, LPRECT, LPARAM param) {
    auto *list = reinterpret_cast<std::vector<DisplayInfo> *>(param);
    MONITORINFOEXW info = {};
    info.cbSize = sizeof(info);
    if (GetMonitorInfoW(monitor, &info)) {
        DisplayInfo display;
        display.device = info.szDevice;
        display.name = info.szDevice;
        display.rect = info.rcMonitor;
        display.primary = (info.dwFlags & MONITORINFOF_PRIMARY) != 0;
        list->push_back(display);
    }
    return TRUE;
}

// Friendly monitor names ("DELL U2720Q") keyed by GDI device name, from the
// display configuration API.
std::map<std::wstring, std::wstring> friendlyNames() {
    std::map<std::wstring, std::wstring> names;
    UINT32 pathCount = 0, modeCount = 0;
    if (GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, &pathCount, &modeCount) != ERROR_SUCCESS) return names;
    std::vector<DISPLAYCONFIG_PATH_INFO> paths(pathCount);
    std::vector<DISPLAYCONFIG_MODE_INFO> modes(modeCount);
    if (QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, &pathCount, paths.data(), &modeCount, modes.data(), nullptr) != ERROR_SUCCESS) return names;
    for (UINT32 i = 0; i < pathCount; i++) {
        DISPLAYCONFIG_SOURCE_DEVICE_NAME source = {};
        source.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
        source.header.size = sizeof(source);
        source.header.adapterId = paths[i].sourceInfo.adapterId;
        source.header.id = paths[i].sourceInfo.id;
        if (DisplayConfigGetDeviceInfo(&source.header) != ERROR_SUCCESS) continue;
        DISPLAYCONFIG_TARGET_DEVICE_NAME target = {};
        target.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
        target.header.size = sizeof(target);
        target.header.adapterId = paths[i].targetInfo.adapterId;
        target.header.id = paths[i].targetInfo.id;
        if (DisplayConfigGetDeviceInfo(&target.header) != ERROR_SUCCESS) continue;
        if (target.monitorFriendlyDeviceName[0] != L'\0') {
            names[source.viewGdiDeviceName] = target.monitorFriendlyDeviceName;
        }
    }
    return names;
}

std::vector<DisplayInfo> displays() {
    std::vector<DisplayInfo> list;
    EnumDisplayMonitors(nullptr, nullptr, collectMonitor, reinterpret_cast<LPARAM>(&list));
    auto names = friendlyNames();
    int generic = 0;
    for (auto &display : list) {
        auto found = names.find(display.device);
        if (found != names.end()) {
            display.name = found->second;
        } else {
            generic++;
            display.name = display.primary ? L"Built-in Display" : L"Display " + std::to_wstring(generic);
        }
    }
    // The primary display first, then left to right.
    std::stable_sort(list.begin(), list.end(), [](const DisplayInfo &a, const DisplayInfo &b) {
        if (a.primary != b.primary) return a.primary;
        return a.rect.left < b.rect.left;
    });
    return list;
}

// ---------- Windows ----------

struct OutputWindow {
    int id = 0;
    int display = 0;
    HWND hwnd = nullptr;
    ICoreWebView2Controller *controller = nullptr;
    ICoreWebView2 *webview = nullptr;
};

struct OpenRequest {
    int id;
    int display;
    std::wstring url;
};

struct HostState {
    HWND window = nullptr;
    ICoreWebView2Environment *environment = nullptr;
    ICoreWebView2Controller *controller = nullptr;
    ICoreWebView2 *webview = nullptr;
    std::wstring url;
    int result = 0;
    std::vector<OutputWindow> outputs;
    std::vector<OpenRequest> waitingForEnvironment;
};

HostState *g_state = nullptr;
std::atomic<HWND> g_window{nullptr};
std::atomic<int> g_nextOutputId{1};
std::mutex g_outputsMutex;
std::vector<std::pair<int, int>> g_openOutputs;  // (id, display), for other threads

const wchar_t *const kWindowClass = L"MxUSlidesHostWindow";
const wchar_t *const kOutputClass = L"MxUSlidesOutputWindow";
const UINT WM_APP_OPEN_OUTPUT = WM_APP + 1;   // lParam: OpenRequest*
const UINT WM_APP_CLOSE_OUTPUT = WM_APP + 2;  // wParam: output id

void publishOutputs(HostState *state) {
    std::lock_guard<std::mutex> lock(g_outputsMutex);
    g_openOutputs.clear();
    for (const auto &output : state->outputs) g_openOutputs.emplace_back(output.id, output.display);
}

void resizeWebView(ICoreWebView2Controller *controller, HWND hwnd) {
    if (controller == nullptr || hwnd == nullptr) return;
    RECT bounds;
    GetClientRect(hwnd, &bounds);
    controller->put_Bounds(bounds);
}

void applyCommonSettings(ICoreWebView2 *webview, bool devTools) {
    ICoreWebView2Settings *settings = nullptr;
    if (SUCCEEDED(webview->get_Settings(&settings)) && settings != nullptr) {
        settings->put_IsStatusBarEnabled(FALSE);
        settings->put_AreDefaultContextMenusEnabled(FALSE);
        settings->put_IsZoomControlEnabled(FALSE);
        settings->put_AreDevToolsEnabled(devTools ? TRUE : FALSE);
        settings->Release();
    }
}

void setBackground(ICoreWebView2Controller *controller, COREWEBVIEW2_COLOR color) {
    ICoreWebView2Controller2 *controller2 = nullptr;
    if (SUCCEEDED(controller->QueryInterface(__uuidof(ICoreWebView2Controller2), reinterpret_cast<void **>(&controller2))) && controller2 != nullptr) {
        controller2->put_DefaultBackgroundColor(color);
        controller2->Release();
    }
}

OutputWindow *outputFor(HostState *state, HWND hwnd) {
    for (auto &output : state->outputs) if (output.hwnd == hwnd) return &output;
    return nullptr;
}

void releaseOutput(OutputWindow &output) {
    if (output.webview != nullptr) { output.webview->Release(); output.webview = nullptr; }
    if (output.controller != nullptr) { output.controller->Close(); output.controller->Release(); output.controller = nullptr; }
}

void openOutput(HostState *state, OpenRequest request);

LRESULT CALLBACK windowProcedure(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_SIZE:
        if (g_state != nullptr) resizeWebView(g_state->controller, hwnd);
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
    case WM_APP_OPEN_OUTPUT: {
        auto *request = reinterpret_cast<OpenRequest *>(lParam);
        if (g_state != nullptr) openOutput(g_state, *request);
        delete request;
        return 0;
    }
    case WM_APP_CLOSE_OUTPUT: {
        if (g_state != nullptr) {
            for (auto &output : g_state->outputs) {
                if (output.id == static_cast<int>(wParam) && output.hwnd != nullptr) DestroyWindow(output.hwnd);
            }
        }
        return 0;
    }
    case WM_DESTROY:
        g_window = nullptr;
        if (g_state != nullptr) {
            auto outputs = g_state->outputs;  // DestroyWindow mutates the list
            for (auto &output : outputs) if (output.hwnd != nullptr) DestroyWindow(output.hwnd);
        }
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcW(hwnd, message, wParam, lParam);
    }
}

LRESULT CALLBACK outputProcedure(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_SIZE:
        if (g_state != nullptr) {
            if (auto *output = outputFor(g_state, hwnd)) resizeWebView(output->controller, hwnd);
        }
        return 0;
    case WM_DESTROY:
        if (g_state != nullptr) {
            for (auto it = g_state->outputs.begin(); it != g_state->outputs.end(); ++it) {
                if (it->hwnd == hwnd) {
                    releaseOutput(*it);
                    g_state->outputs.erase(it);
                    break;
                }
            }
            publishOutputs(g_state);
        }
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

void registerClasses(HINSTANCE instance) {
    static bool registered = false;
    if (registered) return;
    registered = true;

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

    WNDCLASSEXW outputClass = {};
    outputClass.cbSize = sizeof(outputClass);
    outputClass.lpfnWndProc = outputProcedure;
    outputClass.hInstance = instance;
    outputClass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    outputClass.hbrBackground = static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
    outputClass.lpszClassName = kOutputClass;
    RegisterClassExW(&outputClass);
}

HWND createWindow(const wchar_t *title, int width, int height) {
    HINSTANCE instance = GetModuleHandleW(nullptr);
    registerClasses(instance);

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

// Creates the output window on the UI thread. The environment must exist;
// requests that arrive earlier wait in `waitingForEnvironment`.
void openOutput(HostState *state, OpenRequest request) {
    if (state->environment == nullptr) {
        state->waitingForEnvironment.push_back(request);
        return;
    }
    auto list = displays();
    if (request.display < 0 || request.display >= static_cast<int>(list.size())) return;
    const DisplayInfo &display = list[request.display];

    // One output per display: replace an earlier one.
    for (auto &existing : state->outputs) {
        if (existing.display == request.display && existing.hwnd != nullptr) DestroyWindow(existing.hwnd);
    }

    HINSTANCE instance = GetModuleHandleW(nullptr);
    HWND hwnd = CreateWindowExW(WS_EX_NOACTIVATE, kOutputClass, L"MxU Slides Output", WS_POPUP,
                                display.rect.left, display.rect.top,
                                display.rect.right - display.rect.left, display.rect.bottom - display.rect.top,
                                nullptr, nullptr, instance, nullptr);
    if (hwnd == nullptr) return;

    OutputWindow output;
    output.id = request.id;
    output.display = request.display;
    output.hwnd = hwnd;
    state->outputs.push_back(output);
    publishOutputs(state);

    // Keep the output above everything on its display, unless it shares the
    // display with the main window (then the operator still needs to get back).
    HMONITOR mainMonitor = MonitorFromWindow(state->window, MONITOR_DEFAULTTONEAREST);
    HMONITOR outputMonitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    SetWindowPos(hwnd, mainMonitor == outputMonitor ? HWND_TOP : HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);

    std::wstring url = request.url;
    auto *handler = new ControllerHandler([state, hwnd, url](HRESULT result, ICoreWebView2Controller *controller) -> HRESULT {
        OutputWindow *output = outputFor(state, hwnd);
        if (output == nullptr) {
            if (controller != nullptr) controller->Close();
            return S_OK;
        }
        if (FAILED(result) || controller == nullptr) {
            DestroyWindow(hwnd);
            return result;
        }
        controller->AddRef();
        output->controller = controller;
        controller->get_CoreWebView2(&output->webview);
        if (output->webview != nullptr) {
            applyCommonSettings(output->webview, false);
            COREWEBVIEW2_COLOR black = {255, 0, 0, 0};
            setBackground(controller, black);
            resizeWebView(controller, hwnd);
            output->webview->Navigate(url.c_str());
        }
        return S_OK;
    });
    state->environment->CreateCoreWebView2Controller(hwnd, handler);
    handler->Release();
}

HRESULT startWebView(HostState *state, const wchar_t *userDataFolder) {
    auto *environmentHandler = new EnvironmentHandler([state](HRESULT result, ICoreWebView2Environment *environment) -> HRESULT {
        if (FAILED(result) || environment == nullptr) {
            state->result = 3;
            PostMessageW(state->window, WM_CLOSE, 0, 0);
            return result;
        }
        environment->AddRef();
        state->environment = environment;
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
                applyCommonSettings(state->webview, true);
                COREWEBVIEW2_COLOR background = {255, 31, 31, 30};
                setBackground(controller, background);
                resizeWebView(controller, state->window);
                state->webview->Navigate(state->url.c_str());
            }
            return S_OK;
        });
        HRESULT created = environment->CreateCoreWebView2Controller(state->window, controllerHandler);
        controllerHandler->Release();

        auto waiting = state->waitingForEnvironment;
        state->waitingForEnvironment.clear();
        for (auto &request : waiting) openOutput(state, request);
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

    for (auto &output : state.outputs) releaseOutput(output);
    state.outputs.clear();
    publishOutputs(&state);
    if (state.webview != nullptr) state.webview->Release();
    if (state.controller != nullptr) {
        state.controller->Close();
        state.controller->Release();
    }
    if (state.environment != nullptr) state.environment->Release();
    g_state = nullptr;
    g_window = nullptr;
    if (initializedCOM) CoUninitialize();
    return state.result;
}

extern "C" void mxu_webview_close(void) {
    HWND hwnd = g_window.load();
    if (hwnd != nullptr) PostMessageW(hwnd, WM_CLOSE, 0, 0);
}

extern "C" int mxu_webview_is_running(void) {
    return g_window.load() != nullptr ? 1 : 0;
}

extern "C" int mxu_display_count(void) {
    return static_cast<int>(displays().size());
}

extern "C" int mxu_display_info(int index, wchar_t *name, int nameCapacity, int *x, int *y, int *width, int *height, int *primary) {
    auto list = displays();
    if (index < 0 || index >= static_cast<int>(list.size())) return 0;
    const DisplayInfo &display = list[index];
    if (name != nullptr && nameCapacity > 0) {
        wcsncpy_s(name, static_cast<size_t>(nameCapacity), display.name.c_str(), _TRUNCATE);
    }
    if (x != nullptr) *x = display.rect.left;
    if (y != nullptr) *y = display.rect.top;
    if (width != nullptr) *width = display.rect.right - display.rect.left;
    if (height != nullptr) *height = display.rect.bottom - display.rect.top;
    if (primary != nullptr) *primary = display.primary ? 1 : 0;
    return 1;
}

extern "C" int mxu_output_open(const wchar_t *url, int displayIndex) {
    HWND hwnd = g_window.load();
    if (hwnd == nullptr || url == nullptr) return -1;
    auto *request = new OpenRequest{g_nextOutputId++, displayIndex, url};
    int id = request->id;
    if (!PostMessageW(hwnd, WM_APP_OPEN_OUTPUT, 0, reinterpret_cast<LPARAM>(request))) {
        delete request;
        return -1;
    }
    return id;
}

extern "C" void mxu_output_close(int outputId) {
    HWND hwnd = g_window.load();
    if (hwnd != nullptr) PostMessageW(hwnd, WM_APP_CLOSE_OUTPUT, static_cast<WPARAM>(outputId), 0);
}

extern "C" int mxu_output_list(int *ids, int *displayIndexes, int capacity) {
    std::lock_guard<std::mutex> lock(g_outputsMutex);
    int count = 0;
    for (const auto &entry : g_openOutputs) {
        if (count < capacity) {
            if (ids != nullptr) ids[count] = entry.first;
            if (displayIndexes != nullptr) displayIndexes[count] = entry.second;
        }
        count++;
    }
    return count;
}
