# pebbledb

Search Pebble apps and faces using many filter options.

## Usage

./pebbledb.pl [mode] [options]

### Mode Switches

-s, --search

    Search in database.

-u, --update

    Rebuild database (will take a few minutes).

-h, --help

    Display this help.

### Options (search mode only)

-t, --title STR

    Search in titles for STR.

-d, --description STR

    Search in description for STR.

-l, --limit N (default 20)

    Limit output to N results. Use 0 to disable this limit.

-w, --description-width N (default 40)

    Display first N characters of description.

-o, --order STR

    Order by STR (id, title, type, author, category, hearts, created, updated).

-O, --order-dir STR

    Sorting direction (asc, desc) (default value depends on column).

-c, --category STR

    Search in category STR ([G]ames, [D]aily, [T]ools & Utilities, [H]ealth & Fitness,

    [N]otifications, [R]emotes, Get[S]omeApps, [I]ndex). This option will only work

    for watchapps as there is no category information for watchfaces.

-a, --apps

    Display only watchapps.

-f, --faces

    Display only watchfaces. This option overrides -a, --apps.

--health (--no-health)

    Display only watchapps or watchfaces which (don't) use the Pebble health API.

--configurable (--not-configurable)

    Display only (not) configurable watchapps or watch faces.

--location (--no-location)

    Display only watchapps or watchfaces which (don't) use location access.

--dates

    Display date of last update and creation.

--url

    Display links to the application page.

--download

    Download PBW file of first result to file.

### Output (characters)

A   watchapp

F   watchface

H   uses Pebble Health API

C   configurable

L   uses location access
