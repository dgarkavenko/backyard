class ABSPlayerController : ABFPlayerController
{
    UPROPERTY()
    TSubclassOf<UCommonActivatableWidget> DebugScreen;

    UPROPERTY()
    TSubclassOf<UCommonActivatableWidget> HUDRoot;

    UPROPERTY(Category = "Input")
	UInputAction ShowDebugAction;

    UEnhancedInputComponent InputComponent;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        PushWidgetToPrimaryLayout(GameplayTags::ForgeryUI_Layer_Game, HUDRoot);
    }

	UFUNCTION(BlueprintOverride)
	void SetupInputComponent()
	{
		InputComponent = UEnhancedInputComponent::Get(this);
		InputComponent.BindAction(ShowDebugAction, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(this, n"Input_Action"));
	}

	UFUNCTION()
	void Input_Action(FInputActionValue ActionValue, float32 ElapsedTime, float32 TriggeredTime, UInputAction SourceAction)
	{
        PushWidgetToPrimaryLayout(GameplayTags::ForgeryUI_Layer_GameMenu, DebugScreen);
	}
}
