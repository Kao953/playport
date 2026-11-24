# 0206: DXMT runs double-precision shader instructions in single precision

**Status:** accepted, 2026-11-24, by the person running this fork.

## Context

Resident Evil 2 "R.P.D. Demo" (1168280) draws its first frame, then creates a compute shader that
uses sm5 double-precision instructions. DXMT reports `DoublePrecisionFloatShaderOps = FALSE`, and
the game uses them anyway. On DXMT the converter hit its "unhandled dxbc instruction" assert and the
game ended with 0x80000101. On Vulkan, DXVK refused the shader (createComputeShader
E_INVALIDARG), because KosmicKrisp has no `shaderFloat64`. Apple GPUs have no fp64, and Metal
offers no double type.

## Decision

DXMT's converter implements every double instruction (`patches/dxmt-port/0046`): dadd, dmul, dmin,
dmax, deq, dge, dlt, dne, dmov, dmovc, dtof, ftod, and the extended ddiv, dfma, drcp, dtoi, dtou,
itod and utod. The registers keep IEEE double bits in their .xy/.zw pairs. Each operation decodes
its doubles to the nearest float (round to nearest; denormals flush to zero; infinity and NaN are
kept), computes in single precision, and encodes the result back. dmov and dmovc copy the bits
exactly. 64-bit immediates are read as their four raw dwords. DXMT still reports no double support.

## Consequences

A shader that uses doubles runs with 24 bits of mantissa instead of 53. A game that needs the extra
precision, such as large world coordinates or long-running time accumulators, can show jitter or
banding where Windows would not. Vulkan (DXVK) still refuses such shaders, so a game that uses
doubles must run on DXMT. Not yet measured on the phone.
