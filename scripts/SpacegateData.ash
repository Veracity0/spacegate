since r18937;

typedef string [int] string_list;
typedef boolean [string] string_set;

// ***************************
//        Planet Data        *
// ***************************

// A planet's coordinates consist of seven letters.
//
// The first letter determines the planet's difficulty: 0 - 15
//
// The remaining six letters allow for 26**6 = 308,915,776 variations.
// That is about 28.5 bits worth of data.
//
// Some of the variation is strictly cosmetic: the planet name, the
// description of the suns, moons, rings, and atmosphere, which image is
// shown for the plants, animals, and aliens that reside on the planet.
//
// All of that is the same every time you visit the same coordinated, so
// it is derived from the data - likely by selecting from the bits that
// specify meaningful differences.
//
// For simplicity, I am modeling planet data as a concatenation of bit
// fields. See "vcode", later.
//
// That is almost certainly not how KoL models it, as it wastes bits.
// For example, if a friendly alien can have one of 4 items and a
// hostile alien can have one of 5 items, a number from 0-9 could encode
// whether the planet has aliens, whether they are hostile, and which
// item they drop. My vcode uses five bits to encode aliens, but KoL
// probably does something like "( (accumulated value*10) + (val % 10) ).
// 
// KoL also knows exactly what is present on a planet but displays less
// than full information when you visit the Spacegate terminal.
//
// Murderbots: none, Recovering the Satellite, drones, drones + soldiers.
// Spants: none, Spant egg casings, drones, drones + soldiers.
//
// For each of those, 4 possibilities - 2 bits - but they all display as
// simply "DANGER: Murderbot frequencies detected" or "DANGER: Spant
// chemical traces detected" at the terminal.
//
// Since I want to be able to represent what we know about a planet from
// the terminal and also from the full information we gain from
// exploring, we have, essentially, 5 values:
//    none, detected, artifact, drones, soldiers
// (where the first two come from the terminal and the last 3 come from exploration.) 
//
// Murderbots: 3 bits, rather than 2
// Spants: 3 bits, rather than 2
// Aliens: (none, friendly, hostile) (one of 5 items): 5 bits, rather than 4
// Ruins (none, detected, Procrastinator, Space Pirate, Space Baby), (one, two, three): 5 bits, rather than 4
//
// Planet name and price for the avilable trade good from friendly
// aliens is undoubtedly also procedurally generated, but I include them
// in the data structure but not in the vcode
//
// Rocks. There are three NCs that give you rocks:
//	Wide Open Spaces	rocks, core sample
//	Space Cave		rocks, core sample, leave
//	Cool Space Rocks	rocks, core sample
// Space Cave has an option to skip the NC. The others are required.
// 
// I initially thought that all planets have all three kinds of rock
// adventures, but I have seen enough that have only one - Space Cave -
// or two - Space Cave and one other - that types of rocks must be a
// planetary parameter.
//
// For now, use 3 bits - one per rock type.
//
// Purely cosmetic things that KoL manages to procedurally generate from
// a 7-letter corrdinate code that we don't track:
// 
// Description: suns, moons, atmosphere, rings, etc.
// Which of 10 friendly intelligent alien images
// Which of 10 hostile intelligent alien images
// Which of 20 hostile plant images
// Which of 10 large hostile plant images
// Which of 3 exotic hostile plant images
// Which of 20 small hostile animal images
// Which of 10 large hostile animal images
// Which of 3 exotic hostile animal images
//
// KoL likely generates these by selecting (n) bytes from the code and
// modding them with the number of possibilities.
//
// Additional things that may be actually encoded in the planet
// cooridinate by KoL or which are not encoded, but which determine
// number and type of encounters:
//
// Friendly Aliens and Alien Ruins appear exactly once
//
// Rocks. There are three kinds of rock adventures. Do all three appear
// on planets that have rocks? Is there a 3-eide bitfield allowing any
// combination>? Do only some planets have Space Caves (say) but all
// planets have the other two?
//
// Number of encounters when you have multiple of (plants, animals,
// hostile aliens, spants, murderbots). The Wiki (and spreadsheet) list
// certain planets as having "maximum anomalous plants", say - and give
// one set of encounters where 6 appeared. But that planet also had
// hostile primitive animals and Murderbot warriors and drones. When I
// went there, I found three hostile anomalous plants - and more animals
// and Murderbots.
//
// I hypothesize that if there is one kind of life, there will be (say)
// 5-6 of it, if two, there will be (say) 9-10, split among the two, if
// 3, ...  and so on. Which is to say, randomness determines how the
// multiple kinds of life are distributed.
//
// Figuring out those distributions would require multiple runs on
// planets with (1, 2, 3, 4, 5) kinds of life.
//
// For the purpose of this script, I simply record what kinds of life
// appear without saying "there are 5 of such-and-such kinf".

// I encode all the parameters as bit fields of integers. This is less
// readable when looking at the "planet" data structure, but makes
// conversion to/from the vcode easier.

static int NONE = 0;		// For any field
static int DETECTED = 1;	// for murderbots, spants, and ruins
static int HOSTILE = 1;		// for animals, plants, and aliens
static int FRIENDLY = 2;	// for aliens
static int UNKNOWN = 0;		// For alien item, murderbots, spants, ruin race, ruin step

// 5-bit field for (environemntal, elemental) hazards. A planet will
// have from 1-3 enviromental and 0-3 elemental hazards.
static int HAZARDS_BITS = 5;
typedef int hazard;
typedef string [hazard] hazmap;

string hazards_to_string( hazard haz, hazmap map )
{
    buffer out;
    for ( hazard bit = 1; bit <= 16; bit <<= 1 ) {
	if ( ( haz & bit ) != 0 ) {
	    if ( out.length() > 0 ) {
		out.append( ", " );
	    }
	    out.append( map[ bit ] );
	}
    }
    return out.length() == 0 ? "none" : out.to_string();
}

static string_set ENVIRONMENTAL_HAZARDS = $strings[magnetic storms, high winds, irradiated, toxic atmosphere, high gravity];
// static int NONE = 0;		// No environmental hazard (not possible)
static hazard TOXIC_ATMOSPHERE = 1 << 0;
static hazard HIGH_GRAVITY = 1 << 1;
static hazard IRRADIATED = 1 << 2;
static hazard MAGNETIC_STORMS = 1 << 3;
static hazard HIGH_WINDS = 1 << 4;

static hazmap hazard_to_environmental = {
    MAGNETIC_STORMS : "magnetic storms" ,
    HIGH_WINDS : "high winds",
    IRRADIATED : "irradiated",
    TOXIC_ATMOSPHERE : "toxic atmosphere",
    HIGH_GRAVITY : "high gravity",
};

static item [hazard] hazard_to_equipment = {
    MAGNETIC_STORMS : $item[gate transceiver],
    HIGH_WINDS : $item[high-friction boots],
    IRRADIATED : $item[rad cloak],
    TOXIC_ATMOSPHERE : $item[filter helmet],
    HIGH_GRAVITY : $item[exo-servo leg braces],
};

string environmental_hazards_to_string( hazard haz )
{
    return hazards_to_string( haz, hazard_to_environmental );
}

static string_set ELEMENTAL_HAZARDS = $strings[hot solar flares, frigid zones, scary noises, nasty gasses, lewd rock formations];
// static int NONE = 0;		// No elemental hazard
static hazard HOT_SOLAR_FLARES = 1 << 0;
static hazard FRIGID_ZONES = 1 << 1;
static hazard SCARY_NOISES = 1 << 2;
static hazard NASTY_GASSES = 1 << 3;
static hazard LEWD_ROCK_FORMATIONS = 1 << 4;

static hazmap hazard_to_elemental = {
    HOT_SOLAR_FLARES : "hot solar flares",
    FRIGID_ZONES : "frigid zones",
    SCARY_NOISES : "scary noises",
    NASTY_GASSES : "nasty gasses",
    LEWD_ROCK_FORMATIONS : "lewd rock formations",
};

static element [hazard] hazard_to_element = {
    HOT_SOLAR_FLARES : $element[hot],
    FRIGID_ZONES : $element[cold],
    SCARY_NOISES : $element[spooky],
    NASTY_GASSES : $element[stench],
    LEWD_ROCK_FORMATIONS : $element[sleaze],
};

string elemental_hazards_to_string( hazard haz )
{
    return hazards_to_string( haz, hazard_to_elemental );
}

// All hazards
static hazard [string] name_to_hazard = {
    "magnetic storms" : MAGNETIC_STORMS,
    "high winds" : HIGH_WINDS,
    "irradiated" : IRRADIATED,
    "toxic atmosphere": TOXIC_ATMOSPHERE,
    "high gravity" : HIGH_GRAVITY,
    "hot solar flares" : HOT_SOLAR_FLARES,
    "frigid zones" : FRIGID_ZONES,
    "scary noises" : SCARY_NOISES,
    "nasty gasses" : NASTY_GASSES,
    "lewd rock formations" : LEWD_ROCK_FORMATIONS,
};

// 3 bit field for wildlife: hostile & type
static int WILDLIFE_BITS = 3;
static int WILDLIFE_HOSTILE_BIT_FIELD_OFFSET = 0;
static int WILDLIFE_HOSTILE_BIT_FIELD_MASK = 1;
static int WILDLIFE_TYPE_BIT_FIELD_OFFSET = 1;
static int WILDLIFE_TYPE_BIT_FIELD_MASK = 3;

typedef int wildlife;
// static int NONE = 0;		// No wildlife
// static int HOSTILE = 1;	// (bit) identified or unidentified
static int SIMPLE = 1 << 1;	// (bit field)
static int COMPLEX = 2 << 1;
static int ANOMALOUS = 3 << 1;

string wildlife_to_string( wildlife life )
{
    switch ( life ) {
    case NONE:
	return "none";
    case HOSTILE:
	// Should not be possible; the terminal tells us the complexity
	return "hostile";
    case SIMPLE:
	return "primitive";
    case COMPLEX:
	return "advanced";
    case ANOMALOUS:
	return "anomalous";
    case SIMPLE+HOSTILE:
	return "primitive (hostile)";
    case COMPLEX+HOSTILE:
	return "advanced (hostile)";
    case ANOMALOUS+HOSTILE:
	return "anomalous (hostile)";
    }
    return "unknown";
}

// 5 bit field for aliens: detected & item
static int ALIEN_BITS = 5;
static int ALIEN_TYPE_BIT_FIELD_OFFSET = 0;
static int ALIEN_TYPE_BIT_FIELD_MASK = 3 << ALIEN_TYPE_BIT_FIELD_OFFSET;
static int ALIEN_ITEM_BIT_FIELD_OFFSET = 2;
static int ALIEN_ITEM_BIT_FIELD_MASK = 7 << ALIEN_ITEM_BIT_FIELD_OFFSET ;

typedef int intelligence;
// static int NONE = 0;		// No intelligent life
// static int HOSTILE = 1;	// item identified or unidentified
// static int FRIENDLY = 2;	// item identified or unidentified
// static int UNKNOWN = 0;	// (non-hostile) unidentified trade item
static int SALAD = 1 << 2;	// (non-hostile) primitive alien salad
static int BOOZE = 2 << 2;	// (non-hostile) primitive alien booze
static int MEDICINE = 3 << 2;	// (non-hostile) primitive alien medicine
static int MASK = 4 << 2;	// (non-hostile) primitive alien mask
// static int UNKNOWN = 0;	// (hostile) unidentified trophy item
static int SPEAR = 1 << 2;	// (hostile) primitive alien spear
static int BLOWGUN = 2 << 2;	// (hostile) primitive alien blowgun
static int LOINCLOTH = 3 << 2;	// (hostile) primitive alien loincloth
static int TOTEM = 4 << 2;	// (hostile) primitive alien totem
static int NECKLACE = 5 << 2;	// (hostile) primitive alien necklace

string intelligence_to_string( intelligence i )
{
    intelligence type = i & ALIEN_TYPE_BIT_FIELD_MASK;
    return
	( type == NONE ) ? "none" :
	( type == HOSTILE ) ? "hostile" :
	( type == FRIENDLY ) ? "friendly" :
	"bogus";
}

// intelligence & ALIEN_ITEM_BIT_FIELD_MASK
static string [int] trophy_to_name = {
    UNKNOWN : "unknown alien trophy",
    SPEAR : "primitive alien spear",
    BLOWGUN : "primitive alien blowgun",
    LOINCLOTH : "primitive alien loincloth",
    TOTEM : "primitive alien totem",
    NECKLACE : "primitive alien necklace",
};

static int [string] item_name_to_trophy = {
    "primitive alien spear" : SPEAR,
    "primitive alien blowgun" : BLOWGUN,
    "primitive alien loincloth" : LOINCLOTH,
    "primitive alien totem" : TOTEM,
    "primitive alien necklace" : NECKLACE,
};

static item [int] trophy_to_item = {
    SPEAR : $item[ primitive alien spear ],
    BLOWGUN : $item[ primitive alien blowgun ],
    LOINCLOTH : $item[ primitive alien loincloth ],
    NECKLACE : $item[ primitive alien necklace ],
    TOTEM : $item[ primitive alien totem ],
};

static int [item] item_to_trophy = {
    $item[ primitive alien spear ] : SPEAR,
    $item[ primitive alien blowgun ] : BLOWGUN,
    $item[ primitive alien loincloth ] : LOINCLOTH,
    $item[ primitive alien necklace ] : NECKLACE,
    $item[ primitive alien totem ] : TOTEM,
};

// intelligence & ALIEN_ITEM_BIT_FIELD_MASK
static string [int] trade_item_to_name = {
    UNKNOWN : "unknown alien trade item",
    SALAD : "primitive alien salad",
    BOOZE : "primitive alien booze",
    MEDICINE : "primitive alien medicine",
    MASK : "primitive alien mask",
};

static item [int] trade_item_to_item = {
    UNKNOWN : $item[ none ],
    SALAD : $item[ primitive alien salad ],
    BOOZE : $item[ primitive alien booze ],
    MEDICINE : $item[ primitive alien medicine ],
    MASK : $item[ primitive alien mask ],
};

static int [string] item_name_to_trade = {
    "primitive alien salad" : SALAD,
    "primitive alien booze" : BOOZE,
    "primitive alien medicine": MEDICINE,
    "primitive alien mask": MASK,
};

// 3 bit field for army: detected & type
static int ARMY_DETECTED_BIT_FIELD_OFFSET = 0;
static int ARMY_DETECTED_BIT_FIELD_MASK = 1 << ARMY_DETECTED_BIT_FIELD_OFFSET;
static int ARMY_TYPE_BIT_FIELD_OFFSET = 1;
static int ARMY_TYPE_BIT_FIELD_MASK = 3 << ARMY_TYPE_BIT_FIELD_OFFSET;

typedef int army;
// static int NONE = 0;		// No Murderbots or Spants
// static int DETECTED = 1;	// Detected, but encounter type not known
// static int UNKNOWN = 0;	// Encounter type
static int ARTIFACT = 1 << 1;	// Murderbot data core or Spant egg casing
static int DRONES = 2 << 1;	// Murderbot drone or Spant drone
static int SOLDIERS = 3 << 1;	// Murderbot drone & soldier or Spant drone & soldier

string army_detected_to_string( army a )
{
    return ( ( a & DETECTED ) == DETECTED ) ? "detected" : "not detected";
}

string army_type_to_string( army a )
{
    int type = a & ARMY_TYPE_BIT_FIELD_MASK;
    return
	( type == ARTIFACT ) ? "artifact" :
	( type == DRONES ) ? "drones" :
	( type == SOLDIERS ) ? "soldiers" :
	"unknown";
}

// 5 bit field for ruins: detected & language & step
static int RUINS_DETECTED_BIT_FIELD_OFFSET = 0;
static int RUINS_DETECTED_BIT_FIELD_MASK = 1 << RUINS_DETECTED_BIT_FIELD_OFFSET;
static int RUINS_LANGUAGE_BIT_FIELD_OFFSET = 1;
static int RUINS_LANGUAGE_BIT_FIELD_MASK = 3 << RUINS_LANGUAGE_BIT_FIELD_OFFSET;
static int RUINS_STEP_BIT_FIELD_OFFSET = 3;
static int RUINS_STEP_BIT_FIELD_MASK = 3 << RUINS_STEP_BIT_FIELD_OFFSET;

typedef int ruins;
typedef int language;
typedef int step;
// static int NONE = 0;		// No ruins
// static int DETECTED = 1;	// Detected, but details not known
// static int UNKNOWN = 0;	// Alien Language
static language SPACE_PIRATE = 1 << 1;		// Space Pirate
static language PROCRASTINATOR = 2 << 1;	// Procrastinator
static language SPACE_BABY = 3 << 1;		// Space Baby
// static int UNKNOWN = 0;	// Quest Step
static step ZERO = 0;		// Setup noncombat
static step ONE = 1 << 3;	// First choice adventure
static step TWO = 2 << 3;	// Second choice adventure
static step THREE = 3 << 3;	// Third choice adventure

string ruins_detected_to_string( ruins r )
{
    return ( ( r & DETECTED ) == DETECTED ) ? "detected" : "not detected";
}

static string [language][step] quest_steps = {
   SPACE_PIRATE : {
      ONE: "Land Ho",
      TWO: "Half the Ship it Used to Be",
      THREE: "Paradise under a Strange Sun"
   },
   PROCRASTINATOR : {
      ZERO: "Recovering the Satellite",
      ONE: "That's No Moonlith, it's a Monolith!",
      TWO: "I'm Afraid It's Terminal",
      THREE: "Curses, a Hex"
   },
   SPACE_BABY : {
      ONE: "Time Enough at Last",
      TWO: "Mother May I",
      THREE: "Please Baby Baby Please"
   },
};

static string [language] lang_to_string = {
   SPACE_PIRATE : "Space Pirates",
   PROCRASTINATOR : "Procrastinators",
   SPACE_BABY : "Space Baby",
};

static int [step] step_to_int = {
   ONE : 1,
   TWO : 2,
   THREE : 3,
};

string ruins_type_and_step_to_string( ruins r )
{
    language lang = ( r & RUINS_LANGUAGE_BIT_FIELD_MASK );
    step st = ( r & RUINS_STEP_BIT_FIELD_MASK );
    return lang_to_string[lang] + " " + step_to_int[st] + ": " + quest_steps[lang][st];
}

// 3 bit field for rocks
static int ROCKS_BITS = 3;
static int SPACE_CAVE = 1 << 0;
static int COOL_SPACE_ROCKS = 1 << 1;
static int WIDE_OPEN_SPACES = 1 << 2;

typedef int samples;

string samples_to_string( samples rocks )
{
    switch ( rocks ) {
    case NONE:
	return "none";
    case SPACE_CAVE:
	return "Space Cave";
    case COOL_SPACE_ROCKS:
	return "Cool Space Rocks";
    case WIDE_OPEN_SPACES:
	return "Wide Open Spaces";
    case SPACE_CAVE+COOL_SPACE_ROCKS:
	return "Space Cave & Cool Space Rocks";
    case SPACE_CAVE+WIDE_OPEN_SPACES:
	return "Space Cave & Wide Open Spaces";
    case COOL_SPACE_ROCKS+WIDE_OPEN_SPACES:
	return "Cool Space Rocks & Wide Open Spaces";
    case SPACE_CAVE+COOL_SPACE_ROCKS+WIDE_OPEN_SPACES:
	return "Space Cave & Cool Space Rocks & Wide Open Spaces";
    }
    return "unknown";
}

// Gameplay affecting planet parameters
record planet
{
    int index;			// 0 - 25
    hazard environments;	// HIGH_WINDS
    hazard elements;		// HOT_SOLAR_FLARES+FRIGID_ZONES
    wildlife plants;		// HOSTILE+SIMPLE
    wildlife animals;		// ANOMALOUS
    intelligence aliens;	// MASK or HOSTILE+SPEAR
    int price;			// 124000
    army murderbots;		// NONE
    army spants;		// NONE
    ruins quest;		// SPACE_PIRATE+TWO
    samples rocks;		// SPACE_CAVE+COOL_SPACE_ROCKS
};

planet copy_planet( planet orig )
{
    planet p;
    p.index = orig.index;
    p.environments = orig.environments;
    p.elements = orig.elements;
    p.plants = orig.plants;
    p.animals = orig.animals;
    p.aliens = orig.aliens;
    p.price = orig.price;
    p.murderbots = orig.murderbots;
    p.spants = orig.spants;
    p.quest = orig.quest;
    p.rocks = orig.rocks;
    return p;
}

planet encounters_to_planet( planet template, string_list encounters, string_list shinies )
{
    // Not everything can be deduced from encounters. Create a planet
    // preloaded with data from elsewhere
    planet p = template.copy_planet();
    
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
	    p.plants = SIMPLE;
	    break;
	case "A Complicated Plant":
	    p.plants = COMPLEX;
	    break;
	case "What a Plant!":
	    p.plants = ANOMALOUS;
	    break;
	case "hostile plant":
	    p.plants = HOSTILE+SIMPLE;
	    break;
	case "large hostile plant":
	    p.plants = HOSTILE+COMPLEX;
	    break;
	case "exotic hostile plant":
	    p.plants = HOSTILE+ANOMALOUS;
	    break;
	case "The Animals, The Animals":
	    p.animals = SIMPLE;
	    break;
	case "Buffalo-Like Animal, Won't You Come Out Tonight":
	    p.animals = COMPLEX;
	    break;
	case "House-Sized Animal":
	    p.animals = ANOMALOUS;
	    break;
	case "small hostile animal":
	    p.animals = HOSTILE+SIMPLE;
	    break;
	case "large hostile animal":
	    p.animals = HOSTILE+COMPLEX;
	    break;
	case "exotic hostile animal":
	    p.animals = HOSTILE+ANOMALOUS;
	    break;
	case "Interstellar Trade":
	    p.aliens &= ~ALIEN_TYPE_BIT_FIELD_MASK;
	    p.aliens |= FRIENDLY;
	    break;
	case "hostile intelligent alien":
	    p.aliens &= ~ALIEN_TYPE_BIT_FIELD_MASK;
	    p.aliens |= HOSTILE;
	    break;
	case "Here There Be No Spants":
	    // Spant Artifact
	    p.spants = DETECTED+ARTIFACT;
	    break;
	case "Spant drone":
	    if ( ( p.spants & ARMY_TYPE_BIT_FIELD_MASK ) != SOLDIERS ) {
		p.spants = DETECTED+DRONES;
	    }
	    break;
	case "Spant soldier": 
	    p.spants = DETECTED+SOLDIERS;
	    break;
	case "Recovering the Satellite":
	    // Murderbot Artifact
	    p.murderbots = DETECTED+ARTIFACT;
	    break;
	case "Murderbot drone":
	    if ( ( p.murderbots & ARMY_TYPE_BIT_FIELD_MASK ) != SOLDIERS ) {
		p.murderbots = DETECTED+DRONES;
	    }
	    break;
	case "Murderbot soldier":
	    p.murderbots = DETECTED+SOLDIERS;
	    break;
	case "Land Ho":
	    p.quest = DETECTED+SPACE_PIRATE+ONE;
	    break;
	case "Half The Ship it Used to Be":
	    p.quest = DETECTED+SPACE_PIRATE+TWO;
	    break;
	case "Paradise Under a Strange Sun":
	    p.quest = DETECTED+SPACE_PIRATE+THREE;
	    break;
	case "That's No Moonlith, it's a Monolith!":
	    p.quest = DETECTED+PROCRASTINATOR+ONE;
	    break;
	case "I'm Afraid It's Terminal":
	    p.quest = DETECTED+PROCRASTINATOR+TWO;
	    break;
	case "Curses, a Hex":
	    p.quest = DETECTED+PROCRASTINATOR+THREE;
	    break;
	case "Time Enough at Last":
	    p.quest = DETECTED+SPACE_BABY+ONE;
	    // Space Baby 1
	    break;
	case "Mother May I":
	    p.quest = DETECTED+SPACE_BABY+TWO;
	    break;
	case "Please Baby Baby Please":
	    p.quest = DETECTED+SPACE_BABY+THREE;
	    break;
	default:
	    // Unknown Spacegate encounter?
	    break;
	}
    }

    foreach index, shiny in shinies {
	switch ( shiny ) {
	case "primitive alien blowgun":
	case "primitive alien loincloth":
	case "primitive alien necklace":
	case "primitive alien spear":
	case "primitive alien totem":
	    p.aliens |= item_name_to_trophy[ shiny ];
	    break;
	case "primitive alien booze":
	case "primitive alien mask":
	case "primitive alien medicine":
	case "primitive alien salad":
	    p.aliens |= item_name_to_trade[ shiny ];
	    break;
	}
    }

    return p;
}

// Purely cosmetic planet parameters
record planet_aux
{
    string name;		// Gamma Bob VIII
    string sky;			// The planet's sky is a deep green, dominated by a system of pale blue rings.
    string suns;		// The system's twin blue suns loom above you.
    string moons;		// Three shimmering moons hang in the sky.
    string plant_image;		// sgplantc1.gif
    string animal_image;	// sganimalb1.gif
    string alien_image;		// sgalienb3.gif
};

// KoLMafia will set a variety of settings when you visit the Spacegate
// terminal. We can construct a planet object from those. It will be
// incomplete; Murderbots, Spants, and Alien Ruins are "detected", with
// no identification.

planet settings_to_planet()
{
    planet p;

    // _spacegateCoordinates	ZLSVLJL

    p.index = get_property( "_spacegatePlanetIndex" ).to_int();

    hazard environmentals = 0;
    hazard elementals = 0;

    string hazards = get_property( "_spacegateHazards" );
    foreach index, name in split_string( hazards, "\\|" ) {
	if ( ENVIRONMENTAL_HAZARDS contains name ) {
	    environmentals |=  name_to_hazard[ name ];
	} else if ( ELEMENTAL_HAZARDS contains name ) {
	    elementals |= name_to_hazard[ name ];
	}
    }

    p.environments = environmentals;
    p.elements = elementals;

    string pprop = get_property( "_spacegatePlantLife" );
    wildlife plants =
	pprop == "primitive" ? SIMPLE :
	pprop == "primitive (hostile)" ? SIMPLE+HOSTILE :
	pprop == "advanced" ? COMPLEX :
	pprop == "advanced (hostile)" ? COMPLEX+HOSTILE :
	pprop == "anomalous" ? ANOMALOUS :
	pprop == "anomalous (hostile)" ? ANOMALOUS+HOSTILE :
	NONE;
    p.plants = plants;

    string aprop = get_property( "_spacegateAnimalLife" );
    wildlife animals =
	aprop == "primitive" ? SIMPLE :
	aprop == "primitive (hostile)" ? SIMPLE+HOSTILE :
	aprop == "advanced" ? COMPLEX :
	aprop == "advanced (hostile)" ? COMPLEX+HOSTILE :
	aprop == "anomalous" ? ANOMALOUS :
	aprop == "anomalous (hostile)" ? ANOMALOUS+HOSTILE :
	NONE;
    p.animals = animals;

    string iprop = get_property( "_spacegateIntelligentLife" );
    intelligence aliens =
	iprop == "detected" ? FRIENDLY :
	iprop == "detected (hostile)" ? HOSTILE :
	NONE;
    p.aliens = aliens;
    p.price = 0;

    p.murderbots = get_property( "_spacegateMurderbot" ).to_boolean() ? DETECTED : NONE;
    p.spants = get_property( "_spacegateSpant" ).to_boolean() ? DETECTED : NONE;
    p.quest = get_property( "_spacegateRuins" ).to_boolean() ? DETECTED : NONE;

    p.rocks = NONE;

    return p;
}

planet_aux settings_to_planet_aux()
{
    planet_aux pa;

    pa.name = get_property( "_spacegatePlanetName" );

    return pa;
}

record planet_difficulty
{
    int index;
    int environmental;
    int elemental;
};

planet_difficulty [string] hazard_level = {
    // A-E: 1 environmental, 0 elemental
    "A": new planet_difficulty( 0, 1, 0 ),
    "B": new planet_difficulty( 1, 1, 0 ),
    "C": new planet_difficulty( 2, 1, 0 ),
    "D": new planet_difficulty( 3, 1, 0 ),
    "E": new planet_difficulty( 4, 1, 0 ),
    // F-I: 1 environmental, 1 elemental
    "F": new planet_difficulty( 5, 1, 1 ),
    "G": new planet_difficulty( 6, 1, 1 ),
    "H": new planet_difficulty( 7, 1, 1 ),
    "I": new planet_difficulty( 8, 1, 1 ),
    // J-O: 2 environmental, 1 elemental
    "J": new planet_difficulty( 9, 2, 1 ),
    "K": new planet_difficulty( 10, 2, 1 ),
    "L": new planet_difficulty( 11, 2, 1 ),
    "M": new planet_difficulty( 12, 2, 1 ),
    "N": new planet_difficulty( 13, 2, 1 ),
    "O": new planet_difficulty( 14, 2, 1 ),
    // P-S: 2 environmental, 2 elemental
    "P": new planet_difficulty( 15, 2, 2 ),
    "Q": new planet_difficulty( 16, 2, 2 ),
    "R": new planet_difficulty( 17, 2, 2 ),
    "S": new planet_difficulty( 18, 2, 2 ),
    // T-Y: 3 environmental, 2 elemental
    "T": new planet_difficulty( 19, 3, 2 ),
    "U": new planet_difficulty( 20, 3, 2 ),
    "V": new planet_difficulty( 21, 3, 2 ),
    "W": new planet_difficulty( 22, 3, 2 ),
    "X": new planet_difficulty( 23, 3, 2 ),
    "Y": new planet_difficulty( 24, 3, 2 ),
    // Z: 3 environmental, 3 elemental
    "Z": new planet_difficulty( 25, 3, 3 ),
};

string [int] difficulty_to_coordinate = {
     0 : "A",
     1 : "B",
     2 : "C",
     3 : "D",
     4 : "E",
     5 : "F",
     6 : "G",
     7 : "H",
     8 : "I",
     9 : "J",
     10 : "K",
     11 : "L",
     12 : "M",
     13 : "N",
     14 : "O",
     15 : "P",
     16 : "Q",
     17 : "R",
     18 : "S",
     19 : "T",
     20 : "U",
     21 : "V",
     22 : "W",
     23 : "X",
     24 : "Y",
     25 : "Z",
};

planet_difficulty coordinates_to_difficulty( string coordinates )
{
    string letter = coordinates.substring( 0, 1 );
    return hazard_level[ letter ];
}

int monster_scale( planet_difficulty difficulty )
{
    return 10 + 25 * difficulty.index;
}

// ***************************
//        Planet Code        *
// ***************************

typedef int planet_code;

// 53353355  (32 bits)
// ||||||||> Environmental Hazards: (1-3) MAGNETIC_STORMS, HIGH WINDS, IRRADIATED, TOXIC_ATMOSPHERE, HIGH GRVITY
// ||||||--> Elemental Hazards: (0-3) HOT_SOLAR_FLARES, FRIGID_ZONES, SCARY_NOISES, NASTY_GASSES, LEWD_ROCK_FORMATIONS
// |||||---> Plants: NONE, (HOSTILE), (SIMPLE, COMPLEX, ANOMALOUS)
// ||||----> Animals: NONE, (HOSTILE), (SIMPLE, COMPLEX, ANOMALOUS)
// |||-----> Aliens: (NONE, HOSTILE, FRIENDLY), (UNKNOWN, SALAD, BOOZE, MEDICINE, MASK), (UNKNOWN, SPEAR, BLOWGUN, LOINCLOTH, TOTEM, NECKLACE)
// ||------> Murderbots: (NONE, DETECTED), (UNKNOWN, ARTIFACT, DRONES, SOLDIERS)
// |-------> Spants: (NONE, DETECTED), (UNKNOWN, ARTIFACT, DRONES, SOLDIERS)
// --------> Ruins: (NONE, DETECTED), (UNKNOWN, SPACE_PIRATE, PROCRASTINATOR, SPACE_BABY), (UNKNOWN, ONE, TWO, THREE)

static int ENVIRONMENT_OFFSET = 0;
static int ENVIRONMENT_BITS = 5;
static int ENVIRONMENT_MASK = ( ( 1 << ENVIRONMENT_BITS ) - 1) << ENVIRONMENT_OFFSET;

static int ELEMENT_OFFSET = ENVIRONMENT_OFFSET + ENVIRONMENT_BITS;
static int ELEMENT_BITS = 5;
static int ELEMENT_MASK = ( ( 1 << ELEMENT_BITS ) - 1) << ELEMENT_OFFSET;

static int PLANTS_OFFSET = ELEMENT_OFFSET + ELEMENT_BITS;
static int PLANTS_BITS = 3;
static int PLANTS_MASK = ( ( 1 << PLANTS_BITS ) - 1) << PLANTS_OFFSET;

static int ANIMALS_OFFSET = PLANTS_OFFSET + PLANTS_BITS;
static int ANIMALS_BITS = 3;
static int ANIMALS_MASK = ( ( 1 << ANIMALS_BITS ) - 1) << ANIMALS_OFFSET;

static int ALIENS_OFFSET = ANIMALS_OFFSET + ANIMALS_BITS;
static int ALIENS_BITS = 5;
static int ALIENS_MASK = ( ( 1 << ALIENS_BITS ) - 1) << ALIENS_OFFSET;

static int MURDERBOTS_OFFSET = ALIENS_OFFSET + ALIENS_BITS;
static int MURDERBOTS_BITS = 3;
static int MURDERBOTS_MASK = ( ( 1 << MURDERBOTS_BITS ) - 1) << MURDERBOTS_OFFSET;

static int SPANTS_OFFSET = MURDERBOTS_OFFSET + MURDERBOTS_BITS;
static int SPANTS_BITS = 3;
static int SPANTS_MASK = ( ( 1 << SPANTS_BITS ) - 1) << SPANTS_OFFSET;

static int RUINS_OFFSET = SPANTS_OFFSET + SPANTS_BITS;
static int RUINS_BITS = 5;
static int RUINS_MASK = ( ( 1 << RUINS_BITS ) - 1) << RUINS_OFFSET;

int planet_to_code( planet p )
{
    int code = 0;

    hazard env = p.environments;
    code += ( ( env << ENVIRONMENT_OFFSET ) & ENVIRONMENT_MASK );

    hazard elm = p.elements;
    code += ( ( elm << ELEMENT_OFFSET ) & ELEMENT_MASK );

    wildlife plants = p.plants;
    code += ( ( plants << PLANTS_OFFSET ) & PLANTS_MASK );

    wildlife animals = p.animals;
    code += ( ( animals << ANIMALS_OFFSET ) & ANIMALS_MASK );

    intelligence aliens = p.aliens;
    code += ( ( aliens << ALIENS_OFFSET ) & ALIENS_MASK );

    army murderbots = p.murderbots;
    code += ( ( murderbots << MURDERBOTS_OFFSET ) & MURDERBOTS_MASK );

    army spants = p.spants;
    code += ( ( spants << SPANTS_OFFSET ) & SPANTS_MASK );

    ruins quest = p.quest;
    code += ( ( quest << RUINS_OFFSET ) & RUINS_MASK );

    return code;
}

planet code_to_planet( int code )
{
    planet p;

    p.environments = ( code & ENVIRONMENT_MASK ) >> ENVIRONMENT_OFFSET;
    p.elements = ( code & ELEMENT_MASK ) >> ELEMENT_OFFSET;
    p.plants = ( code & PLANTS_MASK ) >> PLANTS_OFFSET;
    p.animals = ( code & ANIMALS_MASK ) >> ANIMALS_OFFSET;
    p.aliens = ( code & ALIENS_MASK ) >> ALIENS_OFFSET;
    p.murderbots = ( code & MURDERBOTS_MASK ) >> MURDERBOTS_OFFSET;
    p.spants = ( code & SPANTS_MASK ) >> SPANTS_OFFSET;
    p.quest = ( code & RUINS_MASK ) >> RUINS_OFFSET;

    return p;
}

record compact_planet
{
    int index;			// 0-25
    planet_code code;		// 19387726
    int price;			// 124000
};

planet compact_planet_to_planet( compact_planet cp )
{
    planet p = code_to_planet( cp.code );
    p.index = cp.index;
    p.price = cp.price;
    return p;
}

compact_planet planet_to_compact_planet( planet p )
{
    compact_planet cp;
    cp.index = p.index;
    cp.code = planet_to_code( p );
    cp.price = p.price;
    return cp;
}

// ***************************
//         Visit History     *
// ***************************

string datestamp()
{
    return now_to_string( "yyyyMMdd" );
}

record spacegate_visit
{
    string coordinates;		// ABCDEFG
    string encounters;		// "|" delimited list of encounter
    string shinies;		// "|" delimited list of items
};

typedef spacegate_visit [string] visit_history;

string visit_history_file_name( string username )
{
    return "SpacegateVisits." + username + ".txt";
}

visit_history load_spacegate_visits( string username )
{
    visit_history visits;
    string filename = visit_history_file_name( username );
    file_to_map( filename, visits );
    return visits;
}

void save_spacegate_visit( string username, string date, spacegate_visit visit )
{
    visit_history visits = load_spacegate_visits( username );
    visits[ date ] = visit;
    map_to_file( visits, visit_history_file_name( username ) );
}

spacegate_visit settings_to_spacegate_visit()
{
    string coordinates = get_property( "_spacegateCoordinates" );
    string encounters = get_property( "_SpacegateEncounters" );
    string shinies = get_property( "_SpacegateShinies" );
    return new spacegate_visit( coordinates, encounters, shinies );
}

void save_spacegate_visit()
{
    save_spacegate_visit( my_name(), datestamp(), settings_to_spacegate_visit() );
}

// ***************************
//        Planet Database    *
// ***************************

typedef planet [string] planet_map;
typedef planet_aux [string] planet_aux_map;
typedef string [string] trophy_map;

// Three tiers of planet data:

// https://docs.google.com/spreadsheets/d/1yi08XJNPbfBAIDTR2rNrBJTPnXCO6GME294zU3afdD8/edit
//     There are errors in this.
static string public_planet_file_name = "SpacegatePlanetsPublic.txt";
static string public_planet_aux_file_name = "SpacegatePlanetsAuxPublic.txt";
static string public_trophy_file_name = "SpacegateTrophiesPublic.txt";
static planet_map public_planets;
static planet_aux_map public_planets_aux;
static trophy_map public_trophies;

// Planets that I, personally, have visited and am releasing with this script.
static string veracity_planet_file_name = "SpacegatePlanetsVeracity.txt";
static string veracity_planet_aux_file_name = "SpacegatePlanetsAuxVeracity.txt";
static string veracity_trophy_file_name = "SpacegateTrophiesVeracity.txt";
static planet_map veracity_planets;
static planet_aux_map veracity_planets_aux;
static trophy_map veracity_trophies;

// Planets that the script user has visited using this script, which has scraped the planet data
static string my_planet_file_name = "SpacegatePlanetsMine.txt";
static string my_planet_aux_file_name = "SpacegatePlanetsAuxMine.txt";
static string my_trophy_file_name = "SpacegateTrophiesMine.txt";
static planet_map my_planets;
static planet_aux_map my_planets_aux;
static trophy_map my_trophies;

// Planets from public_planets that that do not appear in either veracity_planets or my_planets
static planet_map unvisited_planets;

// Planets from public_planets that that appear in either veracity_planets or my_planets
static planet_map visited_planets;

void load_planet_data()
{
    void add_all( planet_map map1, planet_map map2 )
    {
	foreach coordinates, p in map2 {
	    map1[ coordinates ] = p;
	}
    }

    void remove_all( planet_map map1, planet_map map2 )
    {
	foreach coordinates, p in map2 {
	    remove map1[ coordinates ];
	}
    }

    void add_all( planet_aux_map map3, planet_aux_map map4 )
    {
	foreach coordinates, p in map4 {
	    map3[ coordinates ] = p;
	}
    }

    void add_all( trophy_map map5, trophy_map map6 )
    {
	foreach coordinates, t in map6 {
	    map5[ coordinates ] = t;
	}
    }

    // Load Public planets & trophies
    file_to_map( public_planet_file_name, public_planets );
    file_to_map( public_planet_aux_file_name, public_planets_aux );
    file_to_map( public_trophy_file_name, public_trophies );

    // Assume they are all unvisited
    unvisited_planets.add_all( public_planets );

    // Load Veracity planets & trophies
    file_to_map( veracity_planet_file_name, veracity_planets );
    file_to_map( veracity_planet_aux_file_name, veracity_planets_aux );
    file_to_map( veracity_trophy_file_name, veracity_trophies );
    // insert them into Public planets & trophies
    public_planets.add_all( veracity_planets );
    public_planets_aux.add_all( veracity_planets_aux );
    public_trophies.add_all( veracity_trophies );
    // Remove them from unvisited_planets
    unvisited_planets.remove_all( veracity_planets );
    // Add them to visited_planets
    visited_planets.add_all( veracity_planets );

    // Load My planets & trophies
    file_to_map( my_planet_file_name, my_planets );
    file_to_map( my_planet_aux_file_name, my_planets_aux );
    file_to_map( my_trophy_file_name, my_trophies );
    // Insert them into Public planets & trophies
    public_planets.add_all( my_planets );
    public_planets_aux.add_all( my_planets_aux );
    public_trophies.add_all( my_trophies );
    // Remove them from unvisited_planets
    unvisited_planets.remove_all( my_planets );
    // Add them to visited_planets
    visited_planets.add_all( my_planets );

    // Merge Public trophies into Public planets
    foreach coords, t in public_trophies {
	if ( public_planets contains coords ) {
	    planet p = public_planets[ coords ];
	    p.aliens &= ~ALIEN_ITEM_BIT_FIELD_MASK;
	    p.aliens |= item_name_to_trophy[ t ];
	}
    }
}
