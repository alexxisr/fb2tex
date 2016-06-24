#!/usr/bin/perl

use v5.16;

use strict;
use utf8;
use open IO => ':utf8';
binmode(STDOUT,':utf8');

use Getopt::Std;

use XML::XPath;
use XML::XPath::XMLParser;

my $cmdOpts={};
getopts("s:", $cmdOpts);

my $xp = XML::XPath->new(ioref=>'STDIN');

my $curLevel = 0;
if($cmdOpts->{"s"}){$curLevel += $cmdOpts->{"s"};}
my $secNames = ['part','chapter','section','subsection'];

my $ens = {
    'child::text()' => {'pre'=>sub{'';}, 
                        'find'=>'', 
                        'post'=>sub{'';}},
    'title-info'    => {'pre'=>sub{'';},
                        'find'=>'author | book-title',
                        'post'=>sub{"";}},
    'book-title'    => {'pre'=>sub{'\title{';},
                        'find'=>'child::text()',
                        'post'=>sub{"}\n";}},
    'first-name'    => {'pre'=>sub{'';},
                        'find'=>'child::text()',
                        'post'=>sub{' ';}},
    'last-name'     => {'pre'=>sub{'';},
                        'find'=>'child::text()',
                        'post'=>sub{'';}},
    'author'        => {'pre'=>sub{'\author{';},
                        'find'=>'first-name | last-name',
                        'post'=>sub{"}\n";}},
    'body'          => {'pre'=>sub{'';},
                        'find'=>'section',
                        'post'=>sub{'';}},
    'section'       => {'pre'=>sub{
                                   my $cn = shift;
                                   
                                   my $ns = $xp->find('title/p/child::text()',$cn);
                                   my $secTitle = '';
                                   foreach my $n ($ns->get_nodelist){
                                        $secTitle .= &texNorm(&xString($n));
                                   }

                                   if($curLevel > $#{$secNames}){
                                        die "$curLevel is not realised\n";
                                   }
                                   $curLevel++;
                                   return "\n".'\\'.$secNames->[$curLevel-1].'{'.$secTitle.'}'."\n";

                                },
                        'find'=>'section|p|poem|cite',
                        'post'=>sub{$curLevel--;return "\n";}},
    'p'             => {'pre'=>sub{"\n";},
                        'find'=>'child::text()|emphasis|strong',
                        'post'=>sub{"\n"}},
    'cite'          => {'pre'=>sub{"\n";},
                        'find'=>'p|poem',
                        'post'=>sub{"\n";}},
    'poem'          => {'pre'=>sub{"\n".'\begin{verse}';},
                        'find'=>'stanza',
                        'post'=>sub{"\n".'\end{verse}'."\n";}},
    'stanza'        => {'pre'=>sub{'';},
                        'find'=>'v',
                        'post'=>sub{'!';}},
    'v'             => {'pre'=>sub{"\n";},
                        'find'=>'child::text()|emphasis|strong',
                        'post'=>sub{'\\\\';}},
    'emphasis'      => {'pre'=>sub{"";},
                        'find'=>'child::text()|emphasis|strong',
                        'post'=>sub{'';}},
    'strong'        => {'pre'=>sub{"";},
                        'find'=>'child::text()|emphasis|strong',
                        'post'=>sub{'';}}
};

my $ns;

say '\documentclass[titlepage,10pt]{octavo}';
say '\usepackage{aviereader}';
say '\begin{document}';
say '\hyphenation{впол-не ус-тра-и-ваю не-ждан-но джу-н-г-ли'.
    ' ба-гро-во}';

$ns = $xp->find('/FictionBook/description/title-info');
&genRender($ns->get_node(0), 'title-info');
say '\maketitle';


$ns = $xp->find('/FictionBook/body[1]');
&genRender($ns->get_node(0), 'body');

say '\end{document}';

sub xString($){
    my $node = shift;
    return XML::XPath::XMLParser::as_string($node);
}

sub texNorm($){
    my $s = shift;
    $s =~ s/\x{00A0}/\~/g;
    $s =~ s/\x{00B0}/\\degree{}/g;
    $s =~ s/℃/\\degree{}/g;
    $s =~ s/\s+\x{2013}\s+/\ ---\ /g;
    $s =~ s/^[-\x{2013}](~|\s+)/---~/g;
    $s =~ s/([\,\!\?])~\x{2013}/$1~---/g;
    $s =~ s/([\.])[~\s]\x{2013}/$1\ ---/g;
    $s =~ s/\s+-\s/\~---\ /g;

    $s =~ s/([[:alpha:]])-([[:alpha:]])/$1\\hyp{}$2/g;

    $s =~ s/\$/\\\$/g;
    $s =~ s/_/\\textunderscore /g;
    $s =~ s/\x{0435}\x{0301}\x{0301}/ё/g;
    $s =~ s/\x{0301}\x{0301}//g;
    
    $s =~ s/&lt;/ </g;
    $s =~ s/(\s)&amp;/$1\\&/g;
    $s =~ s/↑/\$\\uparrow\$/g;
    $s =~ s/↓/\$\\downarrow\$/g;
    $s =~ s/\^/\$\\wedge\$/g;
    $s =~ s/²/\$^{2}\$/g;
    $s =~ s/½/\${1}\/{2}\$/g;
    $s =~ s/\%/\\\%/g;
    return $s;
}

sub genRender($$){
    my $cn = shift;
    my $en = shift;
    
    my $ef = $ens->{$en};
    die $en.' is not realized in genRender' if $ef eq '';

    print $ef->{'pre'}->($cn);

    if($cn->getNodeType != XML::XPath::Node::ELEMENT_NODE){
        print &texNorm(&xString($cn));
    }else{
        my $ns = $xp->find($ef->{'find'}, $cn);
        foreach my $n ($ns->get_nodelist){
            my $nn = $n->getName;
            if($nn eq ''){$nn = 'child::text()';}
            &genRender($n, $nn);
        }
    }

    print $ef->{'post'}->();
}
