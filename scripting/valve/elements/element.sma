/**
*    Elements.  Time of day lighting and weather conditions are brought into the Half-Life server of any mod.
*    Copyleft (C) 2019 .sρiηX҉.
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU Affero General Public License as
*    published by the Free Software Foundation, either version 3 of the
*    License, or (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU Affero General Public License for more details.
*
*    You should have received a copy of the GNU Affero General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
/*Elements☀ ☁ ☂ ☃ ☉ ☼ ☽ ☾ ♁ ♨ ❄ ❅ ❆ ◐ ◑ ◒ ◓ ◔ ◕ ◖ ◗  ♘ ♞ ϟ THIS IS COPYLEFT!!◐  ◖   ◒   ◕   ◑   ◔   ◗   ◓
*
*
*https://github.com/djearthquake/amxx/tree/main/scripting/valve/elements
* API if you need more data on lighting: https://sunrise-sunset.org/api
*
* PLUGIN WAS A FORK FROM AUTOWEATHER. DAY 1 PORTED TO YAHOO. PLANNED ON WIND FACTOR FOR SNIPE AND AFTER YAHOO HACK I MADE IT HAPPEN WITH OPENWEATHER TOKEN API.
* Just make an alias in server.cfg so you can swap cities by typing and name or loading as cs_italy to Italy or dod_charlie to France and so on etc.
*
* alias az "region 5745656"
*
* alias neutral "exec element.cfg"
* neutral
* element.cfg
* time 0
* lums 0
* dark 18
*
*
☼
◖ ◗
ϟ
CVARS:
dark    <0-25> D: 24| The higher the number, the darker after sunset.
lums    <0-25> D: 0 | The lower the number, the brighter it gets at noon.
time    <0-24> D: 0 | Manually sets timeOday 0 = off
region  <region>    | "region" is "4887398" Get from openweathermap.org by looking at weather in your city click a pager deeper on something and copy the ID from end of URL.
uplink  <GETdataURL>| "uplink" is "GET /data/2.5/weather?id="
day <0-24> D: 0 | Override sunrise hour Y38K futureproof. Dark is unpopular smaller darktimeframe keeps 'most' players!
night   <0-24> D: 0 | Override sunset hour Y38K futureproof. Hot Vision is a great plugin to take advantage of the ultra dark night time.
<https://forums.alliedmods.net/showthread.php?t=135617>
sv_region <regioncode>      | 616411 ....[URL="https://openweathermap.org/api"]
sv_units <metric|imperial>  | Simply pick what unit you prefer for weather readings.

CL_COMMANDS

say temp, weather, or climate   - displays weather feed
say /mytemp for local temp
say /news for news*/

///for rain drops
#define COLOR random_num(0,7) ///streak color range
#define DROPS random_num(30,200) ///streak count

#define XOR random_float(-250.0,300.0) ///coordinates
#define YOR random_float(-300.0,250.0) ///coordinates
#define ZOR random_float(500.0,525.0)

#define XDIR random_float(-20.0,1.0) ///coordinates
#define YDIR random_float(-1.0,20.0) ///coordinates
#define ZDIR random_float(-100.0,1.0)

#define PRECIPX random_num(-100000,180000)
#define PRECIPY random_num(-100000,180000)
#define PRECIPZ random_num(-100000,180000)

//compass
#define NORTH   0
#define WEST    90
#define SOUTH   180
#define EAST    270

#include <amxmodx>           /*All plugins need*/
#include <amxmisc>             /*mod checks && task_ex*/
#include <engine_stocks>
#include <hamsandwich>    /*compass activation*/
#include <sockets>               /*feed needs*/
#include <fakemeta>           /*PEV*/
#include <fakemeta_stocks> ///crosshair///
#include <nvault>                /*feed storage Global*/
#include <xs>

#define VERSION "5.0.0"
#define fm_create_entity(%1) engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, %1))
#define fm_set_lights(%1)    engfunc(EngFunc_LightStyle, 0, %1)

#define Radian2Degree(%1) (%1 * 180.0 / M_PI)

#define MAX_PLAYERS     32
#define MAX_CMD_LENGTH             128
#define MAX_USER_INFO_LENGTH       256

new sprLightning, sprFlare6, g_F0g, g_Saturn, g_TesteD; /*Half-Life Fog v.1 2019*/

new gHudSyncInfo, gHudSyncInfo2, g_pcvar_compass, g_pcvar_method,g_Method
new const g_DirNames[4][] = { "N", "E", "S", "W" }
new DirSymbol[MAX_PLAYERS] = "----<>----"

new g_cvar_minlight, g_cvar_maxlight, g_cvar_region, g_cvar_uplink, g_cvar_time, g_cvar_day, g_cvar_night;
new g_sckelement, g_DeG, g_SpeeD, g_temp, g_element, g_hum, g_heat, g_code, g_visi;
new g_env, g_fog, g_sunrise, g_sunset, g_location[MAX_PLAYERS], g_cvar_wind, g_cvar_debug, g_cvar_fog;
new g_vault, g_Nn, g_Up, g_Dwn, g_Ti,  g_debugger_on, g_feel;
new g_LightLevel[][]=   { "z","y","x","w","v","u","t","s","r","q","p","o","n","m","l","k","j","i","h","g","f","e","d","c","b","a" };
new g_env_name[][]=     { ""," ..::DRY::.. "," ..::WET::.. "," ..::ICE::.. " }; // APPLIED SIM: (1-3)(no rain, rain, snow)
new g_element_name[][]= { "","..fair..","..cloud..","..partial.." };
new g_skysuf[6][3]=     { "up", "dn", "ft", "bk", "lf", "rt" };
new g_cvar_token, g_cvar_units, g_SkyNam[16];
new g_SzUnits[16]

new bool:bCompassOn[MAX_PLAYERS +1];
new bool:bTokenOkay
new bool:g_bCSOF
/////////////////////////////////////////////////////////////////////////////////////////////////////////
/*          0   1   2   3   4                       /
/////////////////////////////////////////////////////////////////////////////////////////////////////////
/           normal  sunrise noon    sunset  night                          */
/////////////////////////////////////////////////////////////////////////////////////////////////////////
new g_skynames[][] =
{
    "sunny","3dm_bikini","ava","sunset1","52h03",     /*X҉**☀**SUNNY**☀***X҉*/
    "52h05","nordawn","tornsky","blue","52h03",       /*X҉*PARTLY☂CLOUDED*X҉*/
    "sunbeams_","morningdew","cx","st","paris_night", /*X҉**ϟ*CLOUDED*ϟ***X҉*/
    "CCCP","CCCP","CCCP","dashnight256","CCCP"        /*X҉****☾FOGGY☽*****X҉*/
}
/////////////////////////////////////////////////////////////////////////////////////////////////////////

enum {
    DODW_AMERKNIFE = 1,
    DODW_GERKNIFE,
    DODW_SPADE,
    DODW_BRITKNIFE
};

new const CvarFogDesc[]="Weather fog perentage."
public plugin_init()
{
    register_plugin("Elements", VERSION, ".sρiηX҉.");
    register_cvar("element_version", VERSION, FCVAR_SERVER);

    RegisterHam(Ham_Player_Duck, "player", "fix");
    RegisterHam(Ham_TakeDamage, "player", "windage");

    register_clcmd("say /news", "ClCmd_NewS", 0, "Element | Takes you into a chat room");
    register_clcmd("say /mytemp", "ClCmd_TemP", 0, "Element | Googles your weather.");

    register_concmd("element_snow", "ClCmd_hl_snow", ADMIN_RCON, "-Creates HL1 snow.")  // , "test of hl1 weather")
    register_concmd("element_dry", "ClCmd_hl_dry", ADMIN_RCON, "-Removes all HL1 weather.")   // , "test of hl1 weather")
    register_concmd("element_wet", "ClCmd_hl_precip", ADMIN_RCON, "-Creates HL1 rain.")   // , "test of hl1 weather")
    register_concmd("element_fog", "ClCmd_hl_fog", ADMIN_RCON, "-Creates HL1 fog.")   // , "test of hl1 weather")
    register_concmd("element_flash", "ClCmd_FlasheS", ADMIN_RCON, "-Creates random lights.")   // , "test of hl1 weather")

    register_concmd("element_feed", "ClCmd_get_element", ADMIN_RESERVATION, "-Refreshes weather feed.")

    g_cvar_minlight = register_cvar("dark", "23");  //not too dark
    g_cvar_uplink = register_cvar("uplink", "GET /data/2.5/weather?id=");
    g_cvar_maxlight = register_cvar("lums", "0");  //vivid at noon
    g_cvar_time = register_cvar("time", "0");      //auto light Time of Day

    //override the feeds dusk and dawn settings in military time
    //zero both to disable
    g_cvar_day = register_cvar("day", "0");      //sunrise Hour
    g_cvar_night = register_cvar("night", "0");     //night fall Hour

    g_cvar_region = register_cvar("sv_region", "4887398");
    g_cvar_units = register_cvar("sv_units", "metric");

    bind_pcvar_string(g_cvar_units, g_SzUnits, charsmax(g_SzUnits))

    g_cvar_token = register_cvar("sv_openweather-key", "null");
    g_cvar_wind = register_cvar("sv_wind", "0") //offsets crosshair in direction of fed weather when shot (for now), Duck to reset.
    g_cvar_debug = register_cvar("weather_debug", "0");

    bind_pcvar_num(get_cvar_pointer("weather_fog") ? get_cvar_pointer("weather_fog") : create_cvar("weather_fog", "90.0" ,FCVAR_SERVER, CvarFogDesc,.has_min = true, .min_val = 5.0, .has_max = true, .max_val = 95.0), g_cvar_fog)

    ///AutoExecConfig(.autoCreate = true, .name = "Element")

    register_cvar("element_hud", "200");
    register_clcmd("say /temp", "showinfo");
    register_clcmd("say /time", "showinfo");
    register_clcmd("say /weather", "showinfo");
    register_clcmd("say /climate", "showinfo");

    set_task_ex(10.0, "get_element", 167, .flags = SetTask_AfterMapStart);
    set_task_ex(60.0, "get_element", 167, .flags = SetTask_BeforeMapChange);

    g_visi = nvault_get(g_vault, "visi");
    g_temp = nvault_get(g_vault, "temp");
    g_hum = nvault_get(g_vault, "humidity");
    g_code = nvault_get(g_vault, "code");
    nvault_get(g_vault, "location", g_location, charsmax(g_location));
    nvault_get(g_vault, "env", g_env, 2); ///was g_env_name

    nvault_get(g_vault, "element", g_element_name, 8);
    nvault_prune(g_vault, 0, get_systime() - (60 * 60 * 2)); ///2 hr pruning

    get_cvar_string("sv_skyname", g_SkyNam, charsmax (g_SkyNam) );

    if(task_exists(16))return;
    set_task_ex(3.0, "daylight", 16, .flags = SetTask_Repeat); //One can set it longer but it really does not optimize much.

    ///compass
    g_pcvar_compass = register_cvar("amx_compass", "1");
    g_pcvar_method = register_cvar("amx_compass_method", "2");
    g_Method = get_pcvar_num(g_pcvar_method)

    if(cstrike_running() || is_running("gearbox") == 1)
        g_bCSOF = true

    if(g_bCSOF)
        RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "compass_tic", 1)

    if(is_running("valve") == 1 )
        RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_crowbar", "compass_tic", 1)

    if(is_running("dod") == 1 )
        register_event("CurWeapon", "@dod", "bce", "1=1");

    gHudSyncInfo = CreateHudSyncObj();
    gHudSyncInfo2 = CreateHudSyncObj();

}
public plugin_cfg()
{
    //Do not overcheck for token
    new token[MAX_PLAYERS+1];
    get_pcvar_string(g_cvar_token, token, charsmax (token));

    if (!equal(token, "null"))
        bTokenOkay = true

    //Are Sunrise and Sunset on CVAR override?
    if(get_pcvar_num(g_cvar_day))
        g_Up = get_pcvar_num(g_cvar_day)

    if(get_pcvar_num(g_cvar_night))
        g_Dwn = get_pcvar_num(g_cvar_night)

    !g_Up && !g_Dwn ? server_print("Relying on sunrise and set from feed!") : server_print("Server dusk to down OVERRIDE.")

    g_debugger_on = get_pcvar_num(g_cvar_debug)
}

@dod(id)
{
    if(is_user_alive(id))
    {
        /*
        new wpnid = get_user_weapon(id)
        if ( wpnid == DODW_AMERKNIFE || wpnid == DODW_BRITKNIFE || wpnid == DODW_GERKNIFE || wpnid == DODW_SPADE )
        */
        {
            if (get_user_button(id) & IN_ATTACK)
            {
                bCompassOn[id] = true
                Compass(id)
            }
            if (get_user_button(id) & IN_ATTACK2)
            {
                bCompassOn[id] = true
                Compass(id)
            }
            return PLUGIN_CONTINUE

        }

    }
    return PLUGIN_CONTINUE

}

public ClCmd_NewS(id, level, cid)
{
    if(g_bCSOF)
    {
        new motd[MAX_CMD_LENGTH];
        format(motd, charsmax (motd), "<html><meta http-equiv='Refresh' content='0; URL=http://www.SRNLive.com/listen.html'><body BGCOLOR='#FFFFFF'><br><center>Loading</center></html>");
        show_motd(id, motd, "International and local news");
    }
}

public ClCmd_TemP(id, level, cid)
{
    if(g_bCSOF)
    {
        new motd[MAX_USER_INFO_LENGTH];
        format(motd, charsmax (motd), "<html><meta http-equiv='Refresh' content='0; URL=https://google.com/search?q=weather'><body BGCOLOR='#FFFFFF'><br><center>If we can not determine your country off your IP then this will display generic weather page...</center></html>");
        show_motd(id, motd, "Weather Browser");
    }
}

public plugin_end()
    nvault_close(g_vault);

public plugin_precache()
{
    g_F0g = precache_model("sprites/ballsmoke.spr");
    sprFlare6 = precache_model("sprites/Flare6.spr");
    g_Saturn = precache_model("sprites/zerogxplode.spr");
    g_TesteD = precache_model("sprites/rain.spr");

    sprLightning = precache_model("sprites/lightning.spr");

    g_vault = nvault_open("element");
    g_env = nvault_get(g_vault, "env");
    g_sunrise = nvault_get(g_vault, "sunrise");
    g_sunset = nvault_get(g_vault, "sunset");
    g_DeG = nvault_get(g_vault, "deg");

    makeelement();
}

public client_putinserver(id)
{
    if (is_user_bot(id))
        return;
    g_env = nvault_get(g_vault, "env")

    if(is_user_connected(id))
    {

        if(g_env >= 2)
            set_task_ex(random_float(30.0,60.0), "display_info", id, .flags = SetTask_RepeatTimes, .repeat = 2);

        if(!bTokenOkay && is_user_admin(id))
            set_task_ex(10.0, "needan", id, .flags = SetTask_Once) //key check will update to init bool 1x per load

        set_task(random_float(1.1,5.0), "Et_Val", id) //give the weather and make special weather when admin connects

    }

}

public needan(id)
{
    new token[MAX_PLAYERS+1];
    get_pcvar_string(g_cvar_token, token, charsmax (token));

    if (equal(token, "null"))
    {
        if(g_bCSOF)
        {
            new motd[MAX_CMD_LENGTH];
            format(motd, charsmax (motd), "<html><meta http-equiv='Refresh' content='0; URL=https://openweathermap.org/appid'><body BGCOLOR='#FFFFFF'><br><center>Null sv_openweather-key detected.</center></html>");
            show_motd(id, motd, "Invalid 32-bit API key!");
        }
        if(g_bCSOF) return;
        client_print(id,print_chat,"Check your API key validity!")
        client_print(id,print_center,"Null sv_openweather-key detected.")
        client_print(id,print_console,"Get key from openweathermap.org/appid.")
    }
}

public display_info(id)
if(is_user_connected(id))
{
    client_print(id, print_chat, "Say climate, temp, or weather for conditions.");
    client_print(id, print_chat, "Humidity, Clouds, Sunrise/Sunset all effect visibility.");
}

public showinfo(id)
{
    if(is_user_connected(id) && bTokenOkay)
    {
        if(!g_code)
            get_element();
    
        set_hudmessage(random_num(0,255),random_num(0,255),random_num(0,255), -1.0, 0.55, 1, 2.0, 3.0, 0.7, 0.8, 3);  //-1 auto makes flicker
    
        client_print(id, print_console, "Welcome to %s! Visibility is %d'. Temperature feels like %d°.", g_location, g_visi, g_feel);
    
        /**https://www.amxmodx.org/api/amxmodx/set_hudmessage
        * native set_hudmessage(red = 200, green = 100, blue = 0, Float:x = -1.0, Float:y = 0.35, effects = 0, Float:fxtime = 6.0, Float:holdtime = 12.0, Float:fadeintime = 0.1, Float:fadeouttime = 0.2, channel = -1);
        * native random_num(a,   b);
        * https://www.amxmodx.org/api/amxmodx/random_num
        */
        nvault_get(g_vault, "element", g_element_name, 8);
        client_print(id, print_console, "|||||||||||code %d||||||||||Element: %s%s | humidity: %d | ♞dawn %s ♘dusk %s", g_code, g_env_name[g_env], g_element_name[g_element], g_hum, human_readable_time(g_sunrise), human_readable_time(g_sunset));
    
        if(g_bCSOF)
        {
            show_hudmessage(id, "╚»★Welcome to %s★«╝^nTemperature feels like %d° and was forecasted as %d°.^nSim:%s Sky: %s ^nHumidity %d.^nServer set fog to %d. ^n^n^nCS1.6|Say /news /mytemp for more.", g_location, g_feel, g_temp, g_env_name[g_env],
            g_element_name[g_element], g_hum, g_cvar_fog);
        }
        else
        {
            show_hudmessage(id, "Welcome to %s.^nTemperature feels like %d and was forecasted as %d.^nSim:%s Sky: %s ^nHumidity %d.^nServer set fog to %d. ^n^n^nCS1.6|Say /news /mytemp for more.", g_location, g_feel, g_temp, g_env_name[g_env], g_element_name[g_element], g_hum,
            g_cvar_fog);
        }
        epoch_clock(id);
    }
    return PLUGIN_HANDLED
}
stock human_readable_time(epoch_stamp)
{
    new SzSun[MAX_PLAYERS]

    format_time(SzSun, charsmax(SzSun), "%H:%M:%S", epoch_stamp);
    return SzSun
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public epoch_clock(id)
if(is_user_connected(id))
{
    new bool:bDayOver
    new bool:bNightOver

    new day_override = get_pcvar_num(g_cvar_day)
    new night_override = get_pcvar_num(g_cvar_night)

    if(!day_override && !night_override)
    {
        g_sunrise = nvault_get(g_vault, "sunrise");
        bDayOver = false

        g_sunset = nvault_get(g_vault, "sunset");
        bNightOver = false
    }
    else
    {
        new SzDay[3]
        num_to_str(day_override, SzDay, charsmax(SzDay))
        nvault_set(g_vault, "day", SzDay);

        g_Up  = day_override
        bDayOver = true

        new SzNight[3]
        num_to_str(night_override, SzNight, charsmax(SzNight))
        nvault_set(g_vault, "night", SzNight);

        bNightOver = true
        g_Dwn  = night_override
    }

    if(bDayOver && bNightOver)
        client_print(id, print_chat,"Sunrise and sunset are manually set not fed.")
    else if(!bDayOver && bNightOver)
        client_print(id, print_chat,"Sunset is manually set not fed.")
    else if(bDayOver && !bNightOver)
        client_print(id, print_chat,"Sunrise is manually set not fed.")
    else
        client_print(id, print_chat,"Lighting is socket fed!")

    /////////////////////////////////////////////////////////////

    new SzSunRise[MAX_PLAYERS], SzSunSet[MAX_PLAYERS];

    ///"%m/%d/%Y - %H:%M:%S"
    format_time(SzSunRise, charsmax(SzSunRise), "%H", g_sunrise);
    nvault_set(g_vault, "day", SzSunRise);

    if(g_debugger_on)
        server_print "Sunrise at %s",  SzSunRise

    format_time(SzSunSet, charsmax(SzSunSet), "%H", g_sunset);
    nvault_set(g_vault, "night", SzSunSet);

    if(g_debugger_on)
        server_print "Sunset at %s", SzSunSet

    new SzTime[MAX_PLAYERS]
    static iCurrent_time = -1
    format_time(SzTime, charsmax(SzTime), "%H:%M:%S",  iCurrent_time );
    client_print id, print_chat,"Sunrise hour %s.^nSunset hour %s.^nTime is %s", SzSunRise, SzSunSet, SzTime

    /////////////////////////////////////////////////////////////

    new iNightoverride = get_pcvar_num(g_cvar_night)
    new iMorningoverride = get_pcvar_num(g_cvar_day)

    if(iNightoverride)
    {
        new SzHour[3];
        num_to_str(iNightoverride, SzHour, charsmax(SzHour))
        nvault_set(g_vault, "night", SzHour);
    }
    else
    {
        format_time(SzSunRise, charsmax(SzSunRise), "%H", g_sunrise);
        nvault_set(g_vault, "night", SzSunRise);
        if(g_debugger_on)
            server_print "%s vaulted sunrise ", SzSunRise
    }

    if(iMorningoverride)
    {
        new SzHour[3];
        num_to_str(iMorningoverride, SzHour, charsmax(SzHour))
        nvault_set(g_vault, "day",SzHour);
    }
    else
    {
        format_time(SzSunSet, charsmax(SzSunSet), "%H", g_sunset);
        nvault_set(g_vault, "night", SzSunSet);
        if(g_debugger_on)
            server_print "%s vaulted sunset", SzSunSet
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //FYI
    client_print(id, print_console, "Skyname is %s",g_SkyNam);

    //Setting for skies
    if(!bDayOver)
        g_Up = str_to_num(SzSunRise)

    if(!bNightOver)
        g_Dwn = str_to_num(SzSunSet)

}

public ClCmd_get_element(id, level, cid)
{
    if (is_user_admin(id))
    {
        if(g_debugger_on)
            log_amx("Starting the sockets routine...");


        new Soc_O_ErroR, constring[MAX_USER_INFO_LENGTH], uplink[26], region[63], units[9], token[33];
        get_pcvar_string(g_cvar_region, region, charsmax (region));
        get_pcvar_string(g_cvar_uplink, uplink, charsmax (uplink));
        get_pcvar_string(g_cvar_units, units, charsmax (units));
        get_pcvar_string(g_cvar_token, token, charsmax (token));
        g_sckelement = socket_open("api.openweathermap.org", 80, SOCKET_TCP, Soc_O_ErroR, SOCK_NON_BLOCKING|SOCK_LIBC_ERRORS);
        format(constring,charsmax (constring), "%s%s&units=%s&APPID=%s&u=c HTTP/1.0^nHost: api.openweathermap.org^n^n", uplink, region, units, token);
        write_web(constring);

        if(g_debugger_on)
        {
            log_amx("This is where we are trying to get weather from");
            log_amx(constring);
            log_amx("Debugging enabled::telnet api.openweathermap.org 80 copy and paste link from above into session.");
        }
        read_web();
    }
    return PLUGIN_HANDLED
}

public Et_Val(id)
if(is_user_connected(id))
{
    new iWind = get_pcvar_num(g_cvar_wind)

    if(iWind)
        client_print(id, print_chat, "Due to wind or injury you may have to compensate at range by squatting!");

    if (g_code >= 0)
        finish_weather(id)

    if (is_user_admin(id))
    {
        set_task_ex(random_float(0.3,2.0), "ring_saturn", 223, .flags = SetTask_RepeatTimes, .repeat = 2);

        set_task_ex(random_float(0.3,5.0), "HellRain_Blizzard", 226, .flags = SetTask_RepeatTimes, .repeat = 7);

        set_task_ex(random_float(3.0, 5.0), "ring_saturn", 556, .flags = SetTask_RepeatTimes, .repeat = 3);
    }
}

public finish_weather(id)
{
    if (task_exists(556)) remove_task(556);
    g_SpeeD = nvault_get(g_vault, "speed");
    g_DeG = nvault_get(g_vault, "deg");
    g_heat = nvault_get(g_vault, "temp");
    g_feel =  nvault_get(g_vault, "feelslike");

    nvault_get(g_vault, "location", g_location, charsmax(g_location));

    //If Dusk-to-Dawn is manually set or fed.
    if(g_Up && g_Dwn)
        client_print(id, print_console,"Welcome to %s %n where the temp is %i... Wind speed is %i at %i deg. Fog must be over %i in real life to generate.^nSunRise hour %i SunSet hour %i...server is on the %i hour.", g_location, id, g_feel, g_SpeeD, g_DeG, g_cvar_fog, g_Up, g_Dwn, g_Ti)
    else
    {
        client_print(id, print_console,"Welcome to %s %n where the temp is %i... Wind speed is %i at %i deg. Fog must be over %i in real life to generate.", g_location, id, g_feel, g_SpeeD, g_DeG, g_cvar_fog)
        epoch_clock(id);
    }

    new g_SkyNam[16];
    get_cvar_string("sv_skyname",g_SkyNam, charsmax (g_SkyNam));

    server_print("Map using sky of %s, enjoy.", g_SkyNam);
}

public get_element()
{
    if(g_debugger_on)
        log_amx "Starting the sockets routine..."

    new numplayers = get_playersnum_ex(GetPlayersFlags:GetPlayers_ExcludeBots);
    if (numplayers < 3 )
    {
        client_print(0, print_console,"Making connection to weather feed...")
        client_print(0, print_chat,"Possible interruption. Weather feed sync...")

        new Soc_O_ErroR, constring[MAX_USER_INFO_LENGTH], uplink[26], region[63], units[9], token[33];
        get_pcvar_string(g_cvar_region, region, charsmax (region));
        get_pcvar_string(g_cvar_uplink, uplink, charsmax (uplink));
        get_pcvar_string(g_cvar_units, units, charsmax (units));
        get_pcvar_string(g_cvar_token, token, charsmax (token));
        g_sckelement = socket_open("api.openweathermap.org", 80, SOCKET_TCP, Soc_O_ErroR, SOCK_NON_BLOCKING|SOCK_LIBC_ERRORS);
        format(constring,charsmax (constring), "%s%s&units=%s&APPID=%s&u=c HTTP/1.0^nHost: api.openweathermap.org^n^n", uplink, region, units, token);

        write_web(constring);
        if(g_debugger_on)
        {
            log_amx("This is where we are trying to get weather from");
            log_amx(constring);
            log_amx("Debugging enabled::telnet api.openweathermap.org 80 copy and paste link from above into session.");
        }
        read_web();
    }
}

public write_web(text[MAX_USER_INFO_LENGTH])
{
    if(g_debugger_on)
        server_print("HTTP 1.0-1.1  trying socket write.");

    socket_is_writable(g_sckelement, 100000) ?
    socket_send(g_sckelement,text,charsmax (text))
    : server_print("Unable to write to the web!");
}

public read_web()
{
    if(g_debugger_on)
        server_print("reading the web")
    new buf[668];
    if (socket_is_readable(g_sckelement, 100000))
        socket_recv(g_sckelement,buf,charsmax (buf));
    else
        return

    if (!equal(buf, ""))
    {
        if (containi(buf, "name") >= 0)
        {
            new out[MAX_PLAYERS];
            copyc(out, 24, buf[containi(buf, "name") + 7], '"');
            if(g_debugger_on)
                server_print("writing the name")

            if(g_debugger_on)
                log_amx("Location: %s", out);

            nvault_set(g_vault, "location", out);
            g_location = out;
        }
        if (containi(buf, "temp") >= 0 && g_heat == 0)
        {
            server_print("Ck real temp time..")

            new out[MAX_PLAYERS]
            copyc(out, 6, buf[containi(buf, "temp") + 6], '"');
            replace(out, 6, ":", "");
            replace(out, 6, ",", "");

            if(g_debugger_on)
                log_amx("Temperature: %s", out);

            nvault_set(g_vault, "temp", out);

            g_temp = str_to_num(out);
        }
        if (containi(buf, "feels_like") != -1)
        {
            new out[MAX_PLAYERS];
            copyc(out, 4, buf[containi(buf, "feels_like") + 12], '.');

            if(g_debugger_on)
                log_amx("Feels like: %s", out);

            nvault_set(g_vault, "feelslike", out);
            g_feel = str_to_num(out);
        }
        if (containi(buf, "visibility") >= 0)
        {
            new out[7];
            copyc(out, charsmax(out), buf[containi(buf, "visibility") + 12], '"');
            replace(out, charsmax(out), ",", "");
            replace(out, charsmax(out), ":", "");

            if(g_debugger_on)
                log_amx("Visibility: %s", out);

            nvault_set(g_vault, "visi", out);
            g_visi = str_to_num(out);
        }
        if (containi(buf, "humidity") >= 0 && g_hum == 0)
        {
            new out[MAX_PLAYERS];
            copyc(out, 6, buf[containi(buf, "humidity") + 10], '"');
            replace(out, 6, ",", "");

            if(g_debugger_on)
                log_amx("Humidity: %s", out);

            nvault_set(g_vault, "humidity", out);
            g_hum = str_to_num(out);
        }
        if (containi(buf, "sunrise") !=  -1)
        {
            new out[MAX_PLAYERS];
            copy(out, 10, buf[containi(buf, "sunrise") + 9]);
            replace(out, charsmax(out), ",", "");

            if(g_debugger_on)
                log_amx("Sunrise: %s", out);

            nvault_set(g_vault, "sunrise", out);
            g_sunrise = str_to_num(out);
        }
        if (containi(buf, "deg") != -1 )
        {
            new out[MAX_PLAYERS];
            copy(out, 3, buf[containi(buf, "deg") + 5]);
            replace(out, 3, "&", "");
            replace(out, 3, "}", "");

            if(g_debugger_on)
                log_amx("Deg: %s", out);

            nvault_set(g_vault, "deg", out);
            g_DeG = str_to_num(out);
        }

        if (containi(buf, "speed") != -1)
        {
            new out[MAX_PLAYERS];
            copy(out, 5, buf[containi(buf, "speed") + 7]);
            replace(out, 5, ":", "");
            replace(out, 5, ",", "");

            if(g_debugger_on)
                log_amx("Speed: %s", out);

            nvault_set(g_vault, "speed", out);
            g_SpeeD = str_to_num(out);
        }
        if (containi(buf, "sunset") != -1)
        {
            new out[MAX_PLAYERS];
            copy(out, 10, buf[containi(buf, "sunset") + 8]);
            replace(out, charsmax(out), "}", "");

            if(g_debugger_on)
                log_amx("Sunset: %s", out);

            nvault_set(g_vault, "sunset", out);
            g_sunset = str_to_num(out);
        }
        if (containi(buf, "[") >= 0)
        {
            new out[MAX_PLAYERS];
            copy(out, 3, buf[containi(buf, "[") + 7]);
            replace(out, 3, "&", "");
            replace(out, 3, "#", "");

            if(g_debugger_on)
                log_amx("Code: %s", out);

            nvault_set(g_vault, "code", out);
            g_code = str_to_num(out);

            code_to_weather(g_code)

            new num[1];
            num_to_str(g_env, num, 1);
            nvault_set(g_vault, "env", num);

            if(g_debugger_on)
                server_print("Finished reading code and checking sunrise time...")

            num_to_str(g_element, num, 1);
            nvault_set(g_vault, "element", num);
        }
        set_task_ex(0.2, "read_web");
    }
    else
    {
        socket_close(g_sckelement);
        if(g_debugger_on)
            server_print("finished reading")
    }

}

stock code_to_weather(iWeather_code)
{
    //Set how server makes weather based off code from feed.
    ///https://openweathermap.org/weather-conditions
    //Group 800: Clear
    if (iWeather_code == 800)
    {
        g_env = 1;
        g_element = 1;
    }
    //Group 80x: Clouds
    if (iWeather_code>= 801 && iWeather_code <= 803)
    {
        g_env = 1;
        g_element = 2;
    }
   // Group 7xx: Atmosphere 
    if (iWeather_code >= 701 && iWeather_code<= 762)
    {
        g_env = 1;
        g_element = 2;
    }
   //Group 80x: Clouds
    if (g_code == 804)
    {
        g_element = 3;
        g_env = 1;
    }
    //Group 2xx: Thunderstorm
    //Group 5xx: Rain
    if (iWeather_code >= 200 && iWeather_code <= 531)
    {
        g_env = 2;
        g_element = 3;
    }
    //Group 6xx: Snow
    if (iWeather_code >= 600 && iWeather_code <= 602)
    {
        g_element = 2;
        g_env = 3;
    }
    if (iWeather_code >= 611 && iWeather_code <= 622)
    {
        g_element = 3;
        g_env = 3;
    }
}

public makeelement()
{
    new humi = nvault_get(g_vault, "humidity");
    new e = nvault_get(g_vault, "env");

    HL_WeatheR();

    if ( humi >  g_cvar_fog )
        makeFog(humi);

    if(g_bCSOF)
    switch (e)
    {
        case 2:
        {
            fm_create_entity("env_rain");
        }
        case 3:
        {
            fm_create_entity("env_snow");
        }
        case 4:
        {
            fm_create_entity("env_rain")
            fm_create_entity("env_snow")
            hl_precip()
            hl_snow();
        }

    }
    set_sky(humi);
}

public HoS()
    get_element();

public HL_WeatheR()
{
    if(g_bCSOF) return;

    new humi = nvault_get(g_vault, "humidity");
    new e = nvault_get(g_vault, "env");
    if ( humi > g_cvar_fog )
    makeFog(humi);

    switch (e)
    {
        case 2:
        {
            hl_precip();
        }
        case 3:
        {
            hl_snow();
        }
        case 4:
        {
            hl_precip()
            hl_snow();
        }
    }
    set_sky(humi);
}

public ClCmd_hl_precip(id, level, cid)
{
    if (!cmd_access(id,level,cid,1))
    return PLUGIN_HANDLED

    set_task_ex(3.0, "hl1_effect", 999, .flags = SetTask_Repeat);
    set_task_ex(1.0, "FlasheS", 435, .flags = SetTask_Repeat);
    set_task_ex(0.2, "streak", 221, .flags = SetTask_Repeat);
    set_task_ex(0.3, "streak2", 776, .flags = SetTask_Repeat);
    set_task_ex(0.1, "streak3", 887, .flags = SetTask_Repeat);

    return PLUGIN_HANDLED
}

public hl_precip()
{
    set_task_ex(5.0, "hl1_effect", 998, .flags = SetTask_Repeat);
    set_task_ex(random_float(7.0, 15.0), "ring_saturn", 111, .flags = SetTask_Repeat) ;
    set_task_ex(0.1, "streak", 222, .flags = SetTask_Repeat);
    set_task_ex(0.1, "streak2", 777, .flags = SetTask_Repeat);
    set_task_ex(0.1, "streak3", 888, .flags = SetTask_Repeat);
}


public compass_tic(iPlayerIndex)
{
    new id = pev(iPlayerIndex,pev_owner)
    if(is_user_connected(id))
    {
        if(g_debugger_on > 1)
            server_print "%n compass", id
        bCompassOn[id] = true
        if(get_pcvar_num(g_pcvar_compass))
            set_task_ex(0.2, "Compass", id, .flags = SetTask_RepeatTimes, .repeat = 3)
    }
}

public Compass(id)
{
    if(!is_user_bot(id) && is_user_alive(id) && bCompassOn[id])
    {
        if(g_debugger_on > 1)
            server_print "%n compass on", id

        ///Compass code by Tirant
        new Float:fAngles[3], iAngles[3]
        pev(id, pev_angles, fAngles)

        FVecIVec(fAngles,iAngles)
        iAngles[1] %= 360

        new Float:fHudCoordinates

        new iFakeAngle = iAngles[1] % 90
        new Float:fFakeHudAngle = (float(iFakeAngle) / 100.0) + 0.49
        if (iFakeAngle>45)
            fFakeHudAngle += 0.05

        if (fFakeHudAngle >= 0.95)
            fFakeHudAngle -= 0.95

        else if (fFakeHudAngle <= 0.05)
            fFakeHudAngle += 0.05

        new DirName[32]

        if (iFakeAngle == 0)
        {
            fHudCoordinates = -1.0

            switch(iAngles[1])
            {
                case NORTH: format(DirName, charsmax(DirName), "%s",  g_DirNames[0])
                case WEST: format(DirName, charsmax(DirName), "%s", g_DirNames[3])
                case SOUTH: format(DirName, charsmax(DirName), "%s", g_DirNames[2])
                case EAST: format(DirName, charsmax(DirName), "%s", g_DirNames[1])
            }
        }
        else
        {
            fHudCoordinates = fFakeHudAngle

            switch(g_Method)
            {
                case 1: format(DirName, charsmax(DirName), "%d", iAngles[1])
                case 2:
                {
                    if (NORTH < iAngles[1] < WEST || iAngles[1] > EAST)
                    {
                        if (NORTH < iAngles[1] < WEST)
                        {
                            iAngles[1] %= 90
                            format(DirName, charsmax(DirName), "%s %d%s", g_DirNames[0], iAngles[1], g_DirNames[3])
                        }
                        else if (iAngles[1] > EAST)
                        {
                            iAngles[1] = (90 - (iAngles[1] % 90))
                            format(DirName, charsmax(DirName), "%s %d%s", g_DirNames[0], iAngles[1], g_DirNames[1])
                        }
                    }
                    else
                    {
                        if (SOUTH > iAngles[1] > WEST)
                        {
                            iAngles[1] = (90 - (iAngles[1] % 90))
                            format(DirName, charsmax(DirName), "%s %d%s", g_DirNames[2], iAngles[1], g_DirNames[3])
                        }
                        else if (SOUTH < iAngles[1] < EAST)
                        {
                            iAngles[1] %= 90
                            format(DirName, charsmax(DirName), "%s %d%s", g_DirNames[2], iAngles[1], g_DirNames[1])
                        }
                    }
                }
            }
        }
        if (g_Method)
        {
            set_hudmessage(255, 0, 0, -1.0, 0.9, 0, 0.0, 3.0, 0.0, 0.0);
            ShowSyncHudMsg(id, gHudSyncInfo2, "%s", DirName);
        }
        set_hudmessage(255, 255, 255, fHudCoordinates, 0.9, 0, 0.0, 3.0, 0.0, 0.0);
        ShowSyncHudMsg(id, gHudSyncInfo, "^n%s", DirSymbol);
    }
    return PLUGIN_HANDLED
}

public windage(id)
if(get_pcvar_num(g_cvar_wind))
{
    g_DeG = nvault_get(g_vault, "deg");
    new Float:g_Wind
    g_Wind =  g_DeG*-0.7;
    EF_CrosshairAngle(id, g_Wind, g_Wind ); {}
}

public fix(id)
if(get_pcvar_num(g_cvar_wind))
{
    EF_CrosshairAngle(id, 0.0, 0.0 ); {}
}

public hl1_effect(Float:Origin[3])  ///was the new fog and snow ground cover with long life but decided to use for zass.
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_BEAMDISK);
    write_coord(floatround(Origin[0]));                     // coord coord coord (center position)
    write_coord(floatround(Origin[1]));
    write_coord(floatround(Origin[2]+10.0));
    write_coord(floatround(Origin[0]));                     // coord coord coord (axis and radius)
    write_coord(floatround(Origin[1]));
    write_coord(floatround(Origin[2]+random_float(500.0,1000.0)));
    switch(random_num(0,1))
    {
        case 0: write_short(sprFlare6);                         // short (sprite index)
        case 1: write_short(sprLightning);                      // short (sprite index)
    }
    write_byte(random_num(0,255));                          // byte (starting frame)  //was 1
    write_byte(random_num(0,255));                          // byte (frame rate in 0.1's) //fog is slower like 20fps
    write_byte(random_num(5,1000));                         // byte (life in 0.1's) //500 zombie fog
    write_byte(random_num(5,255));                          // byte (line width in 0.1's) //was 24
    write_byte(random_num(0,255));              // byte (noise amplitude in 0.01's) //was 10
    write_byte(random_num(0,255));                          // byte,byte,byte (color) 255 119 255 pink
    write_byte(random_num(0,255));
    write_byte(random_num(0,255));
    write_byte(random_num(50,1000));                        // byte (brightness) //1000 zombie fog
    write_byte(random_num(7,128));                          // byte (scroll speed in 0.1's) // was 7
    message_end();
}

public ClCmd_hl_fog(id, level, cid)
{
    if (!cmd_access(id,level,cid,1))
        return PLUGIN_HANDLED
    set_task_ex(0.5, "old_fog", 771, .flags = SetTask_Repeat);
    return PLUGIN_HANDLED
}

public old_fog(Float:Vector[3])     ///also good stock for camper honing
{
    message_begin(MSG_PVS, SVC_TEMPENTITY);
    write_byte(TE_BEAMCYLINDER);
    engfunc(EngFunc_WriteCoord,Vector[0]);
    engfunc(EngFunc_WriteCoord,Vector[1]);
    engfunc(EngFunc_WriteCoord,Vector[2] + 16);
    engfunc(EngFunc_WriteCoord,Vector[0]);
    engfunc(EngFunc_WriteCoord,Vector[1]);
    engfunc(EngFunc_WriteCoord,Vector[2] + 200);
    write_short(g_F0g);
    write_byte(100);
    write_byte(random_num(75,500));
    write_byte(random_num(50,175));
    write_byte(random_num(150,500)); //line W
    write_byte(random_num(0,500)); //noise
    write_byte(111);
    write_byte(255);
    write_byte(255);
    write_byte(random_num(5,100));
    write_byte(0);
    message_end();
}

public hl_fog()
    set_task_ex(0.3, "old_fog", 770, .flags = SetTask_Repeat);

public PolaRVorteX(Float:Vector[3])
{
    message_begin(MSG_PVS, SVC_TEMPENTITY);
    write_byte(random_num(19,21));
    engfunc(EngFunc_WriteCoord,Vector[0]+ random_num(-10000,500));
    engfunc(EngFunc_WriteCoord,Vector[1]+ random_num(-10000,500));
    engfunc(EngFunc_WriteCoord,Vector[2]+ random_num(-10000,500));
    engfunc(EngFunc_WriteCoord,Vector[0]* power(random_num(-5,10),3));
    engfunc(EngFunc_WriteCoord,Vector[1]+ random_num(-10000,-500));
    engfunc(EngFunc_WriteCoord,Vector[2]+ random_num(-10000,-500));

    write_short(g_F0g);
    write_byte(100);
    write_byte(255);
    write_byte(255);
    write_byte(400);
    write_byte(500);
    write_byte(random_num(90,130)); /*RGB111255255trademarkFOG*/
    write_byte(random_num(200,255));
    write_byte(random_num(200,255));
    write_byte(random_num(75,125));
    write_byte(0);
    message_end();
}

public HellRain_Blizzard(Float:Vector[3])           /// will code in some of the worst weather codes. Unbeliable.
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_BEAMTORUS);
    /*engfunc(EngFunc_WriteCoord,Vector[0]+ random_num(-10000,500));
    engfunc(EngFunc_WriteCoord,Vector[1]+ random_num(-10000,500));
    engfunc(EngFunc_WriteCoord,Vector[2]+ random_num(-10000,500));
    engfunc(EngFunc_WriteCoord,Vector[0]+ power(random_num(-5,10),3));
    engfunc(EngFunc_WriteCoord,Vector[1]+ random_num(-10000,-500));
    engfunc(EngFunc_WriteCoord,Vector[2]+ random_num(-10000,-500)); */

    /**
    *torisklin https://www.amxmodx.org/api/message_const
    *
    */
    /*19blizz*/
    /*polar vortex nightmare on X DIR * power(random_num(-5,10),3));*/
    engfunc(EngFunc_WriteCoord,Vector[0]+ random_num(-10000,500));
    engfunc(EngFunc_WriteCoord,Vector[1]+ random_num(-10000,500));
    engfunc(EngFunc_WriteCoord,Vector[2]+ random_num(-10000,500));
    engfunc(EngFunc_WriteCoord,Vector[0]+ random_num(-10000,-500));
    engfunc(EngFunc_WriteCoord,Vector[1]+ random_num(-10000,-500));
    engfunc(EngFunc_WriteCoord,Vector[2]+ random_num(-10000,-500));
    /*19blizz*/

    write_short(g_F0g);
    write_byte(100);
    write_byte(255);
    write_byte(255);
    write_byte(400);
    write_byte(500);
    write_byte(random_num(90,130)); /*RGB111255255trademarkFOG*/
    write_byte(random_num(200,255));
    write_byte(random_num(200,255));
    write_byte(random_num(75,125));
    write_byte(0);
    message_end();
}

public ClCmd_hl_snow(id, level, cid)            // the best
{
    if (!cmd_access(id,level,cid,1))
    return PLUGIN_HANDLED

    set_task_ex(0.1, "snow_puff", 333, .flags = SetTask_Repeat);

    set_task_ex(random_float(1.0, 2.0), "snow_flake",444, .flags = SetTask_Repeat);

    set_task_ex(0.3, "streak2", 776, .flags = SetTask_Repeat);

    set_task_ex(1.0, "streak3", 887, .flags = SetTask_Repeat);

    set_task_ex(random_float(3.0, 5.5), "ring_saturn", 111, .flags = SetTask_Repeat);

    return PLUGIN_HANDLED
}

public hl_snow()
{
    set_task_ex(0.1, "snow_puff", 332, .flags = SetTask_Repeat);
    set_task_ex(random_float(2.0, 5.0), "snow_flake",443, .flags = SetTask_Repeat);
    set_task_ex(0.5, "FlasheS", 435, .flags = SetTask_Repeat);
    set_task_ex(0.7, "streak2", 777, .flags = SetTask_Repeat);
    set_task_ex(1.0, "streak3", 888, .flags = SetTask_Repeat);
    set_task_ex(random_float(3.0, 5.5), "ring_saturn", 111, .flags = SetTask_Repeat) ;
}

public ClCmd_hl_dry(id, level, cid)         // end all conditions. The Jesus Handle.
{
    if (!cmd_access(id,level,cid,1))
    return PLUGIN_HANDLED

    if (task_exists(111)) remove_task(111);
    if (task_exists(222)) remove_task(222);
    if (task_exists(221)) remove_task(221);

    // kill snow flaking (sky)
    if (task_exists(332)) remove_task(332);
    if (task_exists(333)) remove_task(333);

    //kill FlasheS
    if (task_exists(435)) remove_task(435);

    // kill snow puffing (falling)
    if (task_exists(443)) remove_task(443);
    if (task_exists(444)) remove_task(444);

    // kill fog lurching
    if (task_exists(770)) remove_task(770);
    if (task_exists(771)) remove_task(771);

    // rain drops streak 1-3 both from auto and user calls
    // streak2
    if (task_exists(777)) remove_task(777);
    if (task_exists(776)) remove_task(776);
    // streak3
    if (task_exists(888)) remove_task(888);
    if (task_exists(887)) remove_task(887);
    // hl effect
    if (task_exists(999)) remove_task(999);
    if (task_exists(998)) remove_task(998);

    return PLUGIN_HANDLED
}

public no_snow()
{
    if (task_exists(111)) remove_task(111);
    if (task_exists(222)) remove_task(222);
    if (task_exists(333)) remove_task(333);
    if (task_exists(444)) remove_task(444);
    if (task_exists(777)) remove_task(777);
    if (task_exists(888)) remove_task(888);
}

public snow_flake(Float:Vector[3])
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_BEAMDISK);
    engfunc(EngFunc_WriteCoord,Vector[0] + random_num(10000,15000));
    engfunc(EngFunc_WriteCoord,Vector[1] + random_num(10000,15000));
    engfunc(EngFunc_WriteCoord,Vector[2] + random_num(10000,15000));
    engfunc(EngFunc_WriteCoord,Vector[0] * random_num(1000,5000));
    engfunc(EngFunc_WriteCoord,Vector[1] / random_num(1000,5000));
    engfunc(EngFunc_WriteCoord,Vector[2] + random_num(-1000,15000));
    switch(random_num(0,2))
    {
        case 0: write_short(g_F0g)
        case 1: write_short(sprLightning)
        case 2: write_short(g_Saturn)
    }
    write_byte(random_num(1,25));
    write_byte(random_num(1,255));
    write_byte(random_num(2,13));
    write_byte(random_num(1,20000));
    write_byte(random_num(50,12000));
    write_byte(random_num(90,150));
    write_byte(random_num(90,150));
    write_byte(random_num(199,255));
    write_byte(random_num(50,500));
    write_byte(0);
    message_end();
}

public snow_puff(Float:Vector[3])
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_LARGEFUNNEL)
    engfunc(EngFunc_WriteCoord,Vector[0] + random_num(-100000,180000));
    engfunc(EngFunc_WriteCoord,Vector[1] + random_num(-100000,180000));
    engfunc(EngFunc_WriteCoord,Vector[2] + random_num(-100000,180000));
    write_short(g_F0g)
    write_short(0) /*snow*/
    message_end()
}

public ring_saturn(Float:bOrigin[3])
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_BEAMTORUS)
    write_coord(floatround(bOrigin[0]+random_num(-11,11)));  /*X*/
    write_coord(floatround(bOrigin[1]-random_num(-11,11)));
    write_coord(floatround(bOrigin[2]+random_num(-11,18000)));
    write_coord(floatround(bOrigin[0]/random_num(-11,11)));
    write_coord(floatround(bOrigin[1]*random_num(-11,11)));
    write_coord(floatround(bOrigin[2]+random_num(-11,11)));
    write_short(g_Saturn)
    write_byte(random_num(3,450));
    write_byte(random_num(2,500));
    write_byte(random_num(30,1000));
    write_byte(random_num(50,800));
    write_byte(random_num(40,3000));
    write_byte(random_num(0,255));
    write_byte(random_num(0,255));
    write_byte(random_num(0,255));
    write_byte(random_num(100,2000));
    write_byte(random_num(2,200));
    message_end()
}

public streak(Float:Vectors[3])
{
    ///RAIN DROPS FROM THE SKY
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_STREAK_SPLASH);
    engfunc(EngFunc_WriteCoord,Vectors[0] + XOR);
    engfunc(EngFunc_WriteCoord,Vectors[1] + YOR);
    engfunc(EngFunc_WriteCoord,Vectors[2] + ZOR);               ///sidewayz like a rainbow, needs work!! x+ran10,200 y+ran100,1000 z+5000|AXIS=+ran-650,-650 y+ran=-700,-700, z=+10

    engfunc(EngFunc_WriteCoord,Vectors[0] + XDIR);
    engfunc(EngFunc_WriteCoord,Vectors[1] + YDIR);
    engfunc(EngFunc_WriteCoord,Vectors[2] + ZDIR);

    write_byte(COLOR);  /*0 wht  3 blu  7 blu*/  ///ever hear of red or green rain???
    write_short(DROPS); //# of streaks
    write_short(random_num(1, 2)); //base speed
    write_short(-1); //ran velocity factor
    message_end();

    ///SPLASH UP or STEAM from RAIN
    new Float:Vectorsa[3];
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);  //want reliable to all as it looks stupid otherwise
    write_byte(TE_LARGEFUNNEL)
    engfunc(EngFunc_WriteCoord,Vectorsa[0] + PRECIPX);
    engfunc(EngFunc_WriteCoord,Vectorsa[1] + PRECIPY);
    engfunc(EngFunc_WriteCoord,Vectorsa[2] + PRECIPZ);

    write_short(g_TesteD) ///(g_F0g)
    write_short(0) //was 2 for reverse funnel
    message_end()
}

public ClCmd_FlasheS(id, level, cid)
{
    if(is_user_admin(id))
        set_task_ex(0.5, "FlasheS", 435, .flags = SetTask_Repeat);
    return PLUGIN_HANDLED
}

public FlasheS(Float:sorigin[3])
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_DLIGHT);
    engfunc(EngFunc_WriteCoord,sorigin[0] + random_num(-8000,7000)) /*position.x*/
    engfunc(EngFunc_WriteCoord,sorigin[1] + random_num(-8000,7000))
    engfunc(EngFunc_WriteCoord,sorigin[2] + random_num(50,3000))
    write_byte(random_num(-1800000,1800000)); /*(radius in 10's)*/   ///was -1000 now -18K
    write_byte(random_num(0,255)); /*rgb*/
    write_byte(random_num(0,255));
    write_byte(random_num(0,255));
    write_byte(random_num(50,5000)); /*bright*/
    write_byte(random_num(1,500));  /*(decay rate in 10's)*/
    message_end();
}

public streak2(Float:Vector2[3])
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_STREAK_SPLASH);
    engfunc(EngFunc_WriteCoord,Vector2[0] + random_num(-5,8000));
    engfunc(EngFunc_WriteCoord,Vector2[1] + random_num(-5,8000));
    engfunc(EngFunc_WriteCoord,Vector2[2] + random_num(3000,11000));
    engfunc(EngFunc_WriteCoord,Vector2[0] * random_num(10,200));
    engfunc(EngFunc_WriteCoord,Vector2[1] + random_num(10,200));
    engfunc(EngFunc_WriteCoord,Vector2[2] - random_num(50,2000));
    write_byte(random_num(0, 7));   /*0 wht  3 blu  7 blu*/  ///ever hear of red or green rain???
    write_short(random_num(30,200));
    write_short(random_num(1,5));
    write_short(random_num(3,15));
    message_end();
}

public streak3(Float:Vector[3])
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_STREAK_SPLASH);
    engfunc(EngFunc_WriteCoord,Vector[0] + XOR );
    engfunc(EngFunc_WriteCoord,Vector[1] + YOR );
    engfunc(EngFunc_WriteCoord,Vector[2] + ZOR );
    engfunc(EngFunc_WriteCoord,Vector[0] + XDIR );
    engfunc(EngFunc_WriteCoord,Vector[1] + YDIR );
    engfunc(EngFunc_WriteCoord,Vector[2] + ZDIR );
    write_byte(COLOR);   /*0 wht  3 blu  7 blu*/  ///ever hear of red or green rain???
    write_short(DROPS);
    write_short(random_num(1,3));
    write_short(random_num(1,2));
    message_end();

    new Float:Vector2[3]
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_STREAK_SPLASH);
    engfunc(EngFunc_WriteCoord,Vector2[0] + XOR );
    engfunc(EngFunc_WriteCoord,Vector2[1] + YOR );
    engfunc(EngFunc_WriteCoord,Vector2[2] + ZOR );
    engfunc(EngFunc_WriteCoord,Vector2[0] + XDIR );
    engfunc(EngFunc_WriteCoord,Vector2[1] + YDIR );
    engfunc(EngFunc_WriteCoord,Vector2[2] + ZDIR );
    write_byte(COLOR);   /*0 wht  3 blu  7 blu*/  ///ever hear of red or green rain???
    write_short(DROPS);
    write_short(random_num(1,2));
    write_short(random_num(1,2));
    message_end();

    new Float:Vector1[3]
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_STREAK_SPLASH);
    engfunc(EngFunc_WriteCoord,Vector1[0] + XOR );
    engfunc(EngFunc_WriteCoord,Vector1[1] + YOR );
    engfunc(EngFunc_WriteCoord,Vector1[2] + ZOR );
    engfunc(EngFunc_WriteCoord,Vector1[0] + XDIR );
    engfunc(EngFunc_WriteCoord,Vector1[1] + YDIR );
    engfunc(EngFunc_WriteCoord,Vector1[2] + ZDIR );
    write_byte(COLOR);
    write_short(DROPS);
    write_short(random_num(1,3));
    write_short(random_num(1,3));
    message_end();

    new Float:Vector0[3]
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_STREAK_SPLASH);
    engfunc(EngFunc_WriteCoord,Vector0[0] + XOR );
    engfunc(EngFunc_WriteCoord,Vector0[1] + YOR );
    engfunc(EngFunc_WriteCoord,Vector0[2] + ZOR );
    engfunc(EngFunc_WriteCoord,Vector0[0] + XDIR );
    engfunc(EngFunc_WriteCoord,Vector0[1] + YDIR );
    engfunc(EngFunc_WriteCoord,Vector0[2] + ZDIR );
    write_byte(COLOR);   /*0 wht  3 blu  7 blu*/  ///ever hear of red or green rain???
    write_short(DROPS);
    write_short(random_num(1,3));
    write_short(random_num(3,5));
    message_end();
}

public set_sky(humi)
{
    new phase;
    new hour[3];
    get_time("%H", hour, charsmax(hour));
    g_Ti = str_to_num(hour);

    g_Nn = 12; ///noon
    //Time of day or night sky setting
    if (g_Ti == g_Nn - 1 || g_Ti == g_Nn)
        phase = 2; //NOON
    else if (g_Ti == g_Up - 1 || g_Ti == g_Up)
        phase = 1; //SUNRISE
    else if (g_Ti == g_Dwn - 1 || g_Ti == g_Dwn)
        phase = 3; //SUNSET
    else if (g_Ti < g_Up - 1 || g_Ti >= g_Dwn + 1)
        phase = 4; //NIGHT
    else if (g_Ti > g_Up + 1 && g_Ti < g_Nn - 1)
        phase = 0; //DAY
    else if (g_Ti > g_Nn + 1 && g_Ti < g_Dwn - 1)
        phase = 0; //DAY

    //Set skies to match the weather.
    humi <= g_cvar_fog ? precache_sky(g_skynames[((nvault_get(g_vault, "element") - 1) * 5) + phase]) : precache_sky(g_skynames[(3 * 5) + phase])
}

public precache_sky(const skyname[])
{
    new bool: pres = true;
    static file[MAX_PLAYERS+2];

    for (new i = 0; i < 6; ++i)
    {
        formatex(file, charsmax(file), "gfx/env/%s%s.tga", skyname, g_skysuf[i]);
        if (file_exists(file))
            precache_generic(file);
        else
        {
            pres = false;
            break;
        }
    }
    if (pres)
        set_cvar_string("sv_skyname", skyname);
}

public daylight()
{
    new sunrise, sunset
    nvault_get(g_vault, "element", g_element_name, 8);

    //g_temp_min = nvault_get(g_vault, "mintemp");
    g_temp = nvault_get(g_vault, "temp");
    g_feel = nvault_get(g_vault, "feelslike");

    //Using sockets feed or CVAR?
    if(get_pcvar_num(g_cvar_day) > 0)
    {
        sunrise = get_pcvar_num(g_cvar_day)
    }
    else
    {
        sunrise = nvault_get(g_vault, "day")
        g_Up = sunrise
        if(g_debugger_on)
            server_print "Illumination fed sunrise %i", sunrise
    }
    if(get_pcvar_num(g_cvar_night) > 0 )
    {
        sunset  = get_pcvar_num(g_cvar_night)
    }
    else
    {
        sunset  = nvault_get(g_vault, "night")
        g_Dwn  = sunset
        if(g_debugger_on)
            server_print "Illumination fed sunset %i", sunset
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    new totalDayLight = (sunset) - sunrise;
    new serv_time[3];
    get_time("%H", serv_time, 2);

    new now = str_to_num(serv_time);

    if (get_pcvar_num(g_cvar_time) > 0)
        now = get_cvar_num("time");

    new light, lightspan = get_pcvar_num(g_cvar_minlight) + 1 - get_pcvar_num(g_cvar_maxlight);
    //new tempspan = g_temp - g_temp_min;
    new noon = (totalDayLight / 2) + sunrise;
    if (now < noon)
    {
        if (now < sunrise)
        {
            light = get_pcvar_num(g_cvar_minlight);
            //g_curr_temp = g_temp_min;
        }
        else
        {
            new prenoon = noon - sunrise;
            light = get_pcvar_num(g_cvar_minlight) - (now - sunrise) * (lightspan / prenoon);
            //g_curr_temp = g_temp - (now - sunrise) * (tempspan / prenoon);
        }
    }
    if (now == noon)
    {
        light = get_pcvar_num(g_cvar_maxlight);
        //g_curr_temp = g_temp;
    }
    if (now > noon)
    {
        if (now > sunset)
        {
            light = get_pcvar_num(g_cvar_minlight);
            //g_curr_temp = g_temp_min;
        }
        else
        {
            new postnoon = noon - sunrise;
            light = (now - noon) * (lightspan / postnoon) + get_pcvar_num(g_cvar_maxlight);
            //g_curr_temp = (now - sunrise) * (tempspan / postnoon) + g_temp_min;
            if (light > get_pcvar_num(g_cvar_minlight))
            {
                light = get_pcvar_num(g_cvar_minlight);
            }
        }
    }
    if(g_debugger_on > 1)
    {
        log_amx("darkness %d", light);
        log_amx("dark %d phase %d lums %d", get_cvar_num("dark"), light, get_cvar_num("lums"));
        log_amx("darkness added to max light is %d out of 25 total darkness", light);
    }
    fm_set_lights(g_LightLevel[light]);
    new fogcolor = (get_pcvar_num(g_cvar_minlight) - light) * 10 + 20;
    new form[12];
    /*model illumination*/
    set_cvar_num("sv_skycolor_r", fogcolor);
    set_cvar_num("sv_skycolor_g", fogcolor);
    set_cvar_num("sv_skycolor_b", fogcolor);
    format(form, 12, "%d %d %d", fogcolor, fogcolor, fogcolor);
    fm_set_kvd(g_fog, "rendercolor", form);
}


public makeFog(amount)
{
    if(g_bCSOF)
    {
        g_fog = fm_create_entity("env_fog");
        new Float: density = ( 0.0002 * ( amount - g_cvar_fog )) + 0.001;
        new dens[7];
        float_to_str(density, dens, 6);
        fm_set_kvd(g_fog, "density", dens);
        fm_set_kvd(g_fog, "rendercolor", "200 200 200");
    }
    else
    {
        hl_fog();
        new Zoo = nvault_get(g_vault, "humidity");
        if ( Zoo < g_cvar_fog )
            no_snow();
    }
    return;
}

/*DispatchKeyValue*/
stock fm_set_kvd(entity, const key[], const value[], const classname[] = "")
{
    if (classname[0])
        set_kvd(0, KV_ClassName, classname);
    else
    {
        new class[MAX_PLAYERS];
        pev(entity, pev_classname, class, sizeof class - 1);
        set_kvd(0, KV_ClassName, class);
    }
    set_kvd(0, KV_KeyName, key);
    set_kvd(0, KV_Value, value);
    set_kvd(0, KV_fHandled, 0);
    return dllfunc(DLLFunc_KeyValue, entity, 0);
}
