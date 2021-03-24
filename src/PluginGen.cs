string globalPrefix = "JLS_";

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

IwbFile CreateESP (string fileName, string meshPath, string prefix, bool disableOthers, bool includeMessages, int frequency, string conditions) {
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
        ClearGroup (esp, "QUST");
        ClearGroup (esp, "SPEL");
        ClearGroup (esp, "MGEF");
        ClearGroup (esp, "CELL");
        CleanMasters (esp);
        SetValueString (esp, "File Header\\HEDR\\Next Object ID", "00000800");
        Add (esp, "LSCR", True);
        Add (esp, "STAT", True);

        // 0: no conditions = standalone
        // 1: always true conditions = replacer
        // 2: frequency with MCM
        // 3: frequency without MCM
        // 4: old frequency
        // 5: test mode

        float probability = 1.0 - Power (1.0 - 0.01 * frequency, 1.0 / totalLoadScreens);
        TStringList approximationArray = CreateRandomProbability (probability, 4);
        TStringList chanceGlobalList = TStringList.Create ();
        IwbMainRecord syncRandomVar;
        IwbMainRecord mcmFrequencyVar;
        IwbMainRecord globRecord;
        bool validConditions = true;
        if ((conditions == "standalone") || (conditions == "replacer")) {
            // do nothing
        } else if ((conditions == "mcm") || (conditions == "fixed")) {
            // https://www.creationkit.com/index.php?title=Detect_Player_Cell_Change_(Without_Polling)
            Add (esp, "GLOB", True);
            Add (esp, "QUST", True);
            Add (esp, "SPEL", True);
            Add (esp, "MGEF", True);
            Add (esp, "CELL", True);
            AddMasterIfMissing (esp, "Skyrim.esm");
            syncRandomVar = Add (GroupBySignature (esp, "GLOB"), "GLOB", True);
            SetEditorID (syncRandomVar, prefix + "SyncRandomVar");
            mcmFrequencyVar = Add (GroupBySignature (esp, "GLOB"), "GLOB", True);
            SetEditorID (mcmFrequencyVar, prefix + "McmFrequencyVar");
            SetValueInt (mcmFrequencyVar, "FLTV - Value", frequency);

            IwbMainRecord cellStalkerCell = Add (GroupBySignature (esp, "CELL"), "CELL", True);
            SetEditorID (cellStalkerCell, prefix + "CellStalkerCell");
            Add (cellStalkerCell, "FULL", true);
            SetValueString (cellStalkerCell, "FULL", prefix + "CellStalkerCell");

            IwbMainRecord cellStalkerMarker = Add (cellStalkerCell, "REFR\\REFR", True);
            SetValueString (cellStalkerMarker, "Record Header\\Record Flags", "00000000001");
            SetValueString (cellStalkerMarker, "NAME", "0000003B");
            IwbElement vmad = Add (cellStalkerMarker, "VMAD", true);
            IwbElement script = ElementAssign (ElementByPath (vmad, "Scripts"), HighInteger, Nil, false);
            SetValueString (script, "ScriptName", globalPrefix + "XMarkerReferenceScript");
            IwbElement randomVarProperty = ElementAssign (ElementByPath (script, "Properties"), HighInteger, Nil, false);
            SetValueString (randomVarProperty, "propertyName", "RandomVar");
            SetValueString (randomVarProperty, "Type", "Object");
            SetLinksTo (randomVarProperty, "Value\\Object Union\\Object v2\\FormID", syncRandomVar);
            IwbElement playerProperty = ElementAssign (ElementByPath (script, "Properties"), HighInteger, Nil, false);
            SetValueString (playerProperty, "propertyName", "PlayerRef");
            SetValueString (playerProperty, "Type", "Object");
            SetValueString (playerProperty, "Value\\Object Union\\Object v2\\FormID", "00000014");

            IwbMainRecord cellStalkerEffect = Add (GroupBySignature (esp, "MGEF"), "MGEF", True);
            SetEditorID (cellStalkerEffect, prefix + "CellStalkerEffect");
            Add (cellStalkerEffect, "FULL", true);
            SetValueString (cellStalkerEffect, "FULL", prefix + "CellStalkerEffect");
            IwbElement vmad = Add (cellStalkerEffect, "VMAD", true);
            IwbElement mgefData = Add (cellStalkerEffect, "Magic Effect Data", true);
            mgefData = ElementByPath (mgefData, "DATA");
            SetValueString (mgefData, "Flags", "0000000000000001");
            SetValueString (mgefData, "Magic Skill", "None");
            SetValueString (mgefData, "Resist Value", "None");
            SetValueString (mgefData, "Archtype", "Script");
            SetValueString (mgefData, "Delivery", "Self");
            SetValueString (mgefData, "Casting Type", "Constant Effect");
            SetValueString (mgefData, "Casting Sound Level", "Silent");
            IwbElement script = ElementAssign (ElementByPath (vmad, "Scripts"), HighInteger, Nil, false);
            SetValueString (script, "ScriptName", globalPrefix + "TrackInSameCell");
            IwbElement playerProperty = ElementAssign (ElementByPath (script, "Properties"), HighInteger, Nil, false);
            SetValueString (playerProperty, "propertyName", "PlayerRef");
            SetValueString (playerProperty, "Type", "Object");
            SetValueString (playerProperty, "Value\\Object Union\\Object v2\\FormID", "00000014");
            IwbElement markerProperty = ElementAssign (ElementByPath (script, "Properties"), HighInteger, Nil, false);
            SetValueString (markerProperty, "propertyName", "MarkerRef");
            SetValueString (markerProperty, "Type", "Object");
            SetLinksTo (markerProperty, "Value\\Object Union\\Object v2\\FormID", cellStalkerMarker);
            IwbElement randomVarProperty = ElementAssign (ElementByPath (script, "Properties"), HighInteger, Nil, false);
            SetValueString (randomVarProperty, "propertyName", "RandomVar");
            SetValueString (randomVarProperty, "Type", "Object");
            SetLinksTo (randomVarProperty, "Value\\Object Union\\Object v2\\FormID", syncRandomVar);

            IwbMainRecord healingSpell = RecordByFormID (FileByLoadOrder (0), 77772, true);
            IwbMainRecord cellStalkerSpell = wbCopyElementToFile (healingSpell, esp, true, true);
            SetEditorID (cellStalkerSpell, prefix + "CellStalkerSpell");
            SetValueString (cellStalkerSpell, "FULL", prefix + "CellStalkerSpell");
            SetValueString (cellStalkerSpell, "SPIT\\Type", "Ability");
            SetValueString (cellStalkerSpell, "SPIT\\Cast Type", "Constant Effect");
            SetValueString (cellStalkerSpell, "SPIT\\Half-cost Perk", "0");
            Remove (ElementByPath (cellStalkerSpell, "Effects\\[0]"));
            SetLinksTo (cellStalkerSpell, "Effects\\[0]\\EFID", CellStalkerEffect);
            SetValueInt (cellStalkerSpell, "Effects\\[0]\\EFIT\\Duration", 0);
            SetValueInt (cellStalkerSpell, "Effects\\[0]\\EFIT\\Magnitude", 0);

            IwbElement conditionData = ElementByPath (cellStalkerSpell, "Effects\\[0]\\Conditions\\[0]\\CTDA");
            SetValueString (conditionData, "Function", "GetInSameCell");
            SetLinksTo (conditionData, "Object Reference", cellStalkerMarker);
            SetValueInt (conditionData, "Comparison Value", 0);

            IwbMainRecord mcmQuest = Add (GroupBySignature (esp, "QUST"), "QUST", True);
            SetEditorID (mcmQuest, prefix + "MCM_Quest");
            Add (mcmQuest, "FULL", true);
            SetValueString (mcmQuest, "FULL", prefix + "MCM_Quest");
            SetValueInt (mcmQuest, "DNAM\\Flags", 100010001);
            SetValueInt (mcmQuest, "DNAM\\Form Version", 255);
            SetValueInt (mcmQuest, "ANAM", 1);
            //IwbElement alias = ElementAssign (ElementByPath (mcmQuest, "Aliases"), HighInteger, Nil, false);
            IwbElement alias = Add (mcmQuest, "Aliases", true);
            alias = ElementByPath (alias, "[0]");
            Add (alias, "ALID", true);
            SetValueString (alias, "ALID", prefix + "MCM_PlayerAlias");
            Add (alias, "FNAM", true);
            Add (alias, "ALFR", true);
            SetValueString (alias, "ALFR", "00000014");
            Add (alias, "VTCK", true);
            IwbElement aliasSpells = Add (alias, "ALSP", true);
            SetLinksTo (aliasSpells, "[0]", cellStalkerSpell);

            if (conditions == "mcm") {
                IwbElement vmad = Add (mcmQuest, "VMAD", true);

                IwbElement script = ElementAssign (ElementByPath (vmad, "Scripts"), HighInteger, Nil, false);
                SetValueString (script, "ScriptName", globalPrefix + "MCM_Quest_Script");
                IwbElement modNameProperty = ElementAssign (ElementByPath (script, "Properties"), HighInteger, Nil, false);
                SetValueString (modNameProperty, "propertyName", "ModName");
                SetValueString (modNameProperty, "Type", "String");
                SetValueString (modNameProperty, "String", ReadSetting (skModName));

                IwbElement frequencyProperty = ElementAssign (ElementByPath (script, "Properties"), HighInteger, Nil, false);
                SetValueString (frequencyProperty, "propertyName", "FrequencyProperty");
                SetValueString (frequencyProperty, "Type", "Object");
                SetLinksTo (frequencyProperty, "Value\\Object Union\\Object v2\\FormID", mcmFrequencyVar);

                alias = ElementAssign (ElementByPath (vmad, "Aliases"), HighInteger, Nil, false);
                SetLinksTo (alias, "Object Union\\Object v2\\FormID", mcmQuest);
                SetValueInt (alias, "Object Union\\Object v2\\Alias", 0);
                IwbElement aliasScript = ElementAssign (ElementByPath (alias, "Alias Scripts"), HighInteger, Nil, false);
                SetValueString (aliasScript, "ScriptName", "SKI_PlayerLoadGameAlias");
            }
        } else if (conditions == "deprecated") {
            Add (esp, "GLOB", True);
            for (int j = 0; j < approximationArray.Count (); j += 1) {
                IwbMainRecord chanceGlobal = Add (GroupBySignature (esp, "GLOB"), "GLOB", True);
                chanceGlobalList.add (IntToHex (GetLoadOrderFormID (chanceGlobal), 8));
                SetEditorID (chanceGlobal, prefix + "Chance_" + inttostr (j));
                SetValueInt (chanceGlobal, "FLTV - Value", Trunc (100 * strtofloat (approximationArray[j])) - 1);
                SetValueString (chanceGlobal, "Record Header\\Record Flags", "0000001");
            }
        } else if (conditions == "test") {
            Add (esp, "GLOB", True);
            if (ReadSettingBool (skTestMode)) {
                globRecord = Add (GroupBySignature (esp, "GLOB"), "GLOB", True);
                SetEditorID (globRecord, prefix + "TestMode");
            }
        } else {
            validConditions = false;
            Log ("No loading plugin generated for invalid conditions option: " + conditions);
        }
        if (validConditions) {
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

                if (conditions == "test") {
                    Add (lscrRecord, "Conditions", True);
                    SetValueInt (lscrRecord, "Conditions\\[0]\\CTDA\\Type", 10000000);
                    SetValueInt (lscrRecord, "Conditions\\[0]\\CTDA\\Comparison Value", i);
                    SetValueString (lscrRecord, "Conditions\\[0]\\CTDA\\Function", "GetGlobalValue");
                    SetLinksTo (lscrRecord, "Conditions\\[0]\\CTDA\\Global", globRecord);
                } else {
                    if (conditions == "replacer") {
                        Add (lscrRecord, "Conditions", True);
                        SetValueInt (lscrRecord, "Conditions\\[0]\\CTDA\\Type", 10100000);
                        SetValueInt (lscrRecord, "Conditions\\[0]\\CTDA\\Comparison Value", 100);
                        SetValueString (lscrRecord, "Conditions\\[0]\\CTDA\\Function", "GetRandomPercent");
                    } else if ((conditions == "mcm") || (conditions == "fixed")) {
                        Add (lscrRecord, "Conditions", True);
                        SetValueInt (lscrRecord, "Conditions\\[0]\\CTDA\\Type", 10100100);
                        SetLinksTo (lscrRecord, "Conditions\\[0]\\CTDA\\Comparison Value", mcmFrequencyVar);
                        SetValueString (lscrRecord, "Conditions\\[0]\\CTDA\\Function", "GetGlobalValue");
                        SetLinksTo (lscrRecord, "Conditions\\[0]\\CTDA\\Global", syncRandomVar);
                    } else if (conditions == "deprecated") {
                        Add (lscrRecord, "Conditions", True);
                        for (int j = 0; j < approximationArray.Count (); j += 1) {
                            ElementAssign (ElementByPath (lscrRecord, "Conditions"), HighInteger, nil, false);
                            SetValueInt (lscrRecord, "Conditions\\[" + inttostr (j) + "]\\CTDA\\Type", 10100100);
                            SetValueString (lscrRecord, "Conditions\\[" + inttostr (j) + "]\\CTDA\\Comparison Value", chanceGlobalList[j]);
                            SetValueString (lscrRecord, "Conditions\\[" + inttostr (j) + "]\\CTDA\\Function", "GetRandomPercent");
                        }
                        Remove (ElementByPath (lscrRecord, "Conditions\\[" + inttostr (approximationArray.Count ()) + "]"));
                    }
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
}

void CreateESPOptions (string pluginName, string modFolder, bool disableOthers, int msgSetting, int frequency, string conditions) {

    if (msgSetting == 0) {
        CreateESP ("FOMOD_M0_P_" + conditions + "_" + inttostr (frequency) + "_FOMODEND_" + pluginName, modFolder, ReadSetting (skPrefix), disableOthers, false, frequency, conditions);
    } else if (msgSetting == 1) {
        CreateESP ("FOMOD_M1_P_" + conditions + "_" + inttostr (frequency) + "_FOMODEND_" + pluginName, modFolder, ReadSetting (skPrefix), disableOthers, true, frequency, conditions);
    } else if (msgSetting == 2) {
        CreateESP ("FOMOD_M0_P_" + conditions + "_" + inttostr (frequency) + "_FOMODEND_" + pluginName, modFolder, ReadSetting (skPrefix), disableOthers, false, frequency, conditions);
        CreateESP ("FOMOD_M1_P_" + conditions + "_" + inttostr (frequency) + "_FOMODEND_" + pluginName, modFolder, ReadSetting (skPrefix), disableOthers, true, frequency, conditions);
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
        TStringList conditionList = TStringList.Create ();
        conditionList.Delimiter = ",";
        conditionList.StrictDelimiter = True;
        conditionList.DelimitedText = ReadSetting (skConditionList);
        for (int i = 0; i < conditionList.Count (); i += 1) {
            CreateESPOptions (pluginName, ReadSetting (skModFolder), disableOthers, msgSetting, ReadSettingInt (skFrequency), conditionList[i]);
        }
    } else {
        CreateESP (defaultPluginName, defaultModFolder, defaultPrefix, disableOthers, true, ReadSettingInt (skFrequency), ReadSetting (skCondition));
    }
}