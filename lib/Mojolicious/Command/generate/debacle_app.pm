package Mojolicious::Command::generate::debacle_app;


our $VERSION = '0.01';

use Syntax::Collection::Basic;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw/class_to_file class_to_path/;

use String::Random;

has description => 'Generate Mojolicious application directory structure (with dbix)';
has usage       => sub { shift->extract_usage };

sub run {
    my $self = shift;
    my $class = shift;

    $class ||= 'MyApp';

    if($class !~ m{^[A-Z](?:\w|::)+$}) {
        die qq{Your application name has to be a well formed (CamelCase) Perl module name, like MyApp};
    }

    # start script
    my $name = class_to_file $class;
    $self->render_to_rel_file('start', "$name/script/$name", $class);

    # application class
    {
        my $app = class_to_path $class;
        $self->render_to_rel_file('appclass', "$name/lib/$app", $class);
    }

    # controller
    {
        my $controller = "${class}::Controller::Example";
        my $path = class_to_path $controller;
        $self->render_to_rel_file('controller', "$name/lib/$path", $controller);
    }

    # schema
    {
        my $schema = "${class}::Schema";
        my $schemapath = class_to_path $schema;
        $self->render_to_rel_file('schema', "$name/lib/$schemapath", $schema);
    }

    # db
    {
        my $db = "${class}::DB";
        my $dbpath = class_to_path $db;
        $self->render_to_rel_file('db', "$name/lib/$dbpath", $db, $class);
    }
    # candy
    {
        my $candy = "${class}::Schema::Candy";
        my $candypath = class_to_path $candy;
        $self->render_to_rel_file('candy', "$name/lib/$candypath", $candy, $class);
    }

    # result
    {
        my $result = "${class}::Schema::Result";
        my $resultpath = class_to_path $result;
        $self->render_to_rel_file('result', "$name/lib/$resultpath", $result);
    }

    # resultset
    {
        my $resultset = "${class}::Schema::ResultSet";
        my $resultsetpath = class_to_path $resultset;
        $self->render_to_rel_file('resultset', "$name/lib/$resultsetpath", $resultset);
    }

    # config
    {
        $self->render_to_rel_file('config_standard', "$name/share/config.conf");
        $self->render_to_rel_file('config_secret', "$name/share/config-secret.conf");
    }

    # templates
    {
        $self->render_to_rel_file('layout', "$name/templates/layouts/default.html.ep");
        $self->render_to_rel_file('index', "$name/templates/example/index.html.ep");
    }

    # db deploy
    {
        $self->render_to_rel_file('dbdeploy', "$name/script/db-deploy.pl", $class);
    }


    # log directory
    {
        $self->create_rel_dir("$name/log");
    }

    # test
    {
        $self->render_to_rel_file('test', "$name/t/basic.t", $class);
    }
}

1;
__DATA__

@@ start
% my $class = shift;
#!/usr/bin/env perl

use Syntax::Collection::Basic;
use FindBin;

BEGIN { unshift @INC, "$FindBin::Bin/../lib" };

require Mojolicious::Commands;
Mojolicious::Commands->start_app('<%= $class %>');


@@ appclass
% my $class = shift;
package <%= $class %> {

    use Mojo::Base 'Mojolicious';
    use Hash::Merge 'merge';

    use Syntax::Collection::Basic;
    use Kavorka;

    method startup {
        $self->setup;

        my $r = $self->routes;
        $r->namespaces(['<%= $class %>::Controller']);

        $r->get('/*message')->to('example#index');
    }

    method setup($app:) {
        my $config_standard = $app->plugin('config', file => 'share/config.conf');
        my $config_secret = $app->plugin('config', file => 'share/config-secret.conf');
        my $config = merge($config_secret => $config_standard);

        $app->secrets($config->{'secrets'});
        $app->defaults(layout => 'default');

        $app->helper(db => sub {
            <%= $class %>::DB->new(config => $config->{'db'});
        })
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
    use Kavorka;

    __PACKAGE__->load_namespaces;

}


@@ db
% my $class = shift;
% my $app_class = shift;
package <%= $class %> {
    use Mojo::Base -base;
    use Syntax::Collection::Basic;
    use Kavorka;

    has 'config';
    has 'schema';

    use vars $AUTOLOAD;

    after new {
        $self->schema = <%= $app_class %>::Schema->connect(
            $self->config->{'dsn'},
            $self->config->{'user'},
            $self->config->{'password'},
            $self->config->{'extra'}
        );
    }

    method AUTOLOAD {
        my $resultset = $AUTOLOAD;
        $resultset =~ s{^<%= $app_class %>::DB::}{};
        return $self->schema->resultset($resultset);
    }

}

@@ candy
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
% my $base = $class; $base =~ s{^(\w+).*}{$1};
package <%= $class %> {
    use parent 'DBIx::Class::Core';

    use Syntax::Collection::Basic;

    __PACKAGE__->load_components(qw/
        Helper::Row::RelationshipDWIM
        InflateColumn::DateTime
    /);

    sub default_result_namespace { '<%= $base %>::Schema::Result' }

}

@@ resultset
% my $class = shift;
package <%= $class %> {
    use base 'DBIx::Class::ResultSet';

    use Syntax::Collection::Basic;

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

Mojolicious::Command::generate::debacle_app - Create Mojolicious app with some DBIx

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
