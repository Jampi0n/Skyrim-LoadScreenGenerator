{
	Produces a fully working standalone loading screen mod from images in a selected directory.
	Supported image types: .jpg, .png, .dds
	The images in the directory are not modified in any way. They are only used to create skyrim compatible textures from them.

	The script will work the same regardless of which record it is used on.

	Output meshes and textures are put in the data folder at "textures\JLoadScreens" and "meshes\JLoadScreens".
	If you start xedit with a mod manager like MO2, the files will appear in the overwrite folder of the mod manager.

	For help, feature suggestions or bug reports visit the mod page:
}
unit _J_LoadScreenGenerator;

const
	version = '1.2.0';

	scriptName = 'JLoadScreens';
	settingsName = 'Settings.txt';

	// Parameters to create model for specific screen aspect ratios.
	// The models needs to be slightly wider at the bottom than at the top.
	// These parameters have worked with the screen resolutions 16:9, 16:10 and 21:9.
	sourceUpperWidth = 45.5;
	sourceLowerWidth = 1.1;
	sourceHeightOffset = 1.0;
	sourceHeight = 29.0;
	sourceOffsetX = 2.5;
	sourceOffsetY = 0.65;
	sourceRatio = 1.6;

var
	editScriptsSubFolder : String;
	messageLog, settings : TStringList;
	settingKey, totalLoadScreens : Integer;
	heightFactor, widthFactor : Real;

	skSourcePath, skDisableOtherLoadScreens, skDisplayWidth, skDisplayHeight, skStretch, skRecursive, skFullHeight, skFrequency, skGamma, skContrast, skBrightness, skSaturation, sk4K : Integer;
	skModName, skModVersion, skModFolder, skPluginName, skModAuthor, skPrefix, skModLink, skTestMode, skAspectRatios, skTextureResolutions, skMessages, skFrequencyList, skDefaultFrequency : Integer;

	gamma, blackPoint, whitePoint, brightness, saturation : Real;

	imagePathArray,	imageWidthArray, imageHeightArray, imageTextArray : TStringList;

	error : Boolean;

	mainForm: TForm;


procedure ErrorMsg(msg : String);
begin
	error := True;
	AddMessage('	');
	AddMessage(msg);
	AddMessage('	');
end;

{
	Returns a new setting key and writes the default value, if the settings file does not have this setting.
}
function GetSettingKey(def : String) : Integer;
begin
	Result := settingKey;
	if settings.Count() <= settingKey then begin
		settings.Add('');
		WriteSetting(settingKey, def);
	end;
	settingKey := settingKey + 1;
end;

// ********************************************************************
// settings read/write functions
// ********************************************************************
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
end;

function ReadSettingFloat(idx : Integer) : Float;
begin
	Result := strtofloat(settings[idx]);
end;

function ReadSettingInt(idx : Integer) : Integer;
begin
	Result := strtoint(settings[idx]);
end;

function ReadSettingBool(idx : Integer) : Boolean;
begin
	Result := settings[idx] = 'True';
end;
// ********************************************************************
// settings read/write functions
// ********************************************************************

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

function ApproximateProbability(approximationArray : TStringList) : Real;
var
	i : Integer;
	approx : Real;
begin
	approx := 1.0;
	for i:= 0 to Pred(approximationArray.Count()) do begin
		approx := approx * strtofloat(approximationArray[i])
	end;
	Result := approx;
end;

function Abs(x : Real) : Real;
begin
	if x < 0 then Result:=-x else Result:=x;
end;

function ProbabilityLoss(probability : Real; approximationArray : TStringList) : Real;
begin
	Result := Abs(ApproximateProbability(approximationArray) / probability - 1.0 );
end;

function CreateRandomProbability(probability : Real; num_approx : Integer) : TStringList;
var
	i, j : Integer;
	dividedProb, bestLoss, currentLoss : Real;
	currentAttempt, bestAttempt, prevAttempt : TStringList;
begin
	Log('probability='+floattostr(probability));
	dividedProb := Trunc(100.0 * Power(probability, 1.0 / num_approx)) / 100.0;

	bestLoss := 1;
	bestAttempt := nil;

	currentAttempt := TStringList.Create();
	for i:=0 to Pred(num_approx) do begin
		currentAttempt.add(floattostr(dividedProb));
	end;
	currentLoss := ProbabilityLoss(probability, currentAttempt);
	Log('currentLoss='+floattostr(currentLoss));
	if currentLoss < bestLoss then begin
		bestLoss := currentLoss;
		bestAttempt := currentAttempt;
	end;

	for i:=0 to Pred(num_approx) do begin
		Log('i='+inttostr(i));
		prevAttempt := currentAttempt;
		currentAttempt := TStringList.Create();
		for j:=0 to Pred(num_approx) do begin
			currentAttempt.add(prevAttempt[j]);
		end;
		currentAttempt[i] := floattostr(strtofloat(currentAttempt[i]) + 0.01);

		for j:=0 to Pred(num_approx) do begin
			Log(currentAttempt[j]);
		end;

		currentLoss := ProbabilityLoss(probability, currentAttempt);
		Log('currentLoss='+floattostr(currentLoss));
		if currentLoss < bestLoss then begin
			bestLoss := currentLoss;
			bestAttempt := currentAttempt;
		end;
	end;

	Result := bestAttempt;

end;

function AddLabel(relativeTo : TForm; offsetX, offsetY, width, height : Real; value : String) : TLabel;
var
	lbl : TLabel;
begin
	lbl := TLabel.Create(mainForm);
	lbl.Parent := mainForm;
	lbl.Width := width;
	lbl.Height := height;
	lbl.Left := GetRelativeX(relativeTo, offsetX);
	lbl.Top := GetRelativeY(relativeTo, offsetY);
	lbl.Caption := value;
	Result := lbl;
end;

function AddLine(relativeTo : TForm; offsetX, offsetY, width : Real; value, hint : String) : TEdit;
var
	line : TEdit;
begin
	line := TEdit.Create(mainForm);
	line.Parent := mainForm;
	line.Left := GetRelativeX(relativeTo, offsetX);
	line.Top := GetRelativeY(relativeTo, offsetY);
	line.Width := width;
	line.Caption := value;
	line.Font.Size := 10;
	line.Hint := hint;
	line.ShowHint := (hint <> '');
	Result := line;
end;

function AddBox(relativeTo : TForm; offsetX, offsetY, width, height : Real; caption : String) : TGroupBox;
var
	box : TGroupBox;
begin
	box := TGroupBox.Create(mainForm);
	box.Parent := mainForm;
	box.Left := GetRelativeX(relativeTo, offsetX);
	box.Top := GetRelativeY(relativeTo, offsetY);	
	box.Caption := caption;
	box.Font.Size := 10;
	box.ClientWidth := width;
	box.ClientHeight := height;
	Result := box;
end;

function AddButton(relativeTo : TForm; offsetX, offsetY : Real; caption : String; modalResult : Integer) : TButton;
var
	button : TButton;
begin
	button := TButton.Create(mainForm);
	button.Parent := mainForm;
	button.Left := GetRelativeX(relativeTo, offsetX);
	button.Top := GetRelativeY(relativeTo, offsetY);	
	button.Caption := caption;
	button.ModalResult := modalResult;
	Result := button;
end;

function AddCheckBox(relativeTo : TForm; offsetX, offsetY : Real; value : Boolean; caption, hint : String) : TCheckBox;
var
	checkBox : TCheckBox;
begin
	checkBox := TCheckBox.Create(mainForm);
	checkBox.Parent := mainForm;
	checkBox.Left := GetRelativeX(relativeTo, offsetX);
	checkBox.Top := GetRelativeY(relativeTo, offsetY);
	checkBox.Width := 500;
	checkBox.Caption := caption;
	checkBox.Checked := value;
	checkBox.Hint := hint;
	checkBox.ShowHint := (hint <> '');
	Result := checkBox;
end;

procedure Log(msg: String);
begin
	addmessage(msg);
	messageLog.add('['+TimeToStr(Time)+'] '+msg);	
	messageLog.SaveToFile(editScriptsSubFolder+'\Log.txt');
end;

{
	Deletes a group from a plugin file.
}
procedure ClearGroup(fileHandle : IwbFile; signature : String;);
var
	group : IwbGroupRecord;
begin
	if HasGroup(fileHandle, signature) then begin
		group := GroupBySignature(fileHandle, signature);
		Remove(group);
	end;
end;

// ********************************************************************
// xEdit utility functions
// ********************************************************************
procedure SetValueString(handle: IInterface; path, value: string);
begin
	SetEditValue(ElementByPath(handle, path), value);
end;

procedure SetValueInt(handle: IInterface; path, value: integer);
begin
	SetValueString(handle, path, inttostr(value));
end;

procedure SetValueFloat(handle: IInterface; path, value: float);
begin
	SetValueString(handle, path, floattostr(value));
end;

procedure SetValueHex(handle: IInterface; path, value: integer);
begin
	SetValueString(handle, path, IntToHex(value, 8));
end;

procedure SetLinksTo(handle: IInterface; path, record_: IwbMainRecord);
begin
	SetValueString(handle, path, IntToHex(GetLoadOrderFormID(record_), 8));
end;
// ********************************************************************
// xEdit utility functions
// ********************************************************************

{
	Returns a plugin file with the given name.
}
function FileByName(s: string): IwbFile;
var
	i: integer;
begin
	Result := nil;
	for i := 0 to FileCount - 1 do begin
    	if GetFileName(FileByIndex(i)) = s then begin
    		Result := FileByIndex(i);
    		break;
    	end;
  	end;
end;

{
	Adds all masters of the element 'master' to the file 'esp'.
}
procedure AddMastersSmart(esp : IwbFile; master : IwbElement);
var
	masterList : TStringList;
	stringCount, i : Integer;
begin
	masterList := TStringList.Create;
	ReportRequiredMasters(master, masterList, false, false);
	stringCount := masterList.Count;
	for i := 0 to Pred(stringCount) do begin
		AddMasterIfMissing(esp, masterList[i]);
	end;
end;

{
	Adds impossible conditions to loading screens from other plugins.
}
procedure PatchLoadingScreens(esp : IwbFile);
var
	i, j: integer;
	group : IwbGroupRecord;
	fileHandle : IwbFile;
	oldRecord, newRecord : IwbMainRecord;
begin
	for i := 0 to FileCount - 1 do begin
		fileHandle := FileByIndex(i);
		if fileHandle <> esp then begin
			if HasGroup(fileHandle, 'LSCR') then begin
				group := GroupBySignature(fileHandle, 'LSCR');
				//AddMasterIfMissing(esp, fileHandle);
				//Log(GetFileName(fileHandle));
				for j := 0 to  Pred(ElementCount(group)) do begin
					//oldRecord := WinningOverride(ElementByIndex(group, j));
					//AddMasterIfMissing(esp, GetFileName(GetFile(winningRecord)));
					oldRecord := ElementByIndex(group, j);

					AddMastersSmart(esp, oldRecord);

					newRecord := wbCopyElementToFile(oldRecord, esp, false, true);
					Remove(ElementByPath(newRecord, 'Conditions'));

					Add(newRecord, 'Conditions', True);
					SetValueInt(newRecord, 'Conditions\[0]\CTDA\Type', 10100000);
					SetValueInt(newRecord, 'Conditions\[0]\CTDA\Comparison Value', -1);
					SetValueString(newRecord, 'Conditions\[0]\CTDA\Function', 'GetRandomPercent');
				end;
			end;
		end;
	end;

	SortMasters(esp);
	CleanMasters(esp);
end;

{
	Creates the esp plugin. Creates LSCR and STAT records for every new loading screen and disables other loading screens.
}
function CreateESP(fileName, meshPath : String; disableOthers, includeMessages : Boolean; frequency : Integer) : IwbFile;
var
	esp : IwbFile;
	i, j : Integer;
	lscrRecord, statRecord : IwbMainRecord;
	editorID, prefix : String;
	esl : Boolean;
	probability : Real;
	approximationArray : TStringList;
begin
	esp := FileByName(fileName);
	if not Assigned(esp) then begin
		esp := AddNewFileName(fileName, false);
	end;
	SetValueString(ElementByIndex(esp, 0), 'CNAM - Author', 'Jampion');
	SetValueInt(ElementByIndex(esp, 0), 'HEDR - Header\Next Object ID', 2048);

	esl := (wbAppName = 'SSE') and (imagePathArray.Count() < 1024);
	SetElementNativeValues(ElementByIndex(esp, 0), 'Record Header\Record Flags\ESL', esl);

	prefix := ReadSetting(skPrefix);

	Log('meshPath='+meshPath);

	ClearGroup(esp, 'LSCR');
	ClearGroup(esp, 'STAT');
	CleanMasters(esp);
	Add(esp, 'LSCR', True);
	Add(esp, 'STAT', True);

	probability := 1.0 - Power(1.0 - 0.01 * frequency, 1.0 / totalLoadScreens);

	approximationArray := CreateRandomProbability(probability, 4);

	for i:=0 to Pred(imagePathArray.Count()) do begin
		editorID := inttostr(i); //StringReplace(imagePathArray[i] ,' ', '_', [rfReplaceAll, rfIgnoreCase]);

		statRecord := Add(GroupBySignature(esp, 'STAT'), 'STAT', True);
		SetEditorID(statRecord , prefix +'STAT_' + editorID);

		Add(statRecord, 'MODL', True);
		SetValueString(statRecord, 'Model\MODL - Model FileName', meshPath + '\' + imagePathArray[i] + '.nif');
		SetValueInt(statRecord, 'DNAM\Max Angle (30-120)', 90);

		lscrRecord := Add(GroupBySignature(esp, 'LSCR'), 'LSCR', True);
		SetEditorID(lscrRecord, prefix + 'LSCR_' + editorID);
		SetLinksTo(lscrRecord, 'NNAM', statRecord);
		Add(lscrRecord, 'SNAM', True);
		SetValueInt(lscrRecord, 'SNAM', 2);
		Add(lscrRecord, 'RNAM', True);
		SetValueInt(lscrRecord, 'RNAM\X', -90);
		Add(lscrRecord, 'ONAM', True);
		Add(lscrRecord, 'XNAM', True);
		SetValueInt(lscrRecord, 'XNAM\X', -45);

		Log('Result');
		Add(lscrRecord, 'Conditions', True);
		for j:= 0 to Pred(approximationArray.Count()) do begin
			Log(approximationArray[j]);

			//Add(lscrRecord, 'Conditions', True);
			ElementAssign(ElementByPath(lscrRecord, 'Conditions'), HighInteger, nil, false);
			SetValueInt(lscrRecord, 'Conditions\[' + inttostr(j)+ ']\CTDA\Type', 10100000);
			SetValueInt(lscrRecord, 'Conditions\[' + inttostr(j)+ ']\CTDA\Comparison Value', Trunc(100 * strtofloat(approximationArray[j]))-1);
			SetValueString(lscrRecord, 'Conditions\[' + inttostr(j)+ ']\CTDA\Function', 'GetRandomPercent');
		end;
		Remove(ElementByPath(lscrRecord, 'Conditions\[' + inttostr(approximationArray.Count())+ ']'));

		{Log('probability = ' + floattostr(probability));
		i1 := Round(100 * Power(probability, 1.0/4.0));
		Log('i1 = ' + inttostr(i1));
		r1 := Power(0.01 * i1, 4);
		Log('approx probability = ' + floattostr(r1));}





		if includeMessages then begin
			SetValueString(lscrRecord, 'DESC - Description', imageTextArray[i]);
		end;
	end;
	if disableOthers then begin
		PatchLoadingScreens(esp);
	end;
end;

{
	Calculates width and height factors for given display and image ratios.
	Sets widthFactor and heightFactor.
}
procedure FitToDisplayRatio(displayRatio, imageRatio : Real; stretch : Boolean);
var
	ratioFactor, width, height : Real;
begin
	// In the first part, the factors are adjusted, so the model fills the entire screen.
	// A width of 1.0 means the entire width of the image is visible on the screen, so width stays at 1.
	// For wider screens (ratioFactor > 1.0), the height is reduced.
	// Likewise for slimmer screens (ratioFactor < 1.0), the height is increased.
	ratioFactor := displayRatio / sourceRatio;
	width := 1.0;
	height := 1.0 / ratioFactor;

	// Now the model fills the entire screen.
	// In order to keep the aspect ratio of the image, the model must be modified.
	// Here, the model only becomes smaller, in order to add black bars.

	if not stretch then begin
		// If the display is wider than the image, black bars on the left and right are required.
		// This is achieved by reducing the width of the model.
		if displayRatio > imageRatio then begin
			width := width * imageRatio / displayRatio;
		end;

		// If the image is wider than the display, black bars on the top and bottom are required.
		// This is achieved by reducing the height of the model.
		if displayRatio < imageRatio then begin
			if ReadSettingBool(skFullHeight) then begin
				width := width * imageRatio / displayRatio;
			end else begin
				height := height * displayRatio / imageRatio;
			end;
		end;
	end;

	// Write result.
	widthFactor := width;
	heightFactor := height;
end;

{
	Create meshes based on a template.
	Set texture and vertex positions according to image and screen resolution.
}
procedure CreateMeshes(targetPath, texturePath : string; templateNif : TwbNifFile; stretch, sse : Boolean; displayRatio : Real);
var
	i, j, vertices : integer;
	Textures, VertexData: TdfElement;
	TextureSet, TriShape: TwbNifBlock;
	VertexPrefix : String;
begin
	for i:=0 to Pred(imagePathArray.Count()) do begin
		if sse then TextureSet := templateNif.Blocks[3] else TextureSet := templateNif.Blocks[4];
		Textures := TextureSet.Elements['Textures'];
		Textures[0].EditValue := texturePath + '\' + imagePathArray[i] + '.dds';

		FitToDisplayRatio(displayRatio, strtofloat(imageWidthArray[i])/strtofloat(imageHeightArray[i]), stretch);
		if sse then begin
			TriShape := templateNif.Blocks[1];
			vertices := TriShape.NativeValues['Num Vertices'];
			VertexData := TriShape.Elements['Vertex Data'];
			VertexPrefix := 'Vertex\';
		end else begin
			TriShape := templateNif.Blocks[2];
			vertices := TriShape.NativeValues['Num Vertices'];
			VertexData := TriShape.Elements['Vertices'];
			VertexPrefix := '';
		end
		

		{Log('widthFactor='+floattostr(widthFactor));
		Log('heightFactor='+floattostr(heightFactor));
		Log('sourceUpperWidth='+floattostr(sourceUpperWidth));
		Log('sourceLowerWidth='+floattostr(sourceLowerWidth));
		Log('sourceHeight='+floattostr(sourceHeight));
		Log('sourceOffsetX='+floattostr(sourceOffsetX));
		Log('sourceOffsetY='+floattostr(sourceOffsetY));}

		// Top Left
		VertexData[0].NativeValues[VertexPrefix + 'X'] := sourceOffsetX - sourceUpperWidth * widthFactor;
		VertexData[0].NativeValues[VertexPrefix + 'Y'] := sourceOffsetY + sourceHeight * heightFactor - sourceHeightOffset * heightFactor;

		// Bottom Left
		VertexData[1].NativeValues[VertexPrefix + 'X'] := sourceOffsetX - sourceUpperWidth * widthFactor - sourceLowerWidth * widthFactor * heightFactor;
		VertexData[1].NativeValues[VertexPrefix + 'Y'] := sourceOffsetY - sourceHeight * heightFactor - sourceHeightOffset * heightFactor;

		// Bottom Right
		VertexData[2].NativeValues[VertexPrefix + 'X'] := sourceOffsetX + sourceUpperWidth * widthFactor + sourceLowerWidth * widthFactor * heightFactor;
		VertexData[2].NativeValues[VertexPrefix + 'Y'] := sourceOffsetY - sourceHeight * heightFactor - sourceHeightOffset * heightFactor;

		// Top Right
		VertexData[3].NativeValues[VertexPrefix + 'X'] := sourceOffsetX + sourceUpperWidth * widthFactor;
		VertexData[3].NativeValues[VertexPrefix + 'Y'] := sourceOffsetY + sourceHeight * heightFactor - sourceHeightOffset * heightFactor;

		templateNif.SaveToFile(targetPath + '\' + imagePathArray[i] + '.nif');
	end;
end;

{
	Add files with extension fileFilter to the list.
}
procedure AddFilesToList(filePath, fileFilter : string; list : TStringList; recursive : Boolean);
var
	matchedFiles: TStringDynArray;
	TDirectory: TDirectory;
	i : integer;
begin
	if recursive then begin
		matchedFiles := TDirectory.GetFiles(filePath, fileFilter, soAllDirectories);
	end else begin
		matchedFiles := TDirectory.GetFiles(filePath, fileFilter, soTopDirectoryOnly);
	end;
	for i:=0 to Pred(Length(matchedFiles)) do begin
		list.Add(matchedFiles[i]);
	end;
end;

{
	Read integer from the texdiag output file.
	The output starts at position 17.
}
function ParseTexDiagOutput(output : String) : String;
begin
	Result := Copy(output, 17, length(output));
end;

{
	Finds image files in the source folder. Converted .dds textures are saved in the data folder.
	The image paths, widths and heights are stored in StringLists.
	texconv.exe comes with SSEEdit
	texdiag.exe is inside the subfolder of this script
}
procedure ProcessTextures(sourcePath, targetPath: string; recursive : Boolean);
var
	TDirectory: TDirectory;
	sourceFiles: TStringDynArray;
	sourcePathList, texturePathList, readTextFile, ignoredFiles : TStringList;
	i, j, imageCount, tmp: integer;
	cmd, s, textFile, srgbCmd : string;
	Nif: TwbNifFile;
	srgb : Boolean;
begin

	sourcePathList := TStringList.Create;

	// Add all image files to a list.
	Log('	Scanning source directory for valid source images...');
	AddFilesToList(sourcePath, '*.dds', sourcePathList, recursive);
	AddFilesToList(sourcePath, '*.png', sourcePathList, recursive);
	AddFilesToList(sourcePath, '*.jpg', sourcePathList, recursive);
	
	imageCount := sourcePathList.Count();
	Log('	' + inttostr(imageCount) + ' images found in the source directory.');
	
	// Create StringLists to store image information.
	imagePathArray := TStringList.Create;
	imageWidthArray := TStringList.Create;
	imageHeightArray := TStringList.Create;
	imageTextArray := TStringList.Create;

	// This list is used to ensure files with the same base name are only used once.
	texturePathList := TStringList.Create;
	texturePathList.Sorted := True;
	texturePathList.Duplicates := dupIgnore;

	ignoredFiles := TStringList.Create;
	ignoredFiles.Sorted := True;
	ignoredFiles.Duplicates := dupIgnore;

	Log('	Creating textures from source images...');
	for i:=0 to Pred(imageCount) do begin
		Log('	' + inttostr(i+1) + '/' +  inttostr(imageCount));
		// Ensure this the only file with this name
		s := ChangeFileExt(ExtractFileName(sourcePathList[i]),'');
		if not texturePathList.Find(s, tmp) then begin
			texturePathList.Add(s);

			srgb := false;
			srgbCmd := '';

			// use texdiag to read input format
			try
				cmd := '/C  ""' + editScriptsSubFolder  + '\DirectXTex\texdiag.exe" info "' + sourcePathList[i] + '" -nologo >"' + editScriptsSubFolder + '\texdiag.txt""';
				ShellExecuteWait(0, nil, 'cmd.exe', cmd, '', SW_HIDE);
				// Read output from %subfolder%\texdiag.txt
				readTextFile := TStringList.Create();
				readTextFile.LoadFromFile(editScriptsSubFolder + '\texdiag.txt');

				if readTextFile.Count <=0 then raise exception.Create('texdiag.txt is empty.');
				if ContainsText(readTextFile[0], 'FAILED') then raise exception.Create('texdiag.exe failed to analyze the texture.');

				if ContainsText(ParseTexDiagOutput(readTextFile[6]), 'SRGB') then begin
					srgb := True;
				end;
			except
				on E : Exception do begin
      				Log(E.ClassName + ' error raised, with message : ' + E.Message);
					Log('Error while using texdiag.exe for image ' + sourcePathList[i]);
					continue;
				end;
			end;

			if srgb then srgbCmd := '-srgb ';

			try
				// Execute texconv.exe (timeout = 10 seconds)
				cmd := ' -m 1 -f BC1_UNORM ' + srgbCmd + '-o "' + targetPath + '" -y -w 2048 -h 2048 "' + sourcePathList[i] + '"';
				CreateProcessWait(ScriptsPath + 'Texconv.exe', cmd, SW_HIDE, 10000);
				cmd := ' -f BC1_UNORM ' + '-o "' + targetPath + '" -y -w 2048 -h 2048 "' + targetPath + '\' + s + '.dds' + ' "';
				CreateProcessWait(ScriptsPath + 'Texconv.exe', cmd, SW_HIDE, 10000);
			except
				on E : Exception do begin
      				Log(E.ClassName + ' error raised, with message : ' + E.Message);
					Log('Error while using texconv.exe for image ' + sourcePathList[i]);
					continue;
				end;
			end;

			try
				// Change gamma/contrast
				if (gamma <> 1.0) OR (ReadSettingInt(skContrast) <> 0) then begin
					cmd := '"' + targetPath + '\' + s + '.dds"';
					cmd := '/C ""' + editScriptsSubFolder  + '\ImageMagick\magick.exe" ' + cmd + ' -level ' + floattostr(blackPoint) + '%,' + floattostr(whitePoint) + '%,' + floattostr(gamma) + ' ' + cmd + '"';
					ShellExecuteWait(0, nil, 'cmd.exe', cmd, '', SW_HIDE);
				end;
				// Change brightness/saturation
				if (brightness <> 100.0) OR (saturation <> 100) then begin

					cmd := '"' + targetPath + '\' + s + '.dds"';
					cmd := '/C ""' + editScriptsSubFolder  + '\ImageMagick\magick.exe" ' + cmd + ' -modulate ' + floattostr(brightness) + ',' + floattostr(saturation) +  ' ' + cmd + '"';
					ShellExecuteWait(0, nil, 'cmd.exe', cmd, '', SW_HIDE);
				end;
			except
				on E : Exception do begin
      				Log(E.ClassName + ' error raised, with message : ' + E.Message);
					Log('Error while using magick.exe for image ' + sourcePathList[i]);
					continue;
				end;
			end;


			try
				// Execute %subfolder%\texdiag.exe
				// Output is saved to %subfolder%\texdiag.txt
				cmd := '/C  ""' + editScriptsSubFolder  + '\DirectXTex\texdiag.exe" info "' + sourcePathList[i] + '" -nologo >"' + editScriptsSubFolder + '\texdiag.txt""';
				ShellExecuteWait(0, nil, 'cmd.exe', cmd, '', SW_HIDE);
				// Read output from %subfolder%\texdiag.txt
				readTextFile := TStringList.Create();
				readTextFile.LoadFromFile(editScriptsSubFolder + '\texdiag.txt');

				if readTextFile.Count <=0 then raise exception.Create('texdiag.txt is empty.');
				if ContainsText(readTextFile[0], 'FAILED') then raise exception.Create('texdiag.exe failed to analyze the texture.');

				imagePathArray.Add(s);
				imageWidthArray.Add(inttostr(strtoint(ParseTexDiagOutput(readTextFile[1]))));
				imageHeightArray.Add(inttostr(strtoint(ParseTexDiagOutput(readTextFile[2]))));
				textFile := ChangeFileExt(sourcePathList[i],'.txt');
				if FileExists(textFile) then begin
					readTextFile := TStringList.Create();
					readTextFile.LoadFromFile(textFile);
					if readTextFile.Count <=0 then raise exception.Create(s + '.txt is empty.');
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
	end;

	if texturePathList.Count() < imageCount then begin
		Log('	');
		Log('	There were multiple images with the same name. Only one loading screen will be created for each image name.');
		Log('	Images may have the same name, because they use different extensions, e.g. image.jpg and image.png');
		Log('	Images may have the same name, because they are in different subdirectories of the source directory, e.g. image.jpg and subfolder\image.jpg');
		Log('	These images would all create a texture named image.dds, so only one of them can be used.');
		Log('	The following files have been ignored due to duplicate image names:');
		Log('	');
		for i:= 0 to Pred(ignoredFiles.Count()) do begin
			Log('	' + ignoredFiles[i]);
		end;
		Log('	');
		Log('	You can give these files unique names and run the script again.');
		Log('	');
	end;
	totalLoadScreens := imagePathArray.Count();
	Log('	Creating loading screens for ' + inttostr(totalLoadScreens) + ' images...');
	Log('	');
end;


procedure CreateESPOptions(pluginName, modFolder : String; disableOthers : Boolean; msgSetting : Integer; frequency : Integer );
begin
 	Log('modFolder='+modFolder);
	if msgSetting = 0 then begin
		CreateESP('FOMOD_M0_P' + inttostr(frequency) + '_FOMODEND_' + pluginName, modFolder, disableOthers, false, frequency);
	end else if msgSetting = 1 then begin
		CreateESP('FOMOD_M1_P' + inttostr(frequency) + '_FOMODEND_' + pluginName, modFolder, disableOthers, true, frequency);
	end else if msgSetting = 2 then begin
		CreateESP('FOMOD_M0_P' + inttostr(frequency) + '_FOMODEND_' + pluginName, modFolder, disableOthers, false, frequency);
		CreateESP('FOMOD_M1_P' + inttostr(frequency) + '_FOMODEND_' + pluginName, modFolder, disableOthers, true, frequency);
	end
end;

{
	Main function.
}
procedure Main(sourcePath : String; disableOthers, recursive, advanced : Boolean);
var
	templatePath, texturePath, meshPath, texturePathShort, cmd, pluginName : string;
	templateNif: TwbNifFile;
	aspectRatioList, sideList, widthList, heightList, frequencyList : TStringList;
	i, msgSetting : Integer;
begin
	Log('	Using source path: ' + sourcePath);
	templatePath := editScriptsSubFolder;

	pluginName := ReadSetting(skPluginName);

	if advanced then begin
		texturePath := DataPath + 'textures\' + ReadSetting(skModFolder);
		texturePathShort :=  'textures\' + ReadSetting(skModFolder);
		meshPath := DataPath + 'meshes\' + ReadSetting(skModFolder);

		forcedirectories(texturePath);
	end else begin
		texturePath := DataPath + 'textures\JLoadScreens';
		texturePathShort := 'textures\JLoadScreens';
		meshPath := DataPath + 'meshes\JLoadScreens';

		// MO2 automatically creates folders
		// Force directories, so it works without MO2
		forcedirectories(meshPath);
		forcedirectories(texturePath);
	end;



	// Create .dds files in texture path
	ProcessTextures(sourcePath, texturePath, recursive);

	// Load template mesh
	templateNif := TwbNifFile.Create;
	try
		if wbAppName = 'SSE' then begin
			templateNif.LoadFromFile(templatePath + '\TemplateSSE.nif');
		end else begin
			templateNif.LoadFromFile(templatePath + '\TemplateLE.nif');
		end;
	except
		Log('Error: Something went wrong when trying to load the template mesh.');
	end;

	// Create .nif files in mesh path
	if advanced then begin
		// loop through aspect ratios and create meshes in subfolder
		Log(ReadSetting(skAspectRatios));

		aspectRatioList := TStringList.Create();
		aspectRatioList.Delimiter := ',';
		aspectRatioList.StrictDelimiter := True;
   		aspectRatioList.DelimitedText   := ReadSetting(skAspectRatios);

		widthList := TStringList.Create();
		heightList := TStringList.Create();
		try
			for i:=0 to Pred(aspectRatioList.Count()) do begin
				Log('aspectRatioList[i] = ' + aspectRatioList[i]);
				sideList := TStringList.Create();
				sideList.Delimiter := 'x';
				sideList.StrictDelimiter := True;
				sideList.DelimitedText := aspectRatioList[i];

				widthList.add(sideList[0]);
				heightList.add(sideList[1]);
			end;
		except
			on E : Exception do begin
				Log(E.ClassName + ' error raised, with message : ' + E.Message);
				Log('Error while parsing the aspect ratio list: ' + ReadSetting(skAspectRatios));
				Raise E;
			end;
		end;
		for i:=0 to Pred(aspectRatioList.Count()) do begin
			forcedirectories(DataPath + 'meshes\' + aspectRatioList[i] + '\' +  ReadSetting(skModFolder));
			CreateMeshes(DataPath + 'meshes\' + aspectRatioList[i] + '\' +  ReadSetting(skModFolder), texturePathShort, templateNif, ReadSettingBool(skStretch), wbAppName = 'SSE', strtofloat(widthList[i]) / strtofloat(heightList[i]) );
		end;


	end else begin
		CreateMeshes(meshPath, texturePathShort, templateNif, ReadSettingBool(skStretch), wbAppName = 'SSE', ReadSettingInt(skDisplayWidth) / ReadSettingInt(skDisplayHeight));
	end;

	// Create .esp
	if advanced then begin
		Log(ReadSetting(skMessages));
		

		msgSetting := 1;
		if ReadSetting(skMessages) = 'optional' then begin
			msgSetting := 2;
		end else if ReadSetting(skMessages) = 'always' then begin
			msgSetting := 1;
		end else if ReadSetting(skMessages) = 'never' then begin
			msgSetting := 0;
		end else begin
			msgSetting := 1;
			Log('The messages option ' + ReadSetting(skMessages) + ' is invalid; "always" will be used instead.');
		end;
			frequencyList := TStringList.Create();
			frequencyList.Delimiter := ',';
			frequencyList.StrictDelimiter := True;
			frequencyList.DelimitedText   := ReadSetting(skFrequencyList);
			for i:=0 to Pred(frequencyList.Count()) do begin
				CreateESPOptions(pluginName, ReadSetting(skModFolder), disableOthers, msgSetting, strtoint(frequencyList[i]));
			end;

	end else begin
		CreateESP(pluginName, ReadSetting(skModFolder), disableOthers, true, ReadSettingInt(skFrequency));
	end;

	if advanced then begin
		{cmd := '/K "python "' + editScriptsSubFolder  + '\Python\create_fomod.py"' +
		' --aspect-ratios ' + ReadSetting(skAspectRatios) + 
		' --messages ' + ReadSetting(skMessages) + 
		' --frequency '+ ReadSetting(skFrequencyOptions) + 
		' --source "' + ReadSetting(skSourcePath) + '"' +
		' --mod-folder "' + ReadSetting(skModFolder) + '"' +
		' --mod-author "' + ReadSetting(skModAuthor) + '"' +
		' --mod-name "' + ReadSetting(skModName) + '"' +
		' --mod-version ' + ReadSetting(skModVersion) + 
		' --data-path "' + ExcludeTrailingBackSlash(DataPath) + '"' +
		' "';
		Log(cmd);
		ShellExecuteWait(0, nil, 'cmd.exe', cmd, '', SW_SHOW);}
		CopyFile(editScriptsSubFolder + '\Custom\create_fomod.cmd', DataPath + 'create_fomod.cmd', false);
		CopyFile(editScriptsSubFolder + '\Custom\create_fomod.py', DataPath + 'create_fomod.py' , false);
		CopyFile(editScriptsSubFolder + '\settings.txt', DataPath + 'settings.txt' , false);
	end;
end;

{
	Runs, if the user clicks on the directory selection line and lets the user select a directory with a dialog.
}
procedure PickSourcePath(Sender: TObject);
var
	i : Integer;
	path : String;
begin
	path := ReadSetting(skSourcePath);
	path := SelectDirectory('Select folder for generated meshes', '', path, '');
	if path <> '\' then begin
		Sender.Text := path;
		WriteSetting(skSourcePath, path);
	end;
end;


function ImageAdjustment(prevAdj : TForm; lineText, description : String) : TEdit;
var
	lbl : TLabel;
	line : TEdit;
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


function Advanced: Integer;
var
  	modNameLabel, modVersionLabel, modFolderLabel, modPluginLabel, modAuthorLabel, modPrefixLabel, modLinkLabel, messagesLabel, frequencyListLabel, frequencyDefaultLabel: TLabel;
	screenResolutionBox, optionsBox, modBox : TGroupBox;
	screenResolutionLine, modNameLine, modVersionLine, modFolderLine, modPluginLine, modAuthorLine, modPrefixLine, modLinkLine, messagesLine, frequencyListLine, frequencyDefaultLine : TEdit;
	btnOk, btnCancel: TButton;
	tmpInt, modalResult : Integer;
	tmpReal : Real;
begin
	mainForm := TForm.Create(nil);
	try
		mainForm.Caption := 'Jampion''s Loading Screen Generator';
		mainForm.Width := 640;
		mainForm.Height := 500;
		mainForm.Position := poScreenCenter;

		screenResolutionBox := AddBox(mainForm, 8, 8, mainForm.Width-24, 48, 'Aspect Ratios');
		screenResolutionLine := AddLine(screenResolutionBox, 16, 16, mainForm.Width - 128, ReadSetting(skAspectRatios), 'Comma separated list of aspect ratios, e.g. "16x9,16x10,21x9"');

		modBox := AddBox(screenResolutionBox, 0, screenResolutionBox.Height + 8, mainForm.Width-24, 192, 'Mod Configuration');

		modNameLabel := AddLabel(modBox, 16, 24, 160, 24, 'Mod name');
		modNameLine := AddLine(modNameLabel, 80, -4, mainForm.Width - 128, ReadSetting(skModName), 'The display name of the mod. Will be used for the FOMOD installer.');

		modVersionLabel := AddLabel(modNameLabel, 0, 24, 160, 24, 'Mod version');
		modVersionLine := AddLine(modVersionLabel, 80, -4, mainForm.Width - 128, ReadSetting(skModVersion), 'Will be used for the FOMOD installer.');

		modFolderLabel := AddLabel(modVersionLabel, 0, 24, 160, 24, 'Sub folder');
		modFolderLine := AddLine(modFolderLabel, 80, -4, mainForm.Width - 128, ReadSetting(skModFolder), 'Sub folder, in which textures and meshes are generated. "MyMod" will result in "textures/MyMod" and "meshes/MyMod".');

		modAuthorLabel := AddLabel(modFolderLabel, 0, 24, 160, 24, 'Author');
		modAuthorLine := AddLine(modAuthorLabel, 80, -4, mainForm.Width - 128, ReadSetting(skModAuthor), 'Your name :).');

		modPluginLabel := AddLabel(modAuthorLabel, 0, 24, 160, 24, 'Plugin');
		modPluginLine := AddLine(modPluginLabel, 80, -4, mainForm.Width - 128, ReadSetting(skPluginName), 'The name of the generated plugin (with extension).');

		modPrefixLabel := AddLabel(modPluginLabel, 0, 24, 160, 24, 'Prefix');
		modPrefixLine := AddLine(modPrefixLabel, 80, -4, mainForm.Width - 128, ReadSetting(skPrefix), 'This prefix is added to all records.');

		modLinkLabel := AddLabel(modPrefixLabel, 0, 24, 160, 24, 'Prefix');
		modLinkLine := AddLine(modLinkLabel, 80, -4, mainForm.Width - 128, ReadSetting(skModLink), 'Will be used for the FOMOD installer.');


		optionsBox := AddBox(modBox, 0, modBox.Height + 8, mainForm.Width-24, 128, 'Options');

		messagesLabel := AddLabel(optionsBox, 16, 24, 160, 24, 'Messages');
		messagesLine := AddLine(messagesLabel, 80, -4, mainForm.Width - 128, ReadSetting(skMessages), 'always/never/optional');

		frequencyListLabel := AddLabel(messagesLabel, 0, 24, 160, 24, 'Freq. List');
		frequencyListLine := AddLine(frequencyListLabel, 80, -4, mainForm.Width - 128, ReadSetting(skFrequencyList), 'Comma separated list of frequencies, e.g. "5,15,50,100"');

		frequencyDefaultLabel := AddLabel(frequencyListLabel, 0, 24, 160, 24, 'Def. Freq.');
		frequencyDefaultLine := AddLine(frequencyDefaultLabel, 80, -4, mainForm.Width - 128, ReadSetting(skDefaultFrequency), 'Default frequency.');

		btnOk := AddButton(nil, 8, mainForm.Height - 64, 'OK', 1);
		btnCancel := AddButton(btnOk, 80, 0, 'Cancel', 2);
		modalResult := mainForm.ShowModal;
		Log(inttostr(modalResult));
		if modalResult = 1 then begin

			WriteSetting(skAspectRatios, screenResolutionLine.Text);
			WriteSetting(skModName, modNameLine.Text);
			WriteSetting(skModVersion, modVersionLine.Text);
			WriteSetting(skModFolder, modFolderLine.Text);
			WriteSetting(skModAuthor, modAuthorLine.Text);
			WriteSetting(skPluginName, modPluginLine.Text);
			WriteSetting(skPrefix, modPrefixLine.Text);
			WriteSetting(skModLink, modLinkLine.Text);
			WriteSetting(skMessages, messagesLine.Text);
			WriteSetting(skFrequencyList, frequencyListLine.Text);
			WriteSetting(skDefaultFrequency, frequencyDefaultLine.Text);

			SaveSettings();
			if not error then begin
				Main(ReadSetting(skSourcePath), ReadSettingBool(skDisableOtherLoadScreens), ReadSettingBool(skRecursive), true);
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

{
	Show the UI. Run main function on OK.
}
function UI: Integer;
var
  	selectDirLabel, screenResolutionLabel, colonLabel, frequencyLabel, imageAdjustmentLabel, gammaLabel, contrastLabel, brightnessLabel, saturationLabel: TLabel;
	screenResolutionBox, selectDirBox, optionsBox, imageAdjustmentBox : TGroupBox;
	selectDirLine, widthLine, heightLine, gammaLine, contrastLine, brightnessLine, saturationLine, frequencyLine : TEdit;
	checkBoxDisableOthers, checkBoxStretch, checkBoxSubDirs, checkBoxTestMode, checkBoxFullHeight : TCheckBox;
	btnOk, btnCancel, btnAdvanced: TButton;
	tmpInt, modalResult : Integer;
	tmpReal : Real;
begin
	mainForm := TForm.Create(nil);
	try
		mainForm.Caption := 'Jampion''s Loading Screen Generator';
		mainForm.Width := 640;
		mainForm.Height := 500;
		mainForm.Position := poScreenCenter;

		selectDirBox := AddBox(mainForm, 8, 0, mainForm.Width-24, 48, 'Source Directory');
		selectDirLine := AddLine(selectDirBox, 8, 16, mainForm.Width - 128, ReadSetting(skSourcePath), 'Click to select folder in explorer.');
		selectDirLine.OnClick := PickSourcePath;

		screenResolutionBox := AddBox(selectDirBox, 0, selectDirBox.Height + 8, mainForm.Width-24, 80, 'Target Aspect Ratio');

		widthLine := AddLine(screenResolutionBox, 8, 16, 64, ReadSetting(skDisplayWidth), 'Enter your display width.');
		colonLabel := AddLabel(widthLine, widthLine.Width, 0, 8, 30, ':');
		colonLabel.Font.Size := 12;
		heightLine := AddLine(colonLabel, 8, 0, 64, ReadSetting(skDisplayHeight), 'Enter your display height.');

 		screenResolutionLabel := AddLabel(widthLine, 0, widthLine.Height, screenResolutionBox.Width - 16, 120, 
		 	'The loading screens will be generated for this aspect ratio.'#13#10
			'Either use your resolution (e.g. 1920:1080) or your aspect ratio (e.g. 16:9).'
		);
		screenResolutionLabel.Font.Size := 9;

		optionsBox := AddBox(screenResolutionBox, 0, screenResolutionBox.Height + 8, mainForm.Width-24, 128, 'Options');

		checkBoxDisableOthers := AddCheckBox(optionsBox, 8, 16, ReadSettingBool(skDisableOtherLoadScreens), 'Disable other Loading Screens', 'Prevents other loading screens (other mods and vanilla) from showing.');
		checkBoxStretch := AddCheckBox(checkBoxDisableOthers, 0, 16, ReadSettingBool(skStretch), 'Stretch images to fill the entire screen', 'Stretches images, if their aspect ratio differs from the target aspect ratio.');
		checkBoxFullHeight := AddCheckBox(checkBoxStretch, 0, 16, ReadSettingBool(skFullHeight), 'Force full height', 'There are no black bars at the top and bottom. Wider pictures will be cropped at the sides.');
		checkBoxSubDirs := AddCheckBox(checkBoxFullHeight, 0, 16, ReadSettingBool(skRecursive), 'Include subdirectories', 'Includes subdirectories of the source directory, when searching for images.');
		checkBoxTestMode := AddCheckBox(checkBoxSubDirs, 0, 16, ReadSettingBool(skTestMode), 'Test Mode', 'Adds a global variable, which can be used to force specific loading screens.');
		frequencyLabel := AddLabel(checkBoxTestMode, 0, 24, 64, 24, 'Frequency:');
		frequencyLine := AddLine(frequencyLabel, 64, -4, 64, ReadSetting(skFrequency), 'Loading screen frequency: 0 - 100');

		imageAdjustmentBox := TGroupBox.Create(mainForm);
		imageAdjustmentBox.Parent := mainForm;
		imageAdjustmentBox.Top := optionsBox.Top + optionsBox.Height + 8;
		imageAdjustmentBox.Left := 8;
		imageAdjustmentBox.Caption := 'Image Adjustments';
		imageAdjustmentBox.Font.Size := 10;
		imageAdjustmentBox.ClientWidth := mainForm.Width-24;
		imageAdjustmentBox.ClientHeight := 152;

		imageAdjustmentLabel := TLabel.Create(mainForm);
		imageAdjustmentLabel.Parent := mainForm;
		imageAdjustmentLabel.Width := imageAdjustmentBox.Width - 16;
		imageAdjustmentLabel.Height := 80;
		imageAdjustmentLabel.Left := 16;
		imageAdjustmentLabel.Top := imageAdjustmentBox.Top + 20;
		imageAdjustmentLabel.Caption :=
			'ENBs and other post processing programs will also affect loading screens.'#13#10
			'You can try these image adjustments in order to counteract the changes of post processing effects.';
		imageAdjustmentLabel.Font.Size := 9;

		brightnessLine := ImageAdjustment(imageAdjustmentLabel, inttostr(ReadSettingInt(skBrightness)), 'Brightness: Default: 0, Range -100 - +100');
		contrastLine := ImageAdjustment(brightnessLine, inttostr(ReadSettingInt(skContrast)), 'Contrast: Default: 0, Range -100 - +100');
		saturationLine := ImageAdjustment(contrastLine, inttostr(ReadSettingInt(skSaturation)), 'Saturation: Default: 0, Range -100 - +100');
		gammaLine := ImageAdjustment(saturationLine, floattostr(ReadSetting(skGamma)), 'Gamma: Increase to brighten the loading screens. Default: 1.0, Range: 0.0 - 4.0');


		btnOk := AddButton(nil, 8, mainForm.Height - 64, 'OK', 1);
		btnCancel := AddButton(btnOk, btnOk.Width + 16, 0, 'Cancel', -1);
		btnAdvanced := AddButton(nil, mainForm.Width - 96, mainForm.Height - 64, 'Advanced', 2);

		modalResult := mainForm.ShowModal;
		if (modalResult = 1) or (modalResult = 2) then begin
			if DirectoryExists(selectDirLine.Text) then WriteSetting(skSourcePath, selectDirLine.Text) else ErrorMsg('The source directory does not exist.');



			tmpInt := strtoint(widthLine.Text);
			
			if tmpInt > 0 then WriteSetting(skDisplayWidth, tmpInt) else ErrorMsg('Width must be a positive number.');
			tmpInt := strtoint(heightLine.Text);
			if tmpInt > 0 then WriteSetting(skDisplayHeight, tmpInt) else ErrorMsg('Height must be positive number.');


			WriteSetting(skDisableOtherLoadScreens, checkBoxDisableOthers.Checked);
			WriteSetting(skStretch, checkBoxStretch.Checked);
			WriteSetting(skRecursive, checkBoxSubDirs.Checked);
			WriteSetting(skFullHeight, checkBoxFullHeight.Checked);
			WriteSetting(skTestMode, checkBoxTestMode.Checked);
			
			tmpInt := strtoint(frequencyLine.Text);
			if (tmpInt >= 0) and (tmpInt <= 100) then WriteSetting(skFrequency, tmpInt ) else ErrorMsg('Frequency must be between 0 and +100.');

			brightness := strtoint(brightnessLine.Text);
			if (brightness >= -100) and (brightness <= 100) then WriteSetting(skBrightness, brightness ) else ErrorMsg('Brightness must be between -100 and +100.');

			tmpInt := strtoint(contrastLine.Text);
			if (tmpInt >= -100) and (tmpInt <= 100) then WriteSetting(skContrast, tmpInt ) else ErrorMsg('Contrast must be between -100 and +100.');

			if tmpInt >= 0 then begin
				blackPoint := tmpInt * 0.5;
				whitePoint := 100.0 - tmpInt * 0.5; 
			end else begin
				blackPoint := tmpInt * 1.0;
				whitePoint := 100.0 - tmpInt * 1.0; 
			end;

			saturation := strtoint(saturationLine.Text);
			if (saturation >= -100) and (saturation <= 100) then WriteSetting(skSaturation, saturation ) else ErrorMsg('Saturation must be between -100 and +100.');

			gamma := strtofloat(gammaLine.Text);
			if (gamma >= 0.0) and (gamma <= 4.0) then WriteSetting(skGamma, gamma ) else ErrorMsg('Gamma must be between 0.0 and 4.0.');


			SaveSettings();
			if not error then begin
				brightness := brightness + 100;
				saturation := saturation + 100;
				if modalResult = 1 then begin
					Main(ReadSetting(skSourcePath), ReadSettingBool(skDisableOtherLoadScreens), ReadSettingBool(skRecursive), false);
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

	if (modalResult = 2) and not error then begin
		Advanced();
	end;
end;

{
	Initializes paths and the settings file.
}
procedure InitSettings();
begin
	editScriptsSubFolder := ScriptsPath + scriptName;
	settings := TStringList.Create;
	messageLog := TStringList.Create;
	settingKey := 0;
	if FileExists(editScriptsSubFolder + '\' + settingsName) then begin
		settings.LoadFromFile(editScriptsSubFolder + '\' + settingsName);
	end
end;

{
	Calculates greatest common divisor of a and b.
}
function GCD(a,b : Integer) : Integer;
begin
	if b = 0 then begin
		Result := a;
	end else begin
		Result := GCD(b, a mod b);
	end;
end;

{
	Creates a setting key for every setting and writes the default value, if the setting was not found in the settings file.
}
procedure InitSettingKeys();
var
	gcdResolution : Integer;
begin
	skSourcePath := GetSettingKey('');
	skDisableOtherLoadScreens := GetSettingKey('True');
	gcdResolution := GCD(Screen.Width, Screen.Height);
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

	skModName :=  GetSettingKey('Nazeem''s Loading Screen Mod');
	skModVersion :=  GetSettingKey('1.0.0');
	skModFolder := GetSettingKey('NazeemLoadScreens');
	skPluginName := GetSettingKey('NazeemsLoadingScreenMod.esp');
	skModAuthor := GetSettingKey('Nazeem');
	skPrefix := GetSettingKey('Nzm_');
	skAspectRatios := GetSettingKey('16x9,16x10,21x9,4x3');
	skTextureResolutions := GetSettingKey('2');
	skMessages := GetSettingKey('optional');

	skFrequencyList :=  GetSettingKey('5,10,15,25,35,50,70,100');
	skDefaultFrequency := GetSettingKey('15');

	skModLink := GetSettingKey('https://www.nexusmods.com/skyrimspecialedition/mods/36556');

end;

function Initialize: Integer;
var
	files : TStringList;
begin
	error := false;
	InitSettings();
	InitSettingKeys();
	
	Log('	');
	Log('	Running JLoadScreenGenerator ' + version);
	UI();
end;

function Finalize: Integer;
begin
end;

end.