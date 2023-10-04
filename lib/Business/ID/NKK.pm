package Business::ID::NKK;

# DATE
# VERSION

use 5.010001;
use warnings;
use strict;

use DateTime;
use Locale::ID::Locality qw(list_idn_localities);
use Locale::ID::Province qw(list_idn_provinces);

use Exporter qw(import);
our @EXPORT_OK = qw(parse_nkk);

our %SPEC;

$SPEC{parse_nkk} = {
    v => 1.1,
    summary => 'Parse Indonesian family card number (nomor kartu keluarga, NKK)',
    args => {
        nkk => {
            summary => 'Input NKK to be validated',
            schema => 'str*',
            pos => 0,
            req => 1,
        },
        check_province => {
            summary => 'Whether to check for known province codes',
            schema  => [bool => default => 1],
        },
        check_locality => {
            summary => 'Whether to check for known locality (city) codes',
            schema  => [bool => default => 1],
        },
    },
};
sub parse_nkk {
    my %args = @_;

    state $provinces;
    if (!$provinces) {
        my $res = list_idn_provinces(detail => 1);
        return [500, "Can't get list of provinces: $res->[0] - $res->[1]"]
            if $res->[0] != 200;
        $provinces = { map {$_->{bps_code} => $_} @{$res->[2]} };
    }

    my $nkk = $args{nkk} or return [400, "Please specify nkk"];
    my $res = {};

    $nkk =~ s/\D+//g;
    return [400, "Not 16 digit"] unless length($nkk) == 16;

    $res->{prov_code} = substr($nkk, 0, 2);
    if ($args{check_province} // 1) {
        my $p = $provinces->{ $res->{prov_code} };
        $p or return [400, "Unknown province code"];
        $res->{prov_eng_name} = $p->{eng_name};
        $res->{prov_ind_name} = $p->{ind_name};
    }

    $res->{loc_code}  = substr($nkk, 0, 4);
    if ($args{check_locality} // 1) {
        my $lres = list_idn_localities(
            detail => 1, bps_code => $res->{loc_code});
        return [500, "Can't check locality: $lres->[0] - $lres->[1]"]
            unless $lres->[0] == 200;
        my $l = $lres->[2][0];
        $l or return [400, "Unknown locality code"];
        #$res->{loc_eng_name} = $p->{eng_name};
        $res->{loc_ind_name} = $l->{ind_name};
        $res->{loc_type} = $l->{type};
    }

    my ($d, $m, $y) = $nkk =~ /^\d{6}(..)(..)(..)/;
    eval { $res->{entry_date} = DateTime->new(day=>$d, month=>$m, year=>$y+2000)->ymd};
    if ($@) {
        return [400, "Invalid entry date (dd-mm-yy): $d-$m-$y"];
    }

    $res->{serial} = substr($nkk, 12);
    return [400, "Serial starts from 1, not 0"] if $res->{serial}+0 < 1;

    [200, "OK", $res];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

    use Business::ID::NKK qw(parse_nkk);

    my $res = parse_nkk(nkk => "3273010119170002");


=head1 DESCRIPTION

This module can be used to validate Indonesian family card number (nomor kartu
keluarga, or NKK for short).

NKK is composed of 16 digits as follow:

 pp.DDSS.ddmmyy.ssss

pp.DDSS is a 6-digit area code where the NKK was registered (it used to be but
nowadays not always [citation needed] composed as: pp 2-digit province code, DD
2-digit city/district [kota/kabupaten] code, SS 2-digit subdistrict [kecamatan]
code), ddmmyy is date of data entry, ssss is 4-digit serial starting from 1.

Keywords: nomor KK, family registration number


=head1 SEE ALSO

L<Business::ID::NIK> to parse NIK (nomor induk kependudukan, nomor KTP)
