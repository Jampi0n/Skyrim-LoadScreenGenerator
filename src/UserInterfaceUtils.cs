float GetRelativeX (TForm relativeTo, float offset) {
    if (Assigned (relativeTo)) {
        Result = relativeTo.Left + offset;
    } else {
        Result = offset;
    }
}

float GetRelativeY (TForm relativeTo, float offset) {
    if (Assigned (relativeTo)) {
        Result = relativeTo.Top + offset;
    } else {
        Result = offset;
    }
}

TLabel AddLabel (TForm relativeTo, float offsetX, float offsetY, float width, float height, string value) {
    TLabel lbl = TLabel.Create (mainForm);
    lbl.Parent = mainForm;
    lbl.Width = width;
    lbl.Height = height;
    lbl.Left = GetRelativeX (relativeTo, offsetX);
    lbl.Top = GetRelativeY (relativeTo, offsetY);
    lbl.Caption = value;
    Result = lbl;
}

TEdit AddLine (TForm relativeTo, float offsetX, float offsetY, float width, string value, string hint) {
    TEdit line = TEdit.Create (mainForm);
    line.Parent = mainForm;
    line.Left = GetRelativeX (relativeTo, offsetX);
    line.Top = GetRelativeY (relativeTo, offsetY);
    line.Width = width;
    line.Caption = value;
    line.Font.Size = 10;
    line.Hint = hint;
    line.ShowHint = (hint != "");
    Result = line;
}

TGroupBox AddBox (TForm relativeTo, float offsetX, float offsetY, float width, float height, string caption) {
    TGroupBox box = TGroupBox.Create (mainForm);
    box.Parent = mainForm;
    box.Left = GetRelativeX (relativeTo, offsetX);
    box.Top = GetRelativeY (relativeTo, offsetY);
    box.Caption = caption;
    box.Font.Size = 10;
    box.ClientWidth = width;
    box.ClientHeight = height;
    Result = box;
}

TButton AddButton (TForm relativeTo, float offsetX, float offsetY, string caption, int modalResult) {
    TButton button = TButton.Create (mainForm);
    button.Parent = mainForm;
    button.Left = GetRelativeX (relativeTo, offsetX);
    button.Top = GetRelativeY (relativeTo, offsetY);
    button.Caption = caption;
    button.ModalResult = modalResult;
    Result = button;
}

TCheckBox AddCheckBox (TForm relativeTo, float offsetX, float offsetY, bool value, string caption, string hint) {
    TCheckBox checkBox = TCheckBox.Create (mainForm);
    checkBox.Parent = mainForm;
    checkBox.Left = GetRelativeX (relativeTo, offsetX);
    checkBox.Top = GetRelativeY (relativeTo, offsetY);
    checkBox.Width = 500;
    checkBox.Caption = caption;
    checkBox.Checked = value;
    checkBox.Hint = hint;
    checkBox.ShowHint = (hint != "");
    Result = checkBox;
}

TComboBox AddComboBox (TForm relativeTo, float offsetX, float offsetY, float width, string current, string options, string hint) {
    TComboBox comboBox = TComboBox.Create (mainForm);
    comboBox.Parent = mainForm;
    comboBox.Left = GetRelativeX (relativeTo, offsetX);
    comboBox.Top = GetRelativeY (relativeTo, offsetY);
    comboBox.Width = width;
    comboBox.Hint = hint;
    comboBox.ShowHint = (hint != "");
    comboBox.Style = csDropDownList;

    TStringList optionList = TStringList.Create ();
    optionList.Delimiter = ",";
    optionList.StrictDelimiter = True;
    optionList.DelimitedText = options;

    string allOptions = "";
    int currentIndex = 0;
    for (int i = 0; i < optionList.Count (); i += 1) {
        if (SameText (optionList[i], current)) {
            currentIndex = i;
        }
        allOptions += optionList[i];
        if (i < optionList.Count () - 1) {
            allOptions += "\n";
        }
    }

    comboBox.Items.Text = allOptions;
    comboBox.ItemIndex = currentIndex;

    Result = comboBox;
}