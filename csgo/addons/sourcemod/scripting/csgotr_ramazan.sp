#include <sourcemod>
#include <overlays>
#include <emitsoundany>
#include <csgoturkiye>

#pragma semicolon 1

public Plugin myinfo = 
{
	name = "Ramazan", 
	author = "oppa", 
	description = "Sunucuda sahur ve iftar vakitlerinde bilgi verir.", 
	version = "1.0", 
	url = "csgo-turkiye.com"
};

ConVar cv_server_location = null;
char s_server_location[32];
bool b_muslim[ MAXPLAYERS + 1 ] = {true, ...}, b_status;
int i_rT;
Handle h_timer = null;

public void OnPluginStart()
{   
    RegConsoleCmd("sm_ramazanbilgi", RamadanInfo, "Sunucu için ayarlı iftar-sahur konumu var ise o zamanlarda oyundan muaf tutulur. Ayrıca ramazan bilgilendirmeleri almaz.");
    HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
    CVAR_Load();
    for (int i = 1; i <= MaxClients; i++) OnClientPostAdminCheck(i);
}

public void OnMapStart()
{
    CVAR_Load();
    AddFileToDownloadsTable("sound/csgo-turkiye_com/ramazan/ezansesi.mp3");
    PrecacheDecalAnyDownload("csgo-turkiye_com/plugin/ramazan/overlays_god");
    PrecacheSoundAny("csgo-turkiye_com/ramazan/ezansesi.mp3", false);
    CreateTimer(60.0, Query, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void CVAR_Load(){
    cv_server_location = CreateConVar("sm_ramazan_server_location", "İSTANBUL", "Sunucu iftar-sahur için konumu. >>configs/ramazan/xxxx.txt<< dosyalarındaki il isimlerine göre.\nBoş bırakırsanız ramazan etkinliği olmayacaktır.");
    AutoExecConfig(true, "ramazan","CSGO_Turkiye");
    GetConVarString(cv_server_location, s_server_location, sizeof(s_server_location));
    HookConVarChange(cv_server_location, OnCvarChanged);
}

public int OnCvarChanged(Handle convar, const char[] oldVal, const char[] newVal)
{
    if(convar == cv_server_location) strcopy(s_server_location, sizeof(s_server_location), newVal);
}

public void OnClientPostAdminCheck(int client)
{
    if (IsValidClient(client)){
        b_muslim[ client ] = true;
        ClientMuslimChat(client);
    }	
}

public Action RamadanInfo(int client,int args)
{
    if(client!=0){
        if(IsValidClient(client)){
            b_muslim[ client ] = !b_muslim[ client ];
            PrintToChat(client, "[SM] \x0CRamazan bilgilendirmeleri %s.", (b_muslim[ client ] ? "\x04açıldı": "\x02kapatıldı"));
            if(b_status && !b_muslim[client] && IsPlayerAlive(client)){
                ForcePlayerSuicide(client);
                PrintToChat(client, "[SM] \x0CRamazan etkinliği başladığında kapattığınız için öldürüldünüz.");
            }
        }
    }else PrintToServer("Bu komutu sadece oyuncular kullanabilir.");
    return Plugin_Handled;
}

public void Event_RoundStart(Handle event, const char[] Name, bool dontbroadcast)
{
    i_rT = GetTime();
    Control();
}

public void Event_RoundEnd(Handle event, const char[] Name, bool dontbroadcast)
{
    Control();
}

public void Control(){
    if(b_status){
        b_status = false;
        if (h_timer != null)
		{
			delete h_timer;
			h_timer = null;
		}
        for (int i = 1; i <= MaxClients; i++) if(IsValidClient(i)) {
            if(IsPlayerAlive(i))SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);
            CreateTimer(0.0, DeleteOverlay, GetClientUserId(i));
        }
    }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
    if(b_status){
        int client = GetClientOfUserId(event.GetInt("userid"));
        if(IsValidClient(client)){
            PrintToChat(client, "[SM] \x0CRamazan etkinliği başladığı için canlandırılamazsınız.");
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

public void ClientMuslimChat(int client)
{
    if (IsValidClient(client)){
        PrintToChat(client, "[SM] \x0C!ramazanbilgi \x0Eyazarak ramazan bilgilendirmeleri %s.", (b_muslim[ client ] ? "\x02kapatabilirsiniz": "\x04açabilirsiniz"));
        if(!StrEqual(s_server_location, "") && b_muslim[ client ])PrintToChat(client, "[SM] \x0CRamazan bilgilerini \x02kapatırsanız \x10%s \x0Esahur-iftar vakitlerinde \x0Eoyundan muaf olacaksınız.", s_server_location);
    }	
}

public Action Query(Handle hTimer)
{
    char s_temp[12], s_path[ PLATFORM_MAX_PATH ];
    int i_time = GetTime();
    FormatTime(s_temp, sizeof(s_temp), "%F", i_time);
    BuildPath( Path_SM, s_path, sizeof( s_path ), "configs/ramazan/%s.txt", s_temp );
    KeyValues kv = CreateKeyValues( s_temp );
    if (!FileToKeyValues(kv, s_path))SetFailState("%s dosyası bulunamadı.", s_path);
    KvRewind(kv);
    FormatTime(s_temp, sizeof(s_temp), "%H:%M", i_time);
    if (KvJumpToKey(kv, s_temp))
    {
        int i_count = KvGetNum(kv, "count");
        char s_list[255], s_temp2[32];
        for(int i = 1 ; i<=i_count ; i++)
        {
            IntToString(i, s_temp2, sizeof(s_temp2));
            KvGetString(kv, s_temp2, s_temp2, sizeof(s_temp2));
            Format(s_list, sizeof(s_list), "%s%s-", s_list, s_temp2);
            if(StrEqual(s_temp2, s_server_location)) Ramadan();
        }
        if(!StrEqual(s_list, "")){
            if(s_list[strlen(s_list)-1] == '-') s_list[strlen(s_list)-1] = ' ';
            for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i)){
                ClientMuslimChat(i);
                if(b_muslim[i]){
                    bool b_type = true;
                    FormatTime(s_temp2, sizeof(s_temp2), "%H", i_time);
                    if(StringToInt(s_temp2) > 13) b_type = false;
                    PrintToChat(i, "[SM] \x0E%s \x0C%s\x02için \x10%s \x04vakti.", s_temp, s_list, (b_type ? "sahur": "iftar"));
                    PrintHintText(i, "<font color='#33a7ff'>%s</font>için <font color='#ff335f'>%s</font> <font color='#00ff2a'>vakti.</font>", s_list, (b_type ? "sahur": "iftar"));
                }
            }
        }
    }
    delete kv;
}

public void Ramadan(){
    b_status = true;
    RemoveWeapons();
    if(i_rT > 0) GameRules_SetProp("m_iRoundTime", (130+(GetTime()-i_rT)), 4, 0, true);
    h_timer = CreateTimer(132.0, RamadanFinish);
    char s_temp[4];
    FormatTime(s_temp, sizeof(s_temp), "%H", GetTime());
    for (int i = 1; i <= MaxClients; i++){
        if(IsValidClient(i)){
            SetHudTextParams(-1.0, 0.1, 5.0, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), 0, 2, 1.0, 0.1, 0.2);
            ShowHudText(i, 1, "%s İÇİN %s VAKTİ", s_server_location, (StringToInt(s_temp) > 13 ? "İFTAR": "SAHUR"));
            RamadanPlayer(i);
        }
    }
}

public Action RamadanFinish(Handle timer)
{
    Control();
    return Plugin_Continue;
}

public void RamadanPlayer(int client){
    if(IsValidClient(client)){
        if(b_muslim[client]){
            SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.0);
            EmitSoundToClientAny(client,"csgo-turkiye_com/ramazan/ezansesi.mp3");
            ShowOverlay(client, "csgo-turkiye_com/plugin/ramazan/overlays_god", 0.0);
        }else{
            if(IsPlayerAlive(client)){
                ForcePlayerSuicide(client);
                PrintToChat(client, "[SM] \x0CRamazan etkinliği \x02kapalı \x04olduğu için öldürüldünüz.");
            }
        }
    }
}

public void RemoveWeapons(){
    char weapon[64];
    for (int i = MaxClients; i < GetMaxEntities(); i++)
    {
        if (IsValidEdict(i) && IsValidEntity(i))
        {
            GetEdictClassname(i, weapon, sizeof(weapon));
            if ((StrContains(weapon, "weapon_") != -1 || StrContains(weapon, "item_") != -1) && GetEntDataEnt2(i, FindSendPropInfo("CBaseCombatWeapon", "m_hOwnerEntity")) == -1)RemoveEntity(i);
        }
    }
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsPlayerAlive(i))
        {
            int j;
            while (j < 5)
            {
                int iweapon = GetPlayerWeaponSlot(i, j);
                if (iweapon != -1)
                {
                    RemovePlayerItem(i, iweapon);
                    RemoveEdict(iweapon);
                }
                j++;
            }
        }
    }
}