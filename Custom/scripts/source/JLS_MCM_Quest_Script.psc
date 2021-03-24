scriptname JLS_MCM_Quest_Script extends SKI_ConfigBase

GlobalVariable Property FrequencyProperty Auto

int frequencySlider

Event OnPageReset(string aPage)
	SetCursorFillMode(TOP_TO_BOTTOM)
	AddHeaderOption("Loading Screen Frequency")
	frequencySlider = AddSliderOption("Frequency", FrequencyProperty.GetValue() as int, "{0}%")
EndEvent

Event OnOptionSliderOpen(int a_option)
	if (a_option == frequencySlider)
		SetSliderDialogStartValue(FrequencyProperty.GetValue() as int)
		SetSliderDialogDefaultValue(50)
		SetSliderDialogRange(0, 100)
		SetSliderDialogInterval(1)
	endif
EndEvent

Event OnOptionSliderAccept(int a_option, float a_value)
	if (a_option == frequencySlider)
		FrequencyProperty.SetValue(a_value as int)
		SetSliderOptionValue(a_option, a_value as int, "{0}%")
	endif
EndEvent

Event OnOptionHighlight(int a_option)
	if (a_option == frequencySlider)
		SetInfoText("Set the chance that a loading screen mod from this mod is used.")
	endif
EndEvent
