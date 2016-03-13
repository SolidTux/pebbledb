#!/bin/perl

use strict;
use warnings;
use LWP::Simple;
use JSON;
use Data::Dumper;

my $appurl = "https://api2.getpebble.com/v2/apps/collection/all/watchapps-and-companions";
my $faceurl = "https://api2.getpebble.com/v2/apps/collection/all/watchfaces";

sub GetApps{
    my ($url) = @_;
    $url //= "$faceurl?limit=10&offset=10";
    print "$url";
    my $data = decode_json(get($url));
    my $next = $data->{'links'}->{'nextPage'};
    print "$next\n";
    GetApps($next);
}

GetApps;
