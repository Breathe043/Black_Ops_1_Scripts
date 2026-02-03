#include maps\_utility;
#include common_scripts\utility;
#include maps\_zombiemode_utility;
#using_animtree( "generic_human" );

// Adding multiple "improvements" to MeatSlingerNick's patch.

init()
{
    if ( GetDvar( #"zombiemode" ) != "1" )
        return;

    // Hook box selection with our full implementation (Moon-patch style)
    replacefunc(
        maps\_zombiemode_weapons::treasure_chest_ChooseWeightedRandomWeapon,
        ::custom_treasure_chest_ChooseWeightedRandomWeapon
    );

    // If Winter's Howl isn't included, don't run the rest
    if ( !maps\_zombiemode_weapons::is_weapon_included( "freezegun_zm" ) )
        return;

    level._ZOMBIE_ACTOR_FLAG_FREEZEGUN_EXTREMITY_DAMAGE_FX = 15;
    level._ZOMBIE_ACTOR_FLAG_FREEZEGUN_TORSO_DAMAGE_FX = 14;

    // Default (fallback) values
    set_zombie_var( "freezegun_cylinder_radius",                120 );
    set_zombie_var( "freezegun_inner_range",                     60 );
    set_zombie_var( "freezegun_outer_range",                    600 );
    set_zombie_var( "freezegun_inner_damage",                  3000 );
    set_zombie_var( "freezegun_outer_damage",                  3000 );
    set_zombie_var( "freezegun_shatter_range",                  180 );
    set_zombie_var( "freezegun_shatter_inner_damage",           500 );
    set_zombie_var( "freezegun_shatter_outer_damage",           250 );

    set_zombie_var( "freezegun_cylinder_radius_upgraded",       200 );
    set_zombie_var( "freezegun_inner_range_upgraded",           120 );
    set_zombie_var( "freezegun_outer_range_upgraded",           9000 );
    set_zombie_var( "freezegun_inner_damage_upgraded",         11000 );
    set_zombie_var( "freezegun_outer_damage_upgraded",         11000 );
    set_zombie_var( "freezegun_shatter_range_upgraded",         600 );
    set_zombie_var( "freezegun_shatter_inner_damage_upgraded",  750 );
    set_zombie_var( "freezegun_shatter_outer_damage_upgraded",  500 );

    // FX
    level._effect[ "freezegun_shatter" ]              = LoadFX( "weapon/freeze_gun/fx_freezegun_shatter" );
    level._effect[ "freezegun_crumple" ]              = LoadFX( "weapon/freeze_gun/fx_freezegun_crumple" );
    level._effect[ "freezegun_smoke_cloud" ]          = loadfx( "weapon/freeze_gun/fx_freezegun_smoke_cloud" );
    level._effect[ "freezegun_damage_torso" ]         = LoadFX( "maps/zombie/fx_zombie_freeze_torso" );
    level._effect[ "freezegun_damage_sm" ]            = LoadFX( "maps/zombie/fx_zombie_freeze_md" );
    level._effect[ "freezegun_shatter_upgraded" ]     = LoadFX( "weapon/freeze_gun/fx_exp_freezegun_impact" );
    level._effect[ "freezegun_crumple_upgraded" ]     = LoadFX( "weapon/freeze_gun/fx_exp_freezegun_impact" );
    level._effect[ "freezegun_shatter_gib_fx" ]       = LoadFX( "weapon/bullet/fx_flesh_gib_fatal_01" );
    level._effect[ "freezegun_shatter_gibtrail_fx" ]  = LoadFX( "weapon/freeze_gun/fx_trail_freezegun_blood_streak" );
    level._effect[ "freezegun_crumple_gib_fx" ]       = LoadFX( "system_elements/fx_null" );
    level._effect[ "freezegun_crumple_gibtrail_fx" ]  = LoadFX( "system_elements/fx_null" );

    // Threads
    level thread freezegun_damage_scaler();
    level thread freezegun_on_player_connect();
}

//
// ------------------------------------------------------------
// Mystery Box Logic + Forced Winter's Howl
// ------------------------------------------------------------
//
custom_treasure_chest_ChooseWeightedRandomWeapon( player )
{
    // Five: force Winter's Howl once (first *valid* box result)
    if ( level.script == "zombie_pentagon" && IsDefined(player) && is_player_valid(player) )
    {
        if ( !IsDefined(level.gave_freezegun_once) )
            level.gave_freezegun_once = false;

        if ( !level.gave_freezegun_once && maps\_zombiemode_weapons::is_weapon_included("freezegun_zm") )
        {
            level.gave_freezegun_once = true;
            return "freezegun_zm";
        }
    }

    keys = GetArrayKeys( level.zombie_weapons );

    toggle_weapons_in_use = 0;

    // Filter out any weapons the player already has
    filtered = [];
    for( i = 0; i < keys.size; i++ )
    {
        if( !maps\_zombiemode_weapons::get_is_in_box( keys[i] ) )
        {
            continue;
        }

        if( isdefined( player ) && is_player_valid(player) && player maps\_zombiemode_weapons::has_weapon_or_upgrade( keys[i] ) )
        {
            if ( maps\_zombiemode_weapons::is_weapon_toggle( keys[i] ) )
            {
                toggle_weapons_in_use++;
            }
            continue;
        }

        if( !IsDefined( keys[i] ) )
        {
            continue;
        }

        num_entries = [[ level.weapon_weighting_funcs[keys[i]] ]]();

        for( j = 0; j < num_entries; j++ )
        {
            filtered[filtered.size] = keys[i];
        }
    }

    // Filter out the limited weapons
    if( IsDefined( level.limited_weapons ) )
    {
        keys2 = GetArrayKeys( level.limited_weapons );
        players = get_players();
        pap_triggers = GetEntArray("zombie_vending_upgrade", "targetname");

        for( q = 0; q < keys2.size; q++ )
        {
            count = 0;

            for( i = 0; i < players.size; i++ )
            {
                if( players[i] maps\_zombiemode_weapons::has_weapon_or_upgrade( keys2[q] ) )
                {
                    count++;
                }
            }

            // Check the pack a punch machines to see if they are holding what we're looking for
            for ( k=0; k<pap_triggers.size; k++ )
            {
                if ( IsDefined(pap_triggers[k].current_weapon) && pap_triggers[k].current_weapon == keys2[q] )
                {
                    count++;
                }
            }

            // Check the other boxes so we don't offer something currently being offered during a fire sale
            for ( chestIndex = 0; chestIndex < level.chests.size; chestIndex++ )
            {
                if ( IsDefined( level.chests[chestIndex].chest_origin.weapon_string ) && level.chests[chestIndex].chest_origin.weapon_string == keys2[q] )
                {
                    count++;
                }
            }

            if ( isdefined( level.random_weapon_powerups ) )
            {
                for ( powerupIndex = 0; powerupIndex < level.random_weapon_powerups.size; powerupIndex++ )
                {
                    if ( IsDefined( level.random_weapon_powerups[powerupIndex] ) && level.random_weapon_powerups[powerupIndex].base_weapon == keys2[q] )
                    {
                        count++;
                    }
                }
            }

            if ( maps\_zombiemode_weapons::is_weapon_toggle( keys2[q] ) )
            {
                toggle_weapons_in_use += count;
            }

            if( count >= level.limited_weapons[keys2[q]] )
            {
                filtered = array_remove( filtered, keys2[q] );
            }
        }
    }

    if ( IsDefined( level.zombie_weapon_toggles ) )
    {
        keys2 = GetArrayKeys( level.zombie_weapon_toggles );
        for( q = 0; q < keys2.size; q++ )
        {
            if ( level.zombie_weapon_toggles[keys2[q]].active )
            {
                if ( toggle_weapons_in_use < level.zombie_weapon_toggle_max_active_count )
                {
                    continue;
                }
            }

            filtered = array_remove( filtered, keys2[q] );
        }
    }

    // Safety check
    if ( filtered.size <= 0 )
    {
        for ( i = 0; i < keys.size; i++ )
        {
            if ( maps\_zombiemode_weapons::get_is_in_box(keys[i]) )
                filtered[filtered.size] = keys[i];
        }
    }

    filtered = array_randomize( filtered );
    return filtered[RandomInt( filtered.size )];
}

//
// ------------------------------------------------------------
// Winter Howl's damage scaler(Adding to MeatSlingerNick's code)
// ------------------------------------------------------------
//
freezegun_damage_scaler()
{
    level endon( "game_ended" );

    for ( ;; )
    {
        wait 0.5;
        r = level.round_number;

        // Base: 1-shot until round 50
        if ( r <= 50 )
        {
            set_zombie_var( "freezegun_inner_damage", 999999 );
            set_zombie_var( "freezegun_outer_damage", 999999 );
            set_zombie_var( "freezegun_shatter_inner_damage", 999999 );
            set_zombie_var( "freezegun_shatter_outer_damage", 999999 );
        }
        else
        {
            set_zombie_var( "freezegun_inner_damage", 3000 );
            set_zombie_var( "freezegun_outer_damage", 3000 );
            set_zombie_var( "freezegun_shatter_inner_damage", 500 );
            set_zombie_var( "freezegun_shatter_outer_damage", 250 );
        }

        // PaP: 1-shot until round 200
        if ( r <= 200 )
        {
            set_zombie_var( "freezegun_inner_damage_upgraded", 999999 );
            set_zombie_var( "freezegun_outer_damage_upgraded", 999999 );
            set_zombie_var( "freezegun_shatter_inner_damage_upgraded", 999999 );
            set_zombie_var( "freezegun_shatter_outer_damage_upgraded", 999999 );
        }
        else
        {
            set_zombie_var( "freezegun_inner_damage_upgraded", 9999 );
            set_zombie_var( "freezegun_outer_damage_upgraded", 9999 );
            set_zombie_var( "freezegun_shatter_inner_damage_upgraded", 750 );
            set_zombie_var( "freezegun_shatter_outer_damage_upgraded", 500 );
        }
    }
}

//
// ------------------------------------------------------------
// Winter's Howl cone logic (From MeatSlingerNick)
// ------------------------------------------------------------
//
freezegun_on_player_connect()
{
    for( ;; )
    {
        level waittill( "connecting", player );
        player thread wait_for_freezegun_fired();
    }
}

wait_for_freezegun_fired()
{
    self endon( "disconnect" );
    self waittill( "spawned_player" );

    for( ;; )
    {
        self waittill( "weapon_fired" );
        currentweapon = self GetCurrentWeapon();

        if( ( currentweapon == "freezegun_zm" ) || ( currentweapon == "freezegun_upgraded_zm" ) )
        {
            self thread freezegun_fired( currentweapon == "freezegun_upgraded_zm" );

            view_pos = self GetTagOrigin( "tag_flash" ) - self GetPlayerViewHeight();
            view_angles = self GetTagAngles( "tag_flash" );
            playfx( level._effect["freezegun_smoke_cloud"], view_pos, AnglesToForward( view_angles ), AnglesToUp( view_angles ) );
        }
    }
}

freezegun_fired( upgraded )
{
    if ( !IsDefined( level.freezegun_enemies ) )
    {
        level.freezegun_enemies = [];
        level.freezegun_enemies_dist_ratio = [];
    }

    self freezegun_get_enemies_in_range( upgraded );

    for ( i = 0; i < level.freezegun_enemies.size; i++ )
    {
        level.freezegun_enemies[i] thread freezegun_do_damage( upgraded, self, level.freezegun_enemies_dist_ratio[i] );
    }

    level.freezegun_enemies = [];
    level.freezegun_enemies_dist_ratio = [];
}

freezegun_get_cylinder_radius( upgraded )
{
    if ( upgraded )
        return level.zombie_vars["freezegun_cylinder_radius_upgraded"];
    else
        return level.zombie_vars["freezegun_cylinder_radius"];
}

freezegun_get_inner_range( upgraded )
{
    if ( upgraded )
        return level.zombie_vars["freezegun_inner_range_upgraded"];
    else
        return level.zombie_vars["freezegun_inner_range"];
}

freezegun_get_outer_range( upgraded )
{
    if ( upgraded )
        return level.zombie_vars["freezegun_outer_range_upgraded"];
    else
        return level.zombie_vars["freezegun_outer_range"];
}

freezegun_get_inner_damage( upgraded )
{
    if ( upgraded )
        return level.zombie_vars["freezegun_inner_damage_upgraded"];
    else
        return level.zombie_vars["freezegun_inner_damage"];
}

freezegun_get_outer_damage( upgraded )
{
    if ( upgraded )
        return level.zombie_vars["freezegun_outer_damage_upgraded"];
    else
        return level.zombie_vars["freezegun_outer_damage"];
}

freezegun_get_enemies_in_range( upgraded )
{
    inner_range = freezegun_get_inner_range( upgraded );
    outer_range = freezegun_get_outer_range( upgraded );
    cylinder_radius = freezegun_get_cylinder_radius( upgraded );

    view_pos = self GetWeaponMuzzlePoint();

    zombies = get_array_of_closest( view_pos, GetAiSpeciesArray( "axis", "all" ), undefined, undefined, (outer_range * 1.1) );
    if ( !isDefined( zombies ) )
        return;

    freezegun_inner_range_squared = inner_range * inner_range;
    freezegun_outer_range_squared = outer_range * outer_range;
    cylinder_radius_squared = cylinder_radius * cylinder_radius;

    forward_view_angles = self GetWeaponForwardDir();
    end_pos = view_pos + vector_scale( forward_view_angles, outer_range );

    for ( i = 0; i < zombies.size; i++ )
    {
        if ( !IsDefined( zombies[i] ) || !IsAlive( zombies[i] ) )
            continue;

        test_origin = zombies[i] getcentroid();
        test_range_squared = DistanceSquared( view_pos, test_origin );

        if ( test_range_squared > freezegun_outer_range_squared )
            return;

        normal = VectorNormalize( test_origin - view_pos );
        dot = VectorDot( forward_view_angles, normal );
        if ( 0 > dot )
            continue;

        radial_origin = PointOnSegmentNearestToPoint( view_pos, end_pos, test_origin );
        if ( DistanceSquared( test_origin, radial_origin ) > cylinder_radius_squared )
            continue;

        if ( 0 == zombies[i] DamageConeTrace( view_pos, self ) )
            continue;

        level.freezegun_enemies[level.freezegun_enemies.size] = zombies[i];
        level.freezegun_enemies_dist_ratio[level.freezegun_enemies_dist_ratio.size] =
            (freezegun_outer_range_squared - test_range_squared) / (freezegun_outer_range_squared - freezegun_inner_range_squared);
    }
}

freezegun_do_damage( upgraded, player, dist_ratio )
{
    damage = Int( LerpFloat( freezegun_get_outer_damage( upgraded ), freezegun_get_inner_damage( upgraded ), dist_ratio ) );
    self DoDamage( damage, player.origin, player, undefined, "projectile" );
}

freezegun_get_shatter_range( upgraded )
{
    if ( upgraded )
        return level.zombie_vars["freezegun_shatter_range_upgraded"];
    else
        return level.zombie_vars["freezegun_shatter_range"];
}

freezegun_get_shatter_inner_damage( upgraded )
{
    if ( upgraded )
        return level.zombie_vars["freezegun_shatter_inner_damage_upgraded"];
    else
        return level.zombie_vars["freezegun_shatter_inner_damage"];
}

freezegun_get_shatter_outer_damage( upgraded )
{
    if ( upgraded )
        return level.zombie_vars["freezegun_shatter_outer_damage_upgraded"];
    else
        return level.zombie_vars["freezegun_shatter_outer_damage"];
}

freezegun_do_shatter( player, weap, shatter_trigger, crumple_trigger )
{
    self freezegun_cleanup_freezegun_triggers( shatter_trigger, crumple_trigger );
    upgraded = (weap == "freezegun_upgraded_zm");

    self radiusDamage(
        self.origin,
        freezegun_get_shatter_range( upgraded ),
        freezegun_get_shatter_inner_damage( upgraded ),
        freezegun_get_shatter_outer_damage( upgraded ),
        player,
        "MOD_EXPLOSIVE",
        weap
    );

    if ( is_mature() )
    {
        self thread freezegun_do_gib( "up", upgraded );
    }
    else
    {
        self StartRagdoll();
    }
}

freezegun_do_gib( gib_type, upgraded )
{
    gibArray = [];
    gibArray[gibArray.size] = level._ZOMBIE_GIB_PIECE_INDEX_ALL;
    if ( upgraded )
        gibArray[gibArray.size] = 7;

    self gib( gib_type, gibArray );
    self hide();
    wait( 0.1 );
    self self_delete();
}

freezegun_wait_for_shatter( player, weap, shatter_trigger, crumple_trigger )
{
    shatter_trigger endon( "cleanup_freezegun_triggers" );
    orig_attacker = self.attacker;

    shatter_trigger waittill( "damage", amount, attacker, dir, org, mod );

    if ( isDefined( attacker ) && attacker == orig_attacker && "MOD_PROJECTILE" == mod &&
        ("freezegun_zm" == attacker GetCurrentWeapon() || "freezegun_upgraded_zm" == attacker GetCurrentWeapon()) )
    {
        self thread freezegun_do_crumple( weap, shatter_trigger, crumple_trigger );
    }
    else
    {
        self thread freezegun_do_shatter( player, weap, shatter_trigger, crumple_trigger );
    }
}

freezegun_do_crumple( weap, shatter_trigger, crumple_trigger )
{
    self freezegun_cleanup_freezegun_triggers( shatter_trigger, crumple_trigger );
    upgraded = (weap == "freezegun_upgraded_zm");

    if ( is_mature() )
        self thread freezegun_do_gib( "freeze", upgraded );
    else
        self StartRagdoll();
}

freezegun_wait_for_crumple( weap, shatter_trigger, crumple_trigger )
{
    crumple_trigger endon( "cleanup_freezegun_triggers" );
    crumple_trigger waittill( "trigger" );
    self thread freezegun_do_crumple( weap, shatter_trigger, crumple_trigger );
}

freezegun_cleanup_freezegun_triggers( shatter_trigger, crumple_trigger )
{
    self notify( "cleanup_freezegun_triggers" );
    shatter_trigger notify( "cleanup_freezegun_triggers" );
    crumple_trigger notify( "cleanup_freezegun_triggers" );
    shatter_trigger self_delete();
    crumple_trigger self_delete();
}