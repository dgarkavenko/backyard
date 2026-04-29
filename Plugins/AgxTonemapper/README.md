# AgX Tonemapper Plugin

This plugin overrides `PostProcessCombineLUTs.usf` at startup and swaps the tonemapper math before shaders compile.

## Modes

- `Stock`: Unreal default `FilmToneMap`
- `AgX`: HiddenEmpire 5.7 AgX with the standard look
- `AgX (Punchy)`: HiddenEmpire 5.7 AgX with the punchy look
- `Reinhard`: HiddenEmpire 5.7 Reinhard

## How To Switch

1. Open `Project Settings -> Plugins -> AgX Tonemapper`
2. Change `Tonemapper Mode`
3. Restart the editor
4. Let shaders recompile

This is a startup-only switch. Changing the setting does not affect the already running editor session.

## Verify It Worked

- Check [BackyardForge.log](/C:/backyard/Saved/Logs/BackyardForge.log)
- Look for:
  - `AgX tonemapper is in Stock mode.`
  - or `AgX tonemapper override active in mode ...`

## Shader Iteration

- Edit the active shader sources
- Restart the editor, or run `RecompileShaders Changed`

Relevant files:

- [PostProcessCombineLUTs_5.7.usf](/C:/backyard/Plugins/AgxTonemapper/Shaders/HiddenEmpire/PostProcessCombineLUTs_5.7.usf)
- [PostProcessCombineLUTs.usf](/C:/backyard/Plugins/AgxTonemapper/Shaders/Overrides/PostProcessCombineLUTs.usf)
- [AgxTonemapperCommon.ush](/C:/backyard/Plugins/AgxTonemapper/Shaders/Private/AgxTonemapperCommon.ush)
