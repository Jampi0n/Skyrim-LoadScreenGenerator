Scriptname JLS_XMarkerReferenceScript extends ObjectReference

GlobalVariable Property RandomVar Auto
Actor Property PlayerRef Auto

Event OnCellDetach()
	Utility.Wait(0.1) ;maybe not necessary
	MoveTo(PlayerRef)
	RandomVar.SetValue(Utility.RandomFloat(0.0, 100.0))
EndEvent
