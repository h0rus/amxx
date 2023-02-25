/*Proactive server refresh.*/
#tryinclude amxmodx

#define PLUGIN  "Daily Reload"
#define VERSION "1.1"
#define AUTHOR  "SPiNX"

#define BOOT_MIN    25
#define BOOT_SEC    40

#define MAP    "bounce"

new g_cvar_bootimes

new g_players, bool:bBot[MAX_PLAYERS +1]

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    set_task( 15.0, "@check_time", 120422, .flags= "b")
    g_cvar_bootimes = register_cvar("reboot_times", "3 9 15 21")
}

@check_time()
{
    new hour,min,sec
    time(hour,min,sec)
    new SzString[MAX_PLAYERS], SzHour[3];
    num_to_str(hour, SzHour,charsmax(SzHour))
    get_pcvar_string(g_cvar_bootimes, SzString, charsmax(SzString))

    if(containi(SzString, SzHour)>-1 && g_players > 1)
    {
        change_task(120422, 2700.0)
        server_print "Retiming task to check in another hour.^nThe time is %i:%i%i.", hour, min, sec
        ///server_print "Reboot  times are: %i,%i,%i",  BOOT_HOUR1,BOOT_HOUR2,BOOT_HOUR3,BOOT_HOUR4
    }
    else
    {
        server_print "This hour there should be a reboot."
        if(min == BOOT_MIN)
        {
            server_print "Anticipating reload this minute..."
            change_task(120422, 1.0)
            if( sec == BOOT_SEC )
            {
                set_task( 0.5, "@reload_server", get_systime() )
            }
            else if( sec < BOOT_SEC )
            {
                server_cmd "say Daily reboot in %i seconds",(BOOT_SEC-sec)
                client_cmd 0, "spk ../../valve/sound/UI/buttonrollover.wav"
            }
            else
            {
                change_task(120422, 2700.0)
                server_print "Retiming task to check in 45 min."
            }

        }
        else if (min > BOOT_MIN || (BOOT_MIN - min) > 20)
        {
            change_task(120422, 900.0)
            server_print "Retiming task to check in 15 min."
        }
        else
        {
            change_task(120422, 15.0)
            server_print "Retiming task to check in 15 sec."
        }
    }
}

@reload_server()
{
    log_amx "Reloading server..."
    server_cmd "map %s", MAP
}

public client_putinserver(id)
{
    bBot[id] = is_user_bot(id) ? true : false
    if(!bBot[id])
    g_players++
}

public client_disconnected(id)
{
    if(!bBot[id])
    g_players--
}
