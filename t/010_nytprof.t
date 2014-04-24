#!perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Mojo;

use File::Spec::Functions 'catfile';
use FindBin '$Bin';

my $prof_dir = catfile($Bin, "nytprof");

my @existing_profs = glob "$prof_dir/nytprof*";
unlink $_ for @existing_profs;

{
  use Mojolicious::Lite;

  dies_ok(
    sub {
      plugin NYTProf => {
        nytprof => {
          nytprofhtml_path => '/tmp/bad'
        },
      };
    },
    'none existent nytprofhtml dies',
  );

  like( $@,qr/Could not find nytprofhtml script/i,' ... with sensible error' );

  plugin NYTProf => {
    nytprof => {
      profiles_dir => $prof_dir,
    },
  };

  any 'some_route' => sub {
    my ($self) = @_;
    $self->render(text => "basic stuff\n");
  };
}

my $t = Test::Mojo->new;

$t->get_ok('/nytprof')
  ->status_is(200)
  ->content_like(qr{<p>No profiles found</p>});

ok(
  !-e catfile($prof_dir, "nytprof.out.some_route.$$"),
  'nytprof.out file not created'
);

$t->get_ok('/some_route')
  ->status_is(200)
  ->content_is("basic stuff\n") for 1 .. 3;

my @profiles = Mojolicious::Plugin::NYTProf::_profiles($prof_dir);

foreach my $prof (@profiles) {
  ok(-e catfile($prof_dir, $prof->{file}), $prof->{file}." created");
}

$t->ua->max_redirects(5);

$t->get_ok('/nytprof')
  ->status_is(200)
  ->content_like(qr{<a href="/nytprof/nytprof_out_\d+_\d+_some_route_\d+">});

TODO: {
  local $TODO = "redirect to profiles";
$t->get_ok("/nytprof/".$profiles[0]->{file}.'/')
  ->status_is(302)
  ->content_is("generate nytprof profile\n");

$t->get_ok("/nytprof/html/".$profiles[0]->{file}.'/')
  ->status_is(302)
  ->content_is("show nytprof profile\n");
}

done_testing();
