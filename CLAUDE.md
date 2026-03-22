# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**BackyardForge** is a first-person simulator game built on a custom Unreal Engine 5.7 fork with [AngelScript support by Hazelight](https://angelscript.hazelight.se/). It uses a variant-based architecture to prototype different game mechanics (Horror, Shooter, etc.) sharing a common first-person character base.

The engine is registered by GUID (`{CDA83A63-4999-9786-3CC3-6CA68D27C361}`) — not a standard Epic launcher install. The UE source lives at `D:\Unreal\ue-as`. Build and run through the custom UE fork's editor or build tools.

## Build & Development

- **Solution**: `BackyardForge.sln` — open in Visual Studio (requires components listed in `.vsconfig`)
- **Build targets**: `BackyardForge.Target.cs` (game), `BackyardForgeEditor.Target.cs` (editor) — both use `BuildSettingsVersion.V6`
- The project will eventually use **AngelScript** (`.as` files in a `Script/` folder) for gameplay prototyping alongside C++. See https://angelscript.hazelight.se/ for API reference, binding patterns, and scripting conventions.
- **AngelScript examples**: `C:\backyard\Script-Examples` contains reference `.as` files — use these for patterns and conventions alongside the [official Hazelight docs](https://angelscript.hazelight.se/).
- **Saltborne examples**: `C:\unreal\Saltborne\Saltborne\Script` — production AngelScript codebase with advanced patterns: `UCLASS(DefaultToInstanced, EditInlineNew)`, `UPROPERTY(Instanced)`, namespaces, mixins, `SpawnActor`, `Material::CreateDynamicMaterialInstance`, `TWeakObjectPtr`, `#if EDITOR`.
- **C++ escape hatch**: When AngelScript lacks access to an engine API, create base C++ classes or `UBlueprintFunctionLibrary` statics that AngelScript can call or inherit from.

## Architecture

### Module Dependencies (BackyardForge.Build.cs)

Core, CoreUObject, Engine, InputCore, EnhancedInput, AIModule, StateTreeModule, GameplayStateTreeModule, UMG, Slate

### Variant System

The codebase uses a **variant pattern** — each game mode variant lives in its own subfolder under `Source/BackyardForge/` and `Content/`, inheriting from shared base classes:

```
ABFCharacter (base first-person character)
├── AHorrorCharacter   — stamina/sprint, spotlight
├── AShooterCharacter  — weapons, health, teams (implements IShooterWeaponHolder)
└── AShooterNPC        — AI-controlled shooter (implements IShooterWeaponHolder)
```

Each variant has its own GameMode, PlayerController, and UI widget classes. The base classes (`BFCharacter`, `BFPlayerController`, `BFGameMode`, `BFCameraManager`) provide shared first-person setup, Enhanced Input, and mobile controls.

### Key Design Patterns

- **Template Method**: `ABFCharacter` defines virtual `DoAim()`, `DoMove()`, `DoJumpStart()`, `DoJumpEnd()` — variants override these
- **IShooterWeaponHolder interface**: Decouples weapon behavior from character type (both player and NPC implement it)
- **Delegate-driven UI**: C++ broadcasts delegates (sprint meter, bullet count, damage, death) → Blueprint-implementable `BP_*` events on UUserWidget subclasses
- **StateTree AI**: Shooter NPCs use StateTree with custom tasks/conditions in `ShooterStateTreeUtility` (line-of-sight checks, perception sensing, shooting tasks)
- **Data Table pickups**: `AShooterPickup` uses `FWeaponTableRow` data tables to map static meshes to weapon classes

### Content Layout

| Path | Purpose |
|------|---------|
| `Content/FirstPerson/` | Base template level and blueprints |
| `Content/Variant_Horror/` | Horror mode level, inputs, UI, blueprints |
| `Content/Variant_Shooter/` | Shooter mode level, weapons, AI, anims, UI |

Default map: `Lvl_FirstPerson`. Each variant has its own level (`Lvl_Horror`, `Lvl_Shooter`).

### Shooter Weapon Pipeline

`AShooterPickup` (world item, data-table-driven) → `AShooterWeapon` (firing, ammo, recoil, AI noise) → `AShooterProjectile` (hit detection, radial/single damage, physics impulse)

### AI System (Shooter)

`AShooterAIController` owns `StateTreeAIComponent` + `AIPerceptionComponent` (sight/hearing). Custom StateTree nodes handle enemy sensing, line-of-sight cone checks, face-target, and shoot-at-target behaviors. `AShooterNPCSpawner` manages one-at-a-time NPC respawning.

### Interaction System

Data-driven interaction foundation in `Script/Interaction/`. Each interactable has a list of actions; the player filters by context (held items, tags).

- **Detection**: Camera line trace on `Interaction` channel (focused) + overlap sphere on character (awareness/glow)
- **`UBSInteractable`** component: attach to any actor, reference a `UBSInteractionActionSet` data asset. Fires `OnActionExecuted` delegate when an action is performed.
- **`FBSInteractionAction`**: action tag, display name, `UInputAction` reference, required `FGameplayTagContainer`
- **`BSInteractionLibrary.as`**: free functions — `TraceForInteractable()`, `GetFilteredActions()`, `ExecuteAction()`
- **Requirements**: GameplayTag matching — held item grants tags, action requires tags. `RequiredTags.IsEmpty()` means no requirement.

### Sentry System

Modular turret in `Script/Sentry/`. Data-driven via `UBSSentryPreset` data asset (meshes + constraints). Component chain: Base → Rotator01 → Rotator02 → Body via `s_pivot` sockets. `AimAt(FVector)` solves the 2-joint rotation chain. Geometry cached in `BeginPlay` for performance with hundreds of instances.

## Config Notes

- Custom collision channels: `Projectile` (ECC_GameTraceChannel1, default Block), `Interaction` (ECC_GameTraceChannel2, default Ignore, trace type)
- `bForgetStaleActors=True` in AISystem config
- Renderer: DX11, SM5, lightweight config — no Lumen, no ray tracing, no Nanite, no Substrate, no VSM. SSR reflections, cascaded shadows, all post-process effects disabled. See README.md for full rationale.
- Engine redirects from `TP_FirstPerson` and `nexss` template classes to `BF` classes (in DefaultEngine.ini)

## Conventions

- C++ class prefix: `BF` for base classes, variant name for specializations (e.g., `Horror*`, `Shooter*`)
- Source subfolder per variant: `Variant_Horror/`, `Variant_Shooter/` with further `AI/`, `UI/`, `Weapons/` subdivision
- UI pattern: abstract C++ `UUserWidget` subclass with `BlueprintImplementableEvent` methods → Blueprint widget implements visuals
- Input: Enhanced Input only (no legacy). Input mapping contexts managed in PlayerController.
- When adding AngelScript files, place them in `Script/` at the project root following Hazelight conventions
- Prefer functional style over OOP — free functions, function libraries, data-driven design over deep class hierarchies
- Performance-aware programming — cache what you can, avoid per-frame allocations and redundant lookups, think about scale (hundreds of actors)
- No excessive code comments — code should be self-explanatory
- Full variable names — `PlayerController` not `PC`, `WorldLocation` not `Loc`
- Allman brace style — opening `{` on new line, always use braces for `if`/`else`/`for`/`while` blocks, even single-line bodies

## C++ Macro Patterns

### UPROPERTY

| Use Case | Specifiers | Example |
|----------|-----------|---------|
| **Components** (private) | `VisibleAnywhere, BlueprintReadOnly, Category="Components", meta=(AllowPrivateAccess="true")` | `UCameraComponent*`, `UPawnNoiseEmitterComponent*` |
| **Gameplay params** (tunable) | `EditAnywhere, Category="Variant\|SubCategory", meta=(ClampMin=X, ClampMax=Y, Units="cm"/"s"/"Degrees")` | `float MaxAimDistance`, `float RespawnTime` |
| **Blueprint-visible state** | `BlueprintReadOnly` or `BlueprintReadWrite` with category | `FBulletCountUpdatedDelegate OnBulletCountUpdated` |
| **Runtime-only state** | No `UPROPERTY` at all | `bool bIsSprinting`, `FTimerHandle`, transient arrays |

Category hierarchy uses pipe delimiter: `Category="Projectile|Noise"`, `Category="Projectile|Hit"`.

Numeric validation: always pair `ClampMin`/`ClampMax` with `Units` when a physical unit applies (`"cm"`, `"s"`, `"Degrees"`).

### UFUNCTION

| Pattern | Specifiers | Naming |
|---------|-----------|--------|
| **Input handlers** | `BlueprintCallable, Category="Input"` | `DoStartFiring()`, `DoMove()` |
| **Blueprint events** | `BlueprintImplementableEvent, Category="Variant", meta=(DisplayName="Readable Name")` | `BP_OnDeath()`, `BP_UpdateScore()` |
| **Pure getters** | `BlueprintPure, Category="..."` | `GetFirstPersonMesh()` |
| **Delegate callbacks** | Bare `UFUNCTION()` — no specifiers | `OnOwnerDestroyed()`, `OnPawnDeath()`, `OnPerceptionUpdated()` |

Blueprint-implementable events always use `BP_` prefix with a `DisplayName` meta for editor readability.

## Delegate Naming Conventions

**Dynamic multicast** (Blueprint-bindable, UI updates):
```cpp
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FUpdateSprintMeterDelegate, float, Percentage);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FBulletCountUpdatedDelegate, int32, MagazineSize, int32, Bullets);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FPawnDeathDelegate);  // zero-param variant
```

**Non-dynamic single-cast** (C++-only, AI/internal plumbing):
```cpp
DECLARE_DELEGATE_TwoParams(FShooterPerceptionUpdatedDelegate, AActor*, const FAIStimulus&);
DECLARE_DELEGATE_OneParam(FShooterPerceptionForgottenDelegate, AActor*);
```

- Type name: `F<Description>Delegate`
- Member instance: `On<Event>` prefix (e.g., `OnBulletCountUpdated`, `OnSprintMeterUpdated`)
- Dynamic multicast for anything Blueprint/UI needs to bind; plain `DECLARE_DELEGATE` for C++-only hooks (StateTree tasks, AI controllers)

## StateTree Node Patterns

Canonical reference: `Variant_Shooter/AI/ShooterStateTreeUtility.h` (7 nodes).

### Condition pattern

```cpp
// 1. Instance data struct
USTRUCT()
struct FStateTreeMyConditionInstanceData
{
    GENERATED_BODY()
    UPROPERTY(EditAnywhere, Category = "Context")  TObjectPtr<AMyActor> Character;
    UPROPERTY(EditAnywhere, Category = "Condition") float Threshold = 0.5f;
};
STATETREE_POD_INSTANCEDATA(FStateTreeMyConditionInstanceData);  // if POD-like

// 2. Condition struct
USTRUCT(DisplayName = "My Condition", Category="VariantName")
struct FStateTreeMyCondition : public FStateTreeConditionCommonBase
{
    GENERATED_BODY()
    using FInstanceDataType = FStateTreeMyConditionInstanceData;
    virtual const UStruct* GetInstanceDataType() const override { return FInstanceDataType::StaticStruct(); }
    virtual bool TestCondition(FStateTreeExecutionContext& Context) const override;
};
```

### Task pattern

```cpp
// 1. Instance data struct — use Category = Context / Input / Output / Parameter
USTRUCT()
struct FStateTreeMyTaskInstanceData
{
    GENERATED_BODY()
    UPROPERTY(EditAnywhere, Category = Context)    TObjectPtr<AAIController> Controller;
    UPROPERTY(EditAnywhere, Category = Input)      TObjectPtr<AActor> Target;
    UPROPERTY(EditAnywhere, Category = Output)     bool bResult = false;
    UPROPERTY(EditAnywhere, Category = Parameter)  FName Tag = FName("Default");
};

// 2. Task struct
USTRUCT(meta=(DisplayName="My Task", Category="VariantName"))
struct FStateTreeMyTask : public FStateTreeTaskCommonBase
{
    GENERATED_BODY()
    using FInstanceDataType = FStateTreeMyTaskInstanceData;
    virtual const UStruct* GetInstanceDataType() const override { return FInstanceDataType::StaticStruct(); }
    virtual EStateTreeRunStatus EnterState(FStateTreeExecutionContext& Context, const FStateTreeTransitionResult& Transition) const override;
    virtual void ExitState(FStateTreeExecutionContext& Context, const FStateTreeTransitionResult& Transition) const override;  // optional
};
```

Instance data categories: `Context` (bound actors/controllers), `Input` (data from other nodes), `Output` (data produced), `Parameter` (tunable defaults). Always include `#if WITH_EDITOR` `GetDescription` override for editor tooltips.

## Logging

- **Primary category**: `LogBackyardForge` — declared in `BackyardForge.h`, defined in `BackyardForge.cpp`. Use this for all new code.
- **Legacy**: `LogTemplateCharacter` declared in `BFCharacter.h` — inherited from template, unused. Do not use for new code.

## Claude Code Tips

- **Read `.h` before `.cpp`** when modifying classes — the header has UPROPERTY/UFUNCTION metadata, inheritance, and delegate declarations that inform the implementation.
- **Use plan mode** (`/plan`) for multi-file variant additions or cross-cutting changes.
- **New variant checklist**: Character subclass, PlayerController, GameMode, UI widget class + `Content/Variant_<Name>/` subfolder + add include paths to `Build.cs` if needed.
- **`FTimerHandle` and internal state bools** (`bIsSprinting`, `bIsFiring`, etc.) never get `UPROPERTY` — they are runtime-only.
- **New StateTree nodes** go in the variant's `AI/` subfolder (e.g., `Variant_Shooter/AI/ShooterStateTreeUtility.h`).
- **Collision channels**: Check `DefaultEngine.ini` before adding new trace channels — `Projectile` is already `ECC_GameTraceChannel1`.
- **Delegate wiring**: UI widgets bind to character delegates in `NativeConstruct`; check existing `ShooterBulletCounterUI` and `HorrorUI` for the pattern.
