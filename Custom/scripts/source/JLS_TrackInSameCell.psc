Scriptname JLS_TrackInSameCell extends ActiveMagicEffect
{ability that will be activated when player is not in the same cell as invisibleObject}

Actor Property PlayerRef Auto
GlobalVariable Property RandomVar Auto
ObjectReference Property MarkerRef Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	Utility.Wait(0.1) ; Required.
	MarkerRef.MoveTo(PlayerRef)
	RandomVar.SetValue(Utility.RandomFloat(0.0, 100.0))
EndEvent
