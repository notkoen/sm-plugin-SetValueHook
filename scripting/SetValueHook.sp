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

    // /!\ NOTE: The "SetValue" hook from IDA shows there's actually 3 parameters:
    //           1. (unknown), 2. string, 3. any
    //           Issue right now is we do not know how to get "any" parameter.
    PrintToChatAll("-------------------------[ Detour_SetValue ]-------------------------");

    // Get cvar name
    char szCvar[128];
    DHookGetParamString(hParams, 2, szCvar, sizeof(szCvar));
    PrintToChatAll("string cvar = %s", szCvar);

    // Because the value can be multiple data types, we need to do this shit
    // EDIT: The below code doesn't work.
    char szValue[64] = "";
    DHookGetParamString(hParams, 3, szValue, sizeof(szValue));
    if (strcmp(szValue, "")) {
        PrintToChatAll("any value = %s (string)", szValue);
        PrintToChatAll("-------------------------------------------------------------------------");
        return MRES_Supercede;
    }

    bool bValue = DHookGetParam(hParams, 3);
    if (bValue || !bValue) {
        PrintToChatAll("any value = %b (bool)", bValue);
        PrintToChatAll("-------------------------------------------------------------------------");
        return MRES_Supercede;
    }

    float flValue = DHookGetParam(hParams, 3);
    if (flValue) {
        PrintToChatAll("any value = %.2f (float)", flValue);
        PrintToChatAll("-------------------------------------------------------------------------");
        return MRES_Supercede;
    }

    int iValue = DHookGetParam(hParams, 3);
    if (iValue) {
        PrintToChatAll("any value = %d (int)", iValue);
        PrintToChatAll("-------------------------------------------------------------------------");
        return MRES_Supercede;
    }

    PrintToChatAll("[SetValueHook] ERROR - Detour_SetValue param 2 returned invalid type?");
    PrintToChatAll("-------------------------------------------------------------------------");
    return MRES_Supercede;
}