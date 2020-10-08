void ClearGroup (IwbFile fileHandle, string signature) {
    if (HasGroup (fileHandle, signature)) {
        IwbGroupRecord group = GroupBySignature (fileHandle, signature);
        Remove (group);
    }
}

void SetValueString (IInterface handle, string path, string value) {
    SetEditValue (ElementByPath (handle, path), value);
}

void SetValueInt (IInterface handle, string path, int value) {
    SetValueString (handle, path, inttostr (value));
}

void SetValueFloat (IInterface handle, string path, float value) {
    SetValueString (handle, path, floattostr (value));
}

void SetValueHex (IInterface handle, string path, int value) {
    SetValueString (handle, path, IntToHex (value, 8));
}

void SetLinksTo (IInterface handle, string path, IwbMainRecord record_) {
    SetValueString (handle, path, IntToHex (GetLoadOrderFormID (record_), 8));
}

IwbFile FileByName (string s) {
    for (int i = 0; i < FileCount; i += 1) {
        if (GetFileName (FileByIndex (i)) == s) {
            return FileByIndex (i);
        }
    }
    return nil;
}

void AddMastersSmart (IwbFile esp, IwbElement master) {
    TStringList masterList = TStringList.Create ();
    ReportRequiredMasters (master, masterList, false, false);
    int stringCount = masterList.Count;
    for (int i = 0; i < stringCount; i += 1) {
        AddMasterIfMissing (esp, masterList[i]);
    }
}