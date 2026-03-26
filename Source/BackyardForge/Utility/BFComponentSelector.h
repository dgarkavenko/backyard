#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "GameFramework/Actor.h"
#include "BFComponentSelector.generated.h"

USTRUCT(BlueprintType)
struct BACKYARDFORGE_API FBFComponentSelector
{
	GENERATED_BODY()

public:
	FBFComponentSelector() = default;
	FBFComponentSelector(const UActorComponent* InComponent);
	FBFComponentSelector(TSubclassOf<UActorComponent> ComponentType);
	FBFComponentSelector(UClass* ComponentType);

	bool operator ==(const FBFComponentSelector& Rhs) const;

	UActorComponent* Get(const AActor* Owner) const;

	template <class T>
	T* Get(const AActor* Owner) const
	{
		return Cast<T>(Get(Owner));
	}

	UActorComponent* ResolveComponent(const AActor* Owner) const;

	template <class T>
	T* ResolveComponent(const AActor* Owner) const
	{
		return Cast<T>(ResolveComponent(Owner));
	}

	void ClearCached();
	bool CheckEditorOnly(const UActorComponent* Comp) const;
	TSubclassOf<UActorComponent> GetComponentType() const;

	template <class T, class F>
	static void ForComponents(TArray<FBFComponentSelector>& Selectors, AActor* Owner, F&& Func)
	{
		for (FBFComponentSelector& Selector : Selectors)
		{
			Func(Selector.Get<T>(Owner));
		}
	}

	template <class T>
	static TArray<T*> ToComponents(TArray<FBFComponentSelector>& Selectors, AActor* Owner)
	{
		TArray<T*> Ret;
		for (FBFComponentSelector& Selector : Selectors)
		{
			T* Comp = Selector.Get<T>(Owner);
			if (Comp)
			{
				Ret.Add(Comp);
			}
		}
		return Ret;
	}

	UPROPERTY(EditAnywhere)
	TSubclassOf<UActorComponent> ComponentType = UActorComponent::StaticClass();
	UPROPERTY(EditAnywhere)
	FName ComponentName;

	UPROPERTY(Transient)
	mutable UActorComponent* Component = nullptr;

	uint8 bIncludeEditorOnly : 1;
	uint8 bIsNoneAllowed : 1;
};
