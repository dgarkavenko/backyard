// Copyright Epic Games, Inc. All Rights Reserved.


#include "BFPlayerController.h"
#include "EnhancedInputSubsystems.h"
#include "Engine/LocalPlayer.h"
#include "InputMappingContext.h"
#include "BFCameraManager.h"
#include "Blueprint/UserWidget.h"
#include "BackyardForge.h"
#include "PrimaryGameLayout.h"
#include "Widgets/Input/SVirtualJoystick.h"

ABFPlayerController::ABFPlayerController()
{
	PlayerCameraManagerClass = ABFCameraManager::StaticClass();
}

void ABFPlayerController::SetupInputComponent()
{
	Super::SetupInputComponent();

	if (IsLocalPlayerController())
	{
		if (UEnhancedInputLocalPlayerSubsystem* Subsystem = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(GetLocalPlayer()))
		{
			for (UInputMappingContext* CurrentContext : DefaultMappingContexts)
			{
				Subsystem->AddMappingContext(CurrentContext, 0);
			}
		}
	}
	
	ReceiveSetupInputComponent();
}

UCommonActivatableWidget* ABFPlayerController::PushWidgetToPrimaryLayout(const FGameplayTag LayerName, UClass* ActivatableWidgetClass)
{
	if (ActivatableWidgetClass == nullptr)
	{
		return nullptr;
	}

	if (UPrimaryGameLayout* RootLayout = UPrimaryGameLayout::GetPrimaryGameLayout(this))
	{		
		return RootLayout->PushWidgetToLayerStack(LayerName, ActivatableWidgetClass);
	}

	return nullptr;
}
