TStringList messageLog;

void trace (string msg) {
    messageLog.add ("[" + TimeToStr (Time) + "] " + msg);
    messageLog.SaveToFile (editScriptsSubFolder + "\\Log.txt");
}

void log (string msg) {
    addmessage (msg);
    Trace (msg);
}

void errorMsg (string msg) {
    error = true;
    Log ("	");
    Log (msg);
    Log ("	");
}