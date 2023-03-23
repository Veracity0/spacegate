import <SpacegateData.ash>;

// ***************************
//     Utility Functions     *
// ***************************

buffer sg_pnum( buffer b, int n )
{
    buffer pnum_helper( buffer b, int n, int level )
    {
	if ( n >= 10 ) {
	    pnum_helper( b, n / 10, level + 1 );
	}
	b.append( to_string( n % 10 ) );
	if ( level > 0 && level % 3 == 0 ) {
	    b.append( "," );
	}
	return b;
    }

    if ( n < 0 ) {
	b.append( "-" );
	n = -n;
    }
    return pnum_helper( b, n, 0 );
}

string sg_pnum( int n )
{
    buffer b;
    return sg_pnum( b, n ).to_string();
}

void planet_description( string coordinates, planet p, planet_aux pa )
{
    static string indent = "\u00A0\u00A0\u00A0\u00A0";

    print( "Planet Name: " + pa.name + " (difficulty = " + p.index + ")" );

    if ( coordinates != "" ) {
	print( "Coordinates: " + coordinates.to_upper_case() );
    }

    print();

    {
	boolean printed_aux_data = false;

	if ( pa.sky != "" ) {
	    print( pa.sky );
	    printed_aux_data = true;
	}

	if ( pa.suns != "" ) {
	    print( pa.suns );
	    printed_aux_data = true;
	}

	if ( pa.moons != "" ) {
	    print( pa.moons );
	    printed_aux_data = true;
	}

	if ( printed_aux_data ) {
	    print();
	}
    }

    if ( p.environments != NONE ) {
	print( "Environmental Hazards:" );
	for ( int bit = 1; bit <= 16; bit <<= 1 ) {
	    if ( ( p.environments & bit ) != 0 ) {
		print( indent +  hazard_to_environmental[ bit ] );
	    }
	}
    }

    if ( p.elements != NONE ) {
	print( "Elemental Hazards:" );
	for ( int bit = 1; bit <= 16; bit <<= 1 ) {
	    if ( ( p.elements & bit ) != 0 ) {
		print( indent +  hazard_to_elemental[ bit ] );
	    }
	}
    }

    string plants =
	( p.plants == SIMPLE ) ? "primitive" :
	( p.plants == SIMPLE+HOSTILE ) ? "primitive (hostile)" :
	( p.plants == COMPLEX ) ? "advanced" :
	( p.plants == COMPLEX+HOSTILE ) ? "advanced (hostile)" :
	( p.plants == ANOMALOUS ) ? "anomalous" :
	( p.plants == ANOMALOUS+HOSTILE ) ? "anomalous (hostile)" :
	"none detected";
    string plant_image = ( pa.plant_image == "" ) ? "" : ( " (" + pa.plant_image + ")" );
    print( "Plant Life: " + plants + plant_image );

    string animals =
	( p.animals == SIMPLE ) ? "primitive" :
	( p.animals == SIMPLE+HOSTILE ) ? "primitive (hostile)" :
	( p.animals == COMPLEX ) ? "advanced" :
	( p.animals == COMPLEX+HOSTILE ) ? "advanced (hostile)" :
	( p.animals == ANOMALOUS ) ? "anomalous" :
	( p.animals == ANOMALOUS+HOSTILE ) ? "anomalous (hostile)" :
	"none detected";
    string animal_image = ( pa.animal_image == "" ) ? "" : ( " (" + pa.animal_image + ")" );
    print( "Animal Life: " + animals + animal_image );

    int aliens_type = ( p.aliens & ALIEN_TYPE_BIT_FIELD_MASK );
    string aliens =
	( aliens_type == FRIENDLY ) ? "detected" :
	( aliens_type == HOSTILE ) ? "detected (hostile)" :
	"none detected";

    if ( aliens_type != NONE ) {
	int alien_item = ( p.aliens & ALIEN_ITEM_BIT_FIELD_MASK );
	string item_name = ( aliens_type == HOSTILE ) ? trophy_to_name[ alien_item ] : trade_item_to_name[ alien_item ];
	string item_price = ( aliens_type == HOSTILE ) ? "" : ( " @ " + sg_pnum( p.price ) + " Meat" );
	string alien_image = ( pa.alien_image == "" ) ? "" : ( " (" + pa.alien_image + ")" );
	aliens += " (" + item_name + item_price + ")" + alien_image;
    }

    print( "Intelligent Life: " + aliens );

    if ( p.spants != NONE ) {
	string spants = "DANGER: Spant chemical signatures detected";
	int army_type = ( p.spants & ARMY_TYPE_BIT_FIELD_MASK );
	if ( army_type != UNKNOWN ) {
	    string encounter =
		( army_type == ARTIFACT ) ? " (spant egg casing)" :
		( army_type == DRONES ) ? " (drones)" :
		( army_type == SOLDIERS ) ? " (drones and soldiers)" :
		"";
	    spants += encounter;
	}
	print( spants );
    }

    if ( p.murderbots != NONE ) {
	string murderbots = "DANGER: Murderbot frequencies detected";
	int army_type = ( p.murderbots & ARMY_TYPE_BIT_FIELD_MASK );
	if ( army_type != UNKNOWN ) {
	    string encounter =
		( army_type == ARTIFACT ) ? " (data cores)" :
		( army_type == DRONES ) ? " (drones)" :
		( army_type == SOLDIERS ) ? " (drones and soldiers)" :
		"";
	    murderbots += encounter;
	}
	print( murderbots );
    }

    if ( p.quest != NONE ) {
	string pstr = "ALERT: ANCIENT RUINS DETECTED";
	int lang = ( p.quest & RUINS_LANGUAGE_BIT_FIELD_MASK );
	if ( lang != UNKNOWN ) {
	    pstr += " (" + ruins_type_and_step_to_string( p.quest ) + ")";
	}
	print( pstr );
    }
}

void planet_description( planet p )
{
    string coordinates;
    planet_aux pa;
    planet_description( coordinates, p, pa );
}

void planet_description( string coordinates )
{
    coordinates = coordinates.to_upper_case();
    if ( public_planets contains coordinates ) {
	planet_description( coordinates, public_planets[ coordinates ], public_planets_aux[ coordinates ] );
    } else {
	print( "I don't know the planet at coordinates " + coordinates );
    }
}

void main( string coordinates )
{
    load_planet_data();
    planet_description( coordinates );
}
