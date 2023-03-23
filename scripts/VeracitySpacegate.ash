since r18997;

import <vprops.ash>;
import <SpacegateData.ash>
import <SpacegateExplorer.ash>

// ***************************
//       Specification       *
// ***************************

// Command format:
//
//   help				// print something like this
//
// prefix commands:
//   [suggest]				// (default) select a planet that meets remaining parameters
//   (visit)				// visit selected planet
//
// For both of the above, if there are no additional parameters use current configuration settings
//
// commands:
//   coordinates XXXXXXX		// Use specific coordinates
//   random [difficulty]		// Choose random coordinates
//   unvisited [difficulty]             // Choose random coordinates from publics planets you've not previously visited
//   validated [difficulty]             // Choose random coordinates from publics planets somebody has previously visited
//   [goal] A [, B]... [difficulty]	// (default) Choose a planet with goal A (and additional goals) and minimal other life forms
//
// optional difficulty:
//   (X)				// Difficulty level X only
//   (X-Y)				// Difficulty level betwen X and Y inclusive
//
// goals:
//   rocks				// (default) no lifeforms or ruins
//   rocks0                             // no known rocks
//   rocks1                             // only Space Cave
//   rocks2                             // only Cool Space Rocks
//   rocks3                             // only Space Cave and Cool Space Rocks
//   rocks4                             // only Wide Open Spaces
//   rocks5                             // only Space Cave and Wide Open Spaces
//   rocks6                             // only Cool Space Rocks and Wide Open Spaces
//   rocks7                             // Space Cave and Cool Space Rocks and Wide Open Spaces
//   plants				// hostile anomalous plants
//   animals				// hostile anomalous animals
//   [type] plants			// hostile plants [primitive (simple), advanced (complex), anomalous (exotic)]
//   [type] animals			// hostile animals [primitive (simple), advanced (complex), anomalous (exotic)]
//   trade [buy] [item]			// friendly aliens [salad, booze, medicine, mask]
//   trophy [item]			// hostile aliens [blowgun, loincloth, necklace, spear, totem]
//   murderbots [type]			// murderbot [artifact, drones, soldiers]
//   spants [type]			// spant [artifact, drones, soldiers]
//   ruins				// Any ruins
//   detected [type]			// Detected but unidentified [trade, trophy, murderbots, spants, ruins]
//   procrastinator [step]		// Procrastinator quest [1, 2, 3]
//   space baby [step]			// Space Baby quest [1, 2, 3]
//   space pirate [step]		// Space Pirate quest [1, 2, 3]
//
// For plants and animals, [type] is optional. If omitted, it will look for anomalous wildlife
// For spants and murderbots, [type] is optional. If omitted, will choose a planet with that lifeform "detected" but type not known.
// For aliens, [item] is optional. If omitted, will choose a plent with aliens "detected", but item not known
// For alien races, [step] is optional. If omitted, will detect where you are in that quest and do the appropriate step.
//
// Settings to control the above
//
//   VSG.Coordinates			// If valid coordinates, that specific planet.
//					// If RANDOM, a random planet within configured difficulty range
//					// If KNOWN, a random known planet within configured goals and difficulty range
//					// If UNVISITED, a random unvisited planet within configured goals and difficulty range
//					// If VALIDATED, a random previously visited planet within configured goals and difficulty range
//					// Default is unset
//   VSG.Goals				// Set of goals. Default to "rocks"
//   VSG.BuyTradeItem			// Default is false. If true, selects cheapest offer
//   VSG.BoozeMaximumPrice		// Default is 1000000. Set to 0 to never buy this item
//   VSG.MaskMaximumPrice		// Default is 1000000. Set to 0 to never buy this item
//   VSG.MedicineMaximumPrice		// Default is 1000000. Set to 0 to never buy this item
//   VSG.SaladMaximumPrice		// Default is 1000000. Set to 0 to never buy this item
//   VSG.MinimumDifficulty		// (A) Easiest planet to visit
//   VSG.MaximumDifficulty		// (Z) Hardest planet to visit
//
//   VSG.Strategy			// "research" (collect research) or "turns" (walk away from NCs when possible)
//   VSG.MinimumProcrastinatorLanguage	// (60) Minimum language fluency to try for step 2
//   VSG.MinimumSpaceBabyLanguage	// (50) Minimum language fluency to try for step 2
//   VSG.MinimumSpacePirateLanguage	// (40) Minimum language fluency to try for step 2
//
// Additional settings to control actual adventuring
//
//   VSG.SampleKit			// none, geological sample kit (default), votanical sample kit, zoological sample kit
//   VSG.ExtraMaximizerParameters	// anything you want. Avoid equipment that precludes required hazard mitigation
//   VSG.TurnInResearch			// Turn in research at end. Default is true
//   VSG.AlienGemstoneHandling		// Special handling for alien gemstones. none (default), closet, mallsell

// ***************************
//          To Do            *
// ***************************

// Using a portable Spacegate gives you a portable spacegate (open)
// which lets you go Through the Spacegate.  It does not give access to
// the Secret Underground Spacegate Facility. Therefore, you cannot look
// at the terminal to see the coordinates or attributes of the planet
// you are visiting and you cannot turn in items to get SpaceGate
// research. This seems pointless to try to support in this script.

// ***************************
//        Requirements       *
// ***************************

// Permanent access to the Spacegate
// (the portable Spacegate does not let you select a planet to visit)
//
// CCS configured
// HP & MP restoration configured
// Mood configured

// ***************************
//          Utilities        *
// ***************************

typedef string goal;
typedef boolean [string] goal_set;

static item SPACEGATE_RESEARCH = $item[ Spacegate Research ];

typedef int [item] item_count_map;

item_count_map to_item_count_map( string input )
{
    item_count_map retval;
    item_list items = input.to_item_list();
    foreach i, it in items {
	retval[ it ] ++;
    }
    return retval;
}

string to_string( item_count_map input )
{
    buffer retval;
    foreach it, n in input {
	for ( int i = 0; i < n; i++ ) {
	    if ( retval.length() > 0 ) {
		retval.append( "|" );
	    }
	    retval.append( it.to_string() );
	}
    }
    return retval.to_string();
}

string trim( string input )
{
    matcher m = create_matcher( "^ *(.*?) *$", input );
    return m.find() ? m.group(1) : input;
}

// Properties we use
static string COUNTER_PROPERTY = "dontStopForCounters";
static string SPACEGATE_ENCOUNTERS_PROPERTY = "_SpacegateEncounters";
static string SPACEGATE_RESEARCH_PROPERTY = "_SpacegateResearch";
static string SPACEGATE_SHINIES_PROPERTY = "_SpacegateShinies";

// ***************************
//       Configuration       *
// ***************************

//-------------------------------------------------------------------------
// All of the configuration variables have default values, which apply
// to any character who does not override the variable using the
// appropriate property.
//
// You can edit the default here in the script and it will apply to all
// characters which do not override it.
//
// define_property( PROPERTY, TYPE, DEFAULT )
// define_property( PROPERTY, TYPE, DEFAULT, COLLECTION )
// define_property( PROPERTY, TYPE, DEFAULT, COLLECTION, DELIMITER )
//
// Otherwise, you can change the value for specific characters in the gCLI:
//
//     set PROPERTY=VALUE
//
// Both DEFAULT and a property VALUE will be normalized
//
// All properties used directly by this script start with "VSG."
//-------------------------------------------------------------------------

// If you have a specific planet in mind, you can specify it here.
//
// You can also use "RANDOM" (not a valid coordinate, since it is six
// letters) to choose random coordinates for a planet to visit. Yu can
// specify the deisred difficulty range
//
// All the fancy code to pick an appropriate planet besed on goals and
// quest will be ignored.
//
// You can also use "KNOWN" (not a valid coordinate, since it is five
// letters) to choose a random known planet to visit. Goals and
// difficulty level can be specified
//
// You can also use "UNVISITED" (not a valid coordinate, since it is
// nine letters) to choose a random known but previously unvisited
// planet to visit. Goals and difficulty level can be specified
//
// You can also use "VALIDATED" (not a valid coordinate, since it is
// nine letters) to choose a random known but previously unvisited
// planet to visit. Goals and difficulty level can be specified
//
// The script will equip the necessary equipment and record every
// encounter. At the end, it will print a report and save the code

string coordinates = define_property( "VSG.Coordinates", "string", "" );

// You can specify up to six goals. "rocks" is always a goal; we will
// try to find a planet which has exactly the goals you ask for and no
// other "life" encounters - which will leave you only rocks.
//
// If you specify a single goal which is "rocks", we will find a planet which is all rocks.
//
//   rocks				nothing but rocks
//   rocks0                             no known rocks
//   rocks1                             only Space Cave
//   rocks2                             only Cool Space Rocks
//   rocks3                             only Space Cave and Cool Space Rocks
//   rocks4                             only Wide Open Spaces
//   rocks5                             only Space Cave and Wide Open Spaces
//   rocks6                             only Cool Space Rocks and Wide Open Spaces
//   rocks7                             all types of rocks: Space Cave and Cool Space Rocks and Wide Open Spaces
//   plants				hostile anomalous plants
//   animals				hostile anomalous animals
//   primitive (or simple)
//     primitive plants		        hostile primitive plants
//     primitive animals		hostile primitive animals
//   advanced (or complex)
//     advanced plants		        hostile advanced plants
//     advanced animals			hostile advanced animals
//   anomalous (or exotic)
//     anomalous plants		        hostile anomalous plants
//     anomalous animals		hostile anomalous animals
//   aliens				Any unidentified alien
//     trade				Any unidentified friendly alien
//       trade booze			Friendly alien with primitive alien booze
//       trade mask			Friendly alien with primitive alien mask
//       trade medicine			Friendly alien with primitive alien medicine
//       trade salad			Friendly alien with primitive alien salad
//     trophy				Any unidentified hostile alien
//       trophy blowgun			Hostile alien with primitive alien blowgun
//       trophy loincloth		Hostile alien with primitive alien loincloth
//       trophy necklace		Hostile alien with primitive alien necklace
//       trophy spear			Hostile alien with primitive alien spear
//       trophy totem			Hostile alien with primitive alien totem
//   murderbots				any detected but unidentified murderbot planet
//     murderbot artifacts		Murderbot data cores
//     murderbot drones			Murderbot Drones
//     murderbot soldiers		Murderbot Drones and Soldiers
//   spants				any detected but unidentified spant planet
//     spant artifacts			Spant egg casings
//     spant drones			Spant Drones
//     spant soldiers			Spant Drones and Soldiers
//   ruins				Any unidentified ruins
//     procrastinator			The next step on the Procrastinator quest
//       procrastinator 1		That's No Moonlith, it's a Monolith!
//       procrastinator 2		I'm Afraid It's Terminal
//       procrastinator 3		Curses, a Hex
//     space baby			The next step on the Space Baby quest
//       space baby 1			Time Enough at Last
//       space baby 2			Mother May I
//       space baby 3			Please Baby Baby Please
//     space pirate			The next step on the Space Pirate quest
//       space pirate 1			Land Ho
//       space pirate 2			Half The Ship it Used to Be
//       space pirate 3			Paradise Under a Strange Sun
//   detected
//     trade				Friendly aliens detected with unknown item
//     trophy				Hostile aliens detected with unknown item
//     murderbots			Murderbots detected
//     spants				Spants detected
//     ruins				Ruins detected
//
// You can have up to one each of (plants, animals, aliens, murderbots, spants, ruins)
// You always get rocks. If you have ONLY rocks, you want nothing but rocks
//
// The goals are not ordered; with the exception of friendly aliens and
// ruins - for which you get exactly one encounter if they are present
// on the planet at all - planets with two or more kinds of life do not
// have "more" or "less" of particular types, modulo random variation.

goal_set desired_goals = define_property( "VSG.Goals", "string", "", "set" ).to_string_set();

// If you encounter friendly aliens attempting to sell you something, you can buy it or not.

boolean buy_trade_item = define_property( "VSG.BuyTradeItem", "boolean", "false" ).to_boolean();

// You can limit how much you are willing to pay for each trade item.
// If zero, do not buy this item.

int booze_max_price = define_property( "VSG.BoozeMaximumPrice", "int", "1000000" ).to_int();
int mask_max_price = define_property( "VSG.MaskMaximumPrice", "int", "1000000" ).to_int();
int medicine_max_price = define_property( "VSG.MedicineMaximumPrice", "int", "1000000" ).to_int();
int salad_max_price = define_property( "VSG.SaladMaximumPrice", "int", "1000000" ).to_int();

// If we generate a random planet - or select from a list of candidate
// planets which satisy your goals - you can specify the difficulty
// range you are willing to consider

string minimum_difficulty = define_property( "VSG.MinimumDifficulty", "string", "A" );
string maximum_difficulty = define_property( "VSG.MinimumDifficulty", "string", "Z" );

// When we are automating the Procrastinator, Space Baby, or Space
// Pirate quest, there is a language test which you pass or not based on
// your language fluency in the appropriate language. You will always
// fail with 0% fluency and will always succeed with 100% fluency. It is
// probably optimal to try the test at some intermediate level; you will
// either succeed, or will have to try again.
//
// You can specify the level of language proficiency you are comfortable
// with for each quest.

int minimum_procrastinator_language = define_property( "VSG.MinimumProcrastinatorLanguage", "int", "60" ).to_int();
int minimum_space_baby_language = define_property( "VSG.MinimumSpaceBabyLanguage", "int", "50" ).to_int();
int minimum_space_pirate_language = define_property( "VSG.MinimumSpacePirateLanguage", "int", "40" ).to_int();

// Which strategy to use when selecting planets and dealing with choice adventures
//
//   research				collect research (maximize turns spent)
//   turns				walk away from research (minimize turns spent)

string strategy = define_property( "VSG.Strategy", "string", "research" );

// Which sample kit to equip; improves amount of research gained
//
//   none				don't bother; prefer a different off-hand item
//   geological sample kit		drill out core samples with chance of alien gemstone
//   botanical sample kit		collect DNA from alien plants
//   zoological sample kit		collect DNA from alien animals

item desired_sample_kit = define_property( "VSG.SampleKit", "item", "geological sample kit" ).to_item();

// Additional maximizer parameters

string extra_maximizer_parameters = define_property( "VSG.ExtraMaximizerParameters", "string", "" );

// Whether or not to turn in research at the end of the session.
// 
// The following are not quest items but are not tradeable. Collect away, if you wish.
//
//   alien rock sample			 3 pages
//   alien plant fibers			 1 pages
//   alien plant sample			 3 pages
//   complex alien plant sample		 10 pages
//   fascinating alien plant sample	 20 pages
//   alien toenails			 1 pages
//   alien zoological sample		 3 pages
//   complex alien zoological sample	 10 pages
//   fascinating alien zoological sample 20 pages
//   spant egg casing			 25 pages
//   murderbot memory chip		 15 pages
//
// The following are tradeable, so you can put them in the mall if you wish
// In fact, you can closet or mallsell them even if you are turning in research
//
//   alien gemstone			 100 pages

boolean turn_in_research = define_property( "VSG.TurnInResearch", "boolean", "true" ).to_boolean();

// "none", "closet", or "mallsell"

string alien_gemstone_handling = define_property( "VSG.AlienGemstoneHandling", "string", "none" );

// If not empty, a script called before actually running turns

string setup_script = define_property( "VSG.SetupScript", "string", "" );

// ***************************
//      Command Parsing      *
// ***************************

typedef string mode;

mode SUGGEST = "suggest";
mode VISIT = "visit";
mode STATUS = "status";
mode COUNT = "count";
mode LIST = "list";

mode current_mode = SUGGEST;	// Default

boolean parse_command( string command )
{
    void print_help()
    {
	print( "Available commands:" );
	print();
	print( "help - print this message" );
	print();
	print( "suggest [parameters] - select a planet to visit" );
	print( "visit [parameters] - select a planet to vist and go there" );
	print();
	print( "If you do not specify parameters, the script will use current settings to control selection" );
	print();
	print( "Available parameters:" );
	print();
	print( "coordinates XXXXXXX - go to the coordinates you specified" );
	print( "random [difficulty] - go to a random planet, as restrained by the difficulty you chose" );
	print( "unvisited [goals] [difficulty] - go to a random previously unvisited planet, as restrained by the goals and difficulty you chose" );
	print( "validated [goals] [difficulty] - go to a random previously visited planet, as restrained by the goals and difficulty you chose" );
	print( "known [goals] [difficulty] - go to a random known planet, as restrained by the goals and difficulty you chose" );
	print( "goal A [, B]... [difficulty] - go to the hardest known planet that satisfies all the goals you selected" );
	print();
	print( "Difficulty is always optional; if not selected, script settings will determine it. It defauls to (A-Z)" );
	print();
	print( "(X) - difficulty is exactly X" );
	print( "(X-Y) - difficulty is between X and Y, inclusive" );
	print();
	print( "Available goals:" );
	print();
	print( "rocks - If this is the only goal, will find a planet with all rocks." );
	print( "rocks{0-7} - 0-7 to specifies types of rocks desired." );
	print( "plants - Hostile anomalous plants." );
	print( "animals - Hostile anomalousanimals." );
	print( "TYPE plants - Hostile plants: primitive (or simple), advanced (or complex), anomalous (or exotic)." );
	print( "TYPE animals - Hostile animals: primitive (or simple), advanced (or complex), anomalous (or exotic)." );
	print( "trade [buy] [ITEM] - friendly aliens selling the (optiona) item. Will find cheapest, if you want to 'buy'" );
	print( "(ITEM is one of salad, booze, medicine, mask)" );
	print( "trophy [ITEM] - hostile aliens wielding the (optional) equipment" );
	print( "(ITEM is one of blowgun, loincloth, necklace, spear, totem)" );
	print( "murderbots [TYPE] - Murderbots (optionally) with artifact, drones, or soldiers" );
	print( "spants [TYPE] - Spants (optionally) with artifact, drones, or soldiers" );
	print( "ruins - any ruins" );
	print( "detected [TYPE] - Detected but unidentified (trade, murderbots, spants, ruins" );
	print( "procrastinator [STEP] - the next (or specified: 1, 2, or 3) step in the Procrastinator quest" );
	print( "space baby [STEP] - the next (or specified: 1, 2, or 3) step in the Space Baby quest" );
	print( "space pirate [STEP] - the next (or specified: 1, 2, or 3) step in the Space Pirate quest" );
	print();
	print( "For spants and murderbots, [TYPE] is optional. If omitted, chooses any planet with specified army'." );
	print( "For aliens, [ITEM] is optional. If omitted, chooses any planet with friendly aliens" );
	print();
	print( "Available script settings:" );
	print();
	print( "VSG.Coordinates - coordinates or RANDOM or KNOWN or UNVISITED or VALIDATED" );
	print( "VSG.Goals - set of goals. Default is 'rocks'" );
	print( "VSG.BuyTradeItem - true or false" );
	print( "VSG.BoozeMaximumPrice - Maximum price to spend for primitive alien booze. Default is 1000000. 0 to not buy" );
	print( "VSG.MaskMaximumPrice - Maximum price to spend for primitive alien mask. Default is 1000000. 0 to not buy" );
	print( "VSG.MedicineMaximumPrice - Maximum price to spend for primitive alien medicine. Default is 1000000. 0 to not buy" );
	print( "VSG.SaladMaximumPrice - Maximum price to spend for primitive alien salad. Default is 1000000. 0 to not buy" );
	print( "VSG.MinimumDifficulty - Easiest planet to visit. Default is A" );
	print( "VSG.MaximumDifficulty - Hardest planet to visit. Default is Z" );
	print( "VSG.MinimumProcrastinatorLanguage - Minimum language fluency to try for step 2. Default is 60" );
	print( "VSG.MinimumSpaceBabyLanguage -  Minimum language fluency to try for step 2. Default is 50" );
	print( "VSG.MinimumSpacePirateLanguage - Minimum language fluency to try for step 2. Default is 40" );
	print( "VSG.Strategy - 'research' (default) (at expense of turns) or 'turns' (at expense of research)" );
	print( "VSG.SampleKit - none, geological sample kit (default), botanical sample kit, zoological sample kit" );
	print( "VSG.ExtraMaximizerParameters - anything you want. Be careful not to preclude required hazard mitigation gear!" );
	print( "VSG.TurnInResearch - turn in research at end. Default is true" );
	print( "VSG.AlienGemstoneHandling - special handling for alien gemstones. none (default), closet, mallsell" );
    }

    command = command.trim();

    if ( command == "help" ) {
	print_help();
	return false;
    }

    if ( command == "status" ) {
	current_mode = STATUS;
	return true;
    }

    string next_token()
    {
	int space_index = command.index_of( " " );
	string token;
	if ( space_index != -1 ) {
	    token = command.substring( 0, space_index);
	    command = command.substring( space_index ).trim();
	} else {
	    token = command;
	    command = "";
	}
	return token;
    }

    boolean parse_difficulty()
    {
	string token = next_token();
	if ( token == "" ) {
	    return true;
	}
	matcher m = create_matcher( "^\\(([\\w])(-)?([\\w])?\\)$", token );
	if ( !m.find() ) {
	    command = token + " " + command;
	    print( "cruft at end of command: '" + command + "'" );
	    return false;
	}
	string minimum = m.group(1).to_upper_case();
	string maximum = m.group(3).to_upper_case();
	minimum_difficulty = minimum;
	maximum_difficulty = ( maximum == "" ) ? minimum : maximum;
	return true;
    }

    goal_set goals;
    boolean parse_goal()
    {
	boolean more = false;

	string check_more()
	{
	    string token = next_token();
	    if ( token.ends_with( "," ) ) {
		more = true;
		return  token.substring( 0, token.length() - 1 );
	    }
	    return token;
	}

	boolean is_difficulty( string next )
	{
	    return next.starts_with( "(" ) && next.ends_with( ")" );
	}

	string token = check_more();

	switch ( token ) {
	case "rocks" :
	case "rocks0" :
	case "rocks1" :
	case "rocks2" :
	case "rocks3" :
	case "rocks4" :
	case "rocks5" :
	case "rocks6" :
	case "rocks7" :
	case "ruins":
	    goals[ token ] = true;
	    break;
	case "plants":
	case "animals": {
	    goals[ "anomalous " + token ] = true;
	    break;
	}
	case "simple":
	case "primitive":
	case "complex":
	case "advanced":
	case "exotic":
	case "anomalous": {
	    if ( more ) {
		print( "Unknown goal: " + token );
		return false;
	    }
	    string type = token;
	    switch ( type ) {
	    case "simple":
		type = "primitive";
		break;
	    case "complex":
		type = "advanced";
		break;
	    case "exotic":
		type = "anomalous";
		break;
	    }
	    string next = check_more();
	    switch ( next ) {
	    case "animal":
	    case "animals":
	    case "plant":
	    case "plants": {
		if ( !next.ends_with( "s" ) ) {
		    next += "s";
		}
		break;
	    }
	    default:
		print( "Unknown goal: " + token + " " + next );
		return false;
	    }
	    goals[ type + " " + next ] = true;
	    break;
	}
	case "trade": {
	    // [buy] [item]
	    // (item is one of salad, booze, medicine, mask)
	    if ( more ) {
		goals[ token ] = true;
		break;
	    }
	    string next = check_more();
	    if ( next == "buy" ) {
		buy_trade_item = true;
		if ( more ) {
		    goals[ token ] = true;
		    break;
		}
		next = check_more();
	    }
	    switch( next ) {
	    default:
		if ( !next.is_difficulty() ) {
		    token += " " + next;
		    print( "Unknown goal: " + token );
		    return false;
		}
		command = next + " " + command;
		// Fall through
	    case "":
		goals[ token ] = true;
		break;
	    case "booze":
	    case "salad":
	    case "medicine":
	    case "mask":
		goals[ token + " " + next ] = true;
		break;
	    }
	    break;
	}
	case "trophy": {
	    if ( more ) {
		goals[ token ] = true;
		break;
	    }
	    string next = check_more();
	    switch( next ) {
	    default:
		if ( !next.is_difficulty() ) {
		    token += " " + next;
		    print( "Unknown goal: " + token );
		    return false;
		}
		command = next + " " + command;
		// Fall through
	    case "":
		goals[ token ] = true;
		break;
	    case "blowgun":
	    case "loincloth":
	    case "necklace":
	    case "spear":
	    case "totem":
		goals[ token + " " + next ] = true;
		break;
	    }
	    break;
	}
	case "murderbot":
	case "spant":
	    // The above are the expected form when there is a [type]
	case "murderbots":
	case "spants": {
	    if ( more ) {
		if ( !token.ends_with( "s" ) ) {
		    token += "s";
		}
		goals[ token ] = true;
		break;
	    }
	    string next = check_more();
	    switch( next ) {
	    default:
		if ( !next.is_difficulty() ) {
		    token += " " + next;
		    print( "Unknown goal: " + token );
		    return false;
		}
		command = next + " " + command;
		// Fall through
	    case "":
		if ( !token.ends_with( "s" ) ) {
		    token += "s";
		}
		goals[ token ] = true;
		break;
	    case "artifact":
	    case "drone":
	    case "soldier":
	    case "artifacts":
	    case "drones":
	    case "soldiers":
		if ( !next.ends_with( "s" ) ) {
		    next += "s";
		}
		if ( token.ends_with( "s" ) ) {
		    token = token.substring( 0, token.length() - 1 );
		}
		goals[ token + " " + next ] = true;
		break;
	    }
	    break;
	}
	case "detected": {
	    if ( more ) {
		print( "Unknown goal: " + token );
		return false;
	    }
	    string next = check_more();
	    token += " " + next;
	    switch( token ) {
	    case "detected trade":
	    case "detected trophy":
	    case "detected murderbots":
	    case "detected spants":
	    case "detected ruins":
		break;
	    default:
		print( "Unknown goal: " + token );
		return false;
	    }
	    goals[ token ] = true;
	}
	case "procrastinator": {
	    if ( more ) {
		goals[ token ] = true;
		break;
	    }
	    string next = check_more();
	    switch( next ) {
	    default:
		if ( !next.is_difficulty() ) {
		    token += " " + next;
		    print( "Unknown goal: " + token );
		    return false;
		}
		command = next + " " + command;
		// Fall through
	    case "":
		goals[ token ] = true;
		break;
	    case "1":
	    case "2":
	    case "3":
		goals[ token + " " + next ] = true;
		break;
	    }
	    break;
	}
	case "space": {
	    if ( more ) {
		print( "Unknown goal: " + token );
		return false;
	    }
	    string next = check_more();
	    token += " " + next;
	    switch( token ) {
	    case "space baby":
	    case "space pirate":
		break;
	    default:
		print( "Unknown goal: " + token );
		return false;
	    }
	    if ( more ) {
		goals[ token ] = true;
		break;
	    }
	    next = check_more();
	    switch( next ) {
	    default:
		if ( !next.is_difficulty() ) {
		    token += " " + next;
		    print( "Unknown goal: " + token );
		    return false;
		}
		command = next + " " + command;
		// Fall through
	    case "":
		goals[ token ] = true;
		break;
	    case "1":
	    case "2":
	    case "3":
		goals[ token + " " + next ] = true;
		break;
	    }
	    break;
	}
	default:
	    print( "Unknown goal: " + token );
	    return false;
	}

	// If there are more goals, set up to parse them
	if ( more ) {
	    return true;
	}

	// Otherwise, look for optional difficulty
	return parse_difficulty();
    }

    boolean parse_goals()
    {
	while ( command != "" ) {
	    // If command cannot be parsed as a goal, syntax error
	    if ( !parse_goal() ) {
		return false;
	    }
	    // goal has been added to goals
	}

	// If we found any goals, use them
	if ( goals.count() > 0 ) {
	    desired_goals = goals;
	}

	return true;
    }

    // Check for mode: SUGGEST, VISIT, COUNT, LIST
    if ( command != "" ) {
	string token = next_token();
	switch ( token ) {
	case "suggest": {
	    current_mode = SUGGEST;
	    break;
	}
	case "visit": {
	    current_mode = VISIT;
	    break;
	}
	case "count": {
	    current_mode = COUNT;
	    break;
	}
	case "list": {
	    current_mode = LIST;
	    break;
	}
	default: {
	    command = token + " " + command;
	    break;
	}
	}
    }

    // Parse valid top-level commands:
    //    coordinates, random, known, unvisited, validated, goal, [goals]
    if ( command != "" ) {
	string token = next_token();
	switch ( token ) {
	case "coordinates": {
	    string c = next_token();
	    if ( c == "" ) {
		print( "What coordinates?" );
		return false;
	    }
	    coordinates = c.to_upper_case();
	    if ( command != "" ) {
		print( "ignoring cruft at end of command: '" + command + "'" );
	    }
	    return true;
	}
	case "random": {
	    if ( !parse_difficulty() ) {
		return false;
	    }
	    coordinates = "RANDOM";
	    if ( command != "" ) {
		print( "ignoring cruft at end of command: '" + command + "'" );
	    }
	    return true;
	}
	case "known": {
	    if ( !parse_goals() ) {
		return false;
	    }
	    coordinates = "KNOWN";
	    if ( command != "" ) {
		print( "ignoring cruft at end of command: '" + command + "'" );
	    }
	    return true;
	}
	case "unvisited": {
	    if ( !parse_goals() ) {
		return false;
	    }
	    coordinates = "UNVISITED";
	    if ( command != "" ) {
		print( "ignoring cruft at end of command: '" + command + "'" );
	    }
	    return true;
	}
	case "validated": {
	    if ( !parse_goals() ) {
		return false;
	    }
	    coordinates = "VALIDATED";
	    if ( command != "" ) {
		print( "ignoring cruft at end of command: '" + command + "'" );
	    }
	    return true;
	}
	default:
	    // Perhaps it is a goal.
	    command = token + " " + command;
	    // Fall through and parse as a goal
	case "goal":
	case "goals": {
	    if ( !parse_goals() ) {
		return false;
	    }
	    if ( command != "" ) {
		print( "ignoring cruft at end of command: '" + command + "'" );
	    }
	    return true;
	}
	}
    }

    // Shouldn't be able to get here
    return true;
}

// ***************************
//        Validation         *
// ***************************

static goal NO_GOAL = "none";					// Pseudo Goal

static goal GOAL_ROCKS = "rocks";				// Solo primary goal to maximize "research"
static goal GOAL_ROCKS0 = "rocks0";				// No known rocks
static goal GOAL_ROCKS1 = "rocks1";				// Space Cave
static goal GOAL_ROCKS2 = "rocks2";				// Cool Space Rocks
static goal GOAL_ROCKS3 = "rocks3";				// Space Cave, Cool Space Rocks
static goal GOAL_ROCKS4 = "rocks4";				// Wide Open Spaces
static goal GOAL_ROCKS5 = "rocks5";				// Space Cave, Wide Open Spaces
static goal GOAL_ROCKS6 = "rocks6";				// Cool Space Rocks, Wide Open Spaces
static goal GOAL_ROCKS7 = "rocks7";				// Space Cave, Cool Space Rocks, Wide Open Spaces
static goal GOAL_PRIMITIVE_PLANTS = "primitive plants";		// hostile plants
static goal GOAL_ADVANCED_PLANTS = "advanced plants";		// large hostile plants
static goal GOAL_ANOMALOUS_PLANTS = "anomalous plants";		// exotic hostile plants
static goal GOAL_PRIMITIVE_ANIMALS = "primitive animals";	// small hostile animals
static goal GOAL_ADVANCED_ANIMALS = "advanced animals";		// large hostile animals
static goal GOAL_ANOMALOUS_ANIMALS = "anomalous animals";	// exotic hostile animals
static goal GOAL_ALIENS = "aliens";				// Intelligent Life
static goal GOAL_TRADE = "trade";				// Intelligent Life
static goal GOAL_BOOZE = "trade booze";				// friendly alien with primitive alien booze
static goal GOAL_MASK = "trade mask";				// friendly alien with primitive alien mask
static goal GOAL_MEDICINE = "trade medicine";			// friendly alien with primitive alien medicine
static goal GOAL_SALAD = "trade salad";				// friendly alien with primitive alien salad
static goal GOAL_TROPHY = "trophy";				// Intelligent Life
static goal GOAL_BLOWGUN = "trophy blowgun";			// hostile alien with primitive alien blowgun
static goal GOAL_LOINCLOTH = "trophy loincloth";		// hostile alien with primitive alien loincloth
static goal GOAL_NECKLACE = "trophy necklace";			// hostile alien with primitive alien necklace
static goal GOAL_SPEAR = "trophy spear";			// hostile alien with primitive alien spear
static goal GOAL_TOTEM = "trophy totem";			// hostile alien with primitive alien totem
static goal GOAL_MURDERBOTS = "murderbots";			// Murderbot Drones or Soldiers
static goal GOAL_DATA_CORES = "murderbot artifacts";		// Recovering the Satellite
static goal GOAL_MURDERBOT_DRONES = "murderbot drones";		// Murderbot Drones
static goal GOAL_MURDERBOT_SOLDIERS = "murderbot soldiers";	// Murderbot Drones and Soldiers
static goal GOAL_SPANTS = "spants";				// Spant Drones or Soldiers
static goal GOAL_EGG_CASINGS = "spant artifacts";		// Here There be no Spants
static goal GOAL_SPANT_DRONES = "spant drones";			// Spant Drones
static goal GOAL_SPANT_SOLDIERS = "spant soldiers";		// Spant Drones and Soldiers
static goal GOAL_RUINS = "ruins";				// Ancient Ruins
static goal GOAL_DETECTED_TRADE = "detected trade";		// Friendly aliens
static goal GOAL_DETECTED_TROPHY = "detected trophy";		// Hostile aliens
static goal GOAL_DETECTED_MURDERBOTS = "detected murderbots";	// Murderbots
static goal GOAL_DETECTED_SPANTS = "detected spants";		// Spants
static goal GOAL_DETECTED_RUINS = "detected ruins";		// Ancient Ruins
static goal GOAL_PROCRASTINATOR = "procrastinator";		// Quest: whatever next step is, based of settings and inventory
static goal GOAL_PROCRASTINATOR_1 = "procrastinator 1";		// That's No Moonlith, it's a Monolith!
static goal GOAL_PROCRASTINATOR_2 = "procrastinator 2";		// I'm Afraid It's Terminal
static goal GOAL_PROCRASTINATOR_3 = "procrastinator 3";		// Curses, a Hex
static goal GOAL_SPACE_BABY = "space baby";			// Quest: whatever next step is, based of settings and inventory
static goal GOAL_SPACE_BABY_1 = "space baby 1";			// Time Enough at Last
static goal GOAL_SPACE_BABY_2 = "space baby 2";			// Mother May I
static goal GOAL_SPACE_BABY_3 = "space baby 3";			// Please Baby Baby Please
static goal GOAL_SPACE_PIRATE = "space pirate";			// Quest: whatever next step is, based of settings and inventory
static goal GOAL_SPACE_PIRATE_1 = "space pirate 1";		// Land Ho!
static goal GOAL_SPACE_PIRATE_2 = "space pirate 2";		// Half The Ship it Used to Be
static goal GOAL_SPACE_PIRATE_3 = "space pirate 3";		// Paradise Under a Strange Sun

// These are the goals that the user can set via command line or settings
static goal_set all_goals = {
    GOAL_ROCKS : true,
    GOAL_ROCKS0 : true,
    GOAL_ROCKS1 : true,
    GOAL_ROCKS2 : true,
    GOAL_ROCKS3 : true,
    GOAL_ROCKS4 : true,
    GOAL_ROCKS5 : true,
    GOAL_ROCKS6 : true,
    GOAL_ROCKS7 : true,
    GOAL_PRIMITIVE_PLANTS : true,
    GOAL_ADVANCED_PLANTS : true,
    GOAL_ANOMALOUS_PLANTS : true,
    GOAL_PRIMITIVE_ANIMALS : true,
    GOAL_ADVANCED_ANIMALS : true,
    GOAL_ANOMALOUS_ANIMALS : true,
    GOAL_ALIENS : true,
    GOAL_TRADE : true,
    GOAL_BOOZE : true,
    GOAL_MASK : true,
    GOAL_MEDICINE : true,
    GOAL_SALAD : true,
    GOAL_TROPHY : true,
    GOAL_BLOWGUN : true,
    GOAL_LOINCLOTH : true,
    GOAL_NECKLACE : true,
    GOAL_SPEAR : true,
    GOAL_TOTEM : true,
    GOAL_MURDERBOTS : true,
    GOAL_DATA_CORES : true,
    GOAL_MURDERBOT_DRONES : true,
    GOAL_MURDERBOT_SOLDIERS : true,
    GOAL_SPANTS : true,
    GOAL_EGG_CASINGS : true,
    GOAL_SPANT_DRONES : true,
    GOAL_SPANT_SOLDIERS : true,
    GOAL_RUINS : true,
    GOAL_DETECTED_TRADE : true,
    GOAL_DETECTED_TROPHY : true,
    GOAL_DETECTED_MURDERBOTS : true,
    GOAL_DETECTED_SPANTS : true,
    GOAL_DETECTED_RUINS : true,
    GOAL_PROCRASTINATOR : true,
    GOAL_PROCRASTINATOR_1 : true,
    GOAL_PROCRASTINATOR_2 : true,
    GOAL_PROCRASTINATOR_3 : true,
    GOAL_SPACE_BABY : true,
    GOAL_SPACE_BABY_1 : true,
    GOAL_SPACE_BABY_2 : true,
    GOAL_SPACE_BABY_3 : true,
    GOAL_SPACE_PIRATE : true,
    GOAL_SPACE_PIRATE_1 : true,
    GOAL_SPACE_PIRATE_2 : true,
    GOAL_SPACE_PIRATE_3 : true,
};

static goal_set plant_goals = {
    GOAL_PRIMITIVE_PLANTS : true,
    GOAL_ADVANCED_PLANTS : true,
    GOAL_ANOMALOUS_PLANTS : true,
};

static goal_set animal_goals = {
    GOAL_PRIMITIVE_ANIMALS : true,
    GOAL_ADVANCED_ANIMALS : true,
    GOAL_ANOMALOUS_ANIMALS : true,
};

static goal_set alien_goals = {
    GOAL_ALIENS : true,
    GOAL_DETECTED_TRADE : true,
    GOAL_DETECTED_TROPHY : true,
    GOAL_TRADE : true,
    GOAL_BOOZE : true,
    GOAL_MASK : true,
    GOAL_MEDICINE : true,
    GOAL_SALAD : true,
    GOAL_TROPHY : true,
    GOAL_BLOWGUN : true,
    GOAL_LOINCLOTH : true,
    GOAL_NECKLACE : true,
    GOAL_SPEAR : true,
    GOAL_TOTEM : true,
};

static goal_set friendly_alien_goals = {
    GOAL_DETECTED_TRADE : true,
    GOAL_TRADE : true,
    GOAL_BOOZE : true,
    GOAL_MASK : true,
    GOAL_MEDICINE : true,
    GOAL_SALAD : true,
};

static goal_set hostile_alien_goals = {
    GOAL_DETECTED_TROPHY : true,
    GOAL_TROPHY : true,
    GOAL_BLOWGUN : true,
    GOAL_LOINCLOTH : true,
    GOAL_NECKLACE : true,
    GOAL_SPEAR : true,
    GOAL_TOTEM : true,
};

static goal_set murderbot_goals = {
    GOAL_DETECTED_MURDERBOTS : true,
    GOAL_MURDERBOTS : true,
    GOAL_DATA_CORES : true,
    GOAL_MURDERBOT_DRONES : true,
    GOAL_MURDERBOT_SOLDIERS : true,
};

static goal_set spant_goals = {
    GOAL_DETECTED_SPANTS : true,
    GOAL_SPANTS : true,
    GOAL_EGG_CASINGS : true,
    GOAL_SPANT_DRONES : true,
    GOAL_SPANT_SOLDIERS : true,
};

static goal_set ruins_goals = {
    GOAL_RUINS : true,
    GOAL_DETECTED_RUINS : true,
    GOAL_PROCRASTINATOR : true,
    GOAL_PROCRASTINATOR_1 : true,
    GOAL_PROCRASTINATOR_2 : true,
    GOAL_PROCRASTINATOR_3 : true,
    GOAL_SPACE_BABY : true,
    GOAL_SPACE_BABY_1 : true,
    GOAL_SPACE_BABY_2 : true,
    GOAL_SPACE_BABY_3 : true,
    GOAL_SPACE_PIRATE : true,
    GOAL_SPACE_PIRATE_1 : true,
    GOAL_SPACE_PIRATE_2 : true,
    GOAL_SPACE_PIRATE_3 : true,
};

static goal_set procrastinator_goals = {
    GOAL_PROCRASTINATOR : true,
    GOAL_PROCRASTINATOR_1 : true,
    GOAL_PROCRASTINATOR_2 : true,
    GOAL_PROCRASTINATOR_3 : true,
};

static goal_set space_baby_goals = {
    GOAL_SPACE_BABY : true,
    GOAL_SPACE_BABY_1 : true,
    GOAL_SPACE_BABY_2 : true,
    GOAL_SPACE_BABY_3 : true,
};

static goal_set space_pirate_goals = {
    GOAL_SPACE_PIRATE : true,
    GOAL_SPACE_PIRATE_1 : true,
    GOAL_SPACE_PIRATE_2 : true,
    GOAL_SPACE_PIRATE_3 : true,
};

goal_set choose_quest_step( goal_set goals )
{
    // Iterate through goals. Depending on items in inventory, current language
    // fluency, and confgured required language fluency, replace generic quest
    // with the specific step required.

    goal_set retval;

    foreach g in goals {
	goal next_step = NO_GOAL;
	switch( g ) {
	case GOAL_PROCRASTINATOR: {
	    next_step =
		( available_amount( $item[ Procrastinator locker key ] ) > 0 ) ?
		GOAL_PROCRASTINATOR_3 :
	        ( get_property( "procrastinatorLanguageFluency" ).to_int() >= minimum_procrastinator_language ) ?
		GOAL_PROCRASTINATOR_2 :
	        ( available_amount( $item[ murderbot data core ] ) > 0 ) ?
		GOAL_PROCRASTINATOR_1 :
	        GOAL_DATA_CORES;
	    break;
	}
	case GOAL_SPACE_BABY: {
	    next_step =
		( available_amount( $item[ Space Baby bawbaw ] ) > 0 ) ?
		GOAL_SPACE_BABY_3 :
		( ( get_property( "spaceBabyLanguageFluency" ).to_int() + ( available_amount( $item[ Space Baby children's book ] ) * 10 ) ) >= minimum_space_baby_language ) ?
		GOAL_SPACE_BABY_2 :
	        GOAL_SPACE_BABY_1;
	    break;
	}
	case GOAL_SPACE_PIRATE: {
	    next_step =
		( available_amount( $item[ space pirate treasure map ] ) > 0 ) ?
		GOAL_SPACE_PIRATE_3 :
		( get_property( "spacePirateLanguageFluency" ).to_int() >= minimum_space_pirate_language ) ?
		GOAL_SPACE_PIRATE_2 :
	        GOAL_SPACE_PIRATE_1;
	    break;
	}
	}
	retval[ next_step == NO_GOAL ? g : next_step ] = true;
    }
    return retval;
}

boolean validate_goals( goal_set goals )
{
    boolean bogus = false;
    goal aliens_goal = NO_GOAL;
    goal murderbots_goal = NO_GOAL;
    goal spants_goal = NO_GOAL;
    goal ruins_goal = NO_GOAL;

    foreach g in goals {
	if ( !( all_goals contains g ) ) {
	    print( "Invalid goal: '" + g +  "'.", "red" );
	    bogus = true;
	} else if ( alien_goals contains g ) {
	    if ( aliens_goal != NO_GOAL ) {
		print( "Cannot look for both '" + aliens_goal + "' and '" + g + "'.", "red" );
		bogus = true;
	    }
	    aliens_goal = g;
	} else if ( murderbot_goals contains g ) {
	    if ( murderbots_goal != NO_GOAL ) {
		print( "Cannot look for both '" + murderbots_goal + "' and '" + g + "'.", "red" );
		bogus = true;
	    }
	    murderbots_goal = g;
	} else if ( spant_goals contains g ) {
	    if ( spants_goal != NO_GOAL ) {
		print( "Cannot look for both '" + spants_goal + "' and '" + g + "'.", "red" );
		bogus = true;
	    }
	    spants_goal = g;
	} else if ( ruins_goals contains g ) {
	    if ( ruins_goal != NO_GOAL ) {
		print( "Cannot look for both '" + ruins_goal + "' and '" + g + "'.", "red" );
		bogus = true;
	    }
	    ruins_goal = g;
	}
    }

    return !bogus;
}

string random_coordinates( string minc, string maxc )
{
    int minimum = hazard_level[ minc ].index;
    int maximum = hazard_level[ maxc ].index;
    string result = difficulty_to_coordinate[ (maximum == minimum ) ? minimum : ( random( maximum - minimum + 1 ) + minimum ) ];
    result += difficulty_to_coordinate[ random( 26 ) ];
    result += difficulty_to_coordinate[ random( 26 ) ];
    result += difficulty_to_coordinate[ random( 26 ) ];
    result += difficulty_to_coordinate[ random( 26 ) ];
    result += difficulty_to_coordinate[ random( 26 ) ];
    result += difficulty_to_coordinate[ random( 26 ) ];
    return result;
}

string difficulty_range( string minimum, string maximum )
{
    return "(" + minimum + ( ( minimum == maximum ) ? "" : ( "-" + maximum ) ) + ")";
}

planet_map filter_difficulty( planet_map planets, string minimum, string maximum )
{
    boolean filter_difficulty( planet p, int min_index, int max_index )
    {
	return ( p.index >= min_index ) && ( p.index <= max_index );
    }

    // Filter out planets that are too easy or too hard
    if ( minimum != "A" || maximum != "Z" ) {
	planet_map matching_planets;
	int min_index = hazard_level[ minimum ].index;
	int max_index = hazard_level[ maximum ].index;

	foreach coordinates, p in planets {
	    if ( filter_difficulty( p, min_index, max_index ) ) {
		matching_planets[ coordinates ] = p;
	    }
	}

	planets = matching_planets;

	string range = difficulty_range( minimum, maximum );
	print( "After filtering on planet difficulty " + range + ", " + count( planets ) + " left." );
    }

    return planets;
}

boolean validate_coordinates()
{
    if ( coordinates == "" ) {
	return true;
    }

    // Compensate for lax user input
    coordinates = coordinates.to_upper_case();

    if ( coordinates == "RANDOM" ) {
	string coords = random_coordinates( minimum_difficulty, maximum_difficulty );
	string range = difficulty_range( minimum_difficulty, maximum_difficulty );
	print( "RANDOM coordinates with difficulty " + range + " -> " + coords );
	coordinates = coords;
	return true;
    }

    if ( coordinates == "KNOWN" || coordinates == "UNVISITED" || coordinates == "VALIDATED" ) {
	// Will choose a planet later after planet data loaded
	return true;
    }

    matcher m = create_matcher( "[ABCDEFGHIJKLMNOPQRSTUVWXYZ]{7}", coordinates );
    if ( !m.find() ) {
	print( "VSG.Coordinates: '" + coordinates + "' must be have exactly seven uppercase letters" );
	return false;
    }

    return true;
}

boolean validate_language_proficiencies()
{
    boolean bogus = false;

    void validate_language( string property, string lang, int proficiency )
    {
	if ( proficiency <= 0 || proficiency > 100 ) {
	    print( property + ": proficiency in the '" + lang + "' must be  greater than zero and no greater than 100", "red" );
	    bogus = true;
	}
    }

    validate_language( "VSG.MinimumProcrastinatorLanguage", "Procrastinator Pirate", minimum_procrastinator_language );
    validate_language( "VSG.MinimumSpaceBabyLanguage", "Space Baby", minimum_space_baby_language );
    validate_language( "VSG.MinimumSpacePirateLanguage", "Space Pirate", minimum_space_pirate_language );

    return !bogus;
}

boolean validate_dificulty_range()
{
    boolean bogus = false;
    if ( !( hazard_level contains minimum_difficulty ) ) {
	print( "VSG.MinimumDifficulty: '" + minimum_difficulty + "' must be a single upper case letter", "red" );
	// For later validation
	minimum_difficulty = "A";
	bogus = true;
    }
    if ( !( hazard_level contains maximum_difficulty ) ) {
	print( "VSG.MaximumDifficulty: '" + maximum_difficulty + "' must be a single upper case letter", "red" );
	// For later validation
	maximum_difficulty = "Z";
	bogus = true;
    }
    if ( !bogus ) {
	planet_difficulty minimum = hazard_level[ minimum_difficulty ];
	planet_difficulty maximum = hazard_level[ maximum_difficulty ];
	if ( minimum.index > maximum.index ) {
	    print( "VSG.MinimumDifficulty: '" + minimum_difficulty + "' is greater than VSG.MaximumDifficulty: '" + maximum_difficulty + "'", "red" );
	    // For later validation
	    string temp = minimum_difficulty;
	    minimum_difficulty = maximum_difficulty;
	    maximum_difficulty = temp;
	    bogus = true;
	}
    }
    return !bogus;
}

static string RESEARCH = "research";
static string TURNS = "turns";

static string_set valid_strategies = $strings[
    research,
    turns
];

static item_set valid_sample_kits = $items[
    none,
    geological sample kit,
    botanical sample kit,
    zoological sample kit
];

static string_set valid_gemstone_options = $strings[
    none,
    closet,
    mallsell,
];

boolean validate_configuration()
{
    boolean bogus = false;

    // Difficuly range is used both for RANDOM coordinates and for
    // filtering acceptable planets with goals
    bogus |= !validate_dificulty_range();

    if ( coordinates != "" ) {
	// You can have either coordinates
	bogus |= !validate_coordinates();
    } else {
	// Or goals
	bogus |= !validate_language_proficiencies();
	desired_goals = choose_quest_step( desired_goals );
	bogus |= !validate_goals( desired_goals );
    }

    if ( !( valid_strategies contains strategy ) ) {
	print( "VSG.Strategy: '" + strategy + "' must be either 'research' or 'turns'" );
	bogus = true;
    }

    if ( !( valid_sample_kits contains desired_sample_kit ) ) {
	print( "VSG.SampleKit: '" + desired_sample_kit + "' is not a valid Spacegate sample kit.", "red" );
	bogus = true;
    }

    if ( !( valid_gemstone_options contains alien_gemstone_handling ) ) {
	print( "VSG.AlienGemstoneHandling: '" + alien_gemstone_handling + "' must be 'none', 'closet', or 'mallsell'" );
	bogus = true;
    }

    return !bogus;
}

static item PRIMITIVE_ALIEN_BOOZE = $item[ primitive alien booze ];
static item PRIMITIVE_ALIEN_MASK = $item[ primitive alien mask ];
static item PRIMITIVE_ALIEN_MEDICINE = $item[ primitive alien medicine ];
static item PRIMITIVE_ALIEN_SALAD = $item[ primitive alien salad ];

int trade_price_limit( item trade )
{
    switch ( trade ) {
    case PRIMITIVE_ALIEN_BOOZE:
	return booze_max_price;
    case PRIMITIVE_ALIEN_MASK:
	return mask_max_price;
    case PRIMITIVE_ALIEN_MEDICINE:
	return medicine_max_price;
    case PRIMITIVE_ALIEN_SALAD:
	return salad_max_price;
    }
    return 0;
}

// ***************************
//        Planet Data        *
// ***************************

typedef planet [string] planet_map;

// Planets categorized by primary and secondary goals

planet_map planets_for_goals( planet_map planets, goal_set goals, string minimum, string maximum, boolean only_goals, boolean buying )
{
    static item NO_ITEM = $item[ none ];

    // Replace quests with quest step required to advance
    goals = choose_quest_step( goals );

    if ( !validate_goals( goals ) ) {
	return planets;
    }
    
    load_planet_data();

    boolean filter_goal( planet p, goal g )
    {
	switch ( g ) {
	case NO_GOAL:
	    // All planets are acceptable
	    return true;
	case GOAL_ROCKS:
	    // Only planets with no life or traces thereof
	    return  ( p.plants == NONE && p.animals == NONE && p.aliens == NONE && p.murderbots == NONE && p.spants == none && p.quest == NONE );
	case GOAL_ROCKS0:
	    return ( p.rocks == NONE );
	case GOAL_ROCKS1:
	    return ( p.rocks == SPACE_CAVE );
	case GOAL_ROCKS2:
	    return ( p.rocks == COOL_SPACE_ROCKS );
	case GOAL_ROCKS3:
	    return ( p.rocks == ( SPACE_CAVE | COOL_SPACE_ROCKS ) );
	case GOAL_ROCKS4:
	    return ( p.rocks == WIDE_OPEN_SPACES );
	case GOAL_ROCKS5:
		     return ( p.rocks == ( SPACE_CAVE | WIDE_OPEN_SPACES ) );
	case GOAL_ROCKS6:
		     return ( p.rocks == ( COOL_SPACE_ROCKS | WIDE_OPEN_SPACES ) );
	case GOAL_ROCKS7:
		     return ( p.rocks == ( SPACE_CAVE | COOL_SPACE_ROCKS | WIDE_OPEN_SPACES ) );
	case GOAL_PRIMITIVE_PLANTS:
	    return ( p.plants == HOSTILE+SIMPLE );
	case GOAL_ADVANCED_PLANTS:
	    return ( p.plants == HOSTILE+COMPLEX );
	case GOAL_ANOMALOUS_PLANTS:
	    return ( p.plants == HOSTILE+ANOMALOUS );
	case GOAL_PRIMITIVE_ANIMALS:
	    return ( p.animals == HOSTILE+SIMPLE );
	case GOAL_ADVANCED_ANIMALS:
	    return ( p.animals == HOSTILE+COMPLEX );
	case GOAL_ANOMALOUS_ANIMALS:
	    return ( p.animals == HOSTILE+ANOMALOUS );
	case GOAL_DETECTED_TRADE:
	    return ( ( p.aliens == FRIENDLY ) || ( ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == FRIENDLY ) && p.price == 0 ) );
	case GOAL_TRADE:
	    return ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == FRIENDLY );
	case GOAL_SALAD:
	    return ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == FRIENDLY ) && ( ( p.aliens & ALIEN_ITEM_BIT_FIELD_MASK ) == SALAD );
	case GOAL_BOOZE:
	    return ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == FRIENDLY ) && ( ( p.aliens & ALIEN_ITEM_BIT_FIELD_MASK ) == BOOZE );
	case GOAL_MEDICINE:
	    return ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == FRIENDLY ) && ( ( p.aliens & ALIEN_ITEM_BIT_FIELD_MASK ) == MEDICINE );
	case GOAL_MASK:
	    return ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == FRIENDLY ) && ( ( p.aliens & ALIEN_ITEM_BIT_FIELD_MASK ) == MASK );
	case GOAL_DETECTED_TROPHY:
	    return ( p.aliens == HOSTILE );
	case GOAL_TROPHY:
	    return ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == HOSTILE );
	case GOAL_BLOWGUN:
	    return ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == HOSTILE ) && ( ( p.aliens & ALIEN_ITEM_BIT_FIELD_MASK ) == BLOWGUN );
	case GOAL_LOINCLOTH:
	    return ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == HOSTILE ) && ( ( p.aliens & ALIEN_ITEM_BIT_FIELD_MASK ) == LOINCLOTH );
	case GOAL_NECKLACE:
	    return ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == HOSTILE ) && ( ( p.aliens & ALIEN_ITEM_BIT_FIELD_MASK ) == NECKLACE );
	case GOAL_SPEAR:
	    return ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == HOSTILE ) && ( ( p.aliens & ALIEN_ITEM_BIT_FIELD_MASK ) == SPEAR );
	case GOAL_TOTEM:
	    return ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == HOSTILE ) && ( ( p.aliens & ALIEN_ITEM_BIT_FIELD_MASK ) == TOTEM );
	case GOAL_DETECTED_MURDERBOTS:
	    return ( p.murderbots == DETECTED );
	case GOAL_MURDERBOTS:
	    return ( ( (p.murderbots & ARMY_DETECTED_BIT_FIELD_MASK ) == DETECTED ) && ( (p.murderbots & ARMY_TYPE_BIT_FIELD_MASK ) != ARTIFACT ) );
	case GOAL_DATA_CORES:
	    return ( (p.murderbots & ARMY_TYPE_BIT_FIELD_MASK ) == ARTIFACT );
	case GOAL_MURDERBOT_DRONES:
	    return ( (p.murderbots & ARMY_TYPE_BIT_FIELD_MASK ) == DRONES );
	case GOAL_MURDERBOT_SOLDIERS:
	    return ( (p.murderbots & ARMY_TYPE_BIT_FIELD_MASK ) == SOLDIERS );
	case GOAL_DETECTED_SPANTS:
	    return ( p.spants == DETECTED );
	case GOAL_SPANTS:
	    return ( ( (p.spants & ARMY_DETECTED_BIT_FIELD_MASK ) == DETECTED ) && ( (p.spants & ARMY_TYPE_BIT_FIELD_MASK ) != ARTIFACT ) );
	case GOAL_EGG_CASINGS:
	    return ( (p.spants & ARMY_TYPE_BIT_FIELD_MASK ) == ARTIFACT );
	case GOAL_SPANT_DRONES:
	    return ( (p.spants & ARMY_TYPE_BIT_FIELD_MASK ) == DRONES );
	case GOAL_SPANT_SOLDIERS:
	    return ( (p.spants & ARMY_TYPE_BIT_FIELD_MASK ) == SOLDIERS );
	case GOAL_RUINS:
	case GOAL_DETECTED_RUINS:
	    return ( p.quest == DETECTED );
	case GOAL_PROCRASTINATOR_1:
	    return ( ( p.quest & RUINS_LANGUAGE_BIT_FIELD_MASK ) == PROCRASTINATOR ) && ( ( p.quest & RUINS_STEP_BIT_FIELD_MASK ) == ONE );
	case GOAL_PROCRASTINATOR_2:
	    return ( ( p.quest & RUINS_LANGUAGE_BIT_FIELD_MASK ) == PROCRASTINATOR ) && ( ( p.quest & RUINS_STEP_BIT_FIELD_MASK ) == TWO );
	case GOAL_PROCRASTINATOR_3:
	    return ( ( p.quest & RUINS_LANGUAGE_BIT_FIELD_MASK ) == PROCRASTINATOR ) && ( ( p.quest & RUINS_STEP_BIT_FIELD_MASK ) == THREE );
	case GOAL_SPACE_BABY_1:
	    return ( ( p.quest & RUINS_LANGUAGE_BIT_FIELD_MASK ) == SPACE_BABY ) && ( ( p.quest & RUINS_STEP_BIT_FIELD_MASK ) == ONE );
	case GOAL_SPACE_BABY_2:
	    return ( ( p.quest & RUINS_LANGUAGE_BIT_FIELD_MASK ) == SPACE_BABY ) && ( ( p.quest & RUINS_STEP_BIT_FIELD_MASK ) == TWO );
	case GOAL_SPACE_BABY_3:
	    return ( ( p.quest & RUINS_LANGUAGE_BIT_FIELD_MASK ) == SPACE_BABY ) && ( ( p.quest & RUINS_STEP_BIT_FIELD_MASK ) == THREE );
	case GOAL_SPACE_PIRATE_1:
	    return ( ( p.quest & RUINS_LANGUAGE_BIT_FIELD_MASK ) == SPACE_PIRATE ) && (  (p.quest & RUINS_STEP_BIT_FIELD_MASK ) == ONE );
	case GOAL_SPACE_PIRATE_2:
	    return ( ( p.quest & RUINS_LANGUAGE_BIT_FIELD_MASK ) == SPACE_PIRATE ) && ( ( p.quest & RUINS_STEP_BIT_FIELD_MASK ) == TWO );
	case GOAL_SPACE_PIRATE_3:
	    return ( ( p.quest & RUINS_LANGUAGE_BIT_FIELD_MASK ) == SPACE_PIRATE ) && ( ( p.quest & RUINS_STEP_BIT_FIELD_MASK ) == THREE );
	}
	// GOAL_ALIENS - is this necessary or possible? We know if they are friendly (GOAL_TRADE) or hostile (GOAL_TROPHY)
	// GOAL_PROCRASTINATOR - should be set to GOAL_DATA_CORES, GOAL_PROCRASTINATOR_1, GOAL_PROCRASTINATOR_2, GOAL_PROCRASTINATOR_3
	// GOAL_SPACE_BABY - should be set to GOAL_SPACE_BABY_1, GOAL_SPACE_BABY_2, GOAL_SPACE_BABY_3
	// GOAL_SPACE_PIRATE - should be set to GOAL_SPACE_PIRATE_1, GOAL_SPACE_PIRATE_2, GOAL_SPACE_PIRATE_3
	return false;
    }

    item trade_goal()
    {
	foreach g in goals {
	    switch ( g ) {
	    case GOAL_BOOZE:
		return PRIMITIVE_ALIEN_BOOZE;
	    case GOAL_MASK:
		return PRIMITIVE_ALIEN_MASK;
	    case GOAL_MEDICINE:
		return PRIMITIVE_ALIEN_MEDICINE;
	    case GOAL_SALAD:
		return PRIMITIVE_ALIEN_SALAD;
	    }
	}
	return NO_ITEM;
    }

    // Successively refine the list of planets that fulfil the goals.
    // There are other ways to do this that do not involve looking at a
    // particular planet more than once, but this logs in a more
    // interesting & useful manner.

    print( "Considering " + count( planets ) + " planets." );

    foreach g in goals {
	planet_map matching_planets;

	foreach coordinates, p in planets {
	    if ( filter_goal( p, g ) ) {
		matching_planets[ coordinates ] = p;
	    }
	}

	planets = matching_planets;

	print( "After filtering on '" + g + "', " + count( planets ) + " left." );
    }

    // Filter out planets that are too easy or too hard
    planets = filter_difficulty( planets, minimum, maximum );

    if ( count( planets ) < 2 ) {
	return planets;
    }

    if ( current_mode == COUNT || current_mode == LIST ) {
	return planets;
    }

    // Everything after this is optional.

    // If buying a trade item, filter out all except the cheapest
    item trade = trade_goal();

    // "vsg trade buy salad" says to buy a primitive alien salad. Look
    // for the planet with the cheapest salad.
    //    
    // "vsg trade buy" says to buy any item. That is reasonable for
    // either RANDOM or UNVISITED. The former will not filter on goals,
    // but the latter will. Go for the cheapest anything.

    boolean unvisited = coordinates == "UNVISITED";
    int cheapest = 1000000;
    if ( buying && ( trade != NO_ITEM || unvisited ) ) {
	foreach coordinates, p in planets {
	    // The public spreadsheet has some trade items priced at 0.
	    // That cannot be right. If we want to visit unvisited
	    // planets, go there and correct the saved planet data.
	    if ( ( p.price > 0 || unvisited ) &&
		 p.price < cheapest ) {
		cheapest = p.price;
	    }
	}

	// If we are looking for a particular item, make sure the
	// cheapest is within our price limit
	int limit = trade_price_limit( trade );
	if ( trade != NO_ITEM && limit < cheapest ) {
	    string name = trade.to_string();
	    print( "You want to buy a " + name + " for at most " + sg_pnum( limit ) + " Meat, but the cheapest available costs " + sg_pnum( cheapest ) + " Meat." );
	    print( "Disabling buying." );
	    buying = false;
	}
    }

    // We have identified the cheapest trade item of the requested
    // sort. Find the set of planets that sell it at that price.
    if ( buying && ( trade != NO_ITEM || unvisited ) ) {
	planet_map matching_planets;

	foreach coordinates, p in planets {
	    if ( p.price == cheapest ) {
		matching_planets[ coordinates ] = p;
	    }
	}

	planets = matching_planets;

	string name = trade == NO_ITEM ? "any" : trade.to_string();
	print( "After filtering for cheapest trade item (" + name + " @ " + sg_pnum( cheapest ) + " Meat), " + count( planets ) + " left." );
    }

    if ( count( planets ) == 1 ) {
	return planets;
    }

    // If any planet that fulfils the goals will do, return what we have
    if ( only_goals ) {
	return planets;
    }

    // Finally, depending on startegy, either maximize rocks or skippable nnoncombats

    // The following will each have multiple encounters
    boolean filter_animals = true;
    boolean filter_plants = true;
    boolean filter_trophy = true;
    boolean filter_spants = true;
    boolean filter_murderbots = true;
    // The following have exactly one encounter
    boolean filter_trade = true;
    boolean filter_ruins = true;

    // See what we want to have and don't filter on those
    foreach g in goals {
	if ( animal_goals contains g ) {
	    filter_animals = false;
	} else if ( plant_goals contains g ) {
	    filter_plants = false;
	} else if ( alien_goals contains g ) {
	    filter_trophy = false;
	    filter_trade = false;
	} else if ( murderbot_goals contains g ) {
	    filter_murderbots = false;
	} else if ( spant_goals contains g ) {
	    filter_spants = false;
	} else if ( ruins_goals contains g ) {
	    filter_ruins = false;
	}
    }

    if ( strategy == RESEARCH ) {
	// If our strategy is to maximize amount of research we collect
	// (and spend all of our available turns doing so), we'd like to
	// end up with as many rocks as possible,

	// Filter out combat encounters
	planet_map [6] combats;

	foreach coordinates, p in planets {
	    int encounters = 0;
	    if ( filter_plants && p.plants != NONE ) {
		encounters++;
	    }
	    if ( filter_animals && p.animals != NONE ) {
		encounters++;
	    }
	    if ( filter_trophy && p.aliens == HOSTILE ) {
		encounters++;
	    }
	    if ( filter_spants && p.spants != NONE ) {
		encounters++;
	    }
	    if ( filter_murderbots && p.murderbots != NONE ) {
		encounters++;
	    }
	    combats[encounters][coordinates] = p;
	}

	foreach index, map in combats {
	    if ( count( map ) > 0 ) {
		planets = map;
		print( "After filtering for fewest additional combat encounters, " + count( planets ) + " left." );
		break;
	    }
	}

	if ( count( planets ) == 1 ) {
	    return planets;
	}

	// Filter out non-combat encounters
	planet_map [3] noncombats;

	foreach coordinates, p in planets {
	    int encounters = 0;
	    if ( filter_trade && p.aliens == FRIENDLY ) {
		encounters++;
	    }
	    if ( filter_ruins && p.quest != NONE ) {
		encounters++;
	    }
	    noncombats[encounters][coordinates] = p;
	}

	foreach index, map in noncombats {
	    if ( count( map ) > 0 ) {
		planets = map;
		print( "After filtering for fewest additional noncombat encounters, " + count( planets ) + " left." );
		break;
	    }
	}
    } else if ( strategy == TURNS ) {
	// If our strategy is to minimize the number of turns we spend
	// in the Spacegate, we'd like as many non-hostile life
	// encounters as possible, since you can skip those

	planet_map plant_planets;
	if ( filter_plants ) {
	    foreach coordinates, p in planets {
		// Eliminate the HOSTILE plants
		if ( p.plants == SIMPLE || p.plants == COMPLEX || p.plants == ANOMALOUS ) {
		    plant_planets[ coordinates ] = p;
		}
	    }
	    print( "There are " + plant_planets.count() + " planets with non-hostile plants." );
	}

	planet_map animal_planets;
	if ( filter_animals ) {
	    foreach coordinates, p in planets {
		// Eliminate the HOSTILE animals
		if ( p.animals == SIMPLE || p.animals == COMPLEX || p.animals == ANOMALOUS ) {
		    animal_planets[ coordinates ] = p;
		}
	    }
	    print( "There are " + animal_planets.count() + " planets with non-hostile animals." );
	}

	planet_map wildlife_planets;
	if ( filter_plants && filter_animals ) {
	    foreach coordinates, p in plant_planets {
		// Eliminate the HOSTILE animals
		if ( p.animals == SIMPLE || p.animals == COMPLEX || p.animals == ANOMALOUS ) {
		    wildlife_planets[ coordinates ] = p;
		}
	    }
	    print( "There are " + wildlife_planets.count() + " planets with non-hostile plants AND non-hostile animals." );
	}

	if ( wildlife_planets.count() > 0 ) {
	    // Planets with both kinds of non-hostile wildlife have a
	    // lot of skippable non-combats
	    planets = wildlife_planets;
	    print( "After filtering for non-hostile plants AND non-hostile animals, " + count( planets ) + " left." );
	} else  if ( plant_planets.count() > animal_planets.count() && plant_planets.count() > 0 ) {
	    planets = plant_planets;
	    print( "After filtering for non-hostile plants, " + count( planets ) + " left." );
	} else  if ( animal_planets.count() > 0 ) {
	    planets = animal_planets;
	    print( "After filtering for non-hostile animals, " + count( planets ) + " left." );
	}

	if ( count( planets ) == 1 ) {
	    return planets;
	}

	// Also filter out spants, murderbots, and hostile aliens, since that will make
	// more rocks, some of which are skippable
	if ( filter_spants ) {
	    planet_map no_spant_planets;
	    foreach coordinates, p in planets {
		if ( p.spants == NONE ) {
		    no_spant_planets[ coordinates ] = p;
		}
	    }
	    if ( no_spant_planets.count() > 0 ) {
		planets = no_spant_planets;
		print( "After filtering for planets with no spants, " + count( planets ) + " left." );
	    }
	}

	if ( count( planets ) == 1 ) {
	    return planets;
	}

	if ( filter_murderbots ) {
	    planet_map no_murderbot_planets;
	    foreach coordinates, p in planets {
		if ( p.murderbots == NONE ) {
		    no_murderbot_planets[ coordinates ] = p;
		}
	    }

	    if ( no_murderbot_planets.count() > 0 ) {
		planets = no_murderbot_planets;
		print( "After filtering for planets with no murderbots, " + count( planets ) + " left." );
	    }
	}

	if ( count( planets ) == 1 ) {
	    return planets;
	}

	if ( filter_trophy ) {
	    planet_map no_hostile_aliens_planets;
	    foreach coordinates, p in planets {
		if ( p.aliens != HOSTILE ) {
		    no_hostile_aliens_planets[ coordinates ] = p;
		}
	    }

	    if ( no_hostile_aliens_planets.count() > 0 ) {
		planets = no_hostile_aliens_planets;
		print( "After filtering for planets with no hostile aliens, " + count( planets ) + " left." );
	    }
	}

	if ( count( planets ) == 1 ) {
	    return planets;
	}

	if ( filter_trade ) {
	    planet_map trade_planets;
	    foreach coordinates, p in planets {
		if ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == FRIENDLY ) {
		    trade_planets[ coordinates ] = p;
		}
	    }

	    if ( trade_planets.count() > 0 ) {
		planets = trade_planets;
		print( "After filtering for planets with alien trade, " + count( planets ) + " left." );
	    }
	}
    }

    return planets;
}

string select_hardest_planet( planet_map candidates )
{
    int planets = count( candidates );

    if ( planets == 0 ) {
	return "";
    }

    // The index is a string - the coordinates - and is sorted
    // alphabetically.  The difficulty increases the farther along in
    // the alphabet, so simply take the last planet
    string result;
    foreach coordinates in candidates {
	result = coordinates;
    }

    return result;
}

string select_random_planet( planet_map candidates )
{
    int planets = count( candidates );

    if ( planets == 0 ) {
	return "";
    }

    int nth = ( planets == 1 ) ? 0 : random( planets );
    int n = 0;

    foreach coordinates in candidates {
	if ( n++ == nth ) {
	    return coordinates;
	}
    }

    // Shouldn't be possible to get here
    return "";
}

// ***************************
//       Master Control      *
// ***************************

static location SPACEGATE = $location[ Through the Spacegate ];

int choose_choice_option( planet p )
{
    int choice = last_choice();
    string_list available_options = available_choice_options();

    int option = -1;
    switch (choice ) {
    case 1236: {	// Space Cave
	option =
	    ( strategy == TURNS ) ? 6 :			// Leave it alone
	    ( available_options contains 2 ) ? 2 :	// geological sample kit equipped
	    1;						// Collect rocks
	break;
    }
    case 1237:		// A Simple Plant
    case 1238:		// A Complicated Plant
    case 1239:		// What a Plant!
    case 1240:		// The Animals, The Animals
    case 1241:		// Buffalo-Like Animal, Won't You Come Out Tonight
    case 1242: {	// House-Sized Animal
	option =
	    ( strategy == TURNS ) ? 6 :			// Leave it alone
	    ( available_options contains 3 ) ? 3 :	// Appropriate sample kit - collect DNA
	    2;						// toenails/plant fibers
	break;
    }
    case 1243: {	// Interstellar Trade
	// Regardless of strategy, if we want to buy items, buy it -
	// assuming it is not too expensive.
	int alien_item = ( p.aliens & ALIEN_ITEM_BIT_FIELD_MASK );
	item trade = trade_item_to_item[ alien_item ];
	int price = p.price;
	int limit = trade_price_limit( trade );
	option =
	    ( buy_trade_item && price <= limit ) ? 1 :	// Buy the thing
	    2;						// Don't buy the thing
	break;
    }
    case 1244:		// Here There Be No Spants
    case 1245:		// Recovering the Satellite
	option = 1;
	break;
    case 1246: {	// Land Ho
	boolean can_study = available_options contains 1;
	boolean should_study = get_property( "spacePirateLanguageFluency" ).to_int() < minimum_space_pirate_language;
	option =
	    ( can_study && should_study ) ? 1 :		// Study the scrolls (Space Pirate Language Fluency +10%)
	    6;						// Leave
	break;
    }
    case 1247:		// Half The Ship it Used to Be
	// If you happen to find this on a random world, you may as well explore;
	// you'll either get a tradeable space pirate treasure map or 5% language fluency
	option = 1;					// Explore the ship (space pirate treasure map and lose Space Pirate Language Fluency or Space Pirate Language Fluency +5%)
	break;
    case 1248: {	// Paradise Under a Strange Sun
	option =
	    ( available_options contains 1 ) ? 1 :	// Follow your map (lose space pirate treasure map and gain Space Pirate Astrogation Handbook)
	    ( strategy == TURNS ) ? 6 :			// Leave
	    2;						// Work on your tan (gain 1000 Moxie substats(
	break;
    }
    case 1249: {	// That's No Moonlith, it's a Monolith!
	boolean can_insert = available_options contains 1;
	boolean should_insert = get_property( "procrastinatorLanguageFluency" ).to_int() < minimum_procrastinator_language;
	option =
	    ( can_insert && should_insert ) ? 1 :	// Try inserting the Muderbot cube (Procrastinator Language Fluency +20%)
	    6;						// Leave
	break;
    }
    case 1250: {	// I'm Afraid It's Terminal
	// If you have no fluency in Procrastinator language, you have no chance here.
	// You also don't gain any fluency if you fail, so may as well walk away.
	int fluency = get_property( "procrastinatorLanguageFluency" ).to_int();
	option =
	    ( fluency > 0 ) ? 1 :			// Use the machine (Procrastinator locker key and lose Procrastinator Language Fluency, or nothing)
	    6;
	break;
    }
    case 1251: {	// Curses, a Hex
	option =
	    ( available_options contains 1 ) ? 1 :	// Unlock the locker (lose Procrastinator locker key and gain Non-Euclidean FInance)
	    6;						// Leave
	break;
    }
    case 1252: {	// Time Enough at Last
	// This gives you a tradeable item which you have to read in order to gain fluency.
	// You may as well take the book, even if you don't need more fluency right now
	option = 1;					// Grab a book (gain Space Baby children's book; read for Space Baby Language Fluency +10%)
	break;
    }
    case 1253: {	// Mother May I
	// If you have no fluency in Space Baby language, you have no chance here.
	// You also don't gain any fluency if you fail, so may as well walk away.
	int fluency = get_property( "spaceBabyLanguageFluency" ).to_int();
	option =
	    ( fluency > 0 ) ? 1 :			// Ask the hologram for help (gain Space Baby bawbaw and lose Space Baby Language Fluency or nothing)
	    6;
	break;
    }
    case 1254:  {	// Please Baby Baby Please
	option =
	    ( available_options contains 1 ) ? 1 :	// Feed the baby (lose Space Baby bawbaw and gain Peek-a-Boo!)
	    6;						// Leave
	break;
    }
    case 1255:		// Cool Space Rocks
    case 1256: {	// Wide Open Spaces
	option =
	    ( available_options contains 2 ) ? 2 :	// geological sample kit equipped
	    1;						// Collect rocks
	break;
    }
    }
    return option;
}

void merge_planet_data( planet p1, planet_aux pa1, planet p2, planet_aux pa2 )
{
    // (p1, pa1) is what the Spacegate Terminal tells us
    // (p2, pa2) is what we have recorded about the planet in our database.
    //
    // The Terminal is our Ground Truth, so correct public data if the
    // Terminal contradicts it.
    //
    // For things that the Terminal does not display, assume the public
    // data is correct. We will correct it later, if necessary, after we
    // adventure.

    if ( pa1.name != pa2.name ) {
	print( "Spacegate terminal says planet name is '" +
	       pa1.name +
	       "' but saved planet data incorrectly says it is '" +
	       pa2.name +
	       "'." );
	pa2.name = pa1.name;
    }

    // The following are not detectable from the terminal.
    // Believe what we have in the aux data
    pa1.sky = pa2.sky;
    pa1.suns = pa2.suns;
    pa1.moons = pa2.moons;
    pa1.plant_image = pa2.plant_image;
    pa1.animal_image = pa2.animal_image;
    pa1.alien_image = pa2.alien_image;

    if ( p1.environments != p2.environments ) {
	print( "Spacegate terminal says environmental hazards are '" +
	       environmental_hazards_to_string( p1.environments ) +
	       "' but saved planet data incorrectly says they are '" +
	       environmental_hazards_to_string( p2.environments ) +
	       "'." );
	p2.environments = p1.environments;
    }

    if ( p1.elements != p2.elements ) {
	print( "Spacegate terminal says elemental hazards are '" +
	       elemental_hazards_to_string( p1.elements ) +
	       "' but saved planet data incorrectly says they are '" +
	       elemental_hazards_to_string( p2.elements ) +
	       "'." );
	p2.elements = p1.elements;
    }

    if ( p1.plants != p2.plants ) {
	print( "Spacegate terminal says plants are '" +
	       wildlife_to_string( p1.plants ) +
	       "' but saved planet data incorrectly says they are '" +
	       wildlife_to_string( p2.plants ) +
	       "'." );
	p2.plants = p1.plants;
    }

    if ( p1.animals != p2.animals ) {
	print( "Spacegate terminal says animals are '" +
	       wildlife_to_string( p1.animals ) +
	       "' but saved planet data incorrectly says they are '" +
	       wildlife_to_string( p2.animals ) +
	       "'." );
	p2.animals = p1.animals;
    }

    if ( p1.aliens != p2.aliens ) {
	int p1_type = p1.aliens & ALIEN_TYPE_BIT_FIELD_MASK;
	int p2_type = p2.aliens & ALIEN_TYPE_BIT_FIELD_MASK;
	if ( p1_type != p2_type ) {
	    // Hostile vs. Friendly is incorrect. Believe the spacegate terminal
	    // and clear out the item and price,
	    print( "Spacegate terminal says aliens are '" +
		   intelligence_to_string( p1_type ) +
		   "' but saved planet data incorrectly says they are '" +
		   intelligence_to_string( p2_type ) +
		   "'." );
	    p2.aliens = p1.aliens;
	    p2.price = 0;
	} else {
	    // If agreed that aliens are friendly or hostile, use planet data to
	    // get trade item and price
	    p1.aliens = p2.aliens;
	    p1.price = p2.price;
	}
    }

    if ( p1.price != p2.price ) {
	// This should have taken care of above: if the planet data indicated
	// there was a trade item, we merged the trade item and price. The only
	// way we could be here is if the planet data said the trade item was
	// unknown but had a price. That is bogus. Fix planet data.
	p2.price = 0;
    }

    if ( p1.murderbots != p2.murderbots ) {
	int p1_detected = p1.murderbots & ARMY_DETECTED_BIT_FIELD_MASK;
	int p2_detected = p2.murderbots & ARMY_DETECTED_BIT_FIELD_MASK;
	if ( p1_detected != p2_detected ) {
	    // Detected vs. not is incorrect. Believe the spacegate terminal
	    print( "Spacegate terminal says Murderbots are '" +
		   army_detected_to_string( p1_detected ) +
		   "' but saved planet data incorrectly says they are '" +
		   army_detected_to_string( p2_detected ) +
		   "'." );
	    p2.murderbots = p1.murderbots;
	} else {
	    // If agreed that Murderbots are present, use planet data
	    p1.murderbots = p2.murderbots;
	}
    }

    if ( p1.spants != p2.spants ) {
	int p1_detected = p1.spants & ARMY_DETECTED_BIT_FIELD_MASK;
	int p2_detected = p2.spants & ARMY_DETECTED_BIT_FIELD_MASK;
	if ( p1_detected != p2_detected ) {
	    // Detected vs. not is incorrect. Believe the spacegate terminal
	    print( "Spacegate terminal says Spants are '" +
		   army_detected_to_string( p1_detected ) +
		   "' but saved planet data incorrectly says they are '" +
		   army_detected_to_string( p2_detected ) +
		   "'." );
	    p2.spants = p1.spants;
	} else {
	    // If agreed that Spants are present or not, use planet data
	    p1.spants = p2.spants;
	}
    }

    if ( p1.quest != p2.quest ) {
	int p1_detected = p1.quest & RUINS_DETECTED_BIT_FIELD_MASK;
	int p2_detected = p2.quest & RUINS_DETECTED_BIT_FIELD_MASK;
	if ( p1_detected != p2_detected ) {
	    // Detected vs. not is incorrect. Believe the spacegate terminal
	    print( "Spacegate terminal says Alien Ruins are '" +
		   ruins_detected_to_string( p1_detected ) +
		   "' but saved planet data incorrectly says they are '" +
		   ruins_detected_to_string( p2_detected ) +
		   "'." );
	    p2.quest = p1.quest;
	} else {
	    // If agreed that Ruins are present or not, use planet data
	    p1.quest = p2.quest;
	}
    }

    // Overwrite the saved public data with our corrections
    public_planets[ coordinates ] = p2;
    public_planets_aux[ coordinates ] = pa2;
}

army set_army_type( army a, int type )
{
    a &= ~ARMY_TYPE_BIT_FIELD_MASK;
    a |= type & ARMY_TYPE_BIT_FIELD_MASK;
    return a;
}

ruins set_ruins_quest( ruins r, language lang, step st )
{
    r &= ~RUINS_LANGUAGE_BIT_FIELD_MASK;
    r |= lang & RUINS_LANGUAGE_BIT_FIELD_MASK;
    r &= ~RUINS_STEP_BIT_FIELD_MASK;
    r |= st & RUINS_STEP_BIT_FIELD_MASK;
    return r;
}

void update_planet_data( planet p )
{
    // p is the planet data from the database, as corrected by what we see in the Terminal
    //
    // If we have already visited this planet today but are coming back
    // for additional exploration, _SpacegateEncounters has everything
    // that we have seen so far.
    //
    // Rocks are detectable from encounters. We are now tracking rock
    // types, since not all planets have all rock types.
    // 
    // Existence and type of plants, animals, and aliens were learned
    // from the Terminal. Images and trade items require actual
    // adventure text, rather than simply encounters.
    //
    // Spants, Murderbots, and Ruins were detected in the Terminal, but
    // actual types are derivable from encounters with no adventure text
    // needed.

    string_list encounters = get_property( SPACEGATE_ENCOUNTERS_PROPERTY ).to_string_list();
    foreach index, encounter in encounters {
	switch ( encounter ) {
	case "Cool Space Rocks":
	    p.rocks |= COOL_SPACE_ROCKS;
	    break;
	case "Space Cave":
	    p.rocks |= SPACE_CAVE;
	    break;
	case "Wide Open Spaces":
	    p.rocks |= WIDE_OPEN_SPACES;
	    break;
	case "A Simple Plant":
	case "A Complicated Plant":
	case "What a Plant!":
	case "hostile plant":
	case "large hostile plant":
	case "exotic hostile plant":
	    // Plants. Nothing to learn.
	    break;
	case "The Animals, The Animals":
	case "Buffalo-Like Animal, Won't You Come Out Tonight":
	case "House-Sized Animal":
	case "small hostile animal":
	case "large hostile animal":
	case "exotic hostile animal":
	    // Animals. Nothing to learn.
	    break;
	case "Interstellar Trade":
	case "hostile intelligent alien":
	    // Aliens. Nothing to learn.
	    break;
	case "Here There Be No Spants":
	    // Spant Artifact
	    p.spants = set_army_type( p.spants, ARTIFACT );
	    break;
	case "Spant drone":
	    if ( ( p.spants & ARMY_TYPE_BIT_FIELD_MASK ) != SOLDIERS ) {
		p.spants = set_army_type( p.spants, DRONES );
	    }
	    break;
	case "Spant soldier": 
	    p.spants = set_army_type( p.spants, SOLDIERS );
	    break;
	case "Recovering the Satellite":
	    // Murderbot Artifact
	    p.murderbots = set_army_type( p.murderbots, ARTIFACT );
	    break;
	case "Murderbot drone":
	    if ( ( p.murderbots & ARMY_TYPE_BIT_FIELD_MASK ) != SOLDIERS ) {
		p.murderbots = set_army_type( p.murderbots, DRONES );
	    }
	    break;
	case "Murderbot soldier":
	    p.murderbots = set_army_type( p.murderbots, SOLDIERS );
	    break;
	case "Land Ho":
	    p.quest = set_ruins_quest( p.quest, SPACE_PIRATE, ONE );
	    break;
	case "Half The Ship it Used to Be":
	    p.quest = set_ruins_quest( p.quest, SPACE_PIRATE, TWO );
	    break;
	case "Paradise Under a Strange Sun":
	    p.quest = set_ruins_quest( p.quest, SPACE_PIRATE, THREE );
	    break;
	case "That's No Moonlith, it's a Monolith!":
	    p.quest = set_ruins_quest( p.quest, PROCRASTINATOR, ONE );
	    break;
	case "I'm Afraid It's Terminal":
	    p.quest = set_ruins_quest( p.quest, PROCRASTINATOR, TWO );
	    break;
	case "Curses, a Hex":
	    p.quest = set_ruins_quest( p.quest, PROCRASTINATOR, THREE );
	    break;
	case "Time Enough at Last":
	    p.quest = set_ruins_quest( p.quest, SPACE_BABY, ONE );
	    // Space Baby 1
	    break;
	case "Mother May I":
	    p.quest = set_ruins_quest( p.quest, SPACE_BABY, TWO );
	    break;
	case "Please Baby Baby Please":
	    p.quest = set_ruins_quest( p.quest, SPACE_BABY, THREE );
	    break;
	default:
	    // Unknown Spacegate encounter?
	    break;
	}
    }
}

void validate_planet_data( planet p1, planet_aux pa1, planet p2, planet_aux pa2 )
{
    // (p1, pa1) is what we discovered about the planet in our exploration.
    // (p2, pa2) is what we have recorded about the planet in our database.
    //
    // We started exploring with the (corrected) data from merge_planet_data, so
    // all the Spacegate-terminal visible things are correct. This function
    // simply reports on new things we discovered while exploring.
    //
    // Note that the trophy items are rare. If we find one which was previously
    // not known, rejoice and log it, but if we didn't find one, no harm

    // environmental and elemental hazards, plants, and animals were all
    // validated and corrected when we visited the Spacegate terminal.

    if ( p1.aliens != p2.aliens ) {
	// Hostility (or not) was previously corrected
	int p1_item = p1.aliens & ALIEN_ITEM_BIT_FIELD_MASK;
	int p2_item = p2.aliens & ALIEN_ITEM_BIT_FIELD_MASK;
	if ( ( p1.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == HOSTILE ) {
	    print( "Trophy Item: " +  trophy_to_name[ p1_item ] );
	} else {
	    print( "Trade Item: " + trade_item_to_name[ p1_item ] );
	}
	p2.aliens = p1.aliens;
    }

    if ( p1.price != p2.price ) {
	print( "Trade Item Price: " + sg_pnum( p1.price ) );
	p2.price = p1.price;
    }

    if ( p1.murderbots != p2.murderbots ) {
	// Detected (or not) was previously corrected
	print( "Murderbots: " + army_type_to_string( p1.murderbots ) );
	p2.murderbots = p1.murderbots;
    }

    if ( p1.spants != p2.spants ) {
	// Detected (or not) was previously corrected
	print( "Murderbots: " + army_type_to_string( p1.spants ) );
	p2.spants = p1.spants;
    }

    if ( p1.quest != p2.quest ) {
	// Detected (or not) was previously corrected
	print( "Quest: " + ruins_type_and_step_to_string( p1.quest ) );
	p2.quest = p1.quest;
    }

    // "Cosmetic" attributes probably were not known at all. Log what we discovered.
    if ( pa1.sky != pa2.sky ) {
	print( "Planet Sky: " + pa1.sky );
	pa2.sky = pa1.sky;
    }
    if ( pa1.suns != pa2.suns ) {
	print( "Planet Suns: " + pa1.suns );
	pa2.suns = pa1.suns;
    }
    if ( pa1.moons != pa2.moons ) {
	print( "Planet Moons: " + pa1.moons );
	pa2.moons = pa1.moons;
    }
    if ( pa1.plant_image != pa2.plant_image ) {
	print( "Plant Image: " + pa1.plant_image );
	pa2.plant_image = pa1.plant_image;
    }
    if ( pa1.animal_image != pa2.animal_image ) {
	print( "Animal Image: " + pa1.animal_image );
	pa2.animal_image = pa1.animal_image;
    }
    if ( pa1.alien_image != pa2.alien_image ) {
	print( "Alien Image: " + pa1.alien_image );
	pa2.alien_image = pa1.alien_image;
    }
}

void summarize_encounters( string_list encounters, int research, item_count_map shinies )
{
    static string indent = "\u00A0\u00A0\u00A0\u00A0";

    int [string] counts;
    foreach n, e in encounters {
	counts[e]++;
    }
    foreach e, n in counts {
	print( indent + e + ": " + n );
    }

    if ( research > 0 ) {
	print();
	print( "You gained " + research + " pages of " + SPACEGATE_RESEARCH );
    }

    if ( count( shinies ) > 0 ) {
	print();
	print( "You found some shinies!" );

	foreach it, n in shinies {
	    string count = ( n > 1 ) ? ( " (" + n + ")" ) : "";
	    print( indent + it.to_string() + count );
	}
    }
}

void visit_spacegate( string coordinates )
{
    static item ALIEN_GEMSTONE = $item[ alien gemstone ];

    planet p;				// Gameplay affecting planet data
    planet_aux pa;			// Cosmetic planet data
    boolean combats;			// True if we don't know it the planet is all non-combats

    int energy;				// Current energy left
    buffer page;			// The current page we are visiting
    int initial_research;		// Amount of research at start of run

    // All of today's encounters, in order. Since it's an "_" property, KoLmafia clears it every day
    string_list encounters = get_property( SPACEGATE_ENCOUNTERS_PROPERTY ).to_string_list();

    // How much Spacegate Research you gained today
    int research = get_property( SPACEGATE_RESEARCH_PROPERTY ).to_int();

    // Any rare items you acquired this run
    item_count_map shinies = get_property( SPACEGATE_SHINIES_PROPERTY ).to_item_count_map();

    boolean has_combats()
    {
	return
	    ( p.plants == SIMPLE+HOSTILE || p.plants == COMPLEX+HOSTILE || p.plants == ANOMALOUS+HOSTILE ) ||
	    ( p.animals == SIMPLE+HOSTILE || p.animals == COMPLEX+HOSTILE || p.animals == ANOMALOUS+HOSTILE ) ||
	    ( ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK ) == HOSTILE ) ||
	    ( ( (p.spants & ARMY_DETECTED_BIT_FIELD_MASK ) == DETECTED ) && ( (p.spants & ARMY_TYPE_BIT_FIELD_MASK ) != ARTIFACT ) ) ||
	    ( ( (p.murderbots & ARMY_DETECTED_BIT_FIELD_MASK ) == DETECTED ) && ( (p.murderbots & ARMY_TYPE_BIT_FIELD_MASK ) != ARTIFACT ) );
    }

    void load_planet()
    {
	// load_planets() merged my_planets into public_planets, so, if
	// we use the planet from my_planets, it includes the the
	// planets you personally explored and validated.
	//
	// However, spreadsheet planets often have invalid data.
	//
	// Therefore, load the planet from the settings (set by KoLmafia
	// from what the Spacegate terminal says) and merge in what else
	// the existing planet data says, if any.
	//
	// Some of that data will, as mentioned, be incorrect - but we
	// will correct it in the course of adventuring on the planet

	p = settings_to_planet();
	pa = settings_to_planet_aux();

	if ( public_planets contains coordinates ) {
	    merge_planet_data( p, pa, public_planets[ coordinates ], public_planets_aux[ coordinates ] );
	}

	// If we've already adventured here today and are back for more,
	// update with the encounters we already had

	update_planet_data( p );

	combats = has_combats();
	energy = get_property( "_spacegateTurnsLeft" ).to_int();
    }

    void save_planet( boolean visited )
    {
	// Since we actually visited the planet, save it in my_planets
	// See what changes there are to what already existed, if any
	if ( visited && public_planets contains coordinates ) {
	    validate_planet_data( p, pa, public_planets[ coordinates ], public_planets_aux[ coordinates ] );
	}

	// Save in My planets
	my_planets[ coordinates ] = p;
	map_to_file( my_planets, my_planet_file_name );
	my_planets_aux[ coordinates ] = pa;
	map_to_file( my_planets_aux, my_planet_aux_file_name );
	// And if we found a trophy, it will have been added to my_trophies, so write that
	map_to_file( my_trophies, my_trophy_file_name );
    }

    void activate_spacegate()
    {
	// Visit the Spacegate
	page = visit_url( "place.php?whichplace=spacegate" );

	// Approach the Spacegate Terminal
	page = visit_url( "place.php?whichplace=spacegate&action=sg_Terminal" );

	// This is a GenericRequest, so should have followed the redirect. But, just in case...
	if ( page.length() == 0 ) {
	    // We were redirected. Follow it.
	    page = visit_url( "choice.php?forceoption=0" );
	}

	// If we are not in a choice, we have already visited the Spacegate
	// Terminal today and chosen a planet.
	if ( !page.contains_text( "choice.php" ) ) {
	    // KoLmafia has already loaded the planet info from the page.
	    string coords = get_property( "_spacegateCoordinates" );
	    if ( coordinates != coords ) {
		// We went to a planet this script was not expecting.
		coordinates = coords;
	    }
	} else {
	    // Tell the spacegate to open up to the desired coordinates
	    page = visit_url( "choice.php?whichchoice=1235&pwd&option=2&word=" + coordinates );
	}
												   
	// Load planet data for the new planet, if known.
	// Otherwise, initialize from settings.
	load_planet();
    }

    void perhaps_read_childrens_books()
    {
	static item SPACE_BABY_BOOK = $item[ Space Baby children's book ];

	// No ruins on this planet
	if ( p.quest == NONE ) {
	    return;
	}

	// If you select "space baby" as your quest and we selected a planet for
	// quest step 2 - the language test - we took the number of Space Baby
	// children's books you have available into account.
	//
	// Alternatively, if you selected a random planet - or one with
	// unknown ruins - the planet might contain Mother May I
	//
	// In either case, if we encounter Mother May I, we'll need fluency.

	language lang = p.quest & RUINS_LANGUAGE_BIT_FIELD_MASK;
	if ( lang == PROCRASTINATOR || lang == SPACE_PIRATE ) {
	    return;
	}

	step st = p.quest & RUINS_STEP_BIT_FIELD_MASK;
	if ( lang == SPACE_BABY && st != TWO ) {
	    return;
	}

	// Read enough to get up to your desired level of fluency and no higher
	int current_fluency = get_property( "spaceBabyLanguageFluency" ).to_int();
	int missing_fluency = minimum_space_baby_language - current_fluency;
	int books_needed = ( missing_fluency > 0 ) ? ( missing_fluency / 10 ) : 0;
	int available_books = available_amount( SPACE_BABY_BOOK );
	int books_to_read = min( books_needed, available_books );
	if ( books_to_read > 0 ) {
	    retrieve_item( books_to_read, SPACE_BABY_BOOK );
	    use( books_to_read, SPACE_BABY_BOOK );
	}
    }

    void suit_up()
    {
	static int [item] spacegate_gear_option = {
	    $item[filter helmet] : 1,
	    $item[exo-servo leg braces] : 2,
	    $item[rad cloak] : 3,
	    $item[gate transceiver] : 4,
	    $item[high-friction boots] : 5,
	    $item[geological sample kit ] : 6,
	    $item[botanical sample kit ] : 7,
	    $item[zoological sample kit ] : 8,
	};

	item_set needed_gear;
	if ( p.environments != NONE ) {
	    for ( int bit = 1; bit <= 16; bit <<= 1 ) {
		int haz = p.environments & bit;
		if ( haz != 0 ) {
		    needed_gear[ hazard_to_equipment[ haz ] ] = true;
		}
	    }
	}
	if ( desired_sample_kit != $item[ none ] ) {
	    needed_gear[ desired_sample_kit ] = true;
	}

	buffer maximizer_command;

	// We optimize for Item Drop and ignore any elemental hazards
	maximizer_command.append( "item drop" );

	// Get an "effective" weapon -, just in case your CCS uses attacks against Spacegate monsters
	maximizer_command.append( " +effective" );

	// Retrieve each piece of equipment required to mitigate
	// environmental hazards and add to maximizer string

	// Go to Equipment Requisition 
	page = visit_url( "place.php?whichplace=spacegate&action=sg_requisition" );
	string [int] available_options = available_choice_options();
	foreach e in needed_gear {
	    if ( available_amount( e ) == 0 ) {
		// Requisition the equipment
		int option = spacegate_gear_option[ e ];
		if ( available_options contains option ) {
		    visit_url( "choice.php?whichchoice=1233&option=" + option );
		}
	    } else {
		// Already have the equipment. Put in inventory
		retrieve_item( 1, e );
	    }
	    if ( available_amount( e ) == 0 ) {
		abort( "Unable to retrieve requested gear: " + e );
	    }
	    maximizer_command.append( " +equip " );
	    maximizer_command.append( e.to_string() );
	}

	// If the user has any specific equipment they want - or other
	// modifiers they care about - they can specify them. Caveat
	// Emptor if they require specific equipment which conflicts
	// with required equipment
	if ( extra_maximizer_parameters != "" ) {
	    maximizer_command.append( " " );
	    maximizer_command.append( extra_maximizer_parameters );
	}

	maximize( maximizer_command, false );

	foreach it in needed_gear {
	    if ( !have_equipped( it ) ) {
		abort( "Maximizer failed to equip all needed gear." );
	    }
	}
    }

    void between_battle_checks()
    {
	// Keep in a good mood
	mood_execute( -1 );

	// Only restore one HP if there are no combats
	int hp_desired = combats ? my_maxhp() : 1;
	if ( my_hp() < hp_desired ) {
	    restore_hp( hp_desired );
	}

	// Restore mp per your settings
	restore_mp( 0 );
    }

    intelligence set_alien_item( intelligence i, int it )
    {
	i &= ~ALIEN_ITEM_BIT_FIELD_MASK;
	i |= it & ALIEN_ITEM_BIT_FIELD_MASK;
	return i;
    }

    string extract_choice_image()
    {
	// <center><img src=/images/adventureimages/sganimalc3.gif width=300 height=300></center>
	matcher m = create_matcher( "adventureimages/(sg.*?gif)", page );
	return m.find() ? m.group( 1 ) : "";
    }

    string extract_combat_image()
    {
	// <img id='monpic'   src="/images/adventureimages/sgalienb8.gif" width=100 height=100>
	matcher m = create_matcher( "adventureimages/(sg.*?gif)", page );
	return m.find() ? m.group( 1 ) : "";
    }

    string extract_trade_item()
    {
	// title="primitive alien salad">
	matcher m = create_matcher( "title=\"(.*?)\"", page );
	return m.find() ? m.group( 1 ) : "";
    }

    int extract_trade_item_price()
    {
	// "Buy the thing"></td><td valign=center>[22,900 Meat]</td
	matcher m = create_matcher( "Buy the thing.*?\\[(.*?) Meat\]", page );
	return m.find() ? m.group( 1 ).to_int() : 0;
    }

    void register_encounter( string encounter )
    {
	if ( encounter == "A Whole New World" ) {
	    // We are visiting the planet for the first time.
	    // Extract the sky, sun, and moon descriptions

	    matcher m = create_matcher( "You step through the Spacegate.*?<p>(.*?\\.) *?(.*?\\.) *?(.*?\\.)", page );
	    if ( m.find() ) {
		pa.sky = m.group( 1 ).trim();
		pa.suns = m.group( 2 ).trim();
		pa.moons = m.group( 3 ).trim();
	    }
	    
	    return;
	}

	switch ( encounter ) {
	case "Cool Space Rocks":
	    p.rocks |= COOL_SPACE_ROCKS;
	    break;
	case "Space Cave":
	    p.rocks |= SPACE_CAVE;
	    break;
	case "Wide Open Spaces":
	    p.rocks |= WIDE_OPEN_SPACES;
	    break;
	case "A Simple Plant":
	case "A Complicated Plant":
	case "What a Plant!":
	    pa.plant_image = extract_choice_image();
	    break;
	case "hostile plant":
	case "large hostile plant":
	case "exotic hostile plant":
	    pa.plant_image = extract_combat_image();
	    break;
	case "The Animals, The Animals":
	case "Buffalo-Like Animal, Won't You Come Out Tonight":
	case "House-Sized Animal":
	    pa.animal_image = extract_choice_image();
	    break;
	case "small hostile animal":
	case "large hostile animal":
	case "exotic hostile animal":
	    pa.animal_image = extract_combat_image();
	    break;
	case "Interstellar Trade":
	    pa.alien_image = extract_choice_image();
	    string trade = extract_trade_item();
	    p.aliens = set_alien_item( p.aliens, item_name_to_trade[ trade ] );
	    p.price = extract_trade_item_price();
	    break;
	case "hostile intelligent alien":
	    pa.alien_image = extract_combat_image();
	    break;
	case "Here There Be No Spants":
	    // Spant Artifact
	    p.spants = set_army_type( p.spants, ARTIFACT );
	    break;
	case "Spant drone":
	    if ( ( p.spants & ARMY_TYPE_BIT_FIELD_MASK ) != SOLDIERS ) {
		p.spants = set_army_type( p.spants, DRONES );
	    }
	    break;
	case "Spant soldier": 
	    p.spants = set_army_type( p.spants, SOLDIERS );
	    break;
	case "Recovering the Satellite":
	    // Murderbot Artifact
	    p.murderbots = set_army_type( p.murderbots, ARTIFACT );
	    break;
	case "Murderbot drone":
	    if ( ( p.murderbots & ARMY_TYPE_BIT_FIELD_MASK ) != SOLDIERS ) {
		p.murderbots = set_army_type( p.murderbots, DRONES );
	    }
	    break;
	case "Murderbot soldier":
	    p.murderbots = set_army_type( p.murderbots, SOLDIERS );
	    break;
	case "Land Ho":
	    p.quest = set_ruins_quest( p.quest, SPACE_PIRATE, ONE );
	    break;
	case "Half The Ship it Used to Be":
	    p.quest = set_ruins_quest( p.quest, SPACE_PIRATE, TWO );
	    break;
	case "Paradise Under a Strange Sun":
	    p.quest = set_ruins_quest( p.quest, SPACE_PIRATE, THREE );
	    break;
	case "That's No Moonlith, it's a Monolith!":
	    p.quest = set_ruins_quest( p.quest, PROCRASTINATOR, ONE );
	    break;
	case "I'm Afraid It's Terminal":
	    p.quest = set_ruins_quest( p.quest, PROCRASTINATOR, TWO );
	    break;
	case "Curses, a Hex":
	    p.quest = set_ruins_quest( p.quest, PROCRASTINATOR, THREE );
	    break;
	case "Time Enough at Last":
	    p.quest = set_ruins_quest( p.quest, SPACE_BABY, ONE );
	    // Space Baby 1
	    break;
	case "Mother May I":
	    p.quest = set_ruins_quest( p.quest, SPACE_BABY, TWO );
	    break;
	case "Please Baby Baby Please":
	    p.quest = set_ruins_quest( p.quest, SPACE_BABY, THREE );
	    break;
	default:
	    // Unknown Spacegate encounter?
	    return;
	}

	// append encounters to list. Numbered 0-19
	encounters[ count( encounters ) ] = encounter;
    }

    void check_for_shiny( string encounter )
    {
	switch ( encounter ) {
	case "hostile intelligent alien":
	case "exotic hostile plant":
	case "exotic hostile animal":
	case "Interstellar Trade":
	case "I'm Afraid It's Terminal":
	case "Mother May I":
	case "Half The Ship it Used to Be":
	case "Curses, a Hex":
	case "Please Baby Baby Please":
	case "Paradise Under a Strange Sun": {
	    int [item] items = page.extract_items();
	    foreach it in items {
		switch ( it ) {
		case $item[ primitive alien blowgun ]:
		case $item[ primitive alien loincloth ]:
		case $item[ primitive alien necklace ]:
		case $item[ primitive alien spear ]:
		case $item[ primitive alien totem ]:
		    // Add to my_trophies where it will be saved
		    my_trophies[ coordinates ] = it.to_string();
		    // Add to planet data
		    p.aliens = set_alien_item( p.aliens, item_to_trophy[ it ] );
		    // Fall through
		    // Anomalous wildlife rare items
		case $item[ alien plant pod ]:
		case $item[ alien animal milk ]:
		    // primitive alien trade items
		case PRIMITIVE_ALIEN_BOOZE:
		case PRIMITIVE_ALIEN_MASK:
		case PRIMITIVE_ALIEN_MEDICINE:
		case PRIMITIVE_ALIEN_SALAD:
		    // Quest Step 3 unlockers
		case $item[ Procrastinator locker key ]:
		case $item[ Space Baby bawbaw ]:
		case $item[ space pirate treasure map ]:
		    // Quest Step 3 Skill Books
		case $item[ Non-Euclidean Finance ]:
		case $item[ Peek-a-Boo! ]:
		case $item[ Space Pirate Astrogation Handbook ]:
		    print( "You found a " + it + "!" );
		    shinies[it]++;
		    break;
		}
	    }
	    break;
	}
	}
    }

    void do_adventure()
    {
	string url = SPACEGATE.to_url();
	while ( energy > 0 && my_adventures() > 0 ) {
	    // Refresh mood, HP, MP
	    between_battle_checks();

	    // Visit the page and see what we have
	    page = visit_url( url );

	    // Extract the encounter
	    string encounter = get_property( "lastEncounter" );

	    // Register it: update planet info, etc.
	    register_encounter( encounter );

	    if ( encounter == "A Whole New World" ) {
		// non-combat, non-choice, no energy spent
		continue;
	    }

	    // The spacegate is out of energy for today.  You can
	    // explore another planet tomorrow.  Or the same planet, if
	    // you want.  The spacegate isn't the boss of you.
	    if ( page.contains_text( "The spacegate is out of energy for today." ) ) {
		// This is unexpected; we got the amount of remaining energy wrong?
		print( "Unexpectedly ran out of energy", "red" );
		energy = 0;
		break;
	    }

	    // A voice from the terminal says &quot;Extremely high
	    // gravity detected.  Exo-servo leg braces required for
	    // adequate mobility.&quot;
	    //
	    // This happens if you are not wearing the the correct
	    // equipment. Should only be possible if the maximizer
	    // failed because extra_maximizer_parameters prevented all
	    // required equipment from being worn. We should have
	    // detected that after running the maximizer. Abort
	    if ( page.contains_text( "A voice from the terminal says" ) ) {
		print( "Maximier failed to equip required equipment.", "red" );
		abort();
	    }

	    if ( page.contains_text( "fight.php" ) ) {
		page = run_combat();
		check_for_shiny( encounter );
		energy--;
	    } else if ( page.contains_text( "choice.php" ) ) {
		int option = choose_choice_option( p );
		page = run_choice( option );
		// If we had a non-Spacegate choice (like the
		// hallowiener dog), it used no energy
		if ( option != -1 ) {
		    check_for_shiny( encounter );
		    energy--;
		}
	    } else {
		// Counters going off can result in a blank page.  Uf you don't
		// have a counterScript, we tell KoLmafia to not stop us.
		// Ignore.
	    }
	}
    }

    void claim_research()
    {
	if ( turn_in_research ) {
	    int gemstones = item_amount( ALIEN_GEMSTONE );
	    if ( gemstones > 0 ) {
		switch ( alien_gemstone_handling ) {
		case "closet":
		    put_closet( gemstones, ALIEN_GEMSTONE );
		    break;
		case "mallsell":
		    put_shop( gemstones, 0, ALIEN_GEMSTONE );
		    break;
		case "none":
		    break;
		}
	    }

	    // Visit Spacegate R&D to claim your Spacegate Research pages
	    page = visit_url( "place.php?whichplace=spacegate&action=sg_tech" );

	    research += item_amount( SPACEGATE_RESEARCH ) - initial_research;
	}
    }

    void summarize_encounters()
    {
	print();
	print( "Today's encounters on the planet at coordinates " + coordinates + " (" + pa.name + ")" );

	summarize_encounters( encounters, research, shinies );
    }

    // Do this here so we don't report all research as new
    initial_research = item_amount( SPACEGATE_RESEARCH );

    // Visit the Spacegate Terminal and dial up the requested coordinates
    activate_spacegate();

    if ( energy == 0 ) {
	print();
	print( "You have already fully explored a Spacegate planet today." );

	// When we visited the spacegate, we created a planet object from
	// KoLmafia settings and merged it with what we found in the public
	// database. If the latter had incorrect data, we fixed it duirng the
	// merge.  Therefore, what we have is at least as good as the public
	// data, so, we may as well save it.
	save_planet( false );

	// Summarize today's adventures
	summarize_encounters();
	exit;
    }

    print();
    print( "The Spacegate terminal has " + energy + " turns of energy left in it today." );

    if ( my_inebriety() > inebriety_limit() ) {
	print( "Unfortunately, you are too drunk to explore it." );
	exit;
    }

    if ( my_adventures() < 1 ) {
	print( "Unfortunately, you don't have any turns left right now." );
	exit;
    }

    boolean dont_stop_for_counters = get_property( COUNTER_PROPERTY ).to_boolean();
    boolean reset_counter_setting = get_property( "coiunterScript" ) != "";

    try {
	if ( setup_script != "" ) {
	    cli_execute( "call " + setup_script );
	}

	if ( reset_counter_setting ) {
	    set_property( COUNTER_PROPERTY, true );
	}

	if ( p.quest != NONE ) {
	    perhaps_read_childrens_books();
	}

	suit_up();
	do_adventure();
    } finally {
	// Turn in items for Spacegate Research, with special handling for alien gemstones
	claim_research();

	// Save the list of encounters in a property for later analysis
	set_property( SPACEGATE_ENCOUNTERS_PROPERTY, to_string( encounters ) );

	// Save amount of research found in a property for later analysis
	set_property( SPACEGATE_RESEARCH_PROPERTY, to_string( research ) );

	// Save the list of shinies found in a property for later analysis
	set_property( SPACEGATE_SHINIES_PROPERTY, to_string( shinies ) );

	// Save planet data in SpacegatePlanetsMine and SpacegatePlanetsAuxMine	
	save_planet( true );

	// Save today's encounters and shinies in SpacegateVisits.<NAME>.txt
	save_spacegate_visit();

	// Summarize today's adventures
	summarize_encounters();

	if ( reset_counter_setting ) {
	    set_property( COUNTER_PROPERTY, dont_stop_for_counters );
	}
    }
}

void spacegate_status()
{
    buffer page;

    // Visit the Spacegate
    page = visit_url( "place.php?whichplace=spacegate" );

    // Approach the Spacegate Terminal
    page = visit_url( "place.php?whichplace=spacegate&action=sg_Terminal" );

    coordinates = get_property( "_spacegateCoordinates");
    if ( coordinates == "" ) {
	print( "You haven't activated the Spacegate today" );
	return;
    }

    // Load up planet data from properties set by KoLmafia when we
    // visited the terminal

    planet p = settings_to_planet();
    planet_aux pa = settings_to_planet_aux();

    // If we know the planet, merge in the 
    if ( public_planets contains coordinates ) {
	merge_planet_data( p, pa, public_planets[ coordinates ], public_planets_aux[ coordinates ] );
    } else {
	// Save the planet data
	public_planets[ coordinates ] = p;
	public_planets_aux[ coordinates ] = pa;
    }

    planet_description( coordinates );

    int energy = get_property( "_spacegateTurnsLeft" ).to_int();
    print();
    if ( energy == 0 ) {
	print( "You fully explored that planet today." );
    } else {
	print( "You have used " + ( 20 - energy ) + " turns in the Spacegate today and have " + energy + " turns available to adventure there." );
    }

    // All of today's encounters, in order. Since it's an "_" property, KoLmafia clears it every day
    string_list encounters = get_property( SPACEGATE_ENCOUNTERS_PROPERTY ).to_string_list();

    // How much Spacegate Research you gained today
    int research = get_property( SPACEGATE_RESEARCH_PROPERTY ).to_int();

    // Any rare items you acquired this run
    item_count_map shinies = get_property( SPACEGATE_SHINIES_PROPERTY ).to_item_count_map();

    summarize_encounters( encounters, research, shinies );
}

void main( string command )
{
    // Set configuration variables
    if ( !parse_command( command ) ||
	 !validate_configuration() ) {
	exit;
    }

    // Load all known planets
    load_planet_data();

    if ( current_mode == STATUS ) {
	spacegate_status();
	exit;
    }

    planet_map candidates;

    if ( coordinates == "" ) {
	// Specified goals but not coordinates. Choose a planet to use
	candidates = planets_for_goals( public_planets, desired_goals, minimum_difficulty, maximum_difficulty, false, buy_trade_item );

	if ( count( candidates ) == 0 ) {
	    print( "I'm sorry. I don't know any planets that satisfy all of your requirements" );
	    exit;
	}

	coordinates = select_hardest_planet( candidates );
    } else if ( coordinates == "KNOWN" ) {
	// Specified goals but not coordinates. Choose a planet to use
	candidates = planets_for_goals( public_planets, desired_goals, minimum_difficulty, maximum_difficulty, true, buy_trade_item );

	if ( count( candidates ) == 0 ) {
	    print( "I'm sorry. I don't know any planets that satisfy all of your requirements" );
	    exit;
	}

	coordinates = select_random_planet( candidates );
    } else if ( coordinates == "UNVISITED" ) {
	// Specified goals but not coordinates. Choose a planet to use
	candidates = planets_for_goals( unvisited_planets, desired_goals, minimum_difficulty, maximum_difficulty, true, buy_trade_item );

	if ( count( candidates ) == 0 ) {
	    print( "I'm sorry. I don't know any planets that satisfy all of your requirements" );
	    exit;
	}

	coordinates = select_random_planet( candidates );
    } else if ( coordinates == "VALIDATED" ) {
	// Specified goals but not coordinates. Choose a planet to use
	candidates = planets_for_goals( visited_planets, desired_goals, minimum_difficulty, maximum_difficulty, true, buy_trade_item );

	if ( count( candidates ) == 0 ) {
	    print( "I'm sorry. I don't know any planets that satisfy all of your requirements" );
	    exit;
	}

	coordinates = select_random_planet( candidates );
    }

    if ( current_mode == COUNT ) {
	exit;
    }

    if ( current_mode == LIST ) {
	foreach coords, p in candidates {
	    print( coords );
	}
	exit;
    }

    print();
    print( "I suggest that you visit the planet at coordinates " + coordinates );
    if ( public_planets contains coordinates ) {
	planet winner = public_planets[ coordinates ];
	print( "Here's what I know about that planet: " );
	print();
	planet_description( coordinates );
    } else {
	print( "I know nothing about that planet. Go forth and explore it. Have fun, but be careful!" );
    }

   if ( current_mode == SUGGEST ) {
	exit;
    }

    // If we are "automating" (or "visiting") go there now
    visit_spacegate( coordinates );
}