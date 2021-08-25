#include <cstrike>
#include <sourcemod>
#define MAX_INTEGER_STRING_LENGTH 16
#define MAX_FLOAT_STRING_LENGTH 32
#pragma semicolon 1
#pragma newdecls required
static char _colorNames[][] = {"{NORMAL}","{DARK_RED}","{PINK}","{GREEN}","{YELLOW}","{LIGHT_GREEN}","{LIGHT_RED}","{GRAY}","{ORANGE}","{LIGHT_BLUE}","{DARK_BLUE}","{PURPLE}"};
static char _colorCodes[][] = {"\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x0B", "\x0C", "\x0E"};
ConVar g_hAutoColorize;
ConVar g_hGotFrag;
ConVar g_hNGotFrag;
ConVar g_hGotFragDamage;
ConVar g_hNGotFragDamage;
ConVar g_hEnabled;
ConVar g_hMessageFormat;
int g_DamageDone[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_DamageDoneHits[MAXPLAYERS + 1][MAXPLAYERS + 1];
bool g_GotKill[MAXPLAYERS + 1][MAXPLAYERS + 1];

public Plugin myinfo = {
    name = "damage printer",
    author = "sz",
    description = "Print player damage on round end",
    version = "1.0",
    url = "https://onemyblog.cn"
};

stock bool IsValidClient(int client) {
  return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}

stock void ReplaceStringWithInt(char[] buffer, int len, const char[] replace, int value, bool caseSensitive = false) {
  char intString[MAX_INTEGER_STRING_LENGTH];
  IntToString(value, intString, sizeof(intString));
  ReplaceString(buffer, len, replace, intString, caseSensitive);
}

stock void ReplaceStringWithColoredInt(char[] buffer, int len, const char[] replace, int value, const char[] color, bool caseSensitive = false) {
  char intString[MAX_INTEGER_STRING_LENGTH + 32];
  Format(intString, sizeof(intString), "{%s}%d{NORMAL}", color, value);
  ReplaceString(buffer, len, replace, intString, caseSensitive);
}

stock void Colorize(char[] msg, int size, bool stripColor = false) {
  for (int i = 0; i < sizeof(_colorNames); i++) {
    if (stripColor)
      ReplaceString(msg, size, _colorNames[i], "\x01");
    else
      ReplaceString(msg, size, _colorNames[i], _colorCodes[i]);
  }
}

public void OnPluginStart() {
  g_hAutoColorize = CreateConVar("sm_use_auto_color", "1","This cvar means that the plugin use auto color set.");
  g_hGotFrag = CreateConVar("sm_got_frag_color", "dark_red", "What color should print for the name when killed by yourself.");
  g_hNGotFrag = CreateConVar("sm_not_got_frag_color", "light_green", "What color should print for the name when NOT killed by yourself.");
  g_hGotFragDamage = CreateConVar("sm_not_got_frag_damage_color", "green", "What color should print for the damage when killed by yourself.");
  g_hNGotFragDamage = CreateConVar("sm_got_frag_damage_color", "green", "What color should print for the damage when NOT killed by yourself.");
  g_hEnabled = CreateConVar("sm_damageprint_enabled", "1", "Whether the plugin is enabled");
  g_hMessageFormat = CreateConVar("sm_damageprint_format", "命中{HITS_TO}次{DMG_TO}伤害 被击中{HITS_FROM}次{DMG_FROM}伤害 剩{HEALTH}HP {NAME}", "Format of the damage output string. Avaliable tags are in the default, color tags such as {LIGHT_RED} and {GREEN} also work.");
  AutoExecConfig(true, "damageprint", "sourcemod");
  HookEvent("round_start", Event_RoundStart);
  HookEvent("player_hurt", Event_DamageDealt, EventHookMode_Pre);
  HookEvent("player_death", Event_PlayerDeath);
  HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
}

static void GetDamageColor(char color[16], bool damageGiven, bool gotKill) {
  char Ccolor[16];
  if (damageGiven) {
    if (gotKill) {
      g_hGotFragDamage.GetString(Ccolor, sizeof(Ccolor));
      Format(color, sizeof(color), Ccolor);
    } else {
      g_hNGotFragDamage.GetString(Ccolor, sizeof(Ccolor));
      Format(color, sizeof(color), Ccolor);
    }
  }
  else {
    if (gotKill) {
      g_hGotFrag.GetString(Ccolor, sizeof(Ccolor));
      Format(color, sizeof(color), Ccolor);
    } else {
      g_hNGotFrag.GetString(Ccolor, sizeof(Ccolor));
      Format(color, sizeof(color), Ccolor);
    }
  }
}

static void PrintDamageInfo(int client) {
  if (!IsValidClient(client))
    return;

  int team = GetClientTeam(client);
  if (team != CS_TEAM_T && team != CS_TEAM_CT)
    return;
  char message[256];
  int otherTeam = (team == CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i) && GetClientTeam(i) == otherTeam) {
      int health = IsPlayerAlive(i) ? GetClientHealth(i) : 0;
      char name[64];
      GetClientName(i, name, sizeof(name));
      g_hMessageFormat.GetString(message, sizeof(message));
      if (g_hAutoColorize.IntValue == 0) {
        ReplaceStringWithInt(message, sizeof(message), "{DMG_TO}", g_DamageDone[client][i]);
        ReplaceStringWithInt(message, sizeof(message), "{HITS_TO}", g_DamageDoneHits[client][i]);
        ReplaceStringWithInt(message, sizeof(message), "{DMG_FROM}", g_DamageDone[i][client]);
        ReplaceStringWithInt(message, sizeof(message), "{HITS_FROM}", g_DamageDoneHits[i][client]);
        ReplaceString(message, sizeof(message), "{NAME}", name);
        ReplaceStringWithInt(message, sizeof(message), "{HEALTH}", health);
        Colorize(message, sizeof(message));
      } else {
        // Strip colors first.
        Colorize(message, sizeof(message), true);
        char color[16];
        GetDamageColor(color, true, g_GotKill[client][i]);
        ReplaceStringWithColoredInt(message, sizeof(message), "{DMG_TO}", g_DamageDone[client][i], color);
        ReplaceStringWithColoredInt(message, sizeof(message), "{HITS_TO}", g_DamageDoneHits[client][i], color);
        ReplaceStringWithColoredInt(message, sizeof(message), "{DMG_FROM}", g_DamageDone[i][client], color);
        ReplaceStringWithColoredInt(message, sizeof(message), "{HITS_FROM}", g_DamageDoneHits[i][client], color);
        ReplaceStringWithColoredInt(message, sizeof(message), "{HEALTH}", health, color);
        GetDamageColor(color, false, g_GotKill[client][i]);
        ReplaceStringWithColoredInt(message, sizeof(message), "{NAME}", name, color);
        Colorize(message, sizeof(message));
      }
      PrintToChat(client, message);
    }
  }
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  if (g_hEnabled.IntValue == 0)
    return;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i)) {
      PrintDamageInfo(i);
    }
  }
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  for (int i = 1; i <= MaxClients; i++) {
    for (int j = 1; j <= MaxClients; j++) {
      g_DamageDone[i][j] = 0;
      g_DamageDoneHits[i][j] = 0;
      g_GotKill[i][j] = false;
    }
  }
}

public Action Event_DamageDealt(Event event, const char[] name, bool dontBroadcast) {
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int victim = GetClientOfUserId(event.GetInt("userid"));
  bool validAttacker = IsValidClient(attacker);
  bool validVictim = IsValidClient(victim);
  if (validAttacker && validVictim) {
    int preDamageHealth = GetClientHealth(victim);
    int damage = event.GetInt("dmg_health");
    int postDamageHealth = event.GetInt("health");
    if (postDamageHealth == 0) {
      damage += preDamageHealth;
    }
    g_DamageDone[attacker][victim] += damage;
    g_DamageDoneHits[attacker][victim]++;
  }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int victim = GetClientOfUserId(event.GetInt("userid"));
  bool validAttacker = IsValidClient(attacker);
  bool validVictim = IsValidClient(victim);
  if (validAttacker && validVictim) {
    g_GotKill[attacker][victim] = true;
  }
}
