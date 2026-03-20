# BackyardForge

Simulator sandbox built on a custom Unreal Engine 5.7 fork with [AngelScript support by Hazelight](https://angelscript.hazelight.se/). Uses a variant-based architecture to prototype different game mechanics (Horror, Shooter, etc.) sharing a common first-person character base.

## Renderer & Performance Config

This project is configured for **maximum editor/PIE iteration speed** over visual fidelity. All heavy UE5 rendering features are disabled in `Config/DefaultEngine.ini`.

### Disabled Features

| Feature | Why disabled |
|---------|-------------|
| **Lumen GI** | Massive GPU cost, unnecessary for prototyping |
| **Lumen Reflections** | Replaced with SSR (much cheaper) |
| **Virtual Shadow Maps** | Falls back to cascaded shadow maps (faster, simpler) |
| **Ray Tracing** | GPU cost, requires DX12/SM6 |
| **Nanite** | Extra shader permutations and GPU overhead; meshes are simple enough without it |
| **Substrate/Strata** | New material model adds shader complexity; classic shading is sufficient |
| **Motion Blur** | Visual noise during rapid prototyping |
| **Bloom** | Unnecessary post-process cost |
| **Auto Exposure** | Causes distracting brightness shifts in editor |
| **Lens Flare** | Cosmetic only |
| **Ambient Occlusion** | Post-process cost with minimal prototyping benefit |
| **Depth of Field** | Cosmetic only |
| **Film Grain** | Cosmetic only |
| **Chromatic Aberration** | Cosmetic only |
| **Anti-Aliasing** | Set to none for fastest rendering |
| **Mesh Distance Fields** | Required by Lumen; disabled with it |

### Enabled Features

- **SSR (Screen-Space Reflections)** — lightweight reflections on reflective surfaces
- **Cascaded Shadow Maps** — standard shadow technique, well-understood and fast
- **DX11 / SM5** — widest hardware compatibility, fastest shader compilation
- **Full resolution rendering** (no TSR upscaling)

### Shader Recompile Notice

On first launch after these config changes, the editor will perform a **full shader recompile** due to:
- Nanite disabled (`r.Nanite.ProjectEnabled=False`)
- Substrate disabled (`r.Substrate=False`)
- DX12 → DX11 switch

This is a one-time cost. Subsequent launches will use the shader cache.

## Build & Development

- **Solution**: `BackyardForge.sln` — open in Visual Studio (requires components listed in `.vsconfig`)
- **Build targets**: `BackyardForge.Target.cs` (game), `BackyardForgeEditor.Target.cs` (editor)
- **AngelScript**: Gameplay scripts go in `Script/` at the project root

## Links

- [Hazelight AngelScript for UE](https://angelscript.hazelight.se/) — API reference, binding patterns, scripting conventions
