{
    Produces a fully working standalone loading screen mod from images in a selected directory.
    Supported image types: .jpg, .png, .dds
    The images in the directory are not modified in any way.They are only used to create skyrim compatible textures from them.

    The script will work the same regardless of which record it is used on.

    Output meshes and textures are put in the data folder at "textures\JLoadScreens" and "meshes\JLoadScreens".
    If you start xedit with a mod manager like MO2, the files will appear in the overwrite folder of the mod manager.

    For help, feature suggestions or bug reports visit the mod page:
}

unit _J_LoadScreenGenerator;

const
    sourceUpperWidth = 45.5;
    sourceLowerWidth = 1.1;
    sourceHeightOffset = 1.0;
    sourceHeight = 29.0;
    sourceOffsetX = 2.5;
    sourceOffsetY = 0.65;
    sourceRatio = 1.6;
    version = '1.2.0';
    defaultModFolder = 'JLoadScreens';
    defaultPrefix = 'JLS_';
    defaultPluginName = 'JLoadScreens.esp';
    scriptName = 'JLoadScreens';
    settingsName = 'Settings.txt';

var
    settings : TStringList;
    settingKey : Integer;
    skSourcePath, skDisableOtherLoadScreens, skDisplayWidth, skDisplayHeight, skStretch, skRecursive, skFullHeight, skFrequency, skGamma, skContrast, skBrightness, skSaturation, skBorderOptions, skResolution, skModName, skModVersion, skModFolder, skPluginName, skModAuthor, skPrefix, skModLink, skTestMode, skAspectRatios, skTextureResolutions, skMessages, skFrequencyList, skDefaultFrequency : Integer;
    messageLog : TStringList;
    heightFactor : Real;
    widthFactor : Real;
    editScriptsSubFolder : String;
    totalLoadScreens : Integer;
    gamma, blackPoint, whitePoint, brightness, saturation : Real;
    imagePathArray, imageWidthArray, imageHeightArray, imageTextArray : TStringList;
    error : Boolean;
    mainForm : TForm;

function ApproximateProbability(approximationArray : TStringList) : Real;
var
    approx : Real;
    i : Integer;
begin
    approx := 1.0;
    i := 0;
    while i < approximationArray.Count() - 1 do begin
        approx := approx*strtofloat(approximationArray[i]);
        i := i+1;
    end;
    Result := approx;
    exit;
end;

function Abs(x : Real) : Real;
begin
    if x < 0 then begin
        Result :=  - x;
        exit;
    end else begin 
        Result := x;
        exit;
    end;
end;

function ProbabilityLoss(probability : Real; approximationArray : TStringList) : Real;
begin
    Result := Abs(ApproximateProbability(approximationArray) / probability - 1.0);
    exit;
end;

function CreateRandomProbability(probability : Real; num_approx : Integer) : TStringList;
var
    dividedProb : Real;
    bestLoss : Real;
    bestAttempt : TStringList;
    prevAttempt : TStringList;
    currentAttempt : TStringList;
    i : Integer;
    currentLoss : Real;
    j : Integer;
begin
    dividedProb := Trunc(100.0 * Power(probability,1.0 / num_approx)) / 100.0;
    bestLoss := 1.0;
    bestAttempt := nil;
    currentAttempt := TStringList.Create();
    i := 0;
    while i < num_approx do begin
        currentAttempt.add(floattostr(dividedProb));
        i := i+1;
    end;
    currentLoss := ProbabilityLoss(probability,currentAttempt);
    if currentLoss < bestLoss then begin
        bestLoss := currentLoss;
        bestAttempt := currentAttempt;
    end;
    i := 0;
    while i < num_approx do begin
        prevAttempt := currentAttempt;
        currentAttempt := TStringList.Create();
        j := 0;
        while j < num_approx do begin
            currentAttempt.add(prevAttempt[j]);
            j := j+1;
        end;
        currentAttempt[i] := floattostr(strtofloat(currentAttempt[i]) + 0.01);
        currentLoss := ProbabilityLoss(probability,currentAttempt);
        if currentLoss < bestLoss then begin
            bestLoss := currentLoss;
            bestAttempt := currentAttempt;
        end;
        i := i+1;
    end;
    Result := bestAttempt;
    exit;
end;

function GCD(a : Integer; b : Integer) : Integer;
begin
    if b = 0 then begin
        Result := a;
        exit;
    end else begin 
        Result := GCD(b,a mod b);
        exit;
    end;
end;

function GetRelativeX(relativeTo : TForm; offset : Real) : Real;
begin
    if Assigned(relativeTo) then begin
        Result := relativeTo.Left + offset;
    end else begin 
        Result := offset;
    end;
end;

function GetRelativeY(relativeTo : TForm; offset : Real) : Real;
begin
    if Assigned(relativeTo) then begin
        Result := relativeTo.Top + offset;
    end else begin 
        Result := offset;
    end;
end;

function AddLabel(relativeTo : TForm; offsetX : Real; offsetY : Real; width : Real; height : Real; value : String) : TLabel;
var
    lbl : TLabel;
begin
    lbl := TLabel.Create(mainForm);
    lbl.Parent := mainForm;
    lbl.Width := width;
    lbl.Height := height;
    lbl.Left := GetRelativeX(relativeTo,offsetX);
    lbl.Top := GetRelativeY(relativeTo,offsetY);
    lbl.Caption := value;
    Result := lbl;
end;

function AddLine(relativeTo : TForm; offsetX : Real; offsetY : Real; width : Real; value : String; hint : String) : TEdit;
var
    line : TEdit;
begin
    line := TEdit.Create(mainForm);
    line.Parent := mainForm;
    line.Left := GetRelativeX(relativeTo,offsetX);
    line.Top := GetRelativeY(relativeTo,offsetY);
    line.Width := width;
    line.Caption := value;
    line.Font.Size := 10;
    line.Hint := hint;
    line.ShowHint := (hint <> '');
    Result := line;
end;

function AddBox(relativeTo : TForm; offsetX : Real; offsetY : Real; width : Real; height : Real; caption : String) : TGroupBox;
var
    box : TGroupBox;
begin
    box := TGroupBox.Create(mainForm);
    box.Parent := mainForm;
    box.Left := GetRelativeX(relativeTo,offsetX);
    box.Top := GetRelativeY(relativeTo,offsetY);
    box.Caption := caption;
    box.Font.Size := 10;
    box.ClientWidth := width;
    box.ClientHeight := height;
    Result := box;
end;

function AddButton(relativeTo : TForm; offsetX : Real; offsetY : Real; caption : String; modalResult : Integer) : TButton;
var
    button : TButton;
begin
    button := TButton.Create(mainForm);
    button.Parent := mainForm;
    button.Left := GetRelativeX(relativeTo,offsetX);
    button.Top := GetRelativeY(relativeTo,offsetY);
    button.Caption := caption;
    button.ModalResult := modalResult;
    Result := button;
end;

function AddCheckBox(relativeTo : TForm; offsetX : Real; offsetY : Real; value : Boolean; caption : String; hint : String) : TCheckBox;
var
    checkBox : TCheckBox;
begin
    checkBox := TCheckBox.Create(mainForm);
    checkBox.Parent := mainForm;
    checkBox.Left := GetRelativeX(relativeTo,offsetX);
    checkBox.Top := GetRelativeY(relativeTo,offsetY);
    checkBox.Width := 500;
    checkBox.Caption := caption;
    checkBox.Checked := value;
    checkBox.Hint := hint;
    checkBox.ShowHint := (hint <> '');
    Result := checkBox;
end;

procedure ClearGroup(fileHandle : IwbFile; signature : String);
var
    group : IwbGroupRecord;
begin
    if HasGroup(fileHandle,signature) then begin
        group := GroupBySignature(fileHandle,signature);
        Remove(group);
    end;
end;

procedure SetValueString(handle : IInterface; path : String; value : String);
begin
    SetEditValue(ElementByPath(handle,path),value);
end;

procedure SetValueInt(handle : IInterface; path : String; value : Integer);
begin
    SetValueString(handle,path,inttostr(value));
end;

procedure SetValueFloat(handle : IInterface; path : String; value : Real);
begin
    SetValueString(handle,path,floattostr(value));
end;

procedure SetValueHex(handle : IInterface; path : String; value : Integer);
begin
    SetValueString(handle,path,IntToHex(value,8));
end;

procedure SetLinksTo(handle : IInterface; path : String; record_ : IwbMainRecord);
begin
    SetValueString(handle,path,IntToHex(GetLoadOrderFormID(record_),8));
end;

function FileByName(s : String) : IwbFile;
var
    i : Integer;
begin
    i := 0;
    while i < FileCount do begin
        if GetFileName(FileByIndex(i)) = s then begin
            Result := FileByIndex(i);
            exit;
        end;
        i := i+1;
    end;
    Result := nil;
    exit;
end;

procedure AddMastersSmart(esp : IwbFile; master : IwbElement);
var
    masterList : TStringList;
    stringCount : Integer;
    i : Integer;
begin
    masterList := TStringList.Create();
    ReportRequiredMasters(master,masterList,false,false);
    stringCount := masterList.Count;
    i := 0;
    while i < stringCount do begin
        AddMasterIfMissing(esp,masterList[i]);
        i := i+1;
    end;
end;

function GetSettingKey(def : String) : Integer;
begin
    if settings.Count()<=settingKey then begin
        settings.Add('');
        WriteSetting(settingKey,def);
    end;
    settingKey := settingKey+1;
    Result := settingKey - 1;
    exit;
end;

procedure SaveSettings();
begin
    settings.SaveToFile(editScriptsSubFolder + '\' + settingsName);
end;

procedure WriteSetting(idx : Integer; value : String);
begin
    settings[idx] := value;
end;

function ReadSetting(idx : Integer) : String;
begin
    Result := settings[idx];
    exit;
end;

function ReadSettingFloat(idx : Integer) : Real;
begin
    Result := strtofloat(settings[idx]);
    exit;
end;

function ReadSettingInt(idx : Integer) : Integer;
begin
    Result := strtoint(settings[idx]);
    exit;
end;

function ReadSettingBool(idx : Integer) : Boolean;
begin
    Result := settings[idx] = 'True';
    exit;
end;

procedure InitSettings();
begin
    editScriptsSubFolder := ScriptsPath + scriptName;
    settings := TStringList.Create;
    messageLog := TStringList.Create;
    settingKey := 0;
    if FileExists(editScriptsSubFolder + '\' + settingsName) then begin
        settings.LoadFromFile(editScriptsSubFolder + '\' + settingsName);
    end;
end;

procedure InitSettingKeys();
var
    gcdResolution : Integer;
begin
    skSourcePath := GetSettingKey('');
    skDisableOtherLoadScreens := GetSettingKey('True');
    gcdResolution := GCD(Screen.Width,Screen.Height);
    skDisplayWidth := GetSettingKey(inttostr(Screen.Width / gcdResolution));
    skDisplayHeight := GetSettingKey(inttostr(Screen.Height / gcdResolution));
    skStretch := GetSettingKey('False');
    skRecursive := GetSettingKey('False');
    skGamma := GetSettingKey('1.0');
    skContrast := GetSettingKey('0');
    skBrightness := GetSettingKey('0');
    skSaturation := GetSettingKey('0');
    skFullHeight := GetSettingKey('False');
    skTestMode := GetSettingKey('False');
    skFrequency := GetSettingKey('100');
    skModName := GetSettingKey('Nazeem''s Loading Screen Mod');
    skModVersion := GetSettingKey('1.0.0');
    skModFolder := GetSettingKey('NazeemLoadScreens');
    skPluginName := GetSettingKey('NazeemsLoadingScreenMod.esp');
    skModAuthor := GetSettingKey('Nazeem');
    skPrefix := GetSettingKey('Nzm_');
    skAspectRatios := GetSettingKey('16x9,16x10,21x9,4x3');
    skTextureResolutions := GetSettingKey('2');
    skMessages := GetSettingKey('optional');
    skFrequencyList := GetSettingKey('5,10,15,25,35,50,70,100');
    skDefaultFrequency := GetSettingKey('15');
    skModLink := GetSettingKey('https://www.nexusmods.com/skyrimspecialedition/mods/36556');
    skBorderOptions := GetSettingKey('black');
    skResolution := GetSettingKey('2048');
end;

procedure trace(msg : String);
begin
    messageLog.add('[' + TimeToStr(Time) + '] ' + msg);
    messageLog.SaveToFile(editScriptsSubFolder + '\Log.txt');
end;

procedure log(msg : String);
begin
    addmessage(msg);
    Trace(msg);
end;

procedure errorMsg(msg : String);
begin
    error := true;
    Log('	');
    Log(msg);
    Log('	');
end;

procedure PatchLoadingScreens(esp : IwbFile);
var
    i : Integer;
    fileHandle : IwbFile;
    group : IwbGroupRecord;
    j : Integer;
    oldRecord : IwbMainRecord;
    newRecord : IwbMainRecord;
begin
    i := 0;
    while i < FileCount do begin
        fileHandle := FileByIndex(i);
        if fileHandle <> esp then begin
            if HasGroup(fileHandle,'LSCR') then begin
                group := GroupBySignature(fileHandle,'LSCR');
                j := 0;
                while j < ElementCount(group) do begin
                    oldRecord := ElementByIndex(group,j);
                    AddMastersSmart(esp,oldRecord);
                    newRecord := wbCopyElementToFile(oldRecord,esp,false,true);
                    Remove(ElementByPath(newRecord,'Conditions'));
                    Add(newRecord,'Conditions',True);
                    SetValueInt(newRecord,'Conditions\[0]\CTDA\Type',10100000);
                    SetValueInt(newRecord,'Conditions\[0]\CTDA\Comparison Value',-1);
                    SetValueString(newRecord,'Conditions\[0]\CTDA\Function','GetRandomPercent');
                    j := j+1;
                end;
            end;
        end;
        i := i+1;
    end;
    SortMasters(esp);
    CleanMasters(esp);
end;

function CreateESP(fileName : String; meshPath : String; prefix : String; disableOthers : Boolean; includeMessages : Boolean; frequency : Integer) : IwbFile;
var
    esl : Boolean;
    esp : IwbFile;
    globRecord : IwbMainRecord;
    probability : Real;
    approximationArray : TStringList;
    i : Integer;
    editorID : String;
    statRecord : IwbMainRecord;
    lscrRecord : IwbMainRecord;
    j : Integer;
begin
    Log('	Creating plugin file "' + fileName + '"');
    esl := (wbAppName = 'SSE') And (imagePathArray.Count() < 1024);
    esp := FileByName(fileName);
    if  Not Assigned(esp) then begin
        esp := AddNewFileName(fileName,esl);
    end;
    SetValueString(ElementByIndex(esp,0),'CNAM - Author','Jampion');
    SetValueInt(ElementByIndex(esp,0),'HEDR - Header\Next Object ID',2048);
    SetElementNativeValues(ElementByIndex(esp,0),'Record Header\Record Flags\ESL',esl);
    if  Not Assigned(esp) then begin
        ErrorMsg('The plugin file could not be created.');
    end else begin 
        ClearGroup(esp,'LSCR');
        ClearGroup(esp,'STAT');
        ClearGroup(esp,'GLOB');
        CleanMasters(esp);
        Add(esp,'LSCR',True);
        Add(esp,'STAT',True);
        if ReadSettingBool(skTestMode) then begin
            Add(esp,'GLOB',True);
            globRecord := Add(GroupBySignature(esp,'GLOB'),'GLOB',True);
            SetEditorID(globRecord,prefix + 'TestMode');
        end;
        probability := 1.0 - Power(1.0 - 0.01 * frequency,1.0 / totalLoadScreens);
        approximationArray := CreateRandomProbability(probability,4);
        i := 0;
        while i < imagePathArray.Count() do begin
            editorID := inttostr(i);
            statRecord := Add(GroupBySignature(esp,'STAT'),'STAT',True);
            SetEditorID(statRecord,prefix + 'STAT_' + editorID);
            Add(statRecord,'MODL',True);
            SetValueString(statRecord,'Model\MODL - Model FileName',meshPath + '\' + imagePathArray[i] + '.nif');
            SetValueInt(statRecord,'DNAM\Max Angle (30-120)',90);
            lscrRecord := Add(GroupBySignature(esp,'LSCR'),'LSCR',True);
            SetEditorID(lscrRecord,prefix + 'LSCR_' + editorID);
            SetLinksTo(lscrRecord,'NNAM',statRecord);
            Add(lscrRecord,'SNAM',True);
            SetValueInt(lscrRecord,'SNAM',2);
            Add(lscrRecord,'RNAM',True);
            SetValueInt(lscrRecord,'RNAM\X',-90);
            Add(lscrRecord,'ONAM',True);
            Add(lscrRecord,'XNAM',True);
            SetValueInt(lscrRecord,'XNAM\X',-45);
            Add(lscrRecord,'Conditions',True);
            if ReadSettingBool(skTestMode) then begin
                SetValueInt(lscrRecord,'Conditions\[0]\CTDA\Type',10000000);
                SetValueInt(lscrRecord,'Conditions\[0]\CTDA\Comparison Value',i);
                SetValueString(lscrRecord,'Conditions\[0]\CTDA\Function','GetGlobalValue');
                SetLinksTo(lscrRecord,'Conditions\[0]\CTDA\Global',globRecord);
            end else begin 
                j := 0;
                while j < approximationArray.Count() do begin
                    ElementAssign(ElementByPath(lscrRecord,'Conditions'),HighInteger,nil,false);
                    SetValueInt(lscrRecord,'Conditions\[' + inttostr(j) + ']\CTDA\Type',10100000);
                    SetValueInt(lscrRecord,'Conditions\[' + inttostr(j) + ']\CTDA\Comparison Value',Trunc(100 * strtofloat(approximationArray[j])) - 1);
                    SetValueString(lscrRecord,'Conditions\[' + inttostr(j) + ']\CTDA\Function','GetRandomPercent');
                    j := j+1;
                end;
                Remove(ElementByPath(lscrRecord,'Conditions\[' + inttostr(approximationArray.Count()) + ']'));
            end;
            if includeMessages then begin
                SetValueString(lscrRecord,'DESC - Description',imageTextArray[i]);
            end;
            i := i+1;
        end;
        if disableOthers then begin
            PatchLoadingScreens(esp);
        end;
    end;
end;

procedure CreateESPOptions(pluginName : String; modFolder : String; disableOthers : Boolean; msgSetting : Integer; frequency : Integer);
begin
    if msgSetting = 0 then begin
        CreateESP('FOMOD_M0_P' + inttostr(frequency) + '_FOMODEND_' + pluginName,modFolder,ReadSetting(skPrefix),disableOthers,false,frequency);
    end else begin 
        if msgSetting = 1 then begin
            CreateESP('FOMOD_M1_P' + inttostr(frequency) + '_FOMODEND_' + pluginName,modFolder,ReadSetting(skPrefix),disableOthers,true,frequency);
        end else begin 
            if msgSetting = 2 then begin
                CreateESP('FOMOD_M0_P' + inttostr(frequency) + '_FOMODEND_' + pluginName,modFolder,ReadSetting(skPrefix),disableOthers,false,frequency);
                CreateESP('FOMOD_M1_P' + inttostr(frequency) + '_FOMODEND_' + pluginName,modFolder,ReadSetting(skPrefix),disableOthers,true,frequency);
            end;
        end;
    end;
end;

procedure PluginGen(advanced : Boolean; disableOthers : Boolean; pluginName : String);
var
    msgSetting : Integer;
    frequencyList : TStringList;
    i : Integer;
begin
    Log('	Creating plugin files...');
    if advanced then begin
        msgSetting := 1;
        if ReadSetting(skMessages) = 'optional' then begin
            msgSetting := 2;
        end else begin 
            if ReadSetting(skMessages) = 'always' then begin
                msgSetting := 1;
            end else begin 
                if ReadSetting(skMessages) = 'never' then begin
                    msgSetting := 0;
                end else begin 
                    msgSetting := 1;
                    Log('The messages option ' + ReadSetting(skMessages) + ' is invalid; "always" will be used instead.');
                end;
            end;
        end;
        frequencyList := TStringList.Create();
        frequencyList.Delimiter := ',';
        frequencyList.StrictDelimiter := True;
        frequencyList.DelimitedText := ReadSetting(skFrequencyList);
        i := 0;
        while i < frequencyList.Count() do begin
            CreateESPOptions(pluginName,ReadSetting(skModFolder),disableOthers,msgSetting,strtoint(frequencyList[i]));
            i := i+1;
        end;
    end else begin 
        CreateESP(defaultPluginName,defaultModFolder,defaultPrefix,disableOthers,true,ReadSettingInt(skFrequency));
    end;
end;

procedure FitToDisplayRatio(displayRatio : Real; imageRatio : Real);
var
    ratioFactor : Real;
    width : Real;
    height : Real;
    borderOption : String;
begin
    ratioFactor := displayRatio / sourceRatio;
    width := 1.0;
    height := 1.0 / ratioFactor;
    borderOption := ReadSetting(skBorderOptions);
    if borderOption <> 'stretch' then begin
        if displayRatio > imageRatio then begin
            if borderOption = 'fullwidth' then begin
                height := height*displayRatio / imageRatio;
            end else begin 
                if borderOption = 'fullheight' then begin
                    width := width * imageRatio / displayRatio;
                end else begin 
                    if borderOption = 'crop' then begin
                        height := height * displayRatio / imageRatio;
                    end else begin 
                        if borderOption = 'black' then begin
                            width := width * imageRatio / displayRatio;
                        end;
                    end;
                end;
            end;
        end else begin 
            if displayRatio < imageRatio then begin
                if borderOption = 'fullwidth' then begin
                    height := height * displayRatio / imageRatio;
                end else begin 
                    if borderOption = 'fullheight' then begin
                        width := width * imageRatio / displayRatio;
                    end else begin 
                        if borderOption = 'crop' then begin
                            width := width * imageRatio / displayRatio;
                        end else begin 
                            if borderOption = 'black' then begin
                                height := height * displayRatio / imageRatio;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
    widthFactor := width;
    heightFactor := height;
end;

procedure CreateMeshes(targetPath : String; texturePath : String; templateNif : TwbNifFile; sse : Boolean; displayRatio : Real);
var
    i : Integer;
    TextureSet : TwbNifBlock;
    Textures : TdfElement;
    VertexData : TdfElement;
    VertexPrefix : String;
    blockIndex : Integer;
    TriShape : TwbNifBlock;
begin
    i := 0;
    while i < imagePathArray.Count() do begin
        Log('	' + inttostr(i + 1) + '/' + inttostr(imagePathArray.Count()) + ': ' + targetPath + '\' + imagePathArray[i] + '.nif');
        if sse then begin
            TextureSet := templateNif.Blocks[3];
        end else begin 
            TextureSet := templateNif.Blocks[4];
        end;
        Textures := TextureSet.Elements['Textures'];
        Textures[0].EditValue := texturePath + '\' + imagePathArray[i] + '.dds';
        FitToDisplayRatio(displayRatio,strtofloat(imageWidthArray[i]) / strtofloat(imageHeightArray[i]));
        blockIndex := -1;
        if sse then begin
            TriShape := templateNif.Blocks[1];
            VertexData := TriShape.Elements['Vertex Data'];
            VertexPrefix := 'Vertex\';
        end else begin 
            TriShape := templateNif.Blocks[2];
            VertexData := TriShape.Elements['Vertices'];
            VertexPrefix := '';
        end;
        VertexData[0].NativeValues[VertexPrefix + 'X'] := sourceOffsetX - sourceUpperWidth * widthFactor;
        VertexData[0].NativeValues[VertexPrefix + 'Y'] := sourceOffsetY + sourceHeight * heightFactor - sourceHeightOffset * heightFactor;
        VertexData[1].NativeValues[VertexPrefix + 'X'] := sourceOffsetX - sourceUpperWidth * widthFactor - sourceLowerWidth * widthFactor * heightFactor;
        VertexData[1].NativeValues[VertexPrefix + 'Y'] := sourceOffsetY - sourceHeight * heightFactor - sourceHeightOffset * heightFactor;
        VertexData[2].NativeValues[VertexPrefix + 'X'] := sourceOffsetX + sourceUpperWidth * widthFactor + sourceLowerWidth * widthFactor * heightFactor;
        VertexData[2].NativeValues[VertexPrefix + 'Y'] := sourceOffsetY - sourceHeight * heightFactor - sourceHeightOffset * heightFactor;
        VertexData[3].NativeValues[VertexPrefix + 'X'] := sourceOffsetX + sourceUpperWidth * widthFactor;
        VertexData[3].NativeValues[VertexPrefix + 'Y'] := sourceOffsetY + sourceHeight * heightFactor - sourceHeightOffset * heightFactor;
        templateNif.SaveToFile(targetPath + '\' + imagePathArray[i] + '.nif');
        i := i+1;
    end;
end;

function LoadTemplateNif() : TwbNifFile;
var
    templateNif : TwbNifFile;
begin
    templateNif := TwbNifFile.Create;
    try 
        if wbAppName = 'SSE' then begin
            templateNif.LoadFromFile(templatePath + '\TemplateSSE.nif');
        end else begin 
            templateNif.LoadFromFile(templatePath + '\TemplateLE.nif');
        end;
    except
        on E : Exception do begin
            ErrorMsg('Error: Something went wrong when trying to load the template mesh.');
        end;
    end;
    Result := templateNif;
    exit;
end;

procedure MeshGen(advanced : Boolean; texturePathShort : String);
var
    templateNif : TwbNifFile;
    aspectRatioList : TStringList;
    widthList : TStringList;
    heightList : TStringList;
    i : Integer;
    sideList : TStringList;
    meshPath : String;
begin
    Log('	Creating loading screen meshes...');
    templateNif := LoadTemplateNif();
    if advanced then begin
        aspectRatioList := TStringList.Create();
        aspectRatioList.Delimiter := ',';
        aspectRatioList.StrictDelimiter := True;
        aspectRatioList.DelimitedText := ReadSetting(skAspectRatios);
        widthList := TStringList.Create();
        heightList := TStringList.Create();
        try 
            i := 0;
            while i < aspectRatioList.Count() do begin
                sideList := TStringList.Create();
                sideList.Delimiter := 'x';
                sideList.StrictDelimiter := True;
                sideList.DelimitedText := aspectRatioList[i];
                widthList.add(sideList[0]);
                heightList.add(sideList[1]);
                i := i+1;
            end;
        except
            on E : Exception do begin
                Log(E.ClassName + ' error raised, with message : ' + E.Message);
                Log('Error while parsing the aspect ratio list: ' + ReadSetting(skAspectRatios));
                raise E;
            end;
        end;
        i := 0;
        while i < aspectRatioList.Count() do begin
            meshPath := DataPath + 'meshes\' + aspectRatioList[i] + '\' + ReadSetting(skModFolder);
            Log('	Creating loading screen meshes for aspect ratio: ' + aspectRatioList[i]);
            forcedirectories(meshPath);
            CreateMeshes(meshPath,texturePathShort,templateNif,wbAppName = 'SSE',strtofloat(widthList[i]) / strtofloat(heightList[i]));
            i := i+1;
        end;
    end else begin 
        meshPath := DataPath + 'meshes\JLoadScreens';
        forcedirectories(meshPath);
        CreateMeshes(meshPath,texturePathShort,templateNif,wbAppName = 'SSE',ReadSettingInt(skDisplayWidth) / ReadSettingInt(skDisplayHeight));
    end;
end;

procedure AddFilesToList(filePath : String; fileFilter : String; list : TStringList; recursive : Boolean);
var
    matchedFiles : TStringDynArray;
    TDirectory : TDirectory;
    i : Integer;
begin
    if recursive then begin
        matchedFiles := TDirectory.GetFiles(filePath,fileFilter,soAllDirectories);
    end else begin 
        matchedFiles := TDirectory.GetFiles(filePath,fileFilter,soTopDirectoryOnly);
    end;
    i := 0;
    while i < Length(matchedFiles) do begin
        list.Add(matchedFiles[i]);
        i := i+1;
    end;
end;

function ParseTexDiagOutput(output : String) : String;
begin
    Result := Copy(output,17,length(output));
end;

procedure ProcessTextures(sourcePath : String; targetPath : String; recursive : Boolean);
var
    tmp : Integer;
    cmd : String;
    sourcePathList : TStringList;
    imageCount : Integer;
    texturePathList : TStringList;
    ignoredFiles : TStringList;
    resolution : String;
    i : Integer;
    s : String;
    srgb : Boolean;
    srgbCmd : String;
    readTextFile : TStringList;
    textFile : String;
begin
    sourcePathList := TStringList.Create();
    Log('	Scanning source directory for valid source images...');
    AddFilesToList(sourcePath,'*.dds',sourcePathList,recursive);
    AddFilesToList(sourcePath,'*.png',sourcePathList,recursive);
    AddFilesToList(sourcePath,'*.jpg',sourcePathList,recursive);
    imageCount := sourcePathList.Count();
    Log('	' + inttostr(imageCount) + ' images found in the source directory.');
    imagePathArray := TStringList.Create();
    imageWidthArray := TStringList.Create();
    imageHeightArray := TStringList.Create();
    imageTextArray := TStringList.Create();
    texturePathList := TStringList.Create();
    texturePathList.Sorted := True;
    texturePathList.Duplicates := dupIgnore;
    ignoredFiles := TStringList.Create();
    ignoredFiles.Sorted := True;
    ignoredFiles.Duplicates := dupIgnore;
    resolution := inttostr(ReadSettingInt(skResolution));
    Log('	Creating textures from source images...');
    i := 0;
    while i < imageCount do begin
        s := ChangeFileExt(ExtractFileName(sourcePathList[i]),'');
        Log('	' + inttostr(i + 1) + '/' + inttostr(imageCount) + ': ' + s);
        if  Not texturePathList.Find(s,tmp) then begin
            texturePathList.Add(s);
            srgb := false;
            srgbCmd := '';
            try 
                cmd := '/C  ""' + editScriptsSubFolder + '\DirectXTex\texdiag.exe" info "' + sourcePathList[i] + '" -nologo > "' + editScriptsSubFolder + '\texdiag.txt""';
                ShellExecuteWait(0,nil,'cmd.exe',cmd,'',SW_HIDE);
                readTextFile := TStringList.Create();
                readTextFile.LoadFromFile(editScriptsSubFolder + '\texdiag.txt');
                if readTextFile.Count<=0 then begin
                    raise exception.Create('texdiag.txt is empty.');
                end;
                if ContainsText(readTextFile[0],'FAILED') then begin
                    raise exception.Create('texdiag.exe failed to analyze the texture.');
                end;
                if ContainsText(ParseTexDiagOutput(readTextFile[6]),'SRGB') then begin
                    srgb := True;
                end;
            except
                on E : Exception do begin
                    Log(E.ClassName + ' error raised, with message : ' + E.Message);
                    Log('Error while using texdiag.exe for image ' + sourcePathList[i]);
                    continue;
                end;
            end;
            if srgb then begin
                srgbCmd := '-srgb ';
            end;
            try 
                cmd := ' -m 1 -f BC1_UNORM ' + srgbCmd + '-o "' + targetPath + '" -y -w ' + resolution + ' -h ' + resolution + ' "' + sourcePathList[i] + '"';
                CreateProcessWait(ScriptsPath + 'Texconv.exe',cmd,SW_HIDE,10000);
                cmd := ' -f BC1_UNORM ' + '-o "' + targetPath + '" -y -w ' + resolution + ' -h ' + resolution + ' "' + targetPath + '\' + s + '.dds' + ' "';
                CreateProcessWait(ScriptsPath + 'Texconv.exe',cmd,SW_HIDE,10000);
            except
                on E : Exception do begin
                    Log(E.ClassName + ' error raised, with message : ' + E.Message);
                    Log('Error while using texconv.exe for image ' + sourcePathList[i]);
                    continue;
                end;
            end;
            try 
                if (gamma <> 1.0) Or (ReadSettingInt(skContrast) <> 0) then begin
                    cmd := '"' + targetPath + '\' + s + '.dds"';
                    cmd := '/C ""' + editScriptsSubFolder + '\ImageMagick\magick.exe" ' + cmd + ' - level ' + floattostr(blackPoint) + ' %,' + floattostr(whitePoint) + ' %,' + floattostr(gamma) + ' ' + cmd + '"';
                    ShellExecuteWait(0,nil,'cmd.exe',cmd,'',SW_HIDE);
                end;
                if (brightness <> 100.0) Or (saturation <> 100) then begin
                    cmd := '"' + targetPath + '\' + s + '.dds"';
                    cmd := '/C ""' + editScriptsSubFolder + '\ImageMagick\magick.exe" ' + cmd + ' - modulate ' + floattostr(brightness) + ',' + floattostr(saturation) + ' ' + cmd + '"';
                    ShellExecuteWait(0,nil,'cmd.exe',cmd,'',SW_HIDE);
                end;
            except
                on E : Exception do begin
                    Log(E.ClassName + ' error raised, with message : ' + E.Message);
                    Log('Error while using magick.exe for image ' + sourcePathList[i]);
                    continue;
                end;
            end;
            try 
                cmd := '/C  ""' + editScriptsSubFolder + '\DirectXTex\texdiag.exe" info "' + sourcePathList[i] + '" -nologo > "' + editScriptsSubFolder + '\texdiag.txt""';
                ShellExecuteWait(0,nil,'cmd.exe',cmd,'',SW_HIDE);
                readTextFile := TStringList.Create();
                readTextFile.LoadFromFile(editScriptsSubFolder + '\texdiag.txt');
                if readTextFile.Count<=0 then begin
                    raise exception.Create('texdiag.txt is empty.');
                end;
                if ContainsText(readTextFile[0],'FAILED') then begin
                    raise exception.Create('texdiag.exe failed to analyze the texture.');
                end;
                imagePathArray.Add(s);
                imageWidthArray.Add(inttostr(strtoint(ParseTexDiagOutput(readTextFile[1]))));
                imageHeightArray.Add(inttostr(strtoint(ParseTexDiagOutput(readTextFile[2]))));
                textFile := ChangeFileExt(sourcePathList[i],'.txt');
                if FileExists(textFile) then begin
                    readTextFile := TStringList.Create();
                    readTextFile.LoadFromFile(textFile);
                    if readTextFile.Count<=0 then begin
                        raise exception.Create(s + '.txt is empty.');
                    end;
                    imageTextArray.Add(readTextFile[0]);
                end else begin 
                    imageTextArray.Add('');
                end;
            except
                on E : Exception do begin
                    Log('	');
                    Log(E.ClassName + ' error raised, with message : ' + E.Message);
                    Log('Error while using texdiag.exe for image ' + sourcePathList[i]);
                    Log('	');
                    continue;
                end;
            end;
        end else begin 
            ignoredFiles.Add(sourcePathList[i]);
        end;
        i := i+1;
    end;
    if texturePathList.Count() < imageCount then begin
        Log('	');
        Log('	There were multiple images with the same name. Only one loading screen will be created for each image name.');
        Log('	Images may have the same name, because they use different extensions, e.g. image.jpg and image.png');
        Log('	Images may have the same name, because they are in different subdirectories of the source directory, e.g. image.jpg and subfolder\image.jpg');
        Log('	These images would all create a texture named image.dds, so only one of them can be used.');
        Log('	The following files have been ignored due to duplicate image names:');
        Log('	');
        i := 0;
        while i < ignoredFiles do begin
            Log('	' + ignoredFiles[i]);
            i := i+1;
        end;
        Log('	');
        Log('	You can give these files unique names and run the script again.');
        Log('	');
    end;
    totalLoadScreens := imagePathArray.Count();
end;

procedure Main(sourcePath : String; disableOthers : Boolean; recursive : Boolean; advanced : Boolean);
var
    templatePath : String;
    pluginName : String;
    texturePathShort : String;
    texturePath : String;
begin
    if advanced then begin
        Log('	Running advanved generator...');
    end else begin 
        Log('	Running basic generator...');
    end;
    Log('	Using source path: ' + sourcePath);
    templatePath := editScriptsSubFolder;
    pluginName := ReadSetting(skPluginName);
    if advanced then begin
        texturePathShort := 'textures\' + ReadSetting(skModFolder);
    end else begin 
        texturePathShort := 'textures\JLoadScreens';
    end;
    texturePath := DataPath + texturePathShort;
    forcedirectories(texturePath);
    ProcessTextures(sourcePath,texturePath,recursive);
    Log('  Using ' + inttostr(totalLoadScreens) + ' images for loading screen generation.');
    Log('	');
    MeshGen(advanced,texturePathShort);
    PluginGen(advanced,disableOthers,pluginName);
    if advanced then begin
        Log('	Copying build files...');
        CopyFile(editScriptsSubFolder + '\Custom\create_fomod.cmd',DataPath + 'create_fomod.cmd',false);
        CopyFile(editScriptsSubFolder + '\Custom\create_fomod.py',DataPath + 'create_fomod.py',false);
        CopyFile(editScriptsSubFolder + '\settings.txt',DataPath + 'settings.txt',false);
    end;
    Log('	Done');
end;

procedure PickSourcePath(Sender : TObject);
var
    path : String;
begin
    path := ReadSetting(skSourcePath);
    path := SelectDirectory('Select folder for generated meshes','',path,'');
    if path <> '\' then begin
        Sender.Text := path;
        WriteSetting(skSourcePath,path);
    end;
end;

function ImageAdjustment(prevAdj : TForm; lineText : String; description : String) : TEdit;
var
    line : TEdit;
    lbl : TLabel;
begin
    line := TEdit.Create(prevAdj.Parent);
    line.Parent := prevAdj.Parent;
    line.Top := prevAdj.Top + prevAdj.Height;
    line.Left := 16;
    line.Width := 64;
    line.Caption := lineText;
    line.Font.Size := 10;
    lbl := TLabel.Create(prevAdj.Parent);
    lbl.Parent := prevAdj.Parent;
    lbl.Left := line.Left + line.Width + 8;
    lbl.Top := line.Top + 4;
    lbl.Width := 200;
    lbl.Height := 64;
    lbl.Caption := description;
    lbl.Font.Size := 10;
    Result := line;
end;

function Advanced() : Integer;
var
    aspectRatioBox : TGroupBox;
    screenResolutionLine : TEdit;
    modBox : TGroupBox;
    modNameLabel : TLabel;
    modNameLine : TEdit;
    modVersionLabel : TLabel;
    modVersionLine : TEdit;
    modFolderLabel : TLabel;
    modFolderLine : TEdit;
    modAuthorLabel : TLabel;
    modAuthorLine : TEdit;
    modPluginLabel : TLabel;
    modPluginLine : TEdit;
    modPrefixLabel : TLabel;
    modPrefixLine : TEdit;
    modLinkLabel : TLabel;
    modLinkLine : TEdit;
    optionsBox : TGroupBox;
    messagesLabel : TLabel;
    messagesLine : TEdit;
    frequencyListLabel : TLabel;
    frequencyListLine : TEdit;
    frequencyDefaultLabel : TLabel;
    frequencyDefaultLine : TEdit;
    btnOk : TButton;
    btnCancel : TButton;
    modalResult : Integer;
begin
    mainForm := TForm.Create(nil);
    try 
        mainForm.Caption := 'Jampion''s Loading Screen Generator';
        mainForm.Width := 640;
        mainForm.Height := 500;
        mainForm.Position := poScreenCenter;
        aspectRatioBox := AddBox(mainForm,8,8,mainForm.Width - 24,48,'Aspect Ratios');
        screenResolutionLine := AddLine(aspectRatioBox,16,16,mainForm.Width - 128,ReadSetting(skAspectRatios),'Comma separated list of aspect ratios, e.g. "16x9, 16x10, 21x9"');
        modBox := AddBox(aspectRatioBox,0,aspectRatioBox.Height + 8,mainForm.Width - 24,192,'Mod Configuration');
        modNameLabel := AddLabel(modBox,16,24,160,24,'Mod name');
        modNameLine := AddLine(modNameLabel,80,-4,mainForm.Width - 128,ReadSetting(skModName),'The display name of the mod. Will be used for the FOMOD installer.');
        modVersionLabel := AddLabel(modNameLabel,0,24,160,24,'Mod version');
        modVersionLine := AddLine(modVersionLabel,80,-4,mainForm.Width - 128,ReadSetting(skModVersion),'Will be used for the FOMOD installer.');
        modFolderLabel := AddLabel(modVersionLabel,0,24,160,24,'Sub folder');
        modFolderLine := AddLine(modFolderLabel,80,-4,mainForm.Width - 128,ReadSetting(skModFolder),'Sub folder, in which textures and meshes are generated. "MyMod" will result in "textures / MyMod" and "meshes / MyMod".');
        modAuthorLabel := AddLabel(modFolderLabel,0,24,160,24,'Author');
        modAuthorLine := AddLine(modAuthorLabel,80,-4,mainForm.Width - 128,ReadSetting(skModAuthor),'Your name :).');
        modPluginLabel := AddLabel(modAuthorLabel,0,24,160,24,'Plugin');
        modPluginLine := AddLine(modPluginLabel,80,-4,mainForm.Width - 128,ReadSetting(skPluginName),'The name of the generated plugin (with extension).');
        modPrefixLabel := AddLabel(modPluginLabel,0,24,160,24,'Prefix');
        modPrefixLine := AddLine(modPrefixLabel,80,-4,mainForm.Width - 128,ReadSetting(skPrefix),'This prefix is added to all records.');
        modLinkLabel := AddLabel(modPrefixLabel,0,24,160,24,'Prefix');
        modLinkLine := AddLine(modLinkLabel,80,-4,mainForm.Width - 128,ReadSetting(skModLink),'Will be used for the FOMOD installer.');
        optionsBox := AddBox(modBox,0,modBox.Height + 8,mainForm.Width - 24,128,'Options');
        messagesLabel := AddLabel(optionsBox,16,24,160,24,'Messages');
        messagesLine := AddLine(messagesLabel,80,-4,mainForm.Width - 128,ReadSetting(skMessages),'always/never/optional');
        frequencyListLabel := AddLabel(messagesLabel,0,24,160,24,'Freq. List');
        frequencyListLine := AddLine(frequencyListLabel,80,-4,mainForm.Width - 128,ReadSetting(skFrequencyList),'Comma separated list of frequencies, e.g. "5, 15, 50, 100"');
        frequencyDefaultLabel := AddLabel(frequencyListLabel,0,24,160,24,'Def. Freq.');
        frequencyDefaultLine := AddLine(frequencyDefaultLabel,80,-4,mainForm.Width - 128,ReadSetting(skDefaultFrequency),'Default frequency.');
        btnOk := AddButton(nil,8,mainForm.Height - 64,'OK',1);
        btnCancel := AddButton(btnOk,80,0,'Cancel',2);
        modalResult := mainForm.ShowModal;
        if modalResult = 1 then begin
            WriteSetting(skAspectRatios,screenResolutionLine.Text);
            WriteSetting(skModName,modNameLine.Text);
            WriteSetting(skModVersion,modVersionLine.Text);
            WriteSetting(skModFolder,modFolderLine.Text);
            WriteSetting(skModAuthor,modAuthorLine.Text);
            WriteSetting(skPluginName,modPluginLine.Text);
            WriteSetting(skPrefix,modPrefixLine.Text);
            WriteSetting(skModLink,modLinkLine.Text);
            WriteSetting(skMessages,messagesLine.Text);
            WriteSetting(skFrequencyList,frequencyListLine.Text);
            WriteSetting(skDefaultFrequency,frequencyDefaultLine.Text);
            SaveSettings();
            if  Not error then begin
                Main(ReadSetting(skSourcePath),ReadSettingBool(skDisableOtherLoadScreens),ReadSettingBool(skRecursive),true);
            end else begin 
                Log('	');
                Log('At least one setting has an incorrect value.');
                Log('	');
            end;
        end;
    finally
        mainForm.Free;
    end;
end;

function UI() : Integer;
var
    selectDirBox : TGroupBox;
    selectDirLine : TEdit;
    aspectRatioBox : TGroupBox;
    widthLine : TEdit;
    colonLabel : TLabel;
    heightLine : TEdit;
    aspectRatioLabel : TLabel;
    optionsBox : TGroupBox;
    checkBoxDisableOthers : TCheckBox;
    checkBoxSubDirs : TCheckBox;
    checkBoxTestMode : TCheckBox;
    frequencyLabel : TLabel;
    frequencyLine : TEdit;
    borderLabel : TLabel;
    borderLine : TEdit;
    resolutionLabel : TLabel;
    resolutionLine : TEdit;
    imageAdjustmentBox : TGroupBox;
    imageAdjustmentLabel : TLabel;
    brightnessLine : TEdit;
    contrastLine : TEdit;
    saturationLine : TEdit;
    gammaLine : TEdit;
    btnOk : TButton;
    btnCancel : TButton;
    btnAdvanced : TButton;
    modalResult : Integer;
    tmpInt : Integer;
    tmpStr : String;
begin
    mainForm := TForm.Create(nil);
    try 
        mainForm.Caption := 'Jampion''s Loading Screen Generator';
        mainForm.Width := 640;
        mainForm.Height := 500;
        mainForm.Position := poScreenCenter;
        selectDirBox := AddBox(mainForm,8,0,mainForm.Width - 24,48,'Source Directory');
        selectDirLine := AddLine(selectDirBox,8,16,mainForm.Width - 128,ReadSetting(skSourcePath),'Click to select folder in explorer.');
        selectDirLine.OnClick := PickSourcePath;
        aspectRatioBox := AddBox(selectDirBox,0,selectDirBox.Height + 8,mainForm.Width - 24,80,'Target Aspect Ratio');
        widthLine := AddLine(aspectRatioBox,8,16,64,ReadSetting(skDisplayWidth),'Enter your display width.');
        colonLabel := AddLabel(widthLine,widthLine.Width,0,8,30,':');
        colonLabel.Font.Size := 12;
        heightLine := AddLine(colonLabel,8,0,64,ReadSetting(skDisplayHeight),'Enter your display height.');
        aspectRatioLabel := AddLabel(widthLine,0,widthLine.Height,aspectRatioBox.Width - 16,120,'The loading screens will be generated for this aspect ratio.'#13#10'' + 'Either use your resolution (e.g. 1920:1080) or your aspect ratio (e.g. 16:9).');
        aspectRatioLabel.Font.Size := 9;
        optionsBox := AddBox(aspectRatioBox,0,aspectRatioBox.Height + 8,mainForm.Width - 24,128,'Options');
        checkBoxDisableOthers := AddCheckBox(optionsBox,8,16,ReadSettingBool(skDisableOtherLoadScreens),'Disable other Loading Screens','Prevents other loading screens (other mods and vanilla) from showing.');
        checkBoxSubDirs := AddCheckBox(checkBoxDisableOthers,0,16,ReadSettingBool(skRecursive),'Include subdirectories','Includes subdirectories of the source directory, when searching for images.');
        checkBoxTestMode := AddCheckBox(checkBoxSubDirs,0,16,ReadSettingBool(skTestMode),'Test Mode','Adds a global variable, which can be used to force specific loading screens.');
        frequencyLabel := AddLabel(checkBoxTestMode,0,24,64,24,'Frequency:');
        frequencyLine := AddLine(frequencyLabel,60,-4,40,ReadSetting(skFrequency),'Loading screen frequency: 0 - 100');
        borderLabel := AddLabel(frequencyLabel,0,24,64,24,'Border Options:');
        borderLine := AddLine(borderLabel,80,-4,96,ReadSetting(skBorderOptions),'black,crop,stretch,fullheight,fullwidth');
        resolutionLabel := AddLabel(optionsBox,224,18,64,24,'Texture Resolution:');
        resolutionLine := AddLine(resolutionLabel,96,-4,48,ReadSetting(skResolution),'Texture Resolution: e.g 1024, 2048, 4096');
        imageAdjustmentBox := TGroupBox.Create(mainForm);
        imageAdjustmentBox.Parent := mainForm;
        imageAdjustmentBox.Top := optionsBox.Top + optionsBox.Height + 8;
        imageAdjustmentBox.Left := 8;
        imageAdjustmentBox.Caption := 'Image Adjustments';
        imageAdjustmentBox.Font.Size := 10;
        imageAdjustmentBox.ClientWidth := mainForm.Width - 24;
        imageAdjustmentBox.ClientHeight := 152;
        imageAdjustmentLabel := TLabel.Create(mainForm);
        imageAdjustmentLabel.Parent := mainForm;
        imageAdjustmentLabel.Width := imageAdjustmentBox.Width - 16;
        imageAdjustmentLabel.Height := 80;
        imageAdjustmentLabel.Left := 16;
        imageAdjustmentLabel.Top := imageAdjustmentBox.Top + 20;
        imageAdjustmentLabel.Caption := 'ENBs and other post processing programs will also affect loading screens.'#13#10'' + 'You can try these image adjustments in order to counteract the changes of post processing effects.';
        imageAdjustmentLabel.Font.Size := 9;
        brightnessLine := ImageAdjustment(imageAdjustmentLabel,inttostr(ReadSettingInt(skBrightness)),'Brightness: Default: 0, Range -100 - +100');
        contrastLine := ImageAdjustment(brightnessLine,inttostr(ReadSettingInt(skContrast)),'Contrast: Default: 0, Range -100 - +100');
        saturationLine := ImageAdjustment(contrastLine,inttostr(ReadSettingInt(skSaturation)),'Saturation: Default: 0, Range -100 - +100');
        gammaLine := ImageAdjustment(saturationLine,floattostr(ReadSetting(skGamma)),'Gamma: Increase to brighten the loading screens. Default: 1.0, Range: 0.0 - 4.0');
        btnOk := AddButton(nil,8,mainForm.Height - 64,'OK',1);
        btnCancel := AddButton(btnOk,btnOk.Width + 16,0,'Cancel',-1);
        btnAdvanced := AddButton(nil,mainForm.Width - 96,mainForm.Height - 64,'Advanced',2);
        modalResult := mainForm.ShowModal;
        if (modalResult = 1) Or (modalResult = 2) then begin
            if DirectoryExists(selectDirLine.Text) then begin
                WriteSetting(skSourcePath,selectDirLine.Text);
            end else begin 
                ErrorMsg('The source directory does not exist.');
            end;
            tmpInt := strtoint(widthLine.Text);
            if tmpInt > 0 then begin
                WriteSetting(skDisplayWidth,tmpInt);
            end else begin 
                ErrorMsg('Width must be a positive number.');
            end;
            tmpInt := strtoint(heightLine.Text);
            if tmpInt > 0 then begin
                WriteSetting(skDisplayHeight,tmpInt);
            end else begin 
                ErrorMsg('Height must be positive number.');
            end;
            tmpInt := strtoint(resolutionLine.Text);
            if tmpInt > 0 then begin
                WriteSetting(skResolution,tmpInt);
            end else begin 
                ErrorMsg('Resolution must be positive number.');
            end;
            WriteSetting(skDisableOtherLoadScreens,checkBoxDisableOthers.Checked);
            WriteSetting(skRecursive,checkBoxSubDirs.Checked);
            tmpStr := borderLine.Text;
            if (tmpStr = 'black') Or (tmpStr = 'crop') Or (tmpStr = 'fullheight') Or (tmpStr = 'fullwidth') Or (tmpStr = 'stretch') then begin
                WriteSetting(skBorderOptions,tmpStr);
            end else begin 
                ErrorMsg('Border option <' + tmpStr + '> is unknown.');
            end;
            WriteSetting(skTestMode,checkBoxTestMode.Checked);
            tmpInt := strtoint(frequencyLine.Text);
            if (tmpInt>=0) And (tmpInt<=100) then begin
                WriteSetting(skFrequency,tmpInt);
            end else begin 
                ErrorMsg('Frequency must be between 0 and +100.');
            end;
            brightness := strtoint(brightnessLine.Text);
            if (brightness>=-100) And (brightness<=100) then begin
                WriteSetting(skBrightness,brightness);
            end else begin 
                ErrorMsg('Brightness must be between -100 and +100.');
            end;
            tmpInt := strtoint(contrastLine.Text);
            if (tmpInt>=-100) And (tmpInt<=100) then begin
                WriteSetting(skContrast,tmpInt);
            end else begin 
                ErrorMsg('Contrast must be between -100 and +100.');
            end;
            if tmpInt>=0 then begin
                blackPoint := tmpInt * 0.5;
                whitePoint := 100.0 - tmpInt * 0.5;
            end else begin 
                blackPoint := tmpInt * 1.0;
                whitePoint := 100.0 - tmpInt * 1.0;
            end;
            saturation := strtoint(saturationLine.Text);
            if (saturation>=-100) And (saturation<=100) then begin
                WriteSetting(skSaturation,saturation);
            end else begin 
                ErrorMsg('Saturation must be between -100 and +100.');
            end;
            gamma := strtofloat(gammaLine.Text);
            if (gamma>=0.0) And (gamma<=4.0) then begin
                WriteSetting(skGamma,gamma);
            end else begin 
                ErrorMsg('Gamma must be between 0.0 and 4.0.');
            end;
            SaveSettings();
            if  Not error then begin
                brightness := brightness + 100;
                saturation := saturation + 100;
                if modalResult = 1 then begin
                    Main(ReadSetting(skSourcePath),ReadSettingBool(skDisableOtherLoadScreens),ReadSettingBool(skRecursive),false);
                end;
            end else begin 
                Log('	');
                Log('At least one setting has an incorrect value.');
                Log('	');
            end;
        end;
    finally
        mainForm.Free;
    end;
    if (modalResult = 2) And  Not error then begin
        Advanced();
    end;
end;

procedure __initialize__();
begin
    InitSettings();
    InitSettingKeys();
    Log('	');
    Log('	Running JLoadScreenGenerator ' + version);
    try 
        UI();
    except
        on E : Exception do begin
            Log('Error while running ' + scriptName);
            Log(E.ClassName + ' error raised, with message : ' + E.Message);
        end;
    end;
end;

// InitGlobals
procedure __init_globals__();
begin
    error := false;
end;

function Initialize: Integer;
begin
    __init_globals__();
    __initialize__();
end;

end.