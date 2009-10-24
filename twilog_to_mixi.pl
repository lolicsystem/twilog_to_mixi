#!/usr/bin/perl
#
# twilog_to_mixi.pl
#
# by lolicsystem (Chiemimaru Kai)
#
use strict;
use warnings;
use utf8;
use Config::Pit;
use DateTime;
use Encode;
use URI;
use LWP::UserAgent;
use LWP::Authen::Wsse;
use HTTP::Request::Common;
use HTML::Entities;
use HTML::Template;
use Web::Scraper;

#
# get id & pw from pit.
#
my $config_twitter = pit_get("twitter.com" , require => {
    "username" => "your username on twitter",
});
my $config_mixi = pit_get("mixi.jp" , require => {
    "email"    => "your email address registered in mixi",
    "password" => "your password",
    "userid"   => "your userid number",
});
die 'pit_get failed.' if !%$config_twitter || !%$config_mixi;
my $twitter_id     = $config_twitter->{username} or die $!;
my $mixi_auth_id   = $config_mixi->{email} or die $!;
my $mixi_password  = $config_mixi->{password} or die $!;
my $mixi_member_id = $config_mixi->{userid} or die $!;

#
# set footer
#
my $footer =<< "_FOOTEREND_";
--------
※ これは、僕のTwitterでのつぶやき(http://twitter.com/$twitter_id)を
ついろぐ(http://twilog.org/)で日ごとにまとめ、
それをmixi投稿APIを用いて投稿したものです。

スクリプトのソースは以下を参照して下さい。
http://github.com/lolicsystem/twilog_to_mixi
_FOOTEREND_

#
# Scraping twilog (yesterday).
#
my $dt = DateTime->now(time_zone => 'local');
my $date = $dt->subtract(days => 1)->format_cldr('yyMMdd');

my $uri = URI->new("http://twilog.org/$twitter_id/date-$date/asc-nomen");
my $scraper = scraper {
    process '//h3[@class="bar-main2"]/text()', 'title' => 'TEXT';
    process '.tl-tweet', 'tweet[]' => scraper {
        process '.tl-text',     'text' => ['TEXT', sub {
            encode_entities($_, '&');
            s/\x{ff5e}/\x{301c}/g;
        }];
        process '.tl-posted>a', 'time' => 'TEXT';
    };
};
my $result = $scraper->scrape($uri);

#
# Making contents to write to mixi.
#
my $template = HTML::Template->new(filehandle => *DATA);
$template->param(TITLE  => $result->{title});
$template->param(TWEET  => $result->{tweet});
$template->param(FOOTER => $footer);

#
# Post to mixi.
#
my $ua = LWP::UserAgent->new();
$ua->credentials('mixi.jp:80', '', $mixi_auth_id, $mixi_password);
my $res = $ua->post(
                    "http://mixi.jp/atom/diary/member_id=$mixi_member_id",
                    'Content-Type' => 'application/atom+xml',
                    'content'      => encode('utf8', $template->output())
                    );
warn $res->content unless $res->code == 201;

__DATA__
<?xml version='1.0' encoding='utf-8'?>
<entry xmlns='http://www.w3.org/2007/app'>
  <title><TMPL_VAR NAME="TITLE">のつぶやき</title>
  <summary>
<TMPL_LOOP NAME="TWEET">
<TMPL_VAR NAME="TIME">
<TMPL_VAR NAME="TEXT">
</TMPL_LOOP>
<TMPL_VAR NAME="FOOTER">
  </summary>
</entry>
