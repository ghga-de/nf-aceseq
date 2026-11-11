#!/usr/bin/env perl

# Copyright (c) 2017 The ACEseq workflow developers.
# Distributed under the GNU GENERAL PUBLIC LICENSE (license terms are at https://www.github.com/eilslabs/ACEseqWorkflow/LICENSE_GNU.txt).
use strict;
use warnings;

# Issue #43: a write error on STDOUT (e.g. disk full) is only reported when STDOUT is closed
END { CORE::close(STDOUT) or do { print STDERR "Error writing to STDOUT: $!\n"; $? ||= 1 } }

my %filehandle; my $filename; my $filenametmp; my $chr_prefix;

for (my $i=1; $i < 25; $i++){
	my $id = $i;
	$id =~ s/23/X/;
	$id =~ s/24/Y/;
	$filename = "$ARGV[0]/$ARGV[1]$id.$ARGV[2]";
	$filenametmp = "$ARGV[0]/$ARGV[1]$id.$ARGV[2].tmp";
	open( $filehandle{$id}, ">", $filenametmp) or die "Could not open $filenametmp!\n" ;
	print {$filehandle{$id}} "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tcontrol\n";
}

while (my $line = <STDIN> ){
	my @fields = split("\t", $line);
	next if $fields[8] eq ".\n";
	next if $fields[8] eq "0/0\n";
	$fields[9] = $fields[8];
	$fields[8] = "GT";
	if ($filehandle{$fields[0]}){
		my $fh = $filehandle{$fields[0]};
		$fields[0] = $ARGV[3] . $fields[0];
		print {$fh} join("\t", @fields);
	}
}

# Issue #43: a read error ends the loop like EOF; only close() reports it
close(STDIN) or die "Error reading input: $!\n";

for (my $i=1; $i < 25; $i++){
	my $id = $i;
	$id =~ s/23/X/;
	$id =~ s/24/Y/;
	$filename = "$ARGV[0]/$ARGV[1]$id.$ARGV[2]";
	$filenametmp = "$ARGV[0]/$ARGV[1]$id.$ARGV[2].tmp";
	close( $filehandle{$id}) or die "Error writing $filenametmp: $!\n";  # issue #43
	my $move=system("mv $filenametmp $filename 2>&1");
	die "Could not move $filenametmp!\n" if $move != 0;
}
