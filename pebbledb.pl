#!/bin/perl

use strict;
use warnings;
use LWP::Simple;
use JSON;
use Data::Dumper;
use DBI;
use Getopt::Long;
use File::Basename;
use File::HomeDir;
use Switch;

Getopt::Long::Configure ('bundling');

my $appurl = "https://api2.getpebble.com/v2/apps/collection/all/watchapps-and-companions";
my $faceurl = "https://api2.getpebble.com/v2/apps/collection/all/watchfaces";
my $storeurl = "https://apps.getpebble.com/en_US/application/";
my $dbfile = File::HomeDir->my_home . "/.pebbledb";
my $dbname = "dbi:SQLite:dbname=$dbfile";
my $dbcon = DBI->connect($dbname,"","",{PrintError => 0});
my $count = 0;
my $step = 100;

sub GetAll{
    my ($base,$url) = @_;
    $url //= "$base?limit=$step";
    $count += $step;
    my $resp = decode_json(get($url));
    my $next = $resp->{'links'}->{'nextPage'};
    my $data = $resp->{'data'};
    foreach (@$data) {
        my $id = $_->{'id'};
        my $title = $_->{'title'};
        my $author = $_->{'author'};
        my $category = $_->{'category_name'};
        my $description = $_->{'description'};
        my $screenshoti = $_->{'screenshot_images'};
        my $screenshot = "";
        if (ref($screenshoti) eq "ARRAY") {
            my $screenshota = @$screenshoti[0];
            $screenshot = (values %$screenshota)[0];
        }
        my $capabilities = "";
        my $cap = $_->{'capabilities'};
        if (defined $cap) {
            foreach (@$cap) {
                if ($capabilities eq "") {
                    $capabilities = $_;
                } else {
                    $capabilities = $capabilities . "," . $_;
                }
            }
        }
        my $hearts = $_->{'hearts'};
        my $pbw = $_->{'latest_release'}->{'pbw_file'};
        my $created = $_->{'created_at'};
        my $updated = $_->{'latest_release'}->{'published_date'};
        my $type = $_->{'type'};
        $dbcon->do("INSERT INTO pebble (id,title,author,category,description,screenshot,capabilities,hearts,pbw,created,updated,type) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            undef,
        $id,$title,$author,$category,$description,$screenshot,$capabilities,$hearts,$pbw,$created,$updated,$type);
    }
    print "$count\n";
    if (defined $next) {
        GetAll($base,$next);
    }
}

sub UpdateDb {
    $dbcon->do("DROP TABLE pebble");
    $dbcon->do('CREATE TABLE pebble (
        "id" TEXT,
        "title" TEXT,
        "type" TEXT,
        "author" TEXT,
        "category" TEXT,
        "description" TEXT,
        "screenshot" TEXT,
        "capabilities" TEXT,
        "hearts" INTEGER,
        "pbw" TEXT,
        "created" TEXT,
        "updated" TEXT
    )');
    $dbcon->do('CREATE INDEX "id" on pebble (id ASC)');
    $dbcon->do('CREATE INDEX "type" on pebble (type ASC)');

    print "downloading apps\n";
    GetAll($appurl);
    $count = 0;
    print "downloading faces\n";
    GetAll($faceurl);
}

sub PrintEntry {
    my ($num, $entry,$width,$dates,$url) = @_;
    my $str = $num . "." . " " x (5 - length($num)) . $entry->{"hearts"} . " " x (7-length($entry->{"hearts"})) . $entry->{"title"} . " (" . $entry->{"author"} . ")";
    #if ($entry->{"type"} eq "companion-app") {
        #$str .= " (companion-app required)";
    #}
    my $capstr = " " x 5;
    if ($entry->{"type"} eq "watchface") {
        $capstr = "F" . $capstr;
    } else {
        $capstr = "A" . $capstr;
    }
    if (defined $entry->{"capabilities"}) {
        if ($entry->{"capabilities"} =~ /health/) {
            $capstr .= "H";
        }
        if ($entry->{"capabilities"} =~ /location/) {
            $capstr .= "L";
        }
        if ($entry->{"capabilities"} =~ /configurable/) {
            $capstr .= "C";
        }
    }
    print $str . "\n" . $capstr;
    if (defined $entry->{'description'}) {
        my $desc = $entry->{'description'};
        $desc =~ s/^[ \t]*//;
        $desc =~ s/\n.*//g;
        if (length($desc) > $width) {
            $desc = substr($desc,0,$width) . '...';
        } else {
            $desc = substr($desc,0,$width);
        }
        print " " x (17 - length($capstr)) . $desc . "\n";
    } else {
        print "\n";
    }
    if (defined $dates) {
        print " " x 17;
        if (defined $entry->{"created"}) {
            my $cre = $entry->{"created"};
            $cre =~ s/T.*//;
            print "created " . $cre;
        }
        if (defined $entry->{"updated"}) {
            my $upd = $entry->{"updated"};
            $upd =~ s/T.*//;
            print " updated: " . $upd;
        }
        print "\n";
    }
    if ((defined $url) and (defined $entry->{"id"})) {
        print " " x 17;
        print $storeurl . $entry->{"id"} . "\n";
    }
}

sub Search {
    my ($query,$string,$column) = @_;
    $string =~ s/[^a-zA-Z0-9 ]//g;
    $column =~ s/[^a-zA-Z]//g;
    my $ins = " $column COLLATE UTF8_GENERAL_CI LIKE \"%$string%\"";
    if ($query =~ /WHERE/) {
        $query .= " AND ";
    } else {
        $query .= " WHERE ";
    }
    return $query . $ins;
}

sub SearchNo {
    my ($query,$string,$column) = @_;
    $string =~ s/[^a-zA-Z0-9 ]//g;
    $column =~ s/[^a-zA-Z]//g;
    my $ins = " $column COLLATE UTF8_GENERAL_CI NOT LIKE \"%$string%\"";
    if ($query =~ /WHERE/) {
        $query .= " AND ";
    } else {
        $query .= " WHERE ";
    }
    return $query . $ins;
}

sub Filter {
    my ($query,$string,$column) = @_;
    $string =~ s/[^a-zA-Z0-9 ]//g;
    $column =~ s/[^a-zA-Z]//g;
    my $ins = " $column = \"$string\"";
    if ($query =~ /WHERE/) {
        $query .= " AND (";
    } else {
        $query .= " WHERE (";
    }
    $query .= $ins;
    if ($string eq "watchapp") {
        $query .= " OR $column = \"companion-app\"";
    }
    return $query . ")";
}

sub FilterOut {
    my ($query,$string,$column) = @_;
    $string =~ s/[^a-zA-Z0-9 ]//g;
    $column =~ s/[^a-zA-Z]//g;
    my $ins = " $column <> \"$string\"";
    if ($query =~ /WHERE/) {
        $query .= " AND (";
    } else {
        $query .= " WHERE (";
    }
    $query .= $ins;
    if ($string eq "watchapp") {
        $query .= " OR $column = \"companion-app\"";
    }
    return $query . ")";
}



my $search;
my $title;
my $limit;
my $update;
my $help;
my $description;
my $width;
my $order;
my $orderdir;
my $category;
my $apps;
my $faces;
my $health;
my $conf;
my $loc;
my $nohealth;
my $noconf;
my $noloc;
my $download;
my $dates;
my $url;
#my @columns = ("id", "title", "type", "author", "category", "description", "screenshot", "capabilities", "hearts", "pbw", "created", "updated");
my @ordcols = ("id", "title", "type", "author", "category", "hearts", "created", "updated");
my @desccols = ("hearts", "created", "updated");
my @categories = ("Games", "Daily", "Tools & Utilities", "Health & Fitness", "Notifications", "Remotes", "GetSomeApps", "Index", "Faces");
my $query = "SELECT * FROM pebble";
GetOptions("s|search" => \$search, "t|title=s" => \$title, "d|description=s" => \$description, "l|limit=i" => \$limit, "u|update" => \$update, "h|help" => \$help, "w|description-width=i" => \$width, "o|order=s" => \$order, "O|order-dir" => \$orderdir, "c|category=s" => \$category, "a|apps" => \$apps, "f|faces" => \$faces, "health" => \$health, "configurable" => \$conf, "location" => \$loc, "no-health" => \$nohealth, "no-location" => \$noloc, "not-configurable" => \$noconf, "download" => \$download, "dates" => \$dates, "url" => \$url);
$width //= 50;
$limit //= 20;

if (defined $search) {
    if (defined $title) {
        $query = Search $query, $title, "title";
    }
    if (defined $description) {
        $query = Search $query, $description, "description";
    }
    if (defined $category) {
        switch ($category) {
            case "G"    {$category = "Games"}
            case "D"    {$category = "Daily"}
            case "T"    {$category = "Tools & Utilities"}
            case "H"    {$category = "Health & Fitness"}
            case "N"    {$category = "Notifications"}
            case "R"    {$category = "Remotes"}
            case "S"    {$category = "GetSomeApps"}
            case "I"    {$category = "Index"}
        }
        $query = Filter $query, $category, "category";
    }
    if (defined $faces) {
        $query = Filter $query, "watchface", "type";
    } elsif (defined $apps) {
        $query = Filter $query, "watchapp", "type";
    }
    if (defined $health) {
        $query = Search $query, "health", "capabilities";
    }
    if (defined $conf) {
        $query = Search $query, "configurable", "capabilities";
    }
    if (defined $loc) {
        $query = Search $query, "location", "capabilities";
    }
    if (defined $nohealth) {
        $query = SearchNo $query, "health", "capabilities";
    }
    if (defined $noconf) {
        $query = SearchNo $query, "configurable", "capabilities";
    }
    if (defined $noloc) {
        $query = SearchNo $query, "location", "capabilities";
    }
    if ((defined $order) and (grep {$_ eq $order} @ordcols)) {
        $query .= " ORDER BY " . $order;
        if (defined $orderdir) {
            switch ($orderdir) {
                case "asc" {$query .= " ASC"}
                case "desc" {$query .= " DESC"}
            }
        } else {
            if (grep {$_ eq $order} @desccols) {
                $query .= " DESC";
            } else {
                $query .= " ASC";
            }
        }
    }
    if ((defined $limit) and ($limit > 0)) {
        $query .= " LIMIT " . $limit;
    }
    #print "$query\n";
    my $sth = $dbcon->prepare($query);
    if (defined $sth) {
        $sth->execute();
        my $num = 1;
        my $downloaded = 0;
        my $downtitle = "";
        while (my $row = $sth->fetchrow_hashref) {
            if (($num == 1) and (defined $download)) {
                $downtitle = $row->{"title"};
                if (defined $row->{"pbw"}) {
                    my $fn = $row->{"title"};
                    $fn =~ s/[ \t]+/_/g;
                    $fn =~ s/^_//;
                    $fn =~ s/[^a-zA-Z0-9_]*//g;
                    getstore($row->{"pbw"},$fn . ".pbw");
                    $downloaded = 1;
                } else {
                    $downloaded = 2;
                }
            }
            PrintEntry $num, $row, $width, $dates, $url;
            $num++;
        }
        if ($downloaded == 1) {
            print "Download of " . $downtitle . " finished.\n";
        } elsif ($downloaded == 2) {
            print "No Information about PBW file of " . $downtitle . "\n";
        }
    }
} elsif (defined $update) {
    UpdateDb;
} elsif (defined $help) {
    print "usage: " . basename($0) . " [mode] [options]\n" .
"
MODE SWITCHES
    -s, --search
        Search in database.
    -u, --update
        Rebuild database (will take a few minutes).
    -h, --help
        Display this help.

OPTIONS (SEARCH MODE ONLY):
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

OUTPUT (CHARACTERS):
    A   watchapp
    F   watchface
    H   uses Pebble Health API
    C   configurable
    L   uses location access
";
}

$dbcon->disconnect;
