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

## Consequences

Any game that loads textures through this call gets them instead of a failure.
