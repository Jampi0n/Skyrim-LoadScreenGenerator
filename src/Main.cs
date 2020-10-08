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

const string version = "1.2.0";
const string defaultModFolder = "JLoadScreens";
const string defaultPrefix = "JLS_";
const string defaultPluginName = "JLoadScreens.esp";
const string scriptName = "JLoadScreens";
const string settingsName = "Settings.txt";

string editScriptsSubFolder;

int totalLoadScreens;

float gamma, blackPoint, whitePoint, brightness, saturation;
TStringList imagePathArray, imageWidthArray, imageHeightArray, imageTextArray;

bool error = false;
TForm mainForm;




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
        texturePathShort = "textures\\" + ReadSetting (skModFolder);
    } else {
        texturePathShort = "textures\\JLoadScreens";
    }
    string texturePath = DataPath + texturePathShort;
    // MO2 automatically creates folders
    // Force directories, so it works without MO2
    forcedirectories (texturePath);

    // Create .dds files in texture path
    ProcessTextures (sourcePath, texturePath, recursive);
    Log ("  Using " + inttostr (totalLoadScreens) + " images for loading screen generation.");
    Log ("	");

    // Create .nif files in mesh path
    MeshGen(advanced, texturePathShort);

    // Create .esp
    PluginGen(advanced, disableOthers, pluginName);

    if (advanced) {
        Log ("	Copying build files...");
        CopyFile (editScriptsSubFolder + "\\Custom\\create_fomod.cmd", DataPath + "create_fomod.cmd", false);
        CopyFile (editScriptsSubFolder + "\\Custom\\create_fomod.py", DataPath + "create_fomod.py", false);
        CopyFile (editScriptsSubFolder + "\\settings.txt", DataPath + "settings.txt", false);
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

        TGroupBox optionsBox = AddBox (modBox, 0, modBox.Height + 8, mainForm.Width - 24, 128, "Options");

        TLabel messagesLabel = AddLabel (optionsBox, 16, 24, 160, 24, "Messages");
        TEdit messagesLine = AddLine (messagesLabel, 80, -4, mainForm.Width - 128, ReadSetting (skMessages), "always/never/optional");

        TLabel frequencyListLabel = AddLabel (messagesLabel, 0, 24, 160, 24, "Freq. List");
        TEdit frequencyListLine = AddLine (frequencyListLabel, 80, -4, mainForm.Width - 128, ReadSetting (skFrequencyList), "Comma separated list of frequencies, e.g. \"5, 15, 50, 100\"");

        TLabel frequencyDefaultLabel = AddLabel (frequencyListLabel, 0, 24, 160, 24, "Def. Freq.");
        TEdit frequencyDefaultLine = AddLine (frequencyDefaultLabel, 80, -4, mainForm.Width - 128, ReadSetting (skDefaultFrequency), "Default frequency.");

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
            WriteSetting (skFrequencyList, frequencyListLine.Text);
            WriteSetting (skDefaultFrequency, frequencyDefaultLine.Text);

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
        TCheckBox checkBoxTestMode = AddCheckBox (checkBoxSubDirs, 0, 16, ReadSettingBool (skTestMode), "Test Mode", "Adds a global variable, which can be used to force specific loading screens.");
        TLabel frequencyLabel = AddLabel (checkBoxTestMode, 0, 24, 64, 24, "Frequency:");
        TEdit frequencyLine = AddLine (frequencyLabel, 60, -4, 40, ReadSetting (skFrequency), "Loading screen frequency: 0 - 100");
        TLabel borderLabel = AddLabel (frequencyLabel, 0, 24, 64, 24, "Border Options:");
        TEdit borderLine = AddLine (borderLabel, 80, -4, 96, ReadSetting (skBorderOptions), "black,crop,stretch,fullheight,fullwidth");


        TLabel resolutionLabel = AddLabel (optionsBox, 224, 18, 64, 24, "Texture Resolution:");
        TEdit resolutionLine = AddLine (resolutionLabel, 96, -4, 48, ReadSetting (skResolution), "Texture Resolution: e.g 1024, 2048, 4096");

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
        TButton btnAdvanced = AddButton (nil, mainForm.Width - 96, mainForm.Height - 64, "Advanced", 2);

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

            tmpInt = strtoint(resolutionLine.Text);
            if (tmpInt > 0) {
                WriteSetting (skResolution, tmpInt);
            } else {
                ErrorMsg ("Resolution must be positive number.");
            }
            

            WriteSetting (skDisableOtherLoadScreens, checkBoxDisableOthers.Checked);
            WriteSetting (skRecursive, checkBoxSubDirs.Checked);

            string tmpStr = borderLine.Text;
            if ((tmpStr == "black") || (tmpStr == "crop") || (tmpStr == "fullheight") || (tmpStr == "fullwidth") || (tmpStr == "stretch")) {

                WriteSetting (skBorderOptions, tmpStr);
            } else {
                ErrorMsg ("Border option <" + tmpStr + "> is unknown.");
            }

            WriteSetting (skTestMode, checkBoxTestMode.Checked);

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