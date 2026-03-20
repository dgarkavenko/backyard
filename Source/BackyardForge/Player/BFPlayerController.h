// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "CommonPlayerController.h"
#include "GameplayTagContainer.h"
#include "BFPlayerController.generated.h"

class UCommonActivatableWidget;
class UInputMappingContext;
class UUserWidget;

UCLASS(abstract, config="Game")
class BACKYARDFORGE_API ABFPlayerController : public ACommonPlayerController
{
	GENERATED_BODY()

public:

	ABFPlayerController();

protected:

	UPROPERTY(EditAnywhere, Category="Input|Input Mappings")
	TArray<UInputMappingContext*> DefaultMappingContexts;

	virtual void SetupInputComponent() override;
	
	UFUNCTION(BlueprintImplementableEvent)
	void ReceiveSetupInputComponent();

	UFUNCTION(ScriptCallable)
	UCommonActivatableWidget* PushWidgetToPrimaryLayout(const FGameplayTag LayerName, UClass* ActivatableWidgetClass);

};
