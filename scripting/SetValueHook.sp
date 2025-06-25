#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <dhooks>

// ScriptVariant_t field types (from debug)
#define FIELD_FLOAT         1
#define FIELD_INTEGER       5
#define FIELD_CSTRING       30

public Plugin myinfo = {
    name = "SetValue Vscript Hook",
    author = ".Rushaway, koen",
    description = "Proof of concept plugin for hooking \"SetValue\" vscript function for CS:S",
    version = "1.0",
    url = "https://github.com/notkoen"
};

DHookSetup g_hSetValueDtr;

public void OnPluginStart() {
    EngineVersion iEngine = GetEngineVersion();
    if (iEngine != Engine_CSS) {
        SetFailState("ERROR! This plugin is for CS:S only!");
        return;
    }

    GameData gd = new GameData("SetValueHook.games");
    if (gd == null) {
        LogError("[SetValueHook] Gamedata file not found or failed to load!");
        return;
    }

    g_hSetValueDtr = DynamicDetour.FromConf(gd, "SetValue");
    if (g_hSetValueDtr == null) {
        LogError("[SetValueHook] Failed to setup \"SetValue\" detour!");
        delete gd;
        return;
    }

    if (!DHookEnableDetour(g_hSetValueDtr, false, Detour_SetValue)) {
        LogError("[SetValueHook] Failed to detour \"SetValue()\" function!");
        delete gd;
        return;
    }

    LogMessage("[SetValueHook] Successfully detoured \"SetValue()\" function!");
    delete gd;
}

public void OnPluginEnd() {
    if (g_hSetValueDtr != null) {
        DHookDisableDetour(g_hSetValueDtr, false, Detour_SetValue);
        delete g_hSetValueDtr;
    }
}

/**
 * Detour callback for CScriptConvarAccessor::SetValue
 * From https://developer.valvesoftware.com/wiki/Team_Fortress_2/Scripting/Script_Functions
 * 
 * Original C++ signature:
 * void CScriptConvarAccessor::SetValue(const char *cvar, ScriptVariant_t value)
 * 
 * Compiled signature (with implicit 'this' pointer):
 * CScriptConvarAccessor::SetValue(this*, const char*, ScriptVariant_t)
 * 
 * @param hParams   DHooks parameter handle
 * @return          MRES_Handled to block original execution, MRES_Ignored to continue
 */
public MRESReturn Detour_SetValue(Handle hParams) {
    // Extract ConVar name from first parameter (const char *cvar)
    char szCvar[128];
    DHookGetParamString(hParams, 1, szCvar, sizeof(szCvar));

    // Get address of ScriptVariant_t structure (second parameter)
    // This structure contains both the type and value data
    Address pVariant = DHookGetParamAddress(hParams, 2);
    if (pVariant == Address_Null) {
        LogError("[SetValueHook] Failed to get ScriptVariant_t address!");
        return MRES_Ignored;
    }

    PrintToChatAll("-------------------------[ Detour_SetValue ]-------------------------");
    PrintToChatAll("Cvar: %s", szCvar);

    // Read type from offset +8 (based on assembly: movzx eax, word ptr [edi+8])
    int iType = LoadFromAddress(pVariant + view_as<Address>(8), NumberType_Int16);

    // Read value from offset +0 (based on assembly: push dword ptr [edi])
    int iRawValue = LoadFromAddress(pVariant, NumberType_Int32);

    // Parse value based on type
    switch(iType) {
        case FIELD_INTEGER: {
            PrintToChatAll("Type: INTEGER (ID: %d)", iType);
            PrintToChatAll("Value: %d", iRawValue);
        }
        case FIELD_FLOAT: {
            PrintToChatAll("Type: FLOAT (ID: %d)", iType);
            float fValue = view_as<float>(iRawValue);
            PrintToChatAll("Value: %f", fValue);
        }
        case FIELD_CSTRING: {
            PrintToChatAll("Type: STRING (ID: %d)", iType);
            // For strings, iRawValue is a pointer to the string
            if (iRawValue != 0) {
                char szStringValue[256];
                Address pString = view_as<Address>(iRawValue);

                // Try to read the string safely
                bool bSuccess = false;
                for (int i = 0; i < sizeof(szStringValue) - 1; i++) {
                    int iByte = LoadFromAddress(pString + view_as<Address>(i), NumberType_Int8);
                    if (iByte == 0) {
                        // Null terminator found - string is complete
                        szStringValue[i] = '\0';
                        bSuccess = true;
                        break;
                    }
                    if (iByte < 32 || iByte > 126) {
                        // Invalid character, stop reading to prevent corruption
                        szStringValue[i] = '\0';
                        break;
                    }
                    szStringValue[i] = iByte;
                }
                szStringValue[sizeof(szStringValue) - 1] = '\0';
                
                if (bSuccess && strlen(szStringValue) > 0) {
                    PrintToChatAll("Value: %s", szStringValue);
                } else {
                    PrintToChatAll("Value: <invalid string at 0x%08X>", iRawValue);
                }
            } else {
                PrintToChatAll("Value: <null string>");
            }
        }
        default: {
            // Unknown or unsupported type - display raw data for debugging
            PrintToChatAll("Type: UNKNOWN (%d)", iType);
            PrintToChatAll("Raw value: 0x%08X", iRawValue);
        }
    }

    PrintToChatAll("---------------------------------------------------------------------");
    return MRES_Ignored;
}
