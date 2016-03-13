#!/bin/perl

use strict;
use warnings;
use LWP::Simple;

my $appurl = "https://api2.getpebble.com/v2/apps/collection/all/watchapps-and-companions";
my $faceurl = "https://api2.getpebble.com/v2/apps/collection/all/watchfaces";

sub GetApps{
    my $url = "$appurl?limit=100&offset=100";
    $data = get($url);
    print "$data";
}
