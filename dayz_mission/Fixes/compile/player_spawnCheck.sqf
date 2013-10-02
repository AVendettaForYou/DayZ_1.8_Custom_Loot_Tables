private ["_isAir","_inVehicle","_dateNow","_age","_position","_maxControlledZombies","_type","_nearby","_config","_dis","_checkLoot","_looted","_zombied","_doNothing","_totalcrew","_spawnZedRadius","_bPos","_zombiesNum","_canSpawn","_spawnableObjects","_speed","_maxlocalspawned","_isLand","_isSea"];

_age = -1;
//_nearbyBuildings = [];
_position = getPosATL player;
_spawnableObjects = ["building", "SpawnableWreck"];
//_force = false;
_speed = speed (vehicle player);
_radius = 200;
_spawnZedRadius = 30;

//Current amounts
// we start by the closest buildings. 
_nearby = nearestObjects [_position, _spawnableObjects,200];

//Total Counts
_maxlocalspawned = round(dayz_spawnZombies);
_maxControlledZombies = round(dayz_maxLocalZombies);
_maxWeaponHolders = round(dayz_maxMaxWeaponHolders);
_currentWeaponHolders = round(dayz_currentWeaponHolders);

//Limits (Land,Sea,Air)
_inVehicle = (vehicle player != player);
_isAir = vehicle player iskindof "Air";
_isLand =  vehicle player iskindof "Land";
_isSea =  vehicle player iskindof "Sea";
if (_isLand) then { } else {  };
if (_isAir) then { } else {  };
if (_isSea) then { } else {  };

_doNothing = false;
if (_inVehicle) then {
	//exit if too fast
	if (_speed > 25) exitwith {_doNothing = true;};
	
	//Crew can spawn zeds.
	_totalcrew = count (crew (vehicle player));
	if (_totalcrew > 1) then {
		_maxControlledZombies = _maxControlledZombies / 4; 
		
		//Dont allow driver to spawn if we have other crew members.
		if (player == driver (vehicle player)) exitwith {_doNothing = true;};
	} else {
		_maxControlledZombies = 6; 
	};
};

if (_doNothing) exitwith {lastSpawned = diag_tickTime;};


//Logging
diag_log (format["%1 Local.Agents: %2/%3, NearBy.Agents: %8/%9, Global.Agents: %6/%7, W.holders: %10/%11, (radius:%4m %5fps).","SpawnCheck",
	_maxlocalspawned, _maxControlledZombies, 200, round diag_fpsmin,dayz_currentGlobalZombies, 
	dayz_maxGlobalZeds, dayz_CurrentNearByZombies, dayz_maxNearByZombies, _currentWeaponHolders,_maxWeaponHolders
	]);
	
//Make only 1/5 spawn along player's journey.
_maxlocalspawned = _maxlocalspawned max floor(_maxControlledZombies*.8);

//
if (_maxlocalspawned > 0) then { _spawnZedRadius = _spawnZedRadius * 3; };

{
	_type = typeOf _x;
	_config = missionConfigfile >> "CfgBuildingLoot" >> _type;
	_canSpawn = isClass (_config);
	_dis = _x distance player;
	_checkLoot = ((count (getArray (_config >> "lootPos"))) > 0);
	//_islocal = _x getVariable ["", false]; // object created locally via TownGenerator. See stream_locationFill.sqf
	
	//Make sure wrecks always spawn Zeds
	//_isWreck = _x isKindOf "SpawnableWreck";
	//if (_isWreck) then { _force = true; };

	//Loot
	if (_canSpawn) then {
		if (_currentWeaponHolders < _maxWeaponHolders) then {
			//Baisc loot checks
			if ((_dis < 125) and (_dis > 30) and !_inVehicle and _checkLoot) then {
			
				//Get var Looted
				//[_object,name,defaultValue]
				PVDZ_receiveVar = [player,_x,"looted",-0.1];
				publicVariableServer "PVDZ_receiveVar";

				_looted = (_x getVariable "looted");
					if (isNil "_looted") then {
						_looted = -0.1;
					};
					
				_dateNow = (DateToNumber date);
				_age = (_dateNow - _looted) * 525948;
				//diag_log ("SPAWN LOOT: " + _type + " Building is " + str(_age) + " old" );
				if (_age < -0.1) then {
					//[object,varName]
					PVDZ_serverStoreVar = [_x,"looted",(DateToNumber date)];
					publicVariableServer "PVDZ_serverStoreVar";

					if (!(_x in dayz_buildingBubbleMonitor)) then {
						//add active zed to var
						dayz_buildingBubbleMonitor set [count dayz_buildingBubbleMonitor, _x];
					};
				} else {
					if (_age > 15) then {
					
						//[object,name]
						PVDZ_serverStoreVar = [_x,"looted",(DateToNumber date)];
						publicVariableServer "PVDZ_serverStoreVar";
						sleep 0.01;
						_x call building_spawnLoot;
						if (!(_x in dayz_buildingBubbleMonitor)) then {
							//add active Building to var
							dayz_buildingBubbleMonitor set [count dayz_buildingBubbleMonitor, _x];
						};
					};
				};
			};
		};
	
	//Zeds
		//if (((time - dayz_spawnWait) > dayz_spawnDelay) or (_force)) then {
		if (_dis > _spawnZedRadius) then {
			if ((dayz_spawnZombies < _maxControlledZombies) and (dayz_CurrentNearByZombies < dayz_maxNearByZombies) and (dayz_currentGlobalZombies < dayz_maxGlobalZeds)) then {
				//[_object,name,defaultValue]
				PVDZ_receiveVar = [player,_x,"zombieSpawn",-0.1];
				publicVariableServer "PVDZ_receiveVar";
				sleep 0.01;
				_zombied = (_x getVariable "zombieSpawn");
					if (isNil "_zombied") then {
						_zombied = -0.1;
					};
				_dateNow = (DateToNumber date);
				_age = (_dateNow - _zombied) * 525948; // in minutes
				//diag_log format ["%4 - %5: %1, %2, %3", _zombied, _dateNow, _age, "spawnCheck", _x]; 
				if (_age > 5) then {
					_bPos = getPosATL _x;
					_zombiesNum = {alive _x} count (_bPos nearEntities ["zZombie_Base",(((sizeOf _type) * 2) + 10)]);
					if (_zombiesNum == 0) then {
						//[object,name]
						PVDZ_serverStoreVar = [_x,"zombieSpawn",(DateToNumber date)];
						publicVariableServer "PVDZ_serverStoreVar";
						[_x] call building_spawnZombies;
						//waitUntil{scriptDone _handle};
						if (!(_x in dayz_buildingBubbleMonitor)) then {
							//add active zed to var
							dayz_buildingBubbleMonitor set [count dayz_buildingBubbleMonitor, _x];
						};
					};	
				};
				//diag_log (format["%1 building. %2", __FILE__, _x]);
			};
		};
	};
} forEach _nearby;

//Timer system to monitor if running.
lastSpawned = diag_tickTime;