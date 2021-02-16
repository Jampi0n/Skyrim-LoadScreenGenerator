TStringList settings;
int settingKey;

int skSourcePath, skDisableOtherLoadScreens, skDisplayWidth, skDisplayHeight, skStretch, skRecursive, skFullHeight,
skFrequency, skGamma, skContrast, skBrightness, skSaturation, skBorderOptions, skResolution, skModName, skModVersion,
skModFolder, skPluginName, skModAuthor, skPrefix, skModLink, skTestMode, skAspectRatios, skTextureResolutions,
skMessages, skFrequencyList, skDefaultFrequency, skChooseBorderOption;

int GetSettingKey (string def) {
    if (settings.Count () <= settingKey) {
        settings.Add ("");
        WriteSetting (settingKey, def);
    }
    settingKey += 1;
    return settingKey - 1;
}

void SaveSettings () {
    settings.SaveToFile (editScriptsSubFolder + "\\" + settingsName);
}

void WriteSetting (int idx, string value) {
    settings[idx] = value;
}

string ReadSetting (int idx) {
    return settings[idx];
}

float ReadSettingFloat (int idx) {
    return strtofloat (settings[idx]);
}

int ReadSettingInt (int idx) {
    return strtoint (settings[idx]);
}

bool ReadSettingBool (int idx) {
    return settings[idx] == "True";
}

void InitSettings () {

    editScriptsSubFolder = ScriptsPath + scriptName;
    settings = TStringList.Create;
    messageLog = TStringList.Create;
    settingKey = 0;
    if (FileExists (editScriptsSubFolder + "\\" + settingsName)) {

        settings.LoadFromFile (editScriptsSubFolder + "\\" + settingsName);

    }
}

void InitSettingKeys () {
    skSourcePath = GetSettingKey ("");
    skDisableOtherLoadScreens = GetSettingKey ("True");
    int gcdResolution = GCD (Screen.Width, Screen.Height);
    skDisplayWidth = GetSettingKey (inttostr (Screen.Width / gcdResolution));
    skDisplayHeight = GetSettingKey (inttostr (Screen.Height / gcdResolution));
    skStretch = GetSettingKey ("False");
    skRecursive = GetSettingKey ("False");

    skGamma = GetSettingKey ("1.0");
    skContrast = GetSettingKey ("0");

    skBrightness = GetSettingKey ("0");
    skSaturation = GetSettingKey ("0");

    skFullHeight = GetSettingKey ("False");
    skTestMode = GetSettingKey ("False");
    skFrequency = GetSettingKey ("100");

    skModName = GetSettingKey ("Nazeem's Loading Screen Mod");
    skModVersion = GetSettingKey ("1.0.0");
    skModFolder = GetSettingKey ("NazeemLoadScreens");
    skPluginName = GetSettingKey ("NazeemsLoadingScreenMod.esp");
    skModAuthor = GetSettingKey ("Nazeem");
    skPrefix = GetSettingKey ("Nzm_");
    skAspectRatios = GetSettingKey ("16x9,16x10,21x9,4x3");
    skTextureResolutions = GetSettingKey ("2");
    skMessages = GetSettingKey ("optional");

    skFrequencyList = GetSettingKey ("5,10,15,25,35,50,70,100");
    skDefaultFrequency = GetSettingKey ("15");

    skModLink = GetSettingKey ("https://www.nexusmods.com/skyrimspecialedition/mods/36556");

    skBorderOptions = GetSettingKey ("black");
    skResolution = GetSettingKey ("2048");

    skChooseBorderOption = GetSettingKey ("True");

}