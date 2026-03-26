#include "BFComponentSelector.h"
#include "Engine/World.h"

FBFComponentSelector::FBFComponentSelector(const UActorComponent* InComponent)
	: bIncludeEditorOnly(false)
	, bIsNoneAllowed(false)
{
	if (!ensure(IsValid(InComponent)))
	{
		return;
	}
	ComponentType = InComponent->GetClass();
	ComponentName = InComponent->GetFName();

	bIncludeEditorOnly = 0;
	bIsNoneAllowed = 0;
}

FBFComponentSelector::FBFComponentSelector(TSubclassOf<UActorComponent> ComponentType)
	: ComponentType(ComponentType)
{
}

FBFComponentSelector::FBFComponentSelector(UClass* ComponentType)
	: ComponentType(ComponentType)
{
}

bool FBFComponentSelector::CheckEditorOnly(const UActorComponent* Comp) const
{
	return bIncludeEditorOnly || !Comp->bIsEditorOnly;
}

bool FBFComponentSelector::operator==(const FBFComponentSelector& Rhs) const
{
	return ComponentName == Rhs.ComponentName && ComponentType == Rhs.ComponentType;
}

UActorComponent* FBFComponentSelector::Get(const AActor* Owner) const
{
#if !WITH_EDITOR
	if (Component && Component->GetOwner() == Owner)
	{
		return Component;
	}
#else
	const UWorld* World = Owner->GetWorld();
	const bool DisableCache = !World || (World->WorldType == EWorldType::Editor || World->WorldType == EWorldType::EditorPreview);
	if (!DisableCache && Component && Component->GetOwner() == Owner)
	{
		return Component;
	}
#endif // !WITH_EDITOR
	return ResolveComponent(Owner);
}

UActorComponent* FBFComponentSelector::ResolveComponent(const AActor* Owner) const
{
	TArray<UActorComponent*> Comps;
	Owner->GetComponents(GetComponentType(), Comps);
	UActorComponent** Found = Comps.FindByPredicate([this](const UActorComponent* Comp)
	{
		return CheckEditorOnly(Comp) && Comp->GetFName() == ComponentName;
	});
	if (!Found)
	{
		if (bIsNoneAllowed)
		{
			Component = nullptr;
		}
		return nullptr;
	}
	Component = *Found;
	return *Found;
}

TSubclassOf<UActorComponent> FBFComponentSelector::GetComponentType() const
{
	return ComponentType ? ComponentType : TSubclassOf<UActorComponent>(UActorComponent::StaticClass());
}

void FBFComponentSelector::ClearCached()
{
	Component = nullptr;
}
