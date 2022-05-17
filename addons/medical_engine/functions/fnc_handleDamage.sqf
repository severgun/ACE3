#include "script_component.hpp"
/*
 * Author: commy2, SilentSpike
 * HandleDamage EH where wound events are raised based on incoming damage.
 * Be aware that for each source of damage, the EH can fire multiple times (once for each hitpoint).
 * We store these incoming damages and compare them on our final hitpoint: "ace_hdbracket".
 *
 * Arguments:
 * Handle damage EH
 *
 * Return Value:
 * Damage to be inflicted <NUMBER>
 *
 * Public: No
 */
params ["_unit", "_selection", "_damage", "_shooter", "_ammo", "_hitPointIndex", "_instigator", "_hitpoint"];

// HD sometimes triggers for remote units - ignore.
if !(local _unit) exitWith {nil};

// Get missing meta info
private _oldDamage = 0;

if (_hitPoint isEqualTo "") then {
    _hitPoint = "#structural";
    _oldDamage = damage _unit;
} else {
    _oldDamage = _unit getHitIndex _hitPointIndex;
};

// Damage can be disabled with old variable or via sqf command allowDamage
if !(isDamageAllowed _unit && {_unit getVariable [QEGVAR(medical,allowDamage), true]}) exitWith {_oldDamage};

private _newDamage = _damage - _oldDamage;
// Get armor value of hitpoint and calculate damage before armor
private _armor = [_unit, _hitpoint] call FUNC(getHitpointArmor);
private _realDamage = _newDamage * _armor;
TRACE_4("Received hit",_hitpoint,_ammo,_newDamage,_realDamage);

// Drowning doesn't fire the EH for each hitpoint so the "ace_hdbracket" code never runs
// Damage occurs in consistent increments
if (
    _hitPoint isEqualTo "#structural" &&
    {getOxygenRemaining _unit <= 0.5} &&
    {_damage isEqualTo (_oldDamage + 0.005)}
) exitWith {
    TRACE_5("Drowning",_unit,_shooter,_instigator,_damage,_newDamage);
    [QEGVAR(medical,woundReceived), [_unit, [[_newDamage, "Body", _newDamage]], _unit, "drowning"]] call CBA_fnc_localEvent;

    0
};

// Crashing a vehicle doesn't fire the EH for each hitpoint so the "ace_hdbracket" code never runs
// It does fire the EH multiple times, but this seems to scale with the intensity of the crash
private _vehicle = vehicle _unit;
if (
    EGVAR(medical,enableVehicleCrashes) &&
    {_hitPoint isEqualTo "#structural"} &&
    {_ammo isEqualTo ""} &&
    {_vehicle != _unit} &&
    {vectorMagnitude (velocity _vehicle) > 5}
    // todo: no way to detect if stationary and another vehicle hits you
) exitWith {
    TRACE_5("Crash",_unit,_shooter,_instigator,_damage,_newDamage);
    [QEGVAR(medical,woundReceived), [_unit, [[_newDamage, _hitPoint, _newDamage]], _unit, "vehiclecrash"]] call CBA_fnc_localEvent;

    0
};

// Being inside an exploding vehicle doesn't trigger for each hitpoint
// It seems to fire twice with ammo type "FuelExplosion" or "FuelExplosionBig"
if (
    _hitPoint isEqualTo "#structural" &&
    {_ammo isKindOf "FuelExplosion"} &&
    {_vehicle != _unit} &&
    {_damage == 1}
) exitwith {
    // triggers twice, so do half damage each time. not very important as it's basically always lethal
    private _hit = GET_NUMBER(configFile >> "CfgAmmo" >> _ammo >> "indirectHit", 10)/2;
    private _uniform = uniform _unit;
    if (_uniform isEqualTo "") then {
        _uniform = getText (configOf _unit >> "nakedUniform");
    };
    private _uniformClass = GET_STRING(configFile >> "CfgWeapons" >> _uniform >> "ItemInfo" >> "uniformClass", "U_BasicBody");
    private _damages = [];
    {
        private _armor = [_unit, _x] call FUNC(getHitpointArmor);
        // would be nice to move this into getHitpointArmor
        private _shielding = GET_NUMBER(configFile >> "CfgVehicles" >> _uniformClass >> "Hitpoints" >> _x >> "explosionShielding", 1);
        _damages pushBack [_hit*_shielding/_armor, ALL_BODY_PARTS select _forEachIndex, _hit*_shielding]
    } forEach ALL_HITPOINTS;
    TRACE_6("Vehicle explosion",_unit,_shooter,_instigator,_damage,_newDamage,_damages);
    [QEGVAR(medical,woundReceived), [_unit, _damages, _unit, _ammo]] call CBA_fnc_localEvent;

    0
};

// This hitpoint is set to trigger last, evaluate all the stored damage values
// to determine where wounds are applied
if (_hitPoint isEqualTo "ace_hdbracket") exitWith {
    _unit setVariable [QEGVAR(medical,lastDamageSource), _shooter];
    _unit setVariable [QEGVAR(medical,lastInstigator), _instigator];

    private _damageStructural = _unit getVariable [QGVAR($#structural), [0,0]];

    // --- Head
    private _damageHead = [
        _unit getVariable [QGVAR($HitFace), [0,0]],
        _unit getVariable [QGVAR($HitNeck), [0,0]],
        _unit getVariable [QGVAR($HitHead), [0,0]]
    ];
    _damageHead sort false;
    _damageHead = _damageHead select 0;

    // --- Body
    private _damageBody = [
        _unit getVariable [QGVAR($HitPelvis), [0,0]],
        _unit getVariable [QGVAR($HitAbdomen), [0,0]],
        _unit getVariable [QGVAR($HitDiaphragm), [0,0]],
        _unit getVariable [QGVAR($HitChest), [0,0]]
        // HitBody removed as it's a placeholder hitpoint and the high armor value (1000) throws the calculations off
    ];
    _damageBody sort false;
    _damageBody = _damageBody select 0;

    // --- Arms and Legs
    private _damageLeftArm = _unit getVariable [QGVAR($HitLeftArm), [0,0]];
    private _damageRightArm = _unit getVariable [QGVAR($HitRightArm), [0,0]];
    private _damageLeftLeg = _unit getVariable [QGVAR($HitLeftLeg), [0,0]];
    private _damageRightLeg = _unit getVariable [QGVAR($HitRightLeg), [0,0]];

    // Find hit point that received the maxium damage
    // Priority used for sorting if incoming damage is equal
    private _allDamages = [
        [_damageHead select 0,       PRIORITY_HEAD,       _damageHead select 1,       "Head"],
        [_damageBody select 0,       PRIORITY_BODY,       _damageBody select 1,       "Body"],
        [_damageLeftArm select 0,    PRIORITY_LEFT_ARM,   _damageLeftArm select 1,    "LeftArm"],
        [_damageRightArm select 0,   PRIORITY_RIGHT_ARM,  _damageRightArm select 1,   "RightArm"],
        [_damageLeftLeg select 0,    PRIORITY_LEFT_LEG,   _damageLeftLeg select 1,    "LeftLeg"],
        [_damageRightLeg select 0,   PRIORITY_RIGHT_LEG,  _damageRightLeg select 1,   "RightLeg"],
        [_damageStructural select 0, PRIORITY_STRUCTURAL, _damageStructural select 1, "#structural"]
    ];
    TRACE_2("incoming",_allDamages,_damageStructural);

    _allDamages sort false;
    _allDamages = _allDamages apply {[_x select 2, _x select 3, _x select 0]};
    
    // Environmental damage sources all have empty ammo string
    // No explicit source given, we infer from differences between them
    if (_ammo isEqualTo "") then {
        // Any collision with terrain/vehicle/object has a shooter
        // Check this first because burning can happen at any velocity
        if !(isNull _shooter) then {
            /*
              If shooter != unit then they hit unit, otherwise it could be:
               - Unit hitting anything at speed
               - An empty vehicle hitting unit
               - A physX object hitting unit
               Assume fall damage for downward velocity because it's most common
            */
            if (_shooter == _unit && {(velocity _unit select 2) < -2}) then {
                _ammo = "falling";
                TRACE_5("Fall",_unit,_shooter,_instigator,_damage,_allDamages);
            } else {
                _ammo = "collision";
                TRACE_5("Collision",_unit,_shooter,_instigator,_damage,_allDamages);
            };
        } else {
            // Anything else is almost guaranteed to be fire damage
            _ammo = "fire";
            TRACE_5("Fire Damage",_unit,_shooter,_instigator,_damage,_allDamages);
        };
    };

    // No wounds for minor damage
    // TODO check if this needs to be changed for burning damage (occurs as lots of small events that we add together)
    if ((_allDamages select 0 select 0) > 1E-3) then {
        TRACE_1("received",_allDamages);
        [QEGVAR(medical,woundReceived), [_unit, _allDamages, _shooter, _ammo]] call CBA_fnc_localEvent;
    };

    // Clear stored damages otherwise they will influence future damage events
    // (aka wounds will pile onto the historically most damaged hitpoint)
    {
        _unit setVariable [_x, nil];
    } forEach [
        QGVAR($HitFace),QGVAR($HitNeck),QGVAR($HitHead),
        QGVAR($HitPelvis),QGVAR($HitAbdomen),QGVAR($HitDiaphragm),QGVAR($HitChest),QGVAR($HitBody),
        QGVAR($HitLeftArm),QGVAR($HitRightArm),QGVAR($HitLeftLeg),QGVAR($HitRightLeg),
        QGVAR($#structural)
    ];

    0
};

// Damages are stored for "ace_hdbracket" event triggered last
_unit setVariable [format [QGVAR($%1), _hitPoint], [_realDamage, _newDamage]];

// Engine damage to these hitpoints controls blood visuals, limping, weapon sway
// Handled in fnc_damageBodyPart, persist here
if (_hitPoint in ["hithead", "hitbody", "hithands", "hitlegs"]) exitWith {_oldDamage};

// We store our own damage values so engine damage is unnecessary
0
