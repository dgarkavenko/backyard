namespace UI
{
	UBSHUDRoot GetHUD()
	{
		return Cast<UBSHUDRoot>(ABSPlayerController::Get().PrimaryGameLayout.HUDInstance);
	}

	UFUProjectedWidgetHost MarkerHost()
	{
		return GetHUD().WorldMarkerHost;
	}
}

namespace ABSPlayerController
{
	ABSPlayerController Get()
	{
		return Cast<ABSPlayerController>(Gameplay::GetPlayerController(0));
	}
}