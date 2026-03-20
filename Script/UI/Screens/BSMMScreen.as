class UBSMMScreen : UFUActivatableWidget
{
    UPROPERTY(BindWidget)
    UMMWidget MMWidget;

    const FLinearColor PanelColor = FLinearColor(0.04, 0.04, 0.04);

    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float InDeltaTime)
    {
        mm::BeginDraw(MMWidget);
				
		mm::HAlign_Center();
		mm::Padding(5);
		mm::WithinBorder(PanelColor, 5);
            mm::Text("UBSUmmScreen", 24, FLinearColor::White);
        mm::EndDraw();
    }
}