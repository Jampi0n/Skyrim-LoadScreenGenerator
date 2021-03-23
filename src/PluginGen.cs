void PatchLoadingScreens (IwbFile esp) {
    for (int i = 0; i < FileCount; i += 1) {
        IwbFile fileHandle = FileByIndex (i);
        if ((fileHandle != esp) && (!StartsText ("FOMOD_M", GetFileName (fileHandle)))) {
            if (HasGroup (fileHandle, "LSCR")) {
                IwbGroupRecord group = GroupBySignature (fileHandle, "LSCR");
                for (int j = 0; j < ElementCount (group); j += 1) {
                    IwbMainRecord oldRecord = ElementByIndex (group, j);

                    AddMastersSmart (esp, oldRecord);

                    IwbMainRecord newRecord = wbCopyElementToFile (oldRecord, esp, false, true);
                    Remove (ElementByPath (newRecord, "Conditions"));

                    Add (newRecord, "Conditions", True);
                    SetValueInt (newRecord, "Conditions\\[0]\\CTDA\\Type", 10100000);
                    SetValueInt (newRecord, "Conditions\\[0]\\CTDA\\Comparison Value", -1);
                    SetValueString (newRecord, "Conditions\\[0]\\CTDA\\Function", "GetRandomPercent");
                }
            }
        }
    }

    SortMasters (esp);
    CleanMasters (esp);
}

IwbFile CreateESP (string fileName, string meshPath, string prefix, bool disableOthers, bool includeMessages, int frequency) {
    Log ("	Creating plugin file \"" + fileName + "\"");

    bool esl = (wbAppName == "SSE") && (imagePathArray.Count () < 1024);
    IwbFile esp = FileByName (fileName);
    if (!Assigned (esp)) {
        esp = AddNewFileName (fileName, esl);
    }
    SetValueString (ElementByIndex (esp, 0), "CNAM - Author", "Jampion");
    SetValueInt (ElementByIndex (esp, 0), "HEDR - Header\\Next Object ID", 2048);

    SetElementNativeValues (ElementByIndex (esp, 0), "Record Header\\Record Flags\\ESL", esl);

    if (!Assigned (esp)) {
        ErrorMsg ("The plugin file could not be created.");
    } else {
        ClearGroup (esp, "LSCR");
        ClearGroup (esp, "STAT");
        ClearGroup (esp, "GLOB");
        CleanMasters (esp);
        Add (esp, "LSCR", True);
        Add (esp, "STAT", True);
        Add (esp, "GLOB", True);
        if (ReadSettingBool (skTestMode)) {
            IwbMainRecord globRecord = Add (GroupBySignature (esp, "GLOB"), "GLOB", True);
            SetEditorID (globRecord, prefix + "TestMode");
        }

        float probability = 1.0 - Power (1.0 - 0.01 * frequency, 1.0 / totalLoadScreens);

        TStringList approximationArray = CreateRandomProbability (probability, 4);
        TStringList chanceGlobalList = TStringList.Create ();
        for (int j = 0; j < approximationArray.Count (); j += 1) {
            IwbMainRecord chanceGlobal = Add (GroupBySignature (esp, "GLOB"), "GLOB", True);
            chanceGlobalList.add (IntToHex (GetLoadOrderFormID (chanceGlobal), 8));
            SetEditorID (chanceGlobal, prefix + "Chance_" + inttostr (j));
            SetValueInt (chanceGlobal, "FLTV - Value", Trunc (100 * strtofloat (approximationArray[j])) - 1);
            SetValueString (chanceGlobal, "Record Header\\Record Flags", "0000001");
        }

        for (int i = 0; i < imagePathArray.Count (); i += 1) {
            string editorID = inttostr (i);

            IwbMainRecord statRecord = Add (GroupBySignature (esp, "STAT"), "STAT", True);
            SetEditorID (statRecord, prefix + "STAT_" + editorID);

            Add (statRecord, "MODL", True);
            SetValueString (statRecord, "Model\\MODL - Model FileName", meshPath + "\\" + imagePathArray[i] + ".nif");
            SetValueInt (statRecord, "DNAM\\Max Angle (30-120)", 90);

            IwbMainRecord lscrRecord = Add (GroupBySignature (esp, "LSCR"), "LSCR", True);
            SetEditorID (lscrRecord, prefix + "LSCR_" + editorID);
            SetLinksTo (lscrRecord, "NNAM", statRecord);
            Add (lscrRecord, "SNAM", True);
            SetValueInt (lscrRecord, "SNAM", 2);
            Add (lscrRecord, "RNAM", True);
            SetValueInt (lscrRecord, "RNAM\\X", -90);
            Add (lscrRecord, "ONAM", True);
            Add (lscrRecord, "XNAM", True);
            SetValueInt (lscrRecord, "XNAM\\X", -45);

            Add (lscrRecord, "Conditions", True);
            if (ReadSettingBool (skTestMode)) {
                SetValueInt (lscrRecord, "Conditions\\[0]\\CTDA\\Type", 10000000);
                SetValueInt (lscrRecord, "Conditions\\[0]\\CTDA\\Comparison Value", i);
                SetValueString (lscrRecord, "Conditions\\[0]\\CTDA\\Function", "GetGlobalValue");
                SetLinksTo (lscrRecord, "Conditions\\[0]\\CTDA\\Global", globRecord);
            } else {
                for (int j = 0; j < approximationArray.Count (); j += 1) {
                    ElementAssign (ElementByPath (lscrRecord, "Conditions"), HighInteger, nil, false);
                    SetValueInt (lscrRecord, "Conditions\\[" + inttostr (j) + "]\\CTDA\\Type", 10100100);
                    SetValueString (lscrRecord, "Conditions\\[" + inttostr (j) + "]\\CTDA\\Comparison Value", chanceGlobalList[j]);
                    SetValueString (lscrRecord, "Conditions\\[" + inttostr (j) + "]\\CTDA\\Function", "GetRandomPercent");
                }
                Remove (ElementByPath (lscrRecord, "Conditions\\[" + inttostr (approximationArray.Count ()) + "]"));
            }

            if (includeMessages) {
                SetValueString (lscrRecord, "DESC - Description", imageTextArray[i]);
            }
        }
        if (disableOthers) {
            PatchLoadingScreens (esp);
        }
    }
}

void CreateESPOptions (string pluginName, string modFolder, bool disableOthers, int msgSetting, int frequency) {

    if (msgSetting == 0) {
        CreateESP ("FOMOD_M0_P" + inttostr (frequency) + "_FOMODEND_" + pluginName, modFolder, ReadSetting (skPrefix), disableOthers, false, frequency);
    } else if (msgSetting == 1) {
        CreateESP ("FOMOD_M1_P" + inttostr (frequency) + "_FOMODEND_" + pluginName, modFolder, ReadSetting (skPrefix), disableOthers, true, frequency);
    } else if (msgSetting == 2) {
        CreateESP ("FOMOD_M0_P" + inttostr (frequency) + "_FOMODEND_" + pluginName, modFolder, ReadSetting (skPrefix), disableOthers, false, frequency);
        CreateESP ("FOMOD_M1_P" + inttostr (frequency) + "_FOMODEND_" + pluginName, modFolder, ReadSetting (skPrefix), disableOthers, true, frequency);
    }
}

void PluginGen (bool advanced, bool disableOthers, string pluginName) {
    Log ("	Creating plugin files...");
    if (advanced) {
        int msgSetting = 1;
        if (ReadSetting (skMessages) == "optional") {
            msgSetting = 2;
        } else if (ReadSetting (skMessages) == "always") {
            msgSetting = 1;
        } else if (ReadSetting (skMessages) == "never") {
            msgSetting = 0;
        } else {
            msgSetting = 1;
            Log ("The messages option " + ReadSetting (skMessages) + " is invalid; \"always\" will be used instead.");
        }
        TStringList frequencyList = TStringList.Create ();
        frequencyList.Delimiter = ",";
        frequencyList.StrictDelimiter = True;
        frequencyList.DelimitedText = ReadSetting (skFrequencyList);
        for (int i = 0; i < frequencyList.Count (); i += 1) {
            CreateESPOptions (pluginName, ReadSetting (skModFolder), disableOthers, msgSetting, strtoint (frequencyList[i]));
        }
    } else {
        CreateESP (defaultPluginName, defaultModFolder, defaultPrefix, disableOthers, true, ReadSettingInt (skFrequency));
    }
}