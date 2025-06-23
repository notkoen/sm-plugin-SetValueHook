#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <dhooks>

public Plugin myinfo = {
    name = "SetValue Vscript Hook",
    author = "koen",
    description = "Proof of concept plugin for hooking \"SetValue\" vscript function for CS:S",
    version = "",
    url = "https://github.com/notkoen"
};

DHookSetup g_hSetValueDtr;

public void OnPluginStart() {
    // This is for CS:S only
    EngineVersion iEngine = GetEngineVersion();
    if (iEngine != Engine_CSS) {
        SetFailState("ERROR! This plugin is for CS:S only!");
        return;
    }

    GameData gd;
    if ((gd = new GameData("SetValueHook.games")) == null) {
        LogError("[SetValueHook] Gamedata file not found or failed to load!");
        delete gd;
        return;
    }

    if ((g_hSetValueDtr = DynamicDetour.FromConf(gd, "SetValue")) == null) {
        LogError("[SetValueHook] Failed to setup \"SetValue\" detour!");
        delete gd;
        return;
    } else {
        if (!DHookEnableDetour(g_hSetValueDtr, false, Detour_SetValue)) {
            LogError("[SetValueHook] Failed to detour \"SetValue()\" function!");
        } else {
            LogMessage("[SetValueHook] Successfully detoured \"ClientPrint()\" function!");
        }
    }
}

public MRESReturn Detour_SetValue(Handle hParams) {
    // From https://developer.valvesoftware.com/wiki/Team_Fortress_2/Scripting/Script_Functions
    // void SetValue(string name, any value)

    // /!\ NOTE:
    // The "SetValue" hook from IDA shows there's actually 3 parameters
    // CScriptConvarAccessor::SetValue(int, char *, int)
    // I would assume first int is the instance

    PrintToChatAll("-------------------------[ Detour_SetValue ]-------------------------");

    // Get first unknown param
    // int iParam1 = DHookGetParam(hParams, 1);
    // PrintToChatAll("unknown param 1 = %d", iParam1);

    // Get cvar name
    char szCvar[128];
    DHookGetParamString(hParams, 2, szCvar, sizeof(szCvar));
    PrintToChatAll("(string) cvar = %s", szCvar);

    // Get value
    char szParam3[128];
    DHookGetParamString(hParams, 3, szParam3, sizeof(szParam3));
    int iParam3 = DHookGetParam(hParams, 3);
    PrintToChatAll("(int) value = %i", iParam3);
    PrintToChatAll("(string) value = %s", szParam3);

    PrintToChatAll("---------------------------------------------------------------------");
    return MRES_Supercede;
}