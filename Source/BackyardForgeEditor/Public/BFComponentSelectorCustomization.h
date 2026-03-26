#pragma once
#include "CoreMinimal.h"
#include "IPropertyTypeCustomization.h"
class SWidget;

DECLARE_LOG_CATEGORY_EXTERN(LogBFComponentSelectorCustomization, Log, All);

class FBFComponentSelectorCustomization : public IPropertyTypeCustomization
{
public:
	static TSharedRef<IPropertyTypeCustomization> MakeInstance();
	virtual void CustomizeHeader(TSharedRef<class IPropertyHandle> StructPropertyHandle, class FDetailWidgetRow& HeaderRow, IPropertyTypeCustomizationUtils& StructCustomizationUtils) override;
	virtual void CustomizeChildren(TSharedRef<class IPropertyHandle> StructPropertyHandle, class IDetailChildrenBuilder& StructBuilder, IPropertyTypeCustomizationUtils& StructCustomizationUtils) override;
	TSharedPtr<IPropertyHandle> FindStructMemberProperty(const TSharedRef<IPropertyHandle>& PropertyHandle, const FName& PropertyName);
	void OnSelectionChanged(TSharedPtr<FName> NewValue, ESelectInfo::Type);
	FText GetCurrentItemLabel() const;
	TSharedRef<SWidget> MakeWidgetForOption(TSharedPtr<FName> InOption);
private:
	TSharedPtr<IPropertyHandle> ComponentNameHandle;
	TArray<TSharedPtr<FName>> FoundNames;
};
