requires 'perl', '5.020000';

requires 'Mojolicious', '5.25';
requires 'Kavorka', '0.033';
requires 'String::Random', '0.23';
requires 'Config::FromHash', '0.05';
requires 'Mojolicious::Plugin::BootstrapHelpers', '0.009';
requires 'Dist::Zilla', '5.020';
requires 'Dist::Milla', '1.0.0';

on test => sub {
    requires 'Test::More', '0.96';
};
