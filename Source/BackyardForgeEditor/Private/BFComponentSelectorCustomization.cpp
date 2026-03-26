#include "BFComponentSelectorCustomization.h"
#include "PropertyHandle.h"
#include "Components/ActorComponent.h"
#include "GameFramework/Actor.h"
#include "Templates/SharedPointer.h"
#include "Engine/BlueprintGeneratedClass.h"
#include "Engine/SimpleConstructionScript.h"
#include "Engine/SCS_Node.h"
#include "DetailWidgetRow.h"
#include "Widgets/Input/SComboBox.h"
#include "Widgets/Text/STextBlock.h"
#include "Widgets/DeclarativeSyntaxSupport.h"
#include "IDetailChildrenBuilder.h"
#include "BFComponentSelector.h"

DEFINE_LOG_CATEGORY(LogBFComponentSelectorCustomization)

TSharedRef<IPropertyTypeCustomization> FBFComponentSelectorCustomization::MakeInstance()
{
	return MakeShareable(new FBFComponentSelectorCustomization());
}

void FBFComponentSelectorCustomization::CustomizeHeader(TSharedRef<IPropertyHandle> StructPropertyHandle, FDetailWidgetRow& HeaderRow, IPropertyTypeCustomizationUtils& StructCustomizationUtils)
{
	ComponentNameHandle = FindStructMemberProperty(StructPropertyHandle, GET_MEMBER_NAME_CHECKED(FBFComponentSelector, ComponentName));
	if (!ComponentNameHandle->IsValidHandle())
	{
		UE_LOG(LogBFComponentSelectorCustomization, Warning, TEXT("[BF][FBFComponentSelectorCustomization::CustomizeHeader] ComponentNameHandle is invalid."));
		return;
	}

	FoundNames.Empty();
	TMap<FName, int32> Names;

	bool bAnyError = false;
	TArray<UObject*> Objects;
	TArray<void*> DataPointers;
	StructPropertyHandle->GetOuterObjects(Objects);
	StructPropertyHandle->AccessRawData(DataPointers);

	if (Objects.Num() != DataPointers.Num())
	{
		UE_LOG(LogBFComponentSelectorCustomization, Warning, TEXT("[BF][FBFComponentSelectorCustomization::CustomizeHeader] Object and property data don't match."));
		return;
	}

	for (int32 Index = 0; Index < Objects.Num(); ++Index)
	{
		const UObject* Object = Objects[Index];
		FBFComponentSelector* Data = static_cast<FBFComponentSelector*>(DataPointers[Index]);

		if (!Data)
		{
			continue;
		}

		bool bCurrentValid = Data->ComponentName.IsNone();
		const UClass* ActorClass = Object->GetClass();
		const AActor* Actor = Cast<AActor>(Object);

		auto AddName = [&bCurrentValid, &Data, &Names](const FName& Name)
		{
			Names.Add(Name)++;
			if (!bCurrentValid && Data->ComponentName == Name)
			{
				bCurrentValid = true;
			}
		};

		if (Data->bIsNoneAllowed)
		{
			AddName(NAME_None);
		}

		if (!Actor)
		{
			if (const UBlueprintGeneratedClass* GeneratedClass = Object->GetTypedOuter<UBlueprintGeneratedClass>())
			{
				ActorClass = GeneratedClass;
				Actor = GetDefault<AActor>(GeneratedClass);				
			}
			else if (const AActor* OuterActor = Object->GetTypedOuter<AActor>())
			{
				ActorClass = OuterActor->GetClass();
				Actor = OuterActor;
			}
		}

		if (Actor)
		{
			TArray<UActorComponent*> FoundComponents;
			Actor->GetComponents(Data->GetComponentType(), FoundComponents);

			for (const UActorComponent* ActorComponent : FoundComponents)
			{
				if (ActorComponent->CreationMethod != EComponentCreationMethod::UserConstructionScript && Data->CheckEditorOnly(ActorComponent))
				{
					AddName(ActorComponent->GetFName());
				}
			}
		}
		if (Actor == GetDefault<AActor>(ActorClass))
		{
			TArray<const UBlueprintGeneratedClass*> Classes;
			UBlueprintGeneratedClass::GetGeneratedClassesHierarchy(ActorClass, Classes);

			for (const UBlueprintGeneratedClass* Class : Classes)
			{
				check(Class);
				if (!Class->SimpleConstructionScript)
				{
					continue;
				}
				for (const USCS_Node* Node : Class->SimpleConstructionScript->GetAllNodes())
				{
					if (Node->ComponentClass && Node->ComponentClass->IsChildOf(Data->GetComponentType())
						&& Data->CheckEditorOnly(Node->ComponentTemplate))
					{
						AddName(Node->GetVariableName());
					}
				}
			}
		}
		bAnyError = bAnyError || !bCurrentValid;
	}

	FName CurrentName;
	ComponentNameHandle->GetValue(CurrentName);

	TSharedPtr<FName> SelectedItem;
	for (TTuple<FName, int> Pair : Names)
	{
		if (Pair.Value == Objects.Num())
		{
			FoundNames.Add(MakeShareable(new FName(Pair.Key)));
			if (Pair.Key == CurrentName)
			{
				SelectedItem = FoundNames.Last();
			}
		}
	}

	TSharedRef<SVerticalBox> ValuePart = SNew(SVerticalBox);
	if (bAnyError)
	{
		ValuePart->AddSlot()
		.AutoHeight()
		[
			SNew(STextBlock)
			.Text(FText::FromString(TEXT("ERROR! Cannot find component of selected name!")))
			.ColorAndOpacity(FLinearColor(1, 0, 0))
		];
	}
	ValuePart->AddSlot()
	.AutoHeight()
	[
		SNew(SComboBox<TSharedPtr<FName>>)
		.OptionsSource(&FoundNames)
		.OnSelectionChanged(this, &FBFComponentSelectorCustomization::OnSelectionChanged)
		.OnGenerateWidget(this, &FBFComponentSelectorCustomization::MakeWidgetForOption)
		.InitiallySelectedItem(SelectedItem)
		[
			SNew(STextBlock)
			.Text(this, &FBFComponentSelectorCustomization::GetCurrentItemLabel)
		]
	];

	HeaderRow
	.NameContent()
	[
		StructPropertyHandle->CreatePropertyNameWidget()
	]
	.ValueContent()
	.MaxDesiredWidth(512)
	[
		ValuePart
	];
}

void FBFComponentSelectorCustomization::CustomizeChildren(TSharedRef<IPropertyHandle> StructPropertyHandle, IDetailChildrenBuilder& StructBuilder, IPropertyTypeCustomizationUtils& StructCustomizationUtils)
{
	if (const TSharedPtr<IPropertyHandle> ComponentTypeHandle = StructPropertyHandle->GetChildHandle(GET_MEMBER_NAME_CHECKED(FBFComponentSelector, ComponentType)); ComponentTypeHandle.IsValid())
	{
		StructBuilder.AddProperty(ComponentTypeHandle.ToSharedRef());
	}
}

TSharedPtr<IPropertyHandle> FBFComponentSelectorCustomization::FindStructMemberProperty(const TSharedRef<IPropertyHandle>& PropertyHandle, const FName& PropertyName)
{
	uint32 NumChildren = 0;
	PropertyHandle->GetNumChildren(NumChildren);
	for (uint32 ChildIdx = 0; ChildIdx < NumChildren; ++ChildIdx)
	{
		TSharedPtr<IPropertyHandle> ChildHandle = PropertyHandle->GetChildHandle(ChildIdx);
		if (ChildHandle->GetProperty()->GetFName() == PropertyName)
		{
			return ChildHandle;
		}
	}

	return TSharedPtr<IPropertyHandle>();
}

void FBFComponentSelectorCustomization::OnSelectionChanged(TSharedPtr<FName> NewValue, ESelectInfo::Type Flags)
{
	if (NewValue.IsValid() && ComponentNameHandle && ComponentNameHandle->IsValidHandle())
	{
		ComponentNameHandle->SetValue(*NewValue);
	}
}

FText FBFComponentSelectorCustomization::GetCurrentItemLabel() const
{
	if (ComponentNameHandle && ComponentNameHandle->IsValidHandle())
	{
		FName Value;
		ComponentNameHandle->GetValue(Value);
		return FText::FromName(Value);
	}
	return FText();
}

TSharedRef<SWidget> FBFComponentSelectorCustomization::MakeWidgetForOption(TSharedPtr<FName> InOption)
{
	return SNew(STextBlock).Text(FText::FromName(*InOption));
}
