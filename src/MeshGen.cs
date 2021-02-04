const float sourceUpperWidth = 45.5;
const float sourceLowerWidth = 1.1;
const float sourceHeightOffset = 1.0;
const float sourceHeight = 29.0;
const float sourceOffsetX = 2.5;
const float sourceOffsetY = 0.65;
const float sourceRatio = 1.6;

float heightFactor;
float widthFactor;

void FitToDisplayRatio (float displayRatio, float imageRatio) {
    // In the first part, the factors are adjusted, so the model fills the entire screen.
    // A width of 1.0 means the entire width of the image is visible on the screen, so width stays at 1.
    // For wider screens (ratioFactor > 1.0), the height is reduced.
    // Likewise for slimmer screens (ratioFactor < 1.0), the height is increased.
    float ratioFactor = displayRatio / sourceRatio;
    float width = 1.0;
    float height = 1.0 / ratioFactor;

    // Now the model fills the entire screen.
    // In order to keep the aspect ratio of the image, the model must be modified.
    // Here, the model only becomes smaller, in order to add black bars.

    string borderOption = ReadSetting (skBorderOptions);

    if (borderOption != "stretch") {
        if (displayRatio > imageRatio) {
            if (borderOption == "fullwidth") {
                height *= displayRatio / imageRatio;
            } else if (borderOption == "fullheight") {
                width = width * imageRatio / displayRatio;
            } else if (borderOption == "crop") {
                height = height * displayRatio / imageRatio;
            } else if (borderOption == "black") {
                width = width * imageRatio / displayRatio;
            }
        } else if (displayRatio < imageRatio) {
            if (borderOption == "fullwidth") {
                height = height * displayRatio / imageRatio;
            } else if (borderOption == "fullheight") {
                width = width * imageRatio / displayRatio;
            } else if (borderOption == "crop") {
                width = width * imageRatio / displayRatio;
            } else if (borderOption == "black") {
                height = height * displayRatio / imageRatio;
            }
        }
    }

    // Write result.
    widthFactor = width;
    heightFactor = height;
}

void CreateMeshes (string targetPath, string texturePath, TwbNifFile templateNif, bool sse, float displayRatio) {
    for (int i = 0; i < imagePathArray.Count (); i += 1) {
        Log ("	" + inttostr (i + 1) + "/" + inttostr (imagePathArray.Count ()) + ": " + targetPath + "\\" + imagePathArray[i] + ".nif");
        TwbNifBlock TextureSet;
        if (sse) {
            TextureSet = templateNif.Blocks[3];
        } else {
            TextureSet = templateNif.Blocks[4];
        }
        TdfElement Textures = TextureSet.Elements["Textures"];
        Textures[0].EditValue = texturePath + "\\" + imagePathArray[i] + ".dds";
        FitToDisplayRatio (displayRatio, strtofloat (imageWidthArray[i]) / strtofloat (imageHeightArray[i]));
        TdfElement VertexData;
        string VertexPrefix;
        int blockIndex = -1;
        if (sse) {
            TwbNifBlock TriShape = templateNif.Blocks[1];
            VertexData = TriShape.Elements["Vertex Data"];
            VertexPrefix = "Vertex\\";
        } else {
            TwbNifBlock TriShape = templateNif.Blocks[2];
            VertexData = TriShape.Elements["Vertices"];
            VertexPrefix = "";
        }

        // Top Left
        VertexData[0].NativeValues[VertexPrefix + "X"] = sourceOffsetX - sourceUpperWidth * widthFactor;
        VertexData[0].NativeValues[VertexPrefix + "Y"] = sourceOffsetY + sourceHeight * heightFactor - sourceHeightOffset * heightFactor;

        // Bottom Left
        VertexData[1].NativeValues[VertexPrefix + "X"] = sourceOffsetX - sourceUpperWidth * widthFactor - sourceLowerWidth * widthFactor * heightFactor;
        VertexData[1].NativeValues[VertexPrefix + "Y"] = sourceOffsetY - sourceHeight * heightFactor - sourceHeightOffset * heightFactor;

        // Bottom Right
        VertexData[2].NativeValues[VertexPrefix + "X"] = sourceOffsetX + sourceUpperWidth * widthFactor + sourceLowerWidth * widthFactor * heightFactor;
        VertexData[2].NativeValues[VertexPrefix + "Y"] = sourceOffsetY - sourceHeight * heightFactor - sourceHeightOffset * heightFactor;

        // Top Right
        VertexData[3].NativeValues[VertexPrefix + "X"] = sourceOffsetX + sourceUpperWidth * widthFactor;
        VertexData[3].NativeValues[VertexPrefix + "Y"] = sourceOffsetY + sourceHeight * heightFactor - sourceHeightOffset * heightFactor;

        templateNif.SaveToFile (targetPath + "\\" + imagePathArray[i] + ".nif");
    }
}

TwbNifFile LoadTemplateNif (string templatePath) {
    TwbNifFile templateNif = TwbNifFile.Create;
    string fullPath = templatePath;
    if (wbAppName == "SSE") {
        fullPath += "\\TemplateSSE.nif";
    } else {
        fullPath += "\\TemplateLE.nif";
    }
    try {
        templateNif.LoadFromFile (fullPath);
    } catch (Exception E) {
        ErrorMsg ("Error: Something went wrong when trying to load the template mesh. Path: " + fullPath);
    }
    return templateNif;
}

void MeshGen (bool advanced, string texturePathShort, string templatePath) {
    Log ("	Creating loading screen meshes...");
    TwbNifFile templateNif = LoadTemplateNif (templatePath);
    if (advanced) {
        // loop through aspect ratios and create meshes in subfolder
        TStringList aspectRatioList = TStringList.Create ();
        aspectRatioList.Delimiter = ",";
        aspectRatioList.StrictDelimiter = True;
        aspectRatioList.DelimitedText = ReadSetting (skAspectRatios);
        TStringList widthList = TStringList.Create ();
        TStringList heightList = TStringList.Create ();
        try {
            for (int i = 0; i < aspectRatioList.Count (); i += 1) {
                TStringList sideList = TStringList.Create ();
                sideList.Delimiter = "x";
                sideList.StrictDelimiter = True;
                sideList.DelimitedText = aspectRatioList[i];
                widthList.add (sideList[0]);
                heightList.add (sideList[1]);
            }
        } catch (Exception E) {
            Log (E.ClassName + " error raised, with message : " + E.Message);
            Log ("Error while parsing the aspect ratio list: " + ReadSetting (skAspectRatios));
            throw E;
        }
        for (int i = 0; i < aspectRatioList.Count (); i += 1) {
            string meshPath = DataPath + "meshes\\" + aspectRatioList[i] + "\\" + ReadSetting (skModFolder);
            Log ("	Creating loading screen meshes for aspect ratio: " + aspectRatioList[i]);
            forcedirectories (meshPath);
            CreateMeshes (meshPath, texturePathShort, templateNif, wbAppName == "SSE", strtofloat (widthList[i]) / strtofloat (heightList[i]));
        }
    } else {
        string meshPath = DataPath + "meshes\\JLoadScreens";
        forcedirectories (meshPath);
        CreateMeshes (meshPath, texturePathShort, templateNif, wbAppName == "SSE", ReadSettingInt (skDisplayWidth) / ReadSettingInt (skDisplayHeight));
    }
}