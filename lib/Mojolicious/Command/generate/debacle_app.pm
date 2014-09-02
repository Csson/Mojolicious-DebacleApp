package Mojolicious::Command::generate::debacle_app;

our $VERSION = '0.01';

use strict;
use warnings;
use true;

use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw/class_to_file class_to_path/;

use Dist::Milla::App;
use String::Random;
use IPC::Run qw/timeout/;
use Dist::Zilla;
#use Dist::Zilla::Minting::Profile;

use 5.020;
use experimental 'postderef';

has description => 'Generate Mojolicious application directory structure (with dbix and more)';
has usage       => sub { shift->extract_usage };

sub run {
    my $self = shift;
    my $app = shift;

    $app ||= 'MyApp';

    if($app !~ m{^[A-Z](?:\w|::)+$}) {
        die qq{Your application name has to be a well formed (CamelCase) Perl module name, like MyApp};
    }

    my $basepath = $app =~ s{::}{-}gr;

    {
        IPC::Run::run ['dzil', 'new', '-P', 'TheBest', '-p', 'milla', $app];
        #exec("milla new $app");
    }

    # start script
    $self->render_to_rel_file('start', "$basepath/script/$basepath", $app);
    
    my $classes = {
        appclass     => [],
        controller   => ['Controller::Example'],
        schema       => ['Schema'],
        schema_candy => ['Schema::Candy', $app],
        db           => ['DB', $app],
        result       => ['Schema::Result', $app],
        resultset    => ['Schema::ResultSet'],
        

    };

    while(my($template, $args) = each $classes->%*) {
        my $class = $app . (scalar $args->@* ? '::'.shift $args->@* : '');
        my $path = class_to_path $class;
        $self->render_to_rel_file($template, "$basepath/lib/$path", $class, $args->@*);
    }


    my $files = {
        config_standard => [share => 'config.conf'],
        config_secret   => [share => 'config-secret.conf'],

        layout          => ['templates/layouts', 'default.html.ep'],
        index           => ['templates/example', 'index.html.ep'],

        dbdeploy        => [script => 'db-deploy.pl', $app],

        test            => [t => 'basic.t', $app],

    };

    while(my($template, $args) = each $files->%*) {
        my $dir = shift $args->@*;
        my $filename = shift $args->@*;
        $self->render_to_rel_file($template, "$basepath/$dir/$filename", $args->@*);
    }

    my @directories = qw/log/;

    foreach my $dir (@directories) {
        $self->create_rel_dir("$basepath/$dir");
    }

}

1;
__DATA__

@@ start
% my $class = shift;
#!/usr/bin/env perl

use FindBin;

BEGIN { unshift @INC, "$FindBin::Bin/../lib" };

require Mojolicious::Commands;
Mojolicious::Commands->start_app('<%= $class %>');


@@ appclass
% my $class = shift;
package <%= $class %> {

    use Mojo::Base 'Mojolicious';
    use Config::FromHash;
    use Kavorka;
    use Syntax::Collection::Basic;

    method startup {
        $self->setup;

        my $r = $self->routes;

        $r->get('/*message')->to('example#index');
    }

    method setup($app:) {
        $app->plugin(config => { default => Config::FromHash->new(filenames => ['share/config-secret.conf', 'share/config.conf'])->data });
        
        $app->secrets($config->{'secrets'});
        $app->defaults(layout => 'default');

        $app->helper(db => sub {
            <%= $class %>::DB->connect(config => $config->{'db'});
        });
    }
}


@@ controller
% my $class = shift;
package <%= $class %> {
    use Mojo::Base 'Mojolicious::Controller';

    use Syntax::Collection::Basic;
    use Kavorka;

    method index {
        $self->render(message => $self->param('message'));
    }
}


@@ schema
% my $class = shift;
package <%= $class %> {
    use base 'DBIx::Class::Schema';
    use Syntax::Collection::Basic;

    our $VERSION = 1;

    __PACKAGE__->load_namespaces;

}

@@ db
% my $class = shift;
% my $app_class = shift;
package <%= $class %> {
    use Mojo::Base -base;
    use Syntax::Collection::Basic;

    has 'config';
    has 'schema';

    use vars $AUTOLOAD;

    sub connect {
        my $self = shift;

        $self->schema(<%= $app_class %>::Schema->connect(
            $self->config->{'dsn'},
            $self->config->{'user'},
            $self->config->{'password'},
            $self->config->{'extra'},
        ));
    }

    sub AUTOLOAD {
        my $resultset = substr $AUTOLOAD, 0 => <%= (length '$app_class') + 6 %>; # basically s{^<%= $app_class %>::DB::}{}
        return $self->schema->resultset($resultset);
    }

}

@@ schema_candy
% my $class = shift;
% my $app_class = shift;
package <%= $class %> {
    use base 'DBIx::Class::Candy';

    use Syntax::Collection::Basic;
    use String::CamelCase;

    sub base { $_[1] || '<%= $app_class %>::Schema::Result' }
    sub autotable { 1 }

    sub gen_table {
        my $self = shift;
        my $resultclass = shift;

        $resultclass =~ s{^<%= $app_class %>::Schema::Result::}{};
        $resultclass =~ s{::}{__}g;
        $resultclass = String::CamelCase::decamelize($resultclass);

        return $resultclass;
    }

}


@@ result
% my $class = shift;
% my $app_class = shift;
package <%= $class %> {
    use parent 'DBIx::Class::Core';

    use Syntax::Collection::Basic;

    __PACKAGE__->load_components(qw/
        Helper::Row::RelationshipDWIM
        InflateColumn::DateTime
    /);

    sub default_result_namespace { '<%= $app_class %>::Schema::Result' }

}

@@ resultset
% my $class = shift;
package <%= $class %> {
    use Moose;
    use namespace::sweep;
    use MooseX::NonMoose;
    use Syntax::Collection::Basic;
    use Moops;

    extends 'DBIx::Class::ResultSet';

    sub BUILDARGS { $_[2] }

    __PACKAGE__->meta->make_immutable;
}



@@ dbdeploy
% my $app_class = shift;
#!/usr/bin/env perl

use Syntax::Collection::Basic;
<%= $app_class %>::Inline::App::DeployDB->new_with_syntax->run;

package <%= $app_class %>::Inline::App::DeployDB {
    use MooseX::App::Simple;
    use Config::Hash;
    use Dir::Self;

    use lib __DIR__ . '/../lib';

    use <%= $app_class %>::Schema;

    sub run {
        db();
    }

    method db {
        my $config = Config::Hash->new(
            filename => __DIR__ . '/../share/config-secret.conf',
            data => Config::Hash->new(filename => __DIR__ . '/../share/config.conf')->data
        )->data->{'db'};

        my $db = <%= $app_class %>::Schema->connect($config->{'dsn'}, $config->{'user'}, $config->{'password'}, $config->{'extra'});

        $db->deploy;
        say 'db deploy done.';
    }
}

@@ config_standard
{
    db => {
        extra => {
            mysql_enable_utf8 => 1,
        }
    }
}

@@ config_secret
% my $rand = String::Random->new;
{
    secrets => ['<%= $rand->randregex('\w{40}') %>'],
}


@@ layout
<!DOCTYPE html>
<html>
    <head>
        <title><%% title %></title>
    </head>
    <body>
        <%%= content %>
    </body>
</html>

@@ index
%% layout 'default';
%% title 'Hi!';
        <h1>Mojolicious!</h1>
        <p><%%= $message %></p>
        <p><a href="<%%= url_for %>">Reload the page</a></p>


@@ test
% my $class = shift;
use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $ = Test::Mojo->new('<%= $class %>');
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);

done_testing();

__END__

=encoding utf-8

=head1 NAME

Mojolicious::Command::generate::debacle_app - Create Mojolicious app with DBIx and more

=head1 SYNOPSIS

  use Mojolicious::Command::generate::debacle_app;

=head1 DESCRIPTION

Mojolicious::Command::generate::debacle_app is

=head1 AUTHOR

Erik Carlsson E<lt>info@code301.comE<gt>

=head1 COPYRIGHT

Copyright 2014- Erik Carlsson

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
