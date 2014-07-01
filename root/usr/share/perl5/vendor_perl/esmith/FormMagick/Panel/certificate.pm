#!/usr/bin/perl -w 

package esmith::FormMagick::Panel::certificate;

use strict;
use warnings;
use esmith::ConfigDB;
use esmith::FormMagick;
use esmith::cgi;
#use esmith::util;
#use Net::OpenVPN::Manage;
#use Net::IP;

our @ISA = qw(esmith::FormMagick Exporter);

our @EXPORT = qw(
    write_pem
    read_pem
);

our $config_db = esmith::ConfigDB->open || die "Couldn't open ConfigDB\n";


our $ssl_crt = '/home/e-smith/ssl.crt';
our $ssl_key = '/home/e-smith/ssl.key';

#*wherenext = \&CGI::FormMagick::wherenext;
sub new {
    shift;
    my $fm = esmith::FormMagick->new();
    $fm->{calling_package} = (caller)[0];
    bless $fm;
    return $fm;
}



sub print_section_bar{
    my ($fm) = @_;
    print "  <tr>\n    <td colspan='2'>\n";
    print "<hr class=\"sectionbar\"/>\n";
    return undef;
}

sub read_pem{
    my ($fm,$pem) = @_;
    my $q = $fm->{cgi};
    my $dir = '';
    my $ret;
    my $domain = $config_db->get_value('DomainName');

    if ($pem eq 'domain.crt') { #|| ($pem eq 'cert.pem') || ($pem eq 'dh.pem')){
        $dir = $ssl_crt;
        $pem = "$domain.crt";
    }
    if ($pem eq 'domain.key') {
        $dir = $ssl_key;
        $pem = "$domain.key";
    }

    if (! open (PEM, "<$dir/$pem")){
        $fm->error('ERROR_OPEN_PEM','FIRST');
        # Tell the user something bad has happened
        return;
    }
    while (<PEM>){
        $ret .= $_;
    }
    close PEM;

    return $ret;
}

sub write_pem{
    my ($fm) = @_;
    my $q = $fm->{cgi};
    my $domain = $config_db->get_value('DomainName');

    my $domain_crt  = $q->param('ca_crt');
    my $domain_key = $q->param('ca_key');
   # my $key = $q->param('key_pem');
   # my $dh = $q->param('dhpar_pem');
   # my $ta = $q->param('ta_pem');

if (($domain_crt eq '') && ($domain_key eq ''))
    {
        my $ssl_crt = '/home/e-smith/ssl.crt';
        my $ssl_key = '/home/e-smith/ssl.key';
        my $domain = $config_db->get_value('DomainName');
        my $server = $config_db->get_value('SystemName');


        system("/sbin/e-smith/db configuration setprop modSSL crt $ssl_crt/$server.$domain.crt");
        system("/sbin/e-smith/db configuration setprop modSSL key $ssl_key/$server.$domain.key");
        system("/sbin/e-smith/db configuration delprop modSSL CertificateChainFile");
        system("/sbin/e-smith/expand-template /home/e-smith/ssl.pem/pem");
        system("/sbin/e-smith/expand-template /etc/httpd/conf/httpd.conf");
        system("/sbin/service httpd-e-smith restart");
        system("/sbin/e-smith/signal-event ldap-update");
        system("/sbin/e-smith/signal-event email-update");
    }

elsif (($domain_crt ne '') && ($domain_key ne ''))
    {
        if (! open (CA, ">$ssl_crt/$domain.crt")){
            $fm->error('ERROR_OPEN_CRT','FIRST');
            # Tell the user something bad has happened
            return;
            }
        print CA $domain_crt;
        close CA;

        if (! open (CRT, ">$ssl_key/$domain.key")){
            $fm->error('ERROR_OPEN_KEY','FIRST');
            # Tell the user something bad has happened
            return;
        }
        print CRT $domain_key;
        close CRT;

        # Restrict permissions on sensitive data
        esmith::util::chownFile("root", "root","$ssl_key/$domain.key");
        esmith::util::chownFile("root", "root","$ssl_crt/$domain.crt");
        chmod 0600, "$ssl_key/$domain.key";
        chmod 0600, "$ssl_crt/$domain.crt";

        system("/sbin/e-smith/db configuration setprop modSSL crt $ssl_crt/$domain.crt");
        system("/sbin/e-smith/db configuration setprop modSSL key $ssl_key/$domain.key");

        system("/sbin/e-smith/expand-template /home/e-smith/ssl.pem/pem");
        system("/sbin/e-smith/expand-template /etc/httpd/conf/httpd.conf");
        system("/sbin/service httpd-e-smith restart >/dev/null 2>&1");
    
        system("/sbin/e-smith/signal-event ldap-update");
        system("/sbin/e-smith/signal-event email-update");
        $fm->success('SUCCESS','FIRST');
        return undef;
    }
}
1;
