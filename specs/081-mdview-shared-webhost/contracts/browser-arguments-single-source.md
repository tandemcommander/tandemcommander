# Contract: the Browser-Arguments Set Exists Exactly Once

**Status**: binding for every WebView2 environment created in the product.
Makes `architecture/11-webview2-integration.md` §2.2 literally true.

## 1. Why

`AdditionalBrowserArguments` take effect only for the environment that
**starts** the shared browser process; every later environment's arguments are
silently ignored. Two definitions that drift apart therefore produce a product
whose behaviour depends on which plugin the user happened to open first — the
defect the 065/070 contracts exist to prevent. Today the literal exists three
times (`mdview/webview.cpp`, `webhost.cpp`, `webkeeper.cpp`); after feature 081
it exists once.

## 2. The API

In the COM-free `src/common/webhost/webhost.h`:

```cpp
// The ONE browser-arguments set (architecture/11 §2.2). Every environment the
// product creates -- each plugin's viewer surfaces and each plugin's keeper --
// passes exactly this string; extending it is a coordinated change here.
const wchar_t* TcWebBrowserArguments();
```

Defined once in `webhost.cpp`; the current value is

```
--disable-background-networking --disable-sync --disable-component-update --disable-features=msWebOOUI,msPdfOOUI
```

## 3. Consumers

| Site | Uses |
|---|---|
| `webhost.cpp` `TcWebBuildEnvOptions()` | `options->put_AdditionalBrowserArguments(TcWebBrowserArguments())` |
| `webkeeper.cpp` keeper options builder | same call; its own literal is removed |
| any future WebView2 consumer | the same accessor — never a literal |

## 4. Guard

`rg -c "disable-features=msWebOOUI" src/` MUST report exactly **1** hit
(`src/common/webhost/webhost.cpp`). Documentation may quote the value.

## 5. Changing the set

A change is a single edit in `webhost.cpp`, reviewed with both plugins in
mind, and recorded in `architecture/11-webview2-integration.md` §2.2 (which
quotes the current value). Per-plugin overrides are forbidden.
