####################################
# 4Spgm.pl ver 1.1
# 2019.6.6

use strict;
use Getopt::Long;

my %opts = ( window => 1000, output => "4Soutput");
GetOptions(\%opts, qw( reference=s sam=s window=i output=s help force) ) or exit 1;

if ($opts{help}) {
    die &show_help();
}

my $dieflag;
foreach my $field ( qw( reference sam ) ){
    if(! exists($opts{$field})){
	$dieflag .= "Error: [$field] file is required.\n";
    }else{
	unless(-e $opts{$field}){
	    $dieflag .= "Error: [$opts{$field}] file does not exist.\n";
	}
    }
}

if(-e $opts{output}){
    if(!$opts{force}){
	$dieflag .= "Error: [$opts{output}] directory already exists.\n";
    }else{
	system("rm -rf $opts{output}");
    }
}

die $dieflag if $dieflag;

system("mkdir $opts{output}");

print "Reference (-r):\t".$opts{reference}."\n";
print "SMA file (-s) :\t".$opts{sam}."\n";
print "Window (-w)   :\t".$opts{window}."\n";
print "Output (-o)   :\t".$opts{output}."\n";


###################################
## Data preparation
my ($seq, $tagname);
for(`cat $opts{reference}`){
    chomp;
    if(/>(\S+)/){
	$tagname = $1;
	next;
    }
    $seq .= $_;
}
my $size = length($seq);


my %seen;
my $len;
my @pos;
my @watson;
my @crick;
for my $line (`cat $opts{sam}`){
    chomp($line);
    next if ($line =~ /^\@/);
    next unless($line =~ /$tagname/);
    next if ($line =~ /XA:Z/); # ignore multiple mapping
    my @F = split(/\t/, $line);
    next if ($seen{$F[9]}); # remove PCR duplicate

    if($F[5] =~ /^(\d+)S(\d+)M$/){
	my $one = $1;
	my $two = $2;
	my $tag = complement(substr($F[9], 0, $1));
	if(length($tag) <= 20 && $tag =~ /^GGGAA.{8}TAGGG/ || length($tag) <= 20 && $tag =~/TAGGG$/){ # new tag [1st_Adaptor_N8_BIOTEG]
	    for (my $i = $F[3] - 1; $i <= $F[3] - 1 + $two; $i ++){
		$watson[$i] ++;
	    }
	}
    }elsif($F[5] =~ /^(\d+)M(\d+)S$/){
	my $one = $1;
	my $two = $2;
	my $tag = substr($F[9], $1);
	if(length($tag) <= 20 && $tag =~ /^GGGAA.{8}TAGGG/ || length($tag) <= 20 && $tag =~/TAGGG$/){ # new tag [1st_Adaptor_N8_BIOTEG]
	    for (my $i = $F[3] - 1; $i <= $F[3] - 1 + $one; $i ++){
		$crick[$i] ++;
	    }
	}
    }elsif($F[5] =~ /^(\d+)M$/){
	$len += $1;
	for (my $i = $F[3] - 1; $i <= $F[3] - 1 + $1; $i ++){
	    $pos[$i] ++;
	}
    }
    $seen{$F[9]} ++;
}

my ($und, $top) = (0, 100000);
open(SKEW, "> $opts{output}/skew.tsv");
print SKEW "Position\tWatson strand (median)\tCrick strand (median)\tSkew\n";
for (my $i = 0; $i <= $size; $i += $opts{window}){
    my @watsonT;
    my @crickT;

    for (my $j = $i; $j <= $i + $opts{window}; $j ++){
	if($pos[$j] >= $und && $pos[$j] <= $top && $watson[$j] > 0 && $crick[$j] > 0){
	    push(@watsonT, $watson[$j]);
	    push(@crickT, $crick[$j]);
	}
    }

    my $watson = &median(@watsonT);
    my $crick = &median(@crickT);
    next unless($watson > 1 && $crick > 1);
    my $skew = ($crick - $watson)/($watson + $crick);
    print SKEW $i."\t".$watson."\t".$crick."\t".$skew."\n";
}
close SKEW;

sub median {
    my @set = sort {$a <=> $b} @_;
    my $median;
    if(@set % 2){
        $median = $set[int(@set/2)];
    }else{
        $median = ($set[int(@set/2) - 1] + $set[int(@set/2)])/2;
    }
    return $median;
}

sub complement {
    my $nuc = shift;
    $nuc = reverse($nuc);
    $nuc =~ tr/[acgtACGT]/[tgcaTGCA]/;
    return $nuc;
}

###################################
## Help
sub show_help {
    my $help_doc = <<EOF;
Program: 4S-sqe program
Version: 1.0
Usage:   perl 4Spgm.pl <command> [options]
Command: -r FILE       Reference file (format: FASTA)
         -s FILE       Read mapped file on the reference file (format: SAM)
Option:  -w INT        Window size [1,000]
	 -o STR        Output dir name [4Soutput]
Note:    This program does not require other modules. On the other hand, users should prepare 
         a read mapping file. The sequence reads mapped SAM file on genome reference file can
         be generated by BWA program (http://bio-bwa.sourceforge.net).
License: GNU General Public License
         Copyright (C) 2019
         Institute for Advanced Biosciences, Keio University, JAPAN
Author:  Nobuaki Kono
EOF
return $help_doc;
}

