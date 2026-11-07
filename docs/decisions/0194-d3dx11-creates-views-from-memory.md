# 0194: d3dx11 creates shader resource views from memory

**Status:** accepted, 2026-11-07, by the person running this fork.

## Context

Mega Man Legacy Collection 2 (495050) exited with `STATUS_INTEGER_DIVIDE_BY_ZERO` at `MMLC2.exe`
RVA 0x1683e (`0x10000 / width`), right after its controls screen, with DXMT and with Vulkan. Its
font textures come from `D3DX11CreateShaderResourceViewFromMemory` (d3dx11_43), and the game reads
their size back through the view's resource. Wine's builtin d3dx11 had that function as a stub
returning `E_NOTIMPL`, so the font kept a width of 0. `D3DX11CreateTextureFromMemory` was already
implemented.

## Decision

`D3DX11CreateShaderResourceViewFromMemory` creates the texture as
`D3DX11CreateTextureFromMemory` does (same image formats and load info) and returns a default
shader resource view of it (`patches/wine-pe/0066`). The thread pump stays unimplemented, as for
the other d3dx11 loaders.

- With that alone the game still crashed. A diagnostic (`patches/wine-pe/0067`, MESSAGE, which
  no debug channel gates) showed why: every font is a DX10 DDS in `DXGI_FORMAT_BC7_UNORM` (98),
  which the shared d3dx pixel format table lacked (`E_FAIL`). d3dx now knows BC7_UNORM as a
  4x4, 16-byte block format and maps it to and from DXGI (`patches/wine-pe/0068`): a load that
  keeps the file's format and size copies the blocks. Converting from or to BC7 stays unsupported
  (bcdec's BC7 decoder is in its `WINE_UNUSED` part). The
  diagnostic stays: a texture d3dx11 cannot load is logged as `d3dx11: SRV from memory: …`.

## Consequences

Any game that loads textures through this call gets them instead of a failure.
