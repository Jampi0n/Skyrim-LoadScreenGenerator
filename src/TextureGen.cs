void AddFilesToList (string filePath, string fileFilter, TStringList list, bool recursive) {
    TStringDynArray matchedFiles;
    TDirectory TDirectory;
    if (recursive) {
        matchedFiles = TDirectory.GetFiles (filePath, fileFilter, soAllDirectories);
    } else {
        matchedFiles = TDirectory.GetFiles (filePath, fileFilter, soTopDirectoryOnly);
    }
    for (int i = 0; i < Length (matchedFiles); i += 1) {
        list.Add (matchedFiles[i]);
    }
}

string ParseTexDiagOutput (string output) {
    Result = Copy (output, 17, length (output));
}

void ProcessTextures (string sourcePath, string targetPath, bool recursive, bool advanced) {
    int tmp;
    string cmd;
    TStringList sourcePathList = TStringList.Create ();

    // Add all image files to a list.
    Log ("	Scanning source directory for valid source images...");
    AddFilesToList (sourcePath, "*.dds", sourcePathList, recursive);
    AddFilesToList (sourcePath, "*.png", sourcePathList, recursive);
    AddFilesToList (sourcePath, "*.jpg", sourcePathList, recursive);

    int imageCount = sourcePathList.Count ();
    Log ("	" + inttostr (imageCount) + " images found in the source directory.");

    // Create StringLists to store image information.
    imagePathArray = TStringList.Create ();
    imageWidthArray = TStringList.Create ();
    imageHeightArray = TStringList.Create ();
    imageTextArray = TStringList.Create ();

    // This list is used to ensure files with the same base name are only used once.
    TStringList texturePathList = TStringList.Create ();
    texturePathList.Sorted = True;
    texturePathList.Duplicates = dupIgnore;

    TStringList ignoredFiles = TStringList.Create ();
    ignoredFiles.Sorted = True;
    ignoredFiles.Duplicates = dupIgnore;

    string resolution = inttostr (ReadSettingInt (skResolution));
    Log ("	Creating textures from source images...");
    for (int i = 0; i < imageCount; i += 1) {
        // Ensure this the only file with this name
        string s = ChangeFileExt (ExtractFileName (sourcePathList[i]), "");
        Log ("	" + inttostr (i + 1) + "/" + inttostr (imageCount) + ": " + s);
        if (!texturePathList.Find (s, tmp)) {

            texturePathList.Add (s);

            if (ReadSettingBool (skGenerateTextures) || !advanced) {
                bool srgb = false;
                string srgbCmd = "";

                // use texdiag to read input format
                try {
                    cmd = "/C  \"\"" + editScriptsSubFolder + "\\DirectXTex\\texdiag.exe\" info \"" + sourcePathList[i] + "\" -nologo > \"" + editScriptsSubFolder + "\\texdiag.txt\"\"";
                    ShellExecuteWait (0, nil, "cmd.exe", cmd, "", SW_HIDE);
                    // Read output from %subfolder%\texdiag.txt
                    TStringList readTextFile = TStringList.Create ();
                    readTextFile.LoadFromFile (editScriptsSubFolder + "\\texdiag.txt");

                    if (readTextFile.Count <= 0) {
                        throw exception.Create ("texdiag.txt is empty.");
                    }
                    if (ContainsText (readTextFile[0], "FAILED")) {
                        throw exception.Create ("texdiag.exe failed to analyze the texture.");
                    }

                    if (ContainsText (ParseTexDiagOutput (readTextFile[6]), "SRGB")) {
                        srgb = True;
                    }
                } catch (Exception E) {
                    Log (E.ClassName + " error raised, with message : " + E.Message);
                    Log ("Error while using texdiag.exe for image " + sourcePathList[i]);
                    continue;
                }

                if (srgb) {
                    srgbCmd = "-srgb ";
                }

                try {
                    // Execute texconv.exe (timeout = 10 seconds)
                    cmd = " -m 1 -f BC1_UNORM " + srgbCmd + "-o \"" + targetPath + "\" -y -w " + resolution + " -h " + resolution + " \"" + sourcePathList[i] + "\"";
                    CreateProcessWait (ScriptsPath + "Texconv.exe", cmd, SW_HIDE, 10000);
                    cmd = " -f BC1_UNORM " + "-o \"" + targetPath + "\" -y -w " + resolution + " -h " + resolution + " \"" + targetPath + "\\" + s + ".dds" + " \"";
                    CreateProcessWait (ScriptsPath + "Texconv.exe", cmd, SW_HIDE, 10000);
                } catch (Exception E) {
                    Log (E.ClassName + " error raised, with message : " + E.Message);
                    Log ("Error while using texconv.exe for image " + sourcePathList[i]);
                    continue;
                }

                try {
                    // Change gamma/contrast
                    if ((gamma != 1.0) || (ReadSettingInt (skContrast) != 0)) {

                        cmd = "\"" + targetPath + "\\" + s + ".dds\"";
                        cmd = "/C \"\"" + editScriptsSubFolder + "\\ImageMagick\\magick.exe\" " + cmd + " - level " + floattostr (blackPoint) + " %," + floattostr (whitePoint) + " %," + floattostr (gamma) + " " + cmd + "\"";
                        ShellExecuteWait (0, nil, "cmd.exe", cmd, "", SW_HIDE);
                    }
                    // Change brightness/saturation
                    if ((brightness != 100.0) || (saturation != 100)) {

                        cmd = "\"" + targetPath + "\\" + s + ".dds\"";
                        cmd = "/C \"\"" + editScriptsSubFolder + "\\ImageMagick\\magick.exe\" " + cmd + " - modulate " + floattostr (brightness) + "," + floattostr (saturation) + " " + cmd + "\"";
                        ShellExecuteWait (0, nil, "cmd.exe", cmd, "", SW_HIDE);
                    }
                } catch (Exception E) {

                    Log (E.ClassName + " error raised, with message : " + E.Message);
                    Log ("Error while using magick.exe for image " + sourcePathList[i]);
                    continue;
                }
            }

            if (ReadSettingBool (skGenerateMeshes) || !advanced) {
                try {
                    // Execute %subfolder%\texdiag.exe
                    // Output is saved to %subfolder%\texdiag.txt
                    cmd = "/C  \"\"" + editScriptsSubFolder + "\\DirectXTex\\texdiag.exe\" info \"" + sourcePathList[i] + "\" -nologo > \"" + editScriptsSubFolder + "\\texdiag.txt\"\"";
                    ShellExecuteWait (0, nil, "cmd.exe", cmd, "", SW_HIDE);
                    // Read output from %subfolder%\texdiag.txt
                    TStringList readTextFile = TStringList.Create ();
                    readTextFile.LoadFromFile (editScriptsSubFolder + "\\texdiag.txt");

                    if (readTextFile.Count <= 0) {
                        throw exception.Create ("texdiag.txt is empty.");
                    }
                    if (ContainsText (readTextFile[0], "FAILED")) {
                        throw exception.Create ("texdiag.exe failed to analyze the texture.");
                    }

                    imagePathArray.Add (s);
                    imageWidthArray.Add (inttostr (strtoint (ParseTexDiagOutput (readTextFile[1]))));
                    imageHeightArray.Add (inttostr (strtoint (ParseTexDiagOutput (readTextFile[2]))));
                    string textFile = ChangeFileExt (sourcePathList[i], ".txt");
                    if (FileExists (textFile)) {
                        readTextFile = TStringList.Create ();
                        readTextFile.LoadFromFile (textFile);
                        if (readTextFile.Count <= 0) {
                            throw exception.Create (s + ".txt is empty.");
                        }
                        imageTextArray.Add (readTextFile[0]);
                    } else {
                        imageTextArray.Add ("");
                    }
                } catch (Exception E) {
                    Log ("	");
                    Log (E.ClassName + " error raised, with message : " + E.Message);
                    Log ("Error while using texdiag.exe for image " + sourcePathList[i]);
                    Log ("	");
                    continue;
                }
            } else {
                imagePathArray.Add (s);
                if (FileExists (textFile)) {
                    readTextFile = TStringList.Create ();
                    readTextFile.LoadFromFile (textFile);
                    if (readTextFile.Count <= 0) {
                        throw exception.Create (s + ".txt is empty.");
                    }
                    imageTextArray.Add (readTextFile[0]);
                } else {
                    imageTextArray.Add ("");
                }
            }

        } else {
            ignoredFiles.Add (sourcePathList[i]);
        }
    }

    if (texturePathList.Count () < imageCount) {
        Log ("	");
        Log ("	There were multiple images with the same name. Only one loading screen will be created for each image name.");
        Log ("	Images may have the same name, because they use different extensions, e.g. image.jpg and image.png");
        Log ("	Images may have the same name, because they are in different subdirectories of the source directory, e.g. image.jpg and subfolder\\image.jpg");
        Log ("	These images would all create a texture named image.dds, so only one of them can be used.");
        Log ("	The following files have been ignored due to duplicate image names:");
        Log ("	");
        for (int i = 0; i < ignoredFiles; i += 1) {

            Log ("	" + ignoredFiles[i]);
        }
        Log ("	");
        Log ("	You can give these files unique names and run the script again.");
        Log ("	");
    }
    totalLoadScreens = imagePathArray.Count ();
}