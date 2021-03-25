/*
    Produces a fully working standalone loading screen mod from images in a selected directory.
    Supported image types: .jpg, .png, .dds
    The images in the directory are not modified in any way.They are only used to create skyrim compatible textures from them.

    The script will work the same regardless of which record it is used on.

    Output meshes and textures are put in the data folder at "textures\JLoadScreens" and "meshes\JLoadScreens".
    If you start xedit with a mod manager like MO2, the files will appear in the overwrite folder of the mod manager.

    For help, feature suggestions or bug reports visit the mod page:
*/

// unit _J_LoadScreenGenerator

// import ./MathUtils.cs
// import ./UserInterfaceUtils.cs
// import ./XEditUtils.cs
// import ./Settings.cs
// import ./Logger.cs
// import ./PluginGen.cs
// import ./MeshGen.cs
// import ./TextureGen.cs

const string version = "1.3.0";
const string defaultModFolder = "JLoadScreens";
const string defaultPrefix = "JLS_";
const string defaultPluginName = "JLoadScreens.esp";
const string scriptName = "JLoadScreens";
const string settingsName = "Settings.txt";

const string advancedOutputFolder = "JLoadScreensAdvanced";

string editScriptsSubFolder;

int totalLoadScreens;

float gamma, blackPoint, whitePoint, brightness, saturation;
TStringList imagePathArray, imageWidthArray, imageHeightArray, imageTextArray;

bool error = false;
TForm mainForm;

void CopyFromCustom (string path, bool advanced) {
    if (advanced) {
        CopyFile (editScriptsSubFolder + "\\Custom\\" + path, DataPath + "\\" + advancedOutputFolder + "\\" + path, false);
    } else {
        CopyFile (editScriptsSubFolder + "\\Custom\\" + path, DataPath + "\\" + path, false);
    }
}

void Main (string sourcePath, bool disableOthers, bool recursive, bool advanced) {
    if (advanced) {
        Log ("	Running advanved generator...");
    } else {
        Log ("	Running basic generator...");
    }
    Log ("	Using source path: " + sourcePath);
    string templatePath = editScriptsSubFolder;

    string pluginName = ReadSetting (skPluginName);
    string texturePathShort;
    if (advanced) {
        texturePathShort = advancedOutputFolder + "\\textures\\" + ReadSetting (skModFolder);
    } else {
        texturePathShort = "textures\\" + defaultModFolder;
    }
    string texturePath = DataPath + texturePathShort;
    // MO2 automatically creates folders
    // Force directories, so it works without MO2
    forcedirectories (texturePath);

    // Create .dds files in texture path
    ProcessTextures (sourcePath, texturePath, recursive, advanced);
    Log ("  Using " + inttostr (totalLoadScreens) + " images for loading screen generation.");
    Log ("	");

    // Create .nif files in mesh path
    if (ReadSettingBool (skGenerateMeshes) || !advanced) {
        MeshGen (advanced, texturePathShort, templatePath);
    }

    // Create .esp
    PluginGen (advanced, disableOthers, pluginName);

    if (advanced) {
        Log ("	Copying build files...");
        CopyFromCustom ("create_fomod.cmd", advanced);
        CopyFromCustom ("create_fomod.py", advanced);
        // settings.txt is not located in /custom/
        CopyFile (editScriptsSubFolder + "\\settings.txt", DataPath + "\\" + advancedOutputFolder + "\\settings.txt", false);
        forcedirectories (DataPath + "\\" + advancedOutputFolder + "\\images");
        CopyFromCustom ("images\\black.png", advanced);
        CopyFromCustom ("images\\crop.png", advanced);
        CopyFromCustom ("images\\stretch.png", advanced);
        CopyFromCustom ("images\\fullwidth.png", advanced);
        CopyFromCustom ("images\\fullheight.png", advanced);
        // copy scripts regardless of options
        forcedirectories (DataPath + "\\" + advancedOutputFolder + "\\scripts\\source");
        CopyFromCustom ("scripts\\JLS_MCM_Quest_Script.pex", advanced);
        CopyFromCustom ("scripts\\JLS_TrackInSameCell.pex", advanced);
        CopyFromCustom ("scripts\\JLS_XMarkerReferenceScript.pex", advanced);
        CopyFromCustom ("scripts\\source\\JLS_MCM_Quest_Script.psc", advanced);
        CopyFromCustom ("scripts\\source\\JLS_TrackInSameCell.psc", advanced);
        CopyFromCustom ("scripts\\source\\JLS_XMarkerReferenceScript.psc", advanced);
    } else {
        if ((ReadSetting (skCondition) == "mcm") || (ReadSetting (skCondition) == "fixed")) {
            // copy scripts
            forcedirectories (DataPath + "\\scripts\\source");
            CopyFromCustom ("scripts\\JLS_MCM_Quest_Script.pex", advanced);
            CopyFromCustom ("scripts\\JLS_TrackInSameCell.pex", advanced);
            CopyFromCustom ("scripts\\JLS_XMarkerReferenceScript.pex", advanced);
            CopyFromCustom ("scripts\\source\\JLS_MCM_Quest_Script.psc", advanced);
            CopyFromCustom ("scripts\\source\\JLS_TrackInSameCell.psc", advanced);
            CopyFromCustom ("scripts\\source\\JLS_XMarkerReferenceScript.psc", advanced);
        }
    }
    Log ("	Done");
}

void PickSourcePath (TObject Sender) {
    string path = ReadSetting (skSourcePath);
    path = SelectDirectory ("Select folder for generated meshes", "", path, "");
    if (path != "\\") {
        Sender.Text = path;
        WriteSetting (skSourcePath, path);
    }
}

TEdit ImageAdjustment (TForm prevAdj, string lineText, string description) {
    TEdit line = TEdit.Create (prevAdj.Parent);
    line.Parent = prevAdj.Parent;
    line.Top = prevAdj.Top + prevAdj.Height;
    line.Left = 16;
    line.Width = 64;
    line.Caption = lineText;
    line.Font.Size = 10;

    TLabel lbl = TLabel.Create (prevAdj.Parent);
    lbl.Parent = prevAdj.Parent;
    lbl.Left = line.Left + line.Width + 8;
    lbl.Top = line.Top + 4;
    lbl.Width = 200;
    lbl.Height = 64;
    lbl.Caption = description;
    lbl.Font.Size = 10;
    Result = line;
}

int Advanced () {
    mainForm = TForm.Create (nil);
    try {
        mainForm.Caption = "Jampion's Loading Screen Generator";
        mainForm.Width = 640;
        mainForm.Height = 500;
        mainForm.Position = poScreenCenter;

        TGroupBox aspectRatioBox = AddBox (mainForm, 8, 8, mainForm.Width - 24, 48, "Aspect Ratios");
        TEdit screenResolutionLine = AddLine (aspectRatioBox, 16, 16, mainForm.Width - 128, ReadSetting (skAspectRatios), "Comma separated list of aspect ratios, e.g. \"16x9, 16x10, 21x9\"");

        TGroupBox modBox = AddBox (aspectRatioBox, 0, aspectRatioBox.Height + 8, mainForm.Width - 24, 192, "Mod Configuration");

        TLabel modNameLabel = AddLabel (modBox, 16, 24, 160, 24, "Mod name");
        TEdit modNameLine = AddLine (modNameLabel, 80, -4, mainForm.Width - 128, ReadSetting (skModName), "The display name of the mod. Will be used for the FOMOD installer.");

        TLabel modVersionLabel = AddLabel (modNameLabel, 0, 24, 160, 24, "Mod version");
        TEdit modVersionLine = AddLine (modVersionLabel, 80, -4, mainForm.Width - 128, ReadSetting (skModVersion), "Will be used for the FOMOD installer.");

        TLabel modFolderLabel = AddLabel (modVersionLabel, 0, 24, 160, 24, "Sub folder");
        TEdit modFolderLine = AddLine (modFolderLabel, 80, -4, mainForm.Width - 128, ReadSetting (skModFolder), "Sub folder, in which textures and meshes are generated. \"MyMod\" will result in \"textures / MyMod\" and \"meshes / MyMod\".");

        TLabel modAuthorLabel = AddLabel (modFolderLabel, 0, 24, 160, 24, "Author");
        TEdit modAuthorLine = AddLine (modAuthorLabel, 80, -4, mainForm.Width - 128, ReadSetting (skModAuthor), "Your name :).");

        TLabel modPluginLabel = AddLabel (modAuthorLabel, 0, 24, 160, 24, "Plugin");
        TEdit modPluginLine = AddLine (modPluginLabel, 80, -4, mainForm.Width - 128, ReadSetting (skPluginName), "The name of the generated plugin (with extension).");

        TLabel modPrefixLabel = AddLabel (modPluginLabel, 0, 24, 160, 24, "Prefix");
        TEdit modPrefixLine = AddLine (modPrefixLabel, 80, -4, mainForm.Width - 128, ReadSetting (skPrefix), "This prefix is added to all records.");

        TLabel modLinkLabel = AddLabel (modPrefixLabel, 0, 24, 160, 24, "Prefix");
        TEdit modLinkLine = AddLine (modLinkLabel, 80, -4, mainForm.Width - 128, ReadSetting (skModLink), "Will be used for the FOMOD installer.");

        TGroupBox optionsBox = AddBox (modBox, 0, modBox.Height + 8, mainForm.Width - 24, 168, "Options");

        TLabel messagesLabel = AddLabel (optionsBox, 16, 24, 160, 24, "Messages");
        TEdit messagesLine = AddLine (messagesLabel, 80, -4, mainForm.Width - 128, ReadSetting (skMessages), "always/never/optional");

        TLabel conditionsListLabel = AddLabel (messagesLabel, 0, 24, 160, 24, "Cond. List");
        TEdit conditionsListLine = AddLine (conditionsListLabel, 80, -4, mainForm.Width - 128, ReadSetting (skConditionList), "Comma separated list of condition options, e.g. \"standalone,replacer,mcm\"");

        //TLabel frequencyDefaultLabel = AddLabel (frequencyListLabel, 0, 24, 160, 24, "Def. Freq.");
        //TEdit frequencyDefaultLine = AddLine (frequencyDefaultLabel, 80, -4, mainForm.Width - 128, ReadSetting (skDefaultFrequency), "Default frequency.");

        TCheckBox chooseBorderOptionsCheckBox = AddCheckBox (conditionsListLabel, 0, 24, ReadSettingBool (skChooseBorderOption), "Choose Border", "Adds border options to the FOMOD installer.");

        TCheckBox generateTexturesCheckBox = AddCheckBox (chooseBorderOptionsCheckBox, 0, 24, ReadSettingBool (skGenerateTextures), "Generate Textures", "This step takes long and can be disabled, if the textures were generated previously. Make sure only valid images are in the directory, as image processing/validation may be skipped.");

        TCheckBox generateMeshesCheckBox = AddCheckBox (generateTexturesCheckBox, 0, 24, ReadSettingBool (skGenerateMeshes), "Generate Meshes", "This step takes long and can be disabled, if the meshes were generated previously. Make sure only valid images are in the directory, as image processing/validation may be skipped.");

        TButton btnOk = AddButton (nil, 8, mainForm.Height - 64, "OK", 1);
        TButton btnCancel = AddButton (btnOk, 80, 0, "Cancel", 2);
        int modalResult = mainForm.ShowModal;
        if (modalResult == 1) {

            WriteSetting (skAspectRatios, screenResolutionLine.Text);
            WriteSetting (skModName, modNameLine.Text);
            WriteSetting (skModVersion, modVersionLine.Text);
            WriteSetting (skModFolder, modFolderLine.Text);
            WriteSetting (skModAuthor, modAuthorLine.Text);
            WriteSetting (skPluginName, modPluginLine.Text);
            WriteSetting (skPrefix, modPrefixLine.Text);
            WriteSetting (skModLink, modLinkLine.Text);
            WriteSetting (skMessages, messagesLine.Text);
            WriteSetting (skConditionList, conditionsListLine.Text);
            //WriteSetting (skDefaultFrequency, frequencyDefaultLine.Text);
            WriteSetting (skChooseBorderOption, chooseBorderOptionsCheckBox.Checked);
            WriteSetting (skGenerateTextures, generateTexturesCheckBox.Checked);
            WriteSetting (skGenerateMeshes, generateMeshesCheckBox.Checked);

            SaveSettings ();
            if (!error) {
                Main (ReadSetting (skSourcePath), ReadSettingBool (skDisableOtherLoadScreens), ReadSettingBool (skRecursive), true);
            } else {
                Log ("	");
                Log ("At least one setting has an incorrect value.");
                Log ("	");
            }
        }
    } finally {
        mainForm.Free;
    }

}

int UI () {
    mainForm = TForm.Create (nil);
    try {
        mainForm.Caption = "Jampion's Loading Screen Generator";
        mainForm.Width = 640;
        mainForm.Height = 500;
        mainForm.Position = poScreenCenter;

        TGroupBox selectDirBox = AddBox (mainForm, 8, 0, mainForm.Width - 24, 48, "Source Directory");
        TEdit selectDirLine = AddLine (selectDirBox, 8, 16, mainForm.Width - 128, ReadSetting (skSourcePath), "Click to select folder in explorer.");
        selectDirLine.OnClick = PickSourcePath;

        TGroupBox aspectRatioBox = AddBox (selectDirBox, 0, selectDirBox.Height + 8, mainForm.Width - 24, 80, "Target Aspect Ratio");

        TEdit widthLine = AddLine (aspectRatioBox, 8, 16, 64, ReadSetting (skDisplayWidth), "Enter your display width.");
        TLabel colonLabel = AddLabel (widthLine, widthLine.Width, 0, 8, 30, ":");
        colonLabel.Font.Size = 12;
        TEdit heightLine = AddLine (colonLabel, 8, 0, 64, ReadSetting (skDisplayHeight), "Enter your display height.");

        TLabel aspectRatioLabel = AddLabel (widthLine, 0, widthLine.Height, aspectRatioBox.Width - 16, 120,
            "The loading screens will be generated for this aspect ratio.\n" +
            "Either use your resolution (e.g. 1920:1080) or your aspect ratio (e.g. 16:9)."
        );
        aspectRatioLabel.Font.Size = 9;

        TGroupBox optionsBox = AddBox (aspectRatioBox, 0, aspectRatioBox.Height + 8, mainForm.Width - 24, 128, "Options");

        TCheckBox checkBoxDisableOthers = AddCheckBox (optionsBox, 8, 16, ReadSettingBool (skDisableOtherLoadScreens), "Disable other Loading Screens", "Prevents other loading screens (other mods and vanilla) from showing.");
        TCheckBox checkBoxSubDirs = AddCheckBox (checkBoxDisableOthers, 0, 16, ReadSettingBool (skRecursive), "Include subdirectories", "Includes subdirectories of the source directory, when searching for images.");
        //TCheckBox checkBoxTestMode = AddCheckBox (checkBoxSubDirs, 0, 16, ReadSettingBool (skTestMode), "Test Mode", "Adds a global variable, which can be used to force specific loading screens.");
        TLabel frequencyLabel = AddLabel (checkBoxSubDirs, 0, 24, 64, 24, "Frequency:");
        TEdit frequencyLine = AddLine (frequencyLabel, 60, -4, 40, ReadSetting (skFrequency), "Loading screen frequency: 0 - 100. Only used together with \"mcm\" or \"fixed\" condition options.");

        TLabel conditionLabel = AddLabel (frequencyLabel, 0, 24, 64, 24, "Cond. Options:");
        TComboBox conditionBox = AddComboBox (conditionLabel, 80, -4, 96, ReadSetting (skCondition), "standalone,replacer,mcm,fixed", "Under which conditions the loading screens are shown.");

        TLabel borderLabel = AddLabel (conditionLabel, 0, 24, 64, 24, "Border Options:");
        TComboBox borderBox = AddComboBox (borderLabel, 80, -4, 96, ReadSetting (skBorderOptions), "black,crop,stretch,fullheight,fullwidth", "How images with different aspect ratios are displayed.");

        TLabel resolutionLabel = AddLabel (optionsBox, 224, 18, 64, 24, "Texture Resolution:");
        TComboBox resolutionBox = AddComboBox (resolutionLabel, 96, -4, 64, ReadSetting (skResolution), "1024,2048,4096,8192", "Resolution of the generated textures.");

        TGroupBox imageAdjustmentBox = TGroupBox.Create (mainForm);
        imageAdjustmentBox.Parent = mainForm;
        imageAdjustmentBox.Top = optionsBox.Top + optionsBox.Height + 8;
        imageAdjustmentBox.Left = 8;
        imageAdjustmentBox.Caption = "Image Adjustments";
        imageAdjustmentBox.Font.Size = 10;
        imageAdjustmentBox.ClientWidth = mainForm.Width - 24;
        imageAdjustmentBox.ClientHeight = 152;

        TLabel imageAdjustmentLabel = TLabel.Create (mainForm);
        imageAdjustmentLabel.Parent = mainForm;
        imageAdjustmentLabel.Width = imageAdjustmentBox.Width - 16;
        imageAdjustmentLabel.Height = 80;
        imageAdjustmentLabel.Left = 16;
        imageAdjustmentLabel.Top = imageAdjustmentBox.Top + 20;
        imageAdjustmentLabel.Caption =
            "ENBs and other post processing programs will also affect loading screens.\n" +
            "You can try these image adjustments in order to counteract the changes of post processing effects.";
        imageAdjustmentLabel.Font.Size = 9;

        TEdit brightnessLine = ImageAdjustment (imageAdjustmentLabel, inttostr (ReadSettingInt (skBrightness)), "Brightness: Default: 0, Range -100 - +100");
        TEdit contrastLine = ImageAdjustment (brightnessLine, inttostr (ReadSettingInt (skContrast)), "Contrast: Default: 0, Range -100 - +100");
        TEdit saturationLine = ImageAdjustment (contrastLine, inttostr (ReadSettingInt (skSaturation)), "Saturation: Default: 0, Range -100 - +100");
        TEdit gammaLine = ImageAdjustment (saturationLine, floattostr (ReadSetting (skGamma)), "Gamma: Increase to brighten the loading screens. Default: 1.0, Range: 0.0 - 4.0");

        TButton btnOk = AddButton (nil, 8, mainForm.Height - 64, "OK", 1);
        TButton btnCancel = AddButton (btnOk, btnOk.Width + 16, 0, "Cancel", -1);
        TButton btnAdvanced = AddButton (nil, mainForm.Width - 112, mainForm.Height - 64, "FOMOD Creator", 2);
        btnAdvanced.width = 96;

        int modalResult = mainForm.ShowModal;
        if ((modalResult == 1) || (modalResult == 2)) {
            if (DirectoryExists (selectDirLine.Text)) {
                WriteSetting (skSourcePath, selectDirLine.Text);
            } else { ErrorMsg ("The source directory does not exist."); }

            int tmpInt = strtoint (widthLine.Text);

            if (tmpInt > 0) {
                WriteSetting (skDisplayWidth, tmpInt);
            } else {
                ErrorMsg ("Width must be a positive number.");
            }
            tmpInt = strtoint (heightLine.Text);
            if (tmpInt > 0) {
                WriteSetting (skDisplayHeight, tmpInt);
            } else {
                ErrorMsg ("Height must be positive number.");
            }

            tmpInt = strtoint (resolutionBox.Text);
            if (tmpInt > 0) {
                WriteSetting (skResolution, tmpInt);
            } else {
                ErrorMsg ("Resolution must be positive number.");
            }

            WriteSetting (skDisableOtherLoadScreens, checkBoxDisableOthers.Checked);
            WriteSetting (skRecursive, checkBoxSubDirs.Checked);

            string tmpStr = borderBox.Text;
            if ((tmpStr == "black") || (tmpStr == "crop") || (tmpStr == "fullheight") || (tmpStr == "fullwidth") || (tmpStr == "stretch")) {
                WriteSetting (skBorderOptions, tmpStr);
            } else {
                ErrorMsg ("Border option <" + tmpStr + "> is unknown.");
            }

            string tmpStr = conditionBox.Text;
            if ((tmpStr == "standalone") || (tmpStr == "replacer") || (tmpStr == "mcm") || (tmpStr == "fixed") || (tmpStr == "test") || (tmpStr == "deprecated")) {
                WriteSetting (skCondition, tmpStr);
            } else {
                ErrorMsg ("Condition option <" + tmpStr + "> is unknown.");
            }

            //WriteSetting (skTestMode, checkBoxTestMode.Checked);

            tmpInt = strtoint (frequencyLine.Text);
            if ((tmpInt >= 0) && (tmpInt <= 100)) { WriteSetting (skFrequency, tmpInt); } else { ErrorMsg ("Frequency must be between 0 and +100."); }

            brightness = strtoint (brightnessLine.Text);
            if ((brightness >= -100) && (brightness <= 100)) { WriteSetting (skBrightness, brightness); } else { ErrorMsg ("Brightness must be between -100 and +100."); }

            tmpInt = strtoint (contrastLine.Text);
            if ((tmpInt >= -100) && (tmpInt <= 100)) { WriteSetting (skContrast, tmpInt); } else { ErrorMsg ("Contrast must be between -100 and +100."); }

            if (tmpInt >= 0) {

                blackPoint = tmpInt * 0.5;
                whitePoint = 100.0 - tmpInt * 0.5;
            } else {
                blackPoint = tmpInt * 1.0;
                whitePoint = 100.0 - tmpInt * 1.0;
            }

            saturation = strtoint (saturationLine.Text);
            if ((saturation >= -100) && (saturation <= 100)) { WriteSetting (skSaturation, saturation); } else { ErrorMsg ("Saturation must be between -100 and +100."); }

            gamma = strtofloat (gammaLine.Text);
            if ((gamma >= 0.0) && (gamma <= 4.0)) { WriteSetting (skGamma, gamma); } else { ErrorMsg ("Gamma must be between 0.0 and 4.0."); }

            SaveSettings ();
            if (!error) {

                brightness = brightness + 100;
                saturation = saturation + 100;
                if (modalResult == 1) {

                    Main (ReadSetting (skSourcePath), ReadSettingBool (skDisableOtherLoadScreens), ReadSettingBool (skRecursive), false);
                }
            } else {
                Log ("	");
                Log ("At least one setting has an incorrect value.");
                Log ("	");
            }
        }
    } finally {
        mainForm.Free;
    }

    if ((modalResult == 2) && !error) {
        Advanced ();
    }
}

void __initialize__ () {
    InitSettings ();
    InitSettingKeys ();

    Log ("	");
    Log ("	Running JLoadScreenGenerator " + version);
    try {
        UI ();
    } catch (Exception E) {
        Log ("Error while running " + scriptName);
        Log (E.ClassName + " error raised, with message : " + E.Message);
    }
}