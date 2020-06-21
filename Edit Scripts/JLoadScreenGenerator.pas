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
	modName = 'JLoadScreens.esp';
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
	settingKey : Integer;
	displayRatio, heightFactor, widthFactor : Real;

	skSourcePath, skDisableOtherLoadScreens, skDisplayWidth, skDisplayHeight, skStretch, skRecursive, skGamma, skContrast, skBrightness, skSaturation : Integer;

	gamma, blackPoint, whitePoint, brightness, saturation : Real;

	imagePathArray,	imageWidthArray, imageHeightArray : TStringList;

	error : Boolean;


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

procedure Log(msg: String);
begin
	addmessage(msg);
	messageLog.add('['+TimeToStr(Time)+'] '+msg);	
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
function CreateESP(fileName : String; disableOthers : Boolean) : IwbFile;
var
	esp : IwbFile;
	i : Integer;
	lscrRecord, statRecord : IwbMainRecord;
	editorID : String;
	esl : Boolean;
begin
	esp := FileByName(fileName);
	if not Assigned(esp) then begin
		esp := AddNewFileName(fileName, false);
	end;
	SetValueString(ElementByIndex(esp, 0), 'CNAM - Author', 'Jampion');
	SetValueInt(ElementByIndex(esp, 0), 'HEDR - Header\Next Object ID', 2048);

	esl := (wbAppName = 'SSE') and (imagePathArray.Count() < 1024);
	SetElementNativeValues(ElementByIndex(esp, 0), 'Record Header\Record Flags\ESL', esl);

	ClearGroup(esp, 'LSCR');
	ClearGroup(esp, 'STAT');
	CleanMasters(esp);
	Add(esp, 'LSCR', True);
	Add(esp, 'STAT', True);
	for i:=0 to Pred(imagePathArray.Count()) do begin
		editorID := inttostr(i); //StringReplace(imagePathArray[i] ,' ', '_', [rfReplaceAll, rfIgnoreCase]);

		statRecord := Add(GroupBySignature(esp, 'STAT'), 'STAT', True);
		SetEditorID(statRecord ,'J_STAT_' + editorID);

		Add(statRecord, 'MODL', True);
		SetValueString(statRecord, 'Model\MODL - Model FileName', 'JLoadScreens\' + imagePathArray[i] + '.nif');
		SetValueInt(statRecord, 'DNAM\Max Angle (30-120)', 90);

		lscrRecord := Add(GroupBySignature(esp, 'LSCR'), 'LSCR', True);
		SetEditorID(lscrRecord, 'J_LSCR_' + editorID);
		SetLinksTo(lscrRecord, 'NNAM', statRecord);
		Add(lscrRecord, 'SNAM', True);
		SetValueInt(lscrRecord, 'SNAM', 2);
		Add(lscrRecord, 'RNAM', True);
		SetValueInt(lscrRecord, 'RNAM\X', -90);
		Add(lscrRecord, 'ONAM', True);
		Add(lscrRecord, 'XNAM', True);
		SetValueInt(lscrRecord, 'XNAM\X', -45);

		Add(lscrRecord, 'Conditions', True);
		SetValueInt(lscrRecord, 'Conditions\[0]\CTDA\Type', 10100000);
		SetValueInt(lscrRecord, 'Conditions\[0]\CTDA\Comparison Value', 100);
		SetValueString(lscrRecord, 'Conditions\[0]\CTDA\Function', 'GetRandomPercent');

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
			height := height * displayRatio / imageRatio;
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
procedure CreateMeshes(targetPath : string; templateNif : TwbNifFile; stretch : Boolean);
var
	i, j, vertices : integer;
	Textures, VertexData: TdfElement;
	TextureSet, TriShape: TwbNifBlock;
begin
	for i:=0 to Pred(imagePathArray.Count()) do begin
		TextureSet := templateNif.Blocks[3];
		Textures := TextureSet.Elements['Textures'];
		Textures[0].EditValue := 'textures\JLoadScreens\' + imagePathArray[i] + '.dds';

		FitToDisplayRatio(displayRatio, strtofloat(imageWidthArray[i])/strtofloat(imageHeightArray[i]), stretch);
		TriShape := templateNif.Blocks[1];
		vertices := TriShape.NativeValues['Num Vertices'];
		VertexData := TriShape.Elements['Vertex Data'];

		{Log('widthFactor='+floattostr(widthFactor));
		Log('heightFactor='+floattostr(heightFactor));
		Log('sourceUpperWidth='+floattostr(sourceUpperWidth));
		Log('sourceLowerWidth='+floattostr(sourceLowerWidth));
		Log('sourceHeight='+floattostr(sourceHeight));
		Log('sourceOffsetX='+floattostr(sourceOffsetX));
		Log('sourceOffsetY='+floattostr(sourceOffsetY));}

		// Top Left
		VertexData[0].NativeValues['Vertex\X'] := sourceOffsetX - sourceUpperWidth * widthFactor;
		VertexData[0].NativeValues['Vertex\Y'] := sourceOffsetY + sourceHeight * heightFactor - sourceHeightOffset * heightFactor;

		// Bottom Left
		VertexData[1].NativeValues['Vertex\X'] := sourceOffsetX - sourceUpperWidth * widthFactor - sourceLowerWidth * widthFactor * heightFactor;
		VertexData[1].NativeValues['Vertex\Y'] := sourceOffsetY - sourceHeight * heightFactor - sourceHeightOffset * heightFactor;

		// Bottom Right
		VertexData[2].NativeValues['Vertex\X'] := sourceOffsetX + sourceUpperWidth * widthFactor + sourceLowerWidth * widthFactor * heightFactor;
		VertexData[2].NativeValues['Vertex\Y'] := sourceOffsetY - sourceHeight * heightFactor - sourceHeightOffset * heightFactor;

		// Top Right
		VertexData[3].NativeValues['Vertex\X'] := sourceOffsetX + sourceUpperWidth * widthFactor;
		VertexData[3].NativeValues['Vertex\Y'] := sourceOffsetY + sourceHeight * heightFactor - sourceHeightOffset * heightFactor;

		templateNif.SaveToFile(targetPath + imagePathArray[i] + '.nif');
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
function ParseTexDiagOutput(output : String) : Integer;
begin
	Result := strtoint(Copy(output, 17, length(output)));
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
	sourcePathList, texturePathList, readDiagOutput, ignoredFiles : TStringList;
	i, j, imageCount, tmp: integer;
	cmd, s: string;
	Nif: TwbNifFile;
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

	// This list is used to ensure files with the same base name are only used once.
	texturePathList := TStringList.Create;
	texturePathList.Sorted := True;
	texturePathList.Duplicates := dupIgnore;

	ignoredFiles := TStringList.Create;
	ignoredFiles.Sorted := True;
	ignoredFiles.Duplicates := dupIgnore;

	Log('	Creating textures from source images...');
	for i:=0 to Pred(imageCount) do begin
		// Ensure this the only file with this name
		s := ChangeFileExt(ExtractFileName(sourcePathList[i]),'');
		if not texturePathList.Find(s, tmp) then begin
			texturePathList.Add(s);

			try
				// Execute texconv.exe (timeout = 10 seconds)
				cmd := ' -m 1 -f BC1_UNORM -o "' + targetPath + '" -y -w 2048 -h 2048 "' + sourcePathList[i] + '"';
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
				readDiagOutput := TStringList.Create();
				readDiagOutput.LoadFromFile(editScriptsSubFolder + '\texdiag.txt');

				if readDiagOutput.Count <=0 then raise exception.Create('texdiag.txt is empty.');
				if ContainsText(readDiagOutput[0], 'FAILED') then raise exception.Create('texdiag.exe failed to analyze the texture.');

				imagePathArray.Add(s);
				imageWidthArray.Add(inttostr(ParseTexDiagOutput(readDiagOutput[1])));
				imageHeightArray.Add(inttostr(ParseTexDiagOutput(readDiagOutput[2])));
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
	Log('	Creating loading screens for ' + inttostr(imagePathArray.Count()) + ' images...');
	Log('	');
end;

{
	Main function.
}
procedure Main(sourcePath : String; disableOthers, recursive : Boolean);
var
	templatePath, texturePath, meshPath : string;
	templateNif: TwbNifFile;
begin
	Log('	Using source path: ' + sourcePath);
	templatePath := editScriptsSubFolder;
	texturePath := DataPath + 'textures\JLoadScreens';
	meshPath := DataPath + 'meshes\JLoadScreens\';

	// MO2 automatically creates folders
	// Force directories, so it works without MO2
	forcedirectories(meshPath);
	forcedirectories(texturePath);

	// Create .dds files in texture path
	ProcessTextures(sourcePath, texturePath, recursive);

	// Load template mesh
	templateNif := TwbNifFile.Create;
	try
		templateNif.LoadFromFile(templatePath + '\Template.nif');
	except
		Log('Error: Something went wrong when trying to load the template mesh.');
	end;

	// Create .nif files in mesh path
	CreateMeshes(meshPath, templateNif, ReadSettingBool(skStretch));

	// Create .esp
	CreateESP(modName, disableOthers);
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
	path := IncludeTrailingBackslash(SelectDirectory('Select folder for generated meshes', '', path, ''));
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

{
	Show the UI. Run main function on OK.
}
function UI: Integer;
var
	mainForm: TForm;
  	selectDirLabel, screenResolutionLabel, colonLabel, imageAdjustmentLabel, gammaLabel, contrastLabel, brightnessLabel, saturationLabel: TLabel;
	screenResolutionBox, selectDirBox, optionsBox, imageAdjustmentBox : TGroupBox;
	selectDirLine, widthLine, heightLine, gammaLine, contrastLine, brightnessLine, saturationLine : TEdit;
	checkBoxDisableOthers, checkBoxStretch, checkBoxSubDirs : TCheckBox;
	btnOk, btnCancel: TButton;
	tmpInt : Integer;
	tmpReal : Real;
begin
	mainForm := TForm.Create(nil);
	try
		mainForm.Caption := 'Jampion''s Loading Screen Generator';
		mainForm.Width := 640;
		mainForm.Height := 480;
		mainForm.Position := poScreenCenter;

		
		selectDirBox := TGroupBox.Create(mainForm);
		selectDirBox.Parent := mainForm;
		selectDirBox.Top := 8;
		selectDirBox.Left := 8;
		selectDirBox.Caption := 'Source Directory';
		selectDirBox.Font.Size := 10;
		selectDirBox.ClientWidth := mainForm.Width-24;
		selectDirBox.ClientHeight := 48;

		selectDirLine := TEdit.Create(mainForm);
		selectDirLine.Parent := mainForm;
		selectDirLine.Top := selectDirBox.Top + 16;
		selectDirLine.Left := 16;
		selectDirLine.Width := mainForm.Width - 40;
		selectDirLine.Caption := ReadSetting(skSourcePath);
		selectDirLine.Font.Size := 10;
		selectDirLine.Hint := 'Click to select folder in explorer';
		selectDirLine.ShowHint := true;
		selectDirLine.OnClick := PickSourcePath;


		screenResolutionBox := TGroupBox.Create(mainForm);
		screenResolutionBox.Parent := mainForm;
		screenResolutionBox.Top := selectDirBox.Top + selectDirBox.Height;
		screenResolutionBox.Left := 8;
		screenResolutionBox.Caption := 'Target Aspect Ratio';
		screenResolutionBox.Font.Size := 10;
		screenResolutionBox.ClientWidth := mainForm.Width-24;
		screenResolutionBox.ClientHeight := 80;

		widthLine := TEdit.Create(mainForm);
		widthLine.Parent := mainForm;
		widthLine.Top := screenResolutionBox.Top + 16;
		widthLine.Left := 16;
		widthLine.Width := 64;
		widthLine.Caption := ReadSetting(skDisplayWidth);
		widthLine.Font.Size := 10;
		widthLine.Hint := 'Select your display width';
		widthLine.ShowHint := true;
		widthLine.OnClick := nil;

		colonLabel := TLabel.Create(mainForm);
		colonLabel.Parent := mainForm;
		colonLabel.Width := 8;
		colonLabel.Height := 30;
		colonLabel.Left := widthLine.Left + widthLine.Width;
		colonLabel.Top := widthLine.Top;
		colonLabel.Caption := ':';
		colonLabel.Font.Size := 12;

		heightLine := TEdit.Create(mainForm);
		heightLine.Parent := mainForm;
		heightLine.Top := colonLabel.Top;
		heightLine.Left := colonLabel.Left + colonLabel.width;
		heightLine.Width := 64;
		heightLine.Caption := ReadSetting(skDisplayHeight);
		heightLine.Font.Size := 10;
		heightLine.Hint := 'Select your display height';
		heightLine.ShowHint := true;
		heightLine.OnClick := nil;

		screenResolutionLabel := TLabel.Create(mainForm);
		screenResolutionLabel.Parent := mainForm;
		screenResolutionLabel.Width := screenResolutionBox.Width - 16;
		screenResolutionLabel.Height := 120;
		screenResolutionLabel.Left := widthLine.Left;
		screenResolutionLabel.Top := widthLine.Top + widthLine.Height;
		screenResolutionLabel.Caption :=
			'The loading screens will be generated for this aspect ratio.'#13#10
			'Either use your resolution (e.g. 1920:1080) or your aspect ratio (e.g. 16:9).';
		screenResolutionLabel.Font.Size := 9;
		
		optionsBox := TGroupBox.Create(mainForm);
		optionsBox.Parent := mainForm;
		optionsBox.Top := screenResolutionBox.Top + screenResolutionBox.Height;
		optionsBox.Left := 8;
		optionsBox.Caption := 'Options';
		optionsBox.Font.Size := 10;
		optionsBox.ClientWidth := mainForm.Width-24;
		optionsBox.ClientHeight := 80;

		checkBoxDisableOthers := TCheckBox.Create(mainForm);
		checkBoxDisableOthers.Parent := mainForm;
		checkBoxDisableOthers.Caption := 'Disable other Loading Screens';
		checkBoxDisableOthers.Top := optionsBox.Top + 16;
		checkBoxDisableOthers.Left := 16;
		checkBoxDisableOthers.Width := 260;
		checkBoxDisableOthers.Checked := ReadSettingBool(skDisableOtherLoadScreens);
		checkBoxDisableOthers.Hint := 'Prevents other loading screens (other mods and vanilla) from showing.';
		checkBoxDisableOthers.ShowHint := True;


		checkBoxStretch := TCheckBox.Create(mainForm);
		checkBoxStretch.Parent := mainForm;
		checkBoxStretch.Caption := 'Stretch images to fill the entire screen';
		checkBoxStretch.Top := checkBoxDisableOthers.Top + checkBoxDisableOthers.Height;
		checkBoxStretch.Left := checkBoxDisableOthers.Left;
		checkBoxStretch.Width := 260;
		checkBoxStretch.Checked := ReadSettingBool(skStretch);
		checkBoxStretch.Hint := 'Stretches images, if their aspect ratio differs from the target aspect ratio.';
		checkBoxStretch.ShowHint := True;

		checkBoxSubDirs := TCheckBox.Create(mainForm);
		checkBoxSubDirs.Parent := mainForm;
		checkBoxSubDirs.Caption := 'Include subdirectories';
		checkBoxSubDirs.Top := checkBoxStretch.Top + checkBoxStretch.Height;
		checkBoxSubDirs.Left := checkBoxStretch.Left;
		checkBoxSubDirs.Width := 260;
		checkBoxSubDirs.Checked := ReadSettingBool(skStretch);
		checkBoxSubDirs.Hint := 'Includes subdirectories of the source directory, when searching for images.';
		checkBoxSubDirs.ShowHint := True;

		imageAdjustmentBox := TGroupBox.Create(mainForm);
		imageAdjustmentBox.Parent := mainForm;
		imageAdjustmentBox.Top := optionsBox.Top + optionsBox.Height;
		imageAdjustmentBox.Left := 8;
		imageAdjustmentBox.Caption := 'Image Adjustments';
		imageAdjustmentBox.Font.Size := 10;
		imageAdjustmentBox.ClientWidth := mainForm.Width-24;
		imageAdjustmentBox.ClientHeight := 192;

		imageAdjustmentLabel := TLabel.Create(mainForm);
		imageAdjustmentLabel.Parent := mainForm;
		imageAdjustmentLabel.Width := imageAdjustmentBox.Width - 16;
		imageAdjustmentLabel.Height := 72;
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



		btnOk := TButton.Create(mainForm);
		btnOk.Parent := mainForm;
		btnOk.Left := 8;
		btnOk.Top := mainForm.Height - 64;
		btnOk.Caption := 'OK';
		btnOk.ModalResult := mrOk;

		btnCancel := TButton.Create(mainForm);
		btnCancel.Parent := mainForm;
		btnCancel.Caption := 'Cancel';
		btnCancel.ModalResult := mrCancel;
		btnCancel.Left := btnOk.Left + btnOk.Width + 16;
		btnCancel.Top := btnOk.Top;

		if mainForm.ShowModal = mrOk then begin

			if DirectoryExists(selectDirLine.Text) then WriteSetting(skSourcePath, selectDirLine.Text) else ErrorMsg('The source directory does not exist.');

			WriteSetting(skDisableOtherLoadScreens, checkBoxDisableOthers.Checked);
			WriteSetting(skStretch, checkBoxStretch.Checked);

			tmpInt := strtoint(widthLine.Text);
			
			if tmpInt > 0 then WriteSetting(skDisplayWidth, tmpInt) else ErrorMsg('Width must be a positive number.');
			tmpInt := strtoint(heightLine.Text);
			if tmpInt > 0 then WriteSetting(skDisplayHeight, tmpInt) else ErrorMsg('Height must be positive number.');

			displayRatio := ReadSettingInt(skDisplayWidth) / ReadSettingInt(skDisplayHeight);

			WriteSetting(skRecursive, checkBoxSubDirs.Checked);

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
				Main(ReadSetting(skSourcePath), ReadSettingBool(skDisableOtherLoadScreens), ReadSettingBool(skRecursive));
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
end;

function Initialize: Integer;
var
	files : TStringList;
begin
	error := false;
	InitSettings();
	InitSettingKeys();
	
	Log('	');
	Log('	JLoadScreenGenerator runs.');
	UI();
end;

function Finalize: Integer;
begin
	messageLog.SaveToFile(editScriptsSubFolder+'\Log.txt');
end;

end.